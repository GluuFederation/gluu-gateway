local oxd = require "oxdweb"
local utils = require "kong.tools.utils"
local http = require "resty.http"
local singletons = require "kong.singletons"
local responses = require "kong.tools.responses"
local constants = require "kong.constants"

local helper = require "kong.plugins.gluu-oauth2-client-auth.helper"
local ngx_re_gmatch = ngx.re.gmatch
local ngx_set_header = ngx.req.set_header

local _M = {}

local function getPath()
    local path = ngx.var.request_uri
    ngx.log(ngx.DEBUG, "request_uri " .. path);
    local indexOf = string.find(path, "?")
    if indexOf ~= nil then
        return string.sub(path, 1, (indexOf - 1))
    end
    return path
end

local function generate_token(api, credential, access_token, rpt_token, expiration, method, path)
    local token, err = singletons.dao.gluu_oauth2_client_auth_tokens:insert({
        api_id = api.id,
        credential_id = credential.id,
        expires_in = expiration,
        access_token = access_token,
        rpt_token = rpt_token,
        path = path,
        method = method
    }, { ttl = expiration or nil }) -- Access tokens are being permanently deleted after 14 days (1209600 seconds)

    if err then
        return responses.send_HTTP_INTERNAL_SERVER_ERROR(err)
    end

    return {
        credential_id = credential.id,
        access_token = token.access_token,
        expires_in = expiration or nil,
        rpt_token = rpt_token,
        path = path,
        method = method
    }
end

local function load_credential_into_memory(client_id)
    local credentials, err = singletons.dao.gluu_oauth2_client_auth_credentials:find_all { client_id = client_id }
    if err then
        return nil, err
    end
    return credentials[1]
end

local function load_credential_from_db(client_id)
    if not client_id then
        return
    end

    local credential_cache_key = singletons.dao.gluu_oauth2_client_auth_credentials:cache_key(client_id)
    local credential, err = singletons.cache:get(credential_cache_key, nil,
        load_credential_into_memory,
        client_id)
    if err then
        return responses.send_HTTP_INTERNAL_SERVER_ERROR(err)
    end
    return credential
end

local function load_token_into_memory(api, access_token, method, path)
    local credentials, err = singletons.dao.gluu_oauth2_client_auth_tokens:find_all { api_id = api.id, access_token = access_token, path = path, method = method }
    local result
    ngx.log(ngx.DEBUG, "Before DB cred" .. api.id .. access_token .. method .. path)
    if err then
        return nil, err
    elseif #credentials > 0 then
        result = credentials[1]
    end
    ngx.log(ngx.DEBUG, "After DB cred" .. api.id .. access_token .. method .. path)
    return result
end

local function retrieve_token_cache(access_token, method, path, exp_sec)
    local token, err
    if access_token then
        local token_cache_key = singletons.dao.gluu_oauth2_client_auth_tokens:cache_key(access_token, method, path)
        ngx.log(ngx.DEBUG, "Cache search: " .. token_cache_key)
        token, err = singletons.cache:get(token_cache_key, { ttl = exp_sec },
            load_token_into_memory, ngx.ctx.api,
            access_token, method, path)
        if err then
            return responses.send_HTTP_INTERNAL_SERVER_ERROR(err)
        end
    end
    return token or nil
end

--- validate the access_token in request. If it's active then cache it and allow for request
-- @param credential: client and plugin info
-- @param req_access_token: token comes in req header
local function validate_credentials(credential, req_access_token)
    -- http request
    local httpc = http.new()

    -- Method and path
    local httpMethod = ngx.req.get_method()
    local path = getPath()
    local tokenResposeBody
    -- check token in cache
    local access_token = retrieve_token_cache(req_access_token, httpMethod, path, nil)

    -- If token is exist in cache the allow
    if not helper.isempty(access_token) then
        ngx.log(ngx.DEBUG, "In cache: access_token found")

        -- *---- uma-rs-check-access ----* After
        ngx.log(ngx.DEBUG, "In cache: Request RPT token to uma-rs-check-access")
        local umaRsCheckAccessRequest = {
            oxd_host = credential.oxd_http_url,
            oxd_id = credential.oxd_id,
            rpt = access_token.rpt_token,
            http_method = httpMethod,
            path = path
        }

        local umaRsCheckAccessResponse = oxd.uma_rs_check_access(umaRsCheckAccessRequest, req_access_token)

        if helper.isempty(umaRsCheckAccessResponse.status) or umaRsCheckAccessResponse.status == "error" or umaRsCheckAccessResponse.access == "denied" then
            ngx.log(ngx.DEBUG, "In cache: Request failed in uma-rs-check-access")
            return { active = false }
        end

        access_token.active = true
        return access_token
    else
        ngx.log(ngx.DEBUG, "access_token not found in cache, so goes to introspect it")

        -- *---- Introspect access token ----*
        local tokenBody = {
            oxd_host = credential.oxd_http_url,
            oxd_id = credential.oxd_id,
            access_token = req_access_token
        }

        tokenResposeBody = oxd.introspect_access_token(tokenBody)

        if helper.isempty(tokenResposeBody.status) or tokenResposeBody.status == "error" then
            return { active = false }
        end

        -- If tokne is not active the return false
        if not tokenResposeBody.data.active then
            ngx.log(ngx.DEBUG, "Introspect token: false")
            return { active = false }
        end

        ngx.log(ngx.DEBUG, "Introspect token: true")
    end

    -- *---- uma-rs-check-access ----* Before
    ngx.log(ngx.DEBUG, "Request **before RPT token to uma-rs-check-access")
    local umaRsCheckAccessRequest = {
        oxd_host = credential.oxd_http_url,
        oxd_id = credential.oxd_id,
        rpt = "",
        http_method = httpMethod,
        path = path
    }

    local umaRsCheckAccessResponse = oxd.uma_rs_check_access(umaRsCheckAccessRequest, req_access_token)

    if helper.isempty(umaRsCheckAccessResponse.status) or umaRsCheckAccessResponse.status == "error" then
        return { active = false }
    end

    -- *---- uma-rp-get-rpt ----*
    ngx.log(ngx.DEBUG, "Request to uma-rp-get-rpt")
    local umaRpGetRptRequest = {
        oxd_host = credential.oxd_http_url,
        oxd_id = credential.oxd_id,
        ticket = umaRsCheckAccessResponse.data.ticket
    }

    local umaRpGetRptRequest = oxd.uma_rp_get_rpt(umaRpGetRptRequest, req_access_token)

    if helper.isempty(umaRpGetRptRequest.status) or umaRpGetRptRequest.status == "error" then
        return { active = false }
    end

    -- *---- uma-rs-check-access ----* After
    ngx.log(ngx.DEBUG, "Request **After RPT token to uma-rs-check-access")
    local umaRsCheckAccessRequest = {
        oxd_host = credential.oxd_http_url,
        oxd_id = credential.oxd_id,
        rpt = umaRpGetRptRequest.data.access_token,
        http_method = httpMethod,
        path = path
    }

    local umaRsCheckAccessResponse = oxd.uma_rs_check_access(umaRsCheckAccessRequest, req_access_token)

    if helper.isempty(umaRsCheckAccessResponse.status) or umaRsCheckAccessResponse.status == "error" or umaRsCheckAccessResponse.data.access == "denied" then
        return { active = false }
    end

    if not helper.isempty(access_token) then
        return access_token
    else
        -- count expire time in second
        local exp_sec = (tokenResposeBody.data.exp - tokenResposeBody.data.iat)
        ngx.log(ngx.DEBUG, "API: " .. ngx.ctx.api.id .. ", Client_id: " .. tokenResposeBody.data.client_id .. ", req_access_token: " .. req_access_token .. ", Token exp: " .. tostring(exp_sec))
        generate_token(ngx.ctx.api, credential, req_access_token, umaRpGetRptRequest.data.access_token, exp_sec, httpMethod, path)
        retrieve_token_cache(req_access_token, httpMethod, path, exp_sec)
        return tokenResposeBody.data
    end
end

local function load_consumer_into_memory(consumer_id, anonymous)
    local result, err = singletons.dao.consumers:find { id = consumer_id }
    if not result then
        if anonymous and not err then
            err = 'anonymous consumer "' .. consumer_id .. '" not found'
        end
        return nil, err
    end
    return result
end

local function set_consumer(consumer, credential)
    ngx_set_header(constants.HEADERS.CONSUMER_ID, consumer.id)
    ngx_set_header(constants.HEADERS.CONSUMER_CUSTOM_ID, consumer.custom_id or "")
    ngx_set_header(constants.HEADERS.CONSUMER_USERNAME, consumer.username or "")
    ngx.ctx.authenticated_consumer = consumer
    if credential then
        ngx.ctx.authenticated_credential = credential
        ngx_set_header(constants.HEADERS.ANONYMOUS, nil) -- in case of auth plugins concatenation
    else
        ngx_set_header(constants.HEADERS.ANONYMOUS, true)
    end
end

-- Fast lookup for credential retrieval depending on the type of the authentication
--
-- All methods must respect:
--
-- @param request ngx request object
-- @param {table} conf Plugin config
-- @return {string} client_id
-- @return {string} access_token
local function retrieve_credentials(request, header_name, conf)
    local client_id, access_token
    local authorization_header = request.get_headers()[header_name]

    if authorization_header then
        local iterator, iter_err = ngx.re.gmatch(authorization_header, "\\s*[Bb]earer\\s+(.+)")
        if not iterator then
            ngx.log(ngx.ERR, iter_err)
            return
        end

        local m, err = iterator()
        if err then
            ngx.log(ngx.ERR, err)
            return
        end

        if m and m[1] then
            local decoded_basic = ngx.decode_base64(m[1])
            if decoded_basic then
                local basic_parts = utils.split(decoded_basic, ":")
                client_id = basic_parts[1]
                access_token = basic_parts[2]
            end
        end
    end

    if conf.hide_credentials then
        request.clear_header(header_name)
    end

    return client_id, access_token
end

function _M.execute(config)
    -- Fetch basic token from header
    local clientId, accessToken = retrieve_credentials(ngx.req, "authorization", config)

    -- check token is empty ot not
    if helper.isempty(accessToken) or helper.isempty(clientId) then
        return responses.send_HTTP_UNAUTHORIZED("Failed to get token from header. Please pass token in authorization header")
    end

    ngx.log(ngx.DEBUG, "gluu-oauth2-client-auth accessToken: " .. accessToken)

    local credential
    if not helper.isempty(clientId) then
        credential = load_credential_from_db(clientId)
    end

    if helper.isempty(credential) then
        return responses.send_HTTP_UNAUTHORIZED("Invalid authentication credentials")
    end

    local validToken = validate_credentials(credential, accessToken)

    ngx.log(ngx.DEBUG, "Check Valid token response : ")
    if not validToken.active then
        ngx.log(ngx.DEBUG, "Unauthorized")
        return responses.send_HTTP_UNAUTHORIZED("Unauthorized")
    end

    -- Retrieve consumer
    local consumer_cache_key = singletons.dao.consumers:cache_key(credential.consumer_id)
    local consumer, err = singletons.cache:get(consumer_cache_key, nil,
        load_consumer_into_memory,
        credential.consumer_id)
    if err then
        return responses.send_HTTP_INTERNAL_SERVER_ERROR(err)
    end

    set_consumer(consumer, credential)

    return -- ACCESS GRANTED
end

return _M