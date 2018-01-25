local utils = require "kong.tools.utils"
local http = require "resty.http"
local singletons = require "kong.singletons"
local responses = require "kong.tools.responses"
local constants = require "kong.constants"

local helper = require "kong.plugins.gluu-oauth2-client-auth.helper"
local ngx_re_gmatch = ngx.re.gmatch
local ngx_set_header = ngx.req.set_header

local _M = {}

local function generate_token(api, credential, access_token, expiration)
    local token, err = singletons.dao.gluu_oauth2_client_auth_tokens:insert({
        api_id = api.id,
        credential_id = credential.id,
        expires_in = expiration,
        access_token = access_token
    }, {ttl = expiration or nil}) -- Access tokens are being permanently deleted after 14 days (1209600 seconds)

    if err then
        return responses.send_HTTP_INTERNAL_SERVER_ERROR(err)
    end

    return {
        credential_id = credential.id,
        access_token = token.access_token,
        expires_in = expiration or nil,
    }
end

--- Retrieve a access_token in a request.
-- Checks for the access_token in URI parameters, then in the `Authorization` header.
-- @param request ngx request object
-- @param conf Plugin configuration
-- @return token access token contained in request (can be a table) or nil
-- @return err
local function retrieve_header_token(request)
    local authorization_header = request.get_headers()["authorization"]
    if authorization_header then
        local iterator, iter_err = ngx_re_gmatch(authorization_header, "\\s*[Bb]earer\\s+(.+)")
        if not iterator then
            return nil, iter_err
        end

        local m, err = iterator()
        if err then
            return nil, err
        end

        if m and #m > 0 then
            return m[1]
        end
    end
end

local function load_credential_into_memory(client_id)
    local credentials, err = singletons.dao.gluu_oauth2_client_auth_credentials:find_all {client_id = client_id}
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
    local credential, err      = singletons.cache:get(credential_cache_key, nil,
        load_credential_into_memory,
        client_id)
    if err then
        return responses.send_HTTP_INTERNAL_SERVER_ERROR(err)
    end
    return credential
end

local function load_token_into_memory(api, access_token)
    local credentials, err = singletons.dao.gluu_oauth2_client_auth_tokens:find_all { api_id = api.id, access_token = access_token }
    local result
    if err then
        return nil, err
    elseif #credentials > 0 then
        result = credentials[1]
    end
    return result
end

local function retrieve_token_cache(access_token, exp_sec)
    local token, err
    if access_token then
        local token_cache_key = singletons.dao.gluu_oauth2_client_auth_tokens:cache_key(access_token)

        token, err = singletons.cache:get(token_cache_key, { ttl = exp_sec },
            load_token_into_memory, ngx.ctx.api,
            access_token)
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

    -- check token in cache
    local access_token = retrieve_token_cache(req_access_token, 0)

    -- If token is exist in cache the allow
    if not helper.isempty(access_token) then
        ngx.log(ngx.DEBUG, "access_token found in cache")
        access_token.active = true
        return access_token
    end

    ngx.log(ngx.DEBUG, "access_token not found in cache, so goes to introspect it")

    -- Request to OP and get openid-configuration
    local opRespose, err = httpc:request_uri(credential.op_host .. "/.well-known/openid-configuration", {
        method = "GET",
        ssl_verify = false
    })

    ngx.log(ngx.DEBUG, "gluu-oauth2-client-auth Request : " .. credential.op_host .. "/.well-known/openid-configuration")
    ngx.log(ngx.DEBUG, (not pcall(helper.decode, opRespose.body)))

    if not pcall(helper.decode, opRespose.body) then
        ngx.log(ngx.DEBUG, "Error : " .. helper.print_table(err))
        return false
    end

    local opResposebody = helper.decode(opRespose.body)

    -- Request to OP and get introspect the access_token
    local tokenRespose, err = httpc:request_uri(opResposebody.introspection_endpoint, {
        method = "POST",
        ssl_verify = false,
        headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded",
            ["Authorization"] = "Bearer " .. req_access_token
        },
        body = "token=" .. req_access_token
    })

    ngx.log(ngx.DEBUG, "gluu-oauth2-client-auth Request : " .. opResposebody.introspection_endpoint)

    -- Exception handling for check response body is parse properly or not
    if not pcall(helper.decode, tokenRespose.body) then
        ngx.log(ngx.DEBUG, "Error : " .. helper.print_table(err))
        return { active = false }
    end

    -- Decode token body -- string to lua object
    local tokenResposeBody = helper.decode(tokenRespose.body)

    -- If tokne is not active the return false
    if helper.isempty(tokenResposeBody.active) and not tokenResposeBody.active then
        ngx.log(ngx.DEBUG, "Introspect token: false")
        return { active = false }
    end

    ngx.log(ngx.DEBUG, "Introspect token: true")
    -- If token is active then insert token in db and cache it.
    ngx.log(ngx.DEBUG, "introspection_endpoint response: ")
    helper.print_table(tokenResposeBody)

    -- count expire time in second
    local exp_sec = (tokenResposeBody.exp - tokenResposeBody.iat)

    ngx.log(ngx.DEBUG, "API: " .. ngx.ctx.api.id .. ", Client_id: " .. tokenResposeBody.client_id .. ", req_access_token: " .. req_access_token .. ", Token exp: " .. tostring(exp_sec))
    generate_token(ngx.ctx.api, credential, req_access_token, exp_sec)

    retrieve_token_cache(req_access_token, exp_sec)

    return tokenResposeBody
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
        ngx.log(ngx.DEBUG, "Invalid authentication credentials - Token is not active")
        return responses.send_HTTP_UNAUTHORIZED("Invalid authentication credentials. Token is expired")
    end

    -- Retrieve consumer
    local consumer_cache_key = singletons.dao.consumers:cache_key(credential.consumer_id)
    local consumer, err      = singletons.cache:get(consumer_cache_key, nil,
        load_consumer_into_memory,
        credential.consumer_id)
    if err then
        return responses.send_HTTP_INTERNAL_SERVER_ERROR(err)
    end

    set_consumer(consumer, credential)

    return -- ACCESS GRANTED
end

return _M