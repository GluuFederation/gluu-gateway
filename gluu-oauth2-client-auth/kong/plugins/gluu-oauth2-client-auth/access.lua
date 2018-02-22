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

local function generate_token(api, client_id, access_token, rpt_token, expiration, method, path)
    local token, err = singletons.dao.gluu_oauth2_client_auth_tokens:insert({
        api_id = api.id,
        client_id = client_id,
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
        client_id = client_id,
        access_token = token.access_token,
        expires_in = expiration or nil,
        access_token = access_token,
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

local function load_credential_from_cache(client_id)
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
local function validate_credentials(conf, req_access_token)
    -- Method and path
    local httpMethod = ngx.req.get_method()
    local path = getPath()
    local tokenResposeBody
    local credential
    -- check token in cache
    local access_token = retrieve_token_cache(req_access_token, httpMethod, path, nil)

    -- If token is exist in cache the allow
    if not helper.is_empty(access_token) then
        ngx.log(ngx.DEBUG, "access_token found in cache")
        print("access_token found in cache")
        credential = load_credential_from_cache(access_token.client_id)
        access_token.credential = credential
        access_token.active = true
        return access_token
    end

    ngx.log(ngx.DEBUG, "access_token not found in cache, so goes to introspect it")
    print("access_token not found in cache, so goes to introspect it")
    -- *---- Introspect token ----*
    local tokenResponse = helper.introspect_access_token(conf, req_access_token);

    if tokenResponse.data.active then
        tokenResponse.isOAuth = true
    else
        tokenResponse = helper.introspect_rpt(conf, req_access_token);
        tokenResponse.isUMA = true
    end

    if not tokenResponse.data.active then
        tokenResponse.active = false;
        return tokenResponse
    end

    if pcall(function () print("Client Id: " .. tokenResponse.data.client_id) end) then
        ngx.log(ngx.DEBUG, "Client Id: " .. tokenResponse.data.client_id)
    else
        ngx.log(ngx.DEBUG, "Failed to fetch client id from introspect token")
        return { active = false }
    end

    ngx.log(ngx.DEBUG, "Introspect token isOAuth: " .. helper.ternary(tokenResponse.isOAuth, "true", "false") .. " isUMA: " .. helper.ternary(tokenResponse.isUMA, "true", "false"))
    credential = load_credential_from_cache(tokenResponse.data.client_id)

    -- count expire time in second
    local exp_sec = (tokenResponse.data.exp - tokenResponse.data.iat)
    ngx.log(ngx.DEBUG, "API: " .. ngx.ctx.api.id .. ", Client_id: " .. tokenResponse.data.client_id .. ", req_access_token: " .. req_access_token .. ", Token exp: " .. tostring(exp_sec))
    generate_token(ngx.ctx.api,
        tokenResponse.data.client_id,
        helper.ternary(tokenResponse.isOAuth, req_access_token, ''),
        helper.ternary(tokenResponse.isUMA, req_access_token, ''),
        exp_sec,
        httpMethod,
        path)
    retrieve_token_cache(req_access_token, httpMethod, path, exp_sec)

    tokenResponse.active = true;
    tokenResponse.credential = credential
    return tokenResponse
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

--- Retrieve a RPT token in the `Authorization` header.
-- @param request ngx request object
-- @param conf Plugin configuration
-- @return RPT token or nil
-- @return err
local function retrieve_token(request, conf, header_name)
    local authorization_header = request.get_headers()[header_name]
    if authorization_header then
        local iterator, iter_err = ngx_re_gmatch(authorization_header, "\\s*[Bb]earer\\s+(.+)")
        if not iterator then
            return nil, iter_err
        end

        local m, err = iterator()
        if err then
            return nil, err
        end

        if conf.hide_credentials then
            request.clear_header(header_name)
        end

        if m and #m > 0 then
            return m[1]
        end
    end
end

function _M.execute(config)
    -- Fetch basic token from header
    local accessToken = retrieve_token(ngx.req, config, "authorization")

    if helper.is_empty(accessToken) then
        return responses.send_HTTP_UNAUTHORIZED("Unauthorized")
    end

    local responseValidCredential = validate_credentials(config, accessToken)

    ngx.log(ngx.DEBUG, "Check Valid token response : ")

    if not responseValidCredential.active then
        ngx.log(ngx.DEBUG, "Unauthorized")
        return responses.send_HTTP_UNAUTHORIZED("Unauthorized")
    end

    if config.kong_acts_as_uma_client and responseValidCredential.isRPT then
        ngx.header["Authorization"] = "Bearer " .. accessToken
    end

    -- Retrieve consumer
    local consumer_cache_key = singletons.dao.consumers:cache_key(responseValidCredential.credential.consumer_id)
    local consumer, err = singletons.cache:get(consumer_cache_key, nil,
        load_consumer_into_memory,
        responseValidCredential.credential.consumer_id)
    if err then
        return responses.send_HTTP_INTERNAL_SERVER_ERROR(err)
    end

    set_consumer(consumer, responseValidCredential.credential)

    return -- ACCESS GRANTED
end

return _M