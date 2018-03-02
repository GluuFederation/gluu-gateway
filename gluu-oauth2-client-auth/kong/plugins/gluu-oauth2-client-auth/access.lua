local singletons = require "kong.singletons"
local responses = require "kong.tools.responses"
local constants = require "kong.constants"

local helper = require "kong.plugins.gluu-oauth2-client-auth.helper"
local ngx_re_gmatch = ngx.re.gmatch
local ngx_set_header = ngx.req.set_header
local PLUGINNAME = "gluu-oauth2-client-auth"

local _M = {}

--- Get path from requested URL
-- Example: request URL is https://api.com/photos then path is /photos
-- @return path
local function getPath()
    local path = ngx.var.request_uri
    ngx.log(ngx.DEBUG, "request_uri " .. path)
    local indexOf = string.find(path, "?")
    if indexOf ~= nil then
        return string.sub(path, 1, (indexOf - 1))
    end
    return path
end

--- Return table formate data for caching
-- @return if client_id is set then return valid data otherwise nil
local function get_token_data(token)
    local result
    if not helper.is_empty(token) and not helper.is_empty(token.client_id) then
        result = {
            client_id = token.client_id,
            exp = token.exp,
            consumer_id = token.consumer_id,
            token_type = token.token_type,
            scope = token.scope,
            iss = token.iss,
            permissions = token.permissions,
            iat = token.iat,
            associated_rpt = token.associated_rpt,
            associated_oauth_token = token.associated_oauth_token,
            pct = token.pct,
            claim_tokens = token.claim_tokens,
            active = token.active
        }
    end

    return result
end

--- Used to fetch oauth2-consumer from kong DB based on client-id
-- @param client_id: Client identifier for the OAuth 2.0 client
-- @return oauth2-consumer { id: '...', client_id: '..', client_secret: '...', oxd_id: '...', ...}
local function get_oauth2_consumer(client_id)
    local credentials, err = singletons.dao.gluu_oauth2_client_auth_credentials:find_all { client_id = client_id }
    if err then
        return nil, err
    end
    return credentials[1]
end

--- Used to get or set oauth2-consumer data in kong cache
-- @param client_id: Client identifier for the OAuth 2.0 client
-- @return If data is in cache then return from cache otherwise call `load_credential_into_memory` callback method and return oauth2-consumer
local function get_set_oauth2_consumer(client_id)
    if not client_id then
        return
    end

    local credential_cache_key = singletons.dao.gluu_oauth2_client_auth_credentials:cache_key(client_id)
    local credential, err = singletons.cache:get(credential_cache_key, nil,
        get_oauth2_consumer,
        client_id)
    if err then
        return responses.send_HTTP_INTERNAL_SERVER_ERROR(err)
    end
    return credential
end

--- Get or set token cache token from cache
-- If token not in cache then call load_token_into_memory function and set values in cache return by load_token_into_memory.
-- @param req_token: token from authrorization request header
-- @param method: Requested http method
-- @param path: Requested path
-- @param exp_sec: Expiration time for cache in seccond
-- @return { rpt, method, path }
local function get_set_token_cache(req_token, method, path, token)
    local result, err
    if req_token then
        local token_cache_key = PLUGINNAME .. req_token .. method .. path
        ngx.log(ngx.DEBUG, "Cache search: " .. token_cache_key)

        result, err = singletons.cache:get(token_cache_key, { ttl = (token and token.exp_sec) or nil },
            get_token_data, token)
        if err then
            return responses.send_HTTP_INTERNAL_SERVER_ERROR(err)
        end
    end
    return result or nil
end

--- Used to fetch consumer data from kong DB based on consumer_id
-- @param consumer_id: id of the consumer
-- @param anonymous: check anonymous consumer
-- @return return consumer Example: { id: "<id>", username: "foo", custom_id: "foo" }
local function get_consumer(consumer_id, anonymous)
    local result, err = singletons.dao.consumers:find { id = consumer_id }
    if not result then
        if anonymous and not err then
            err = 'anonymous consumer "' .. consumer_id .. '" not found'
        end
        return nil, err
    end
    return result
end

--- When a client has been authenticated, the plugin will append some headers to the request before proxying it to the upstream API/Microservice, so that you can identify the Consumer in your code
-- @param consumer: consumer data
-- @param credential: oauth2-consumer data
local function set_consumer_in_header(consumer, credential)
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

--- Retrieve a RPT token from the `Authorization` header.
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

--- validate the token in request. If it's active then cache it and allow for request
-- @param credential: client and plugin info
-- @param req_token: token from authrorization request header
local function validate_credentials(conf, req_token)
    -- Method and path
    local httpMethod = ngx.req.get_method()
    local path = getPath()
    local tokenResposeBody
    local credential

    -- check token in cache
    local cacheToken = get_set_token_cache(req_token, httpMethod, path, nil)

    -- If token is exist in cache the allow
    if not helper.is_empty(cacheToken) then
        ngx.log(ngx.DEBUG, "token found in cache")
        credential = get_set_oauth2_consumer(cacheToken.client_id)
        cacheToken.credential = credential

        if cacheToken.token_type == "OAuth" and credential.kong_acts_as_uma_client then
            ngx_set_header("Authorization", "Bearer " .. credential.associated_rpt)
        end

        return cacheToken
    end

    ngx.log(ngx.DEBUG, "token not found in cache, so goes to introspect it")
    -- *---- Introspect token ----*
    local tokenResponse = helper.introspect_access_token(conf, req_token)
    local tokenType
    if tokenResponse.data.active then
        tokenType = "OAuth"
    else
        tokenResponse = helper.introspect_rpt(conf, req_token)
        tokenResponse.isUMA = true
        tokenType = "UMA"
    end

    -- token is active=false then Unauthorized 401
    if not tokenResponse.data.active then
        tokenResponse.active = false
        return tokenResponse
    end

    -- check client_id is available in introspect response or not
    if pcall(function() print("Client Id: " .. tokenResponse.data.client_id) end) then
        ngx.log(ngx.DEBUG, "Client Id: " .. tokenResponse.data.client_id)
    else
        ngx.log(ngx.DEBUG, "Failed to fetch client id from introspect token")
        return { active = false }
    end

    ngx.log(ngx.DEBUG, "Introspect token type: " .. tokenType)

    -- Fetch oauth2-consumer using client_id
    credential = get_set_oauth2_consumer(tokenResponse.data.client_id)

    -- count expire time in second
    local exp_sec = (tokenResponse.data.exp - tokenResponse.data.iat)
    ngx.log(ngx.DEBUG, "Client_id: " .. tokenResponse.data.client_id .. ", req_token: " .. req_token .. ", Token exp: " .. tostring(exp_sec) .. " native_uma_client: " .. tostring(credential.native_uma_client))

    -- tokenType == "UMA" and native_uma_client=false so Unauthorized 401/token can't be validate
    local umaPlugin, err
    if tokenType == "UMA" and not credential.native_uma_client then
        ngx.log(ngx.DEBUG, PLUGINNAME .. " tokenType = UMA and native_uma_client=false so response is Unauthorized 401/token can't be validate")
        tokenResponse.active = false
        return tokenResponse
    end

    if tokenType == "OAuth" and not credential.kong_acts_as_uma_client then
        umaPlugin, err = singletons.dao.plugins:find_all { name = "kong-uma-rs" }
        if err then
            ngx.log(ngx.DEBUG, PLUGINNAME .. " kong-uma-rs is not configured")
            umaPlugin = nil
        else
            ngx.log(ngx.DEBUG, PLUGINNAME .. " kong-uma-rs is configured")
            umaPlugin = umaPlugin[1]
        end
    end

    -- Invalidate(clear) the cache if exist
    singletons.cache:invalidate(PLUGINNAME .. req_token .. httpMethod .. path)

    -- set remaining data for caching
    local cacheTokenData = tokenResponse.data
    cacheTokenData.exp_sec = exp_sec
    cacheTokenData.token_type = tokenType
    cacheTokenData.associated_rpt = helper.ternary(tokenType == "UMA", req_token, nil)
    cacheTokenData.associated_oauth_token = helper.ternary(tokenType == "OAuth", req_token, nil)

    -- set token data in cache for exp_sec(time in second)
    get_set_token_cache(req_token, httpMethod, path, cacheTokenData)

    -- oauth2-consumer data : later on use to send consumer detail in req header. See below set_consumer method for detail
    cacheTokenData.credential = credential

    return cacheTokenData
end

--- Start execution. Call by handler.lua access event
-- @param conf: Global configuration oxd_id, client_id and client_secret
-- @return ACCESS GRANTED and Unauthorized
function _M.execute_access(config)
    -- Fetch basic token from header
    local token = retrieve_token(ngx.req, config, "authorization")

    if helper.is_empty(token ) then
        return responses.send_HTTP_UNAUTHORIZED("Unauthorized")
    end

    local responseValidCredential = validate_credentials(config, token )

    ngx.log(ngx.DEBUG, "Check Valid token response : ")

    if not responseValidCredential.active then
        ngx.log(ngx.DEBUG, "Unauthorized")
        return responses.send_HTTP_UNAUTHORIZED("Unauthorized")
    end

    -- Retrieve consumer
    local consumer_cache_key = singletons.dao.consumers:cache_key(responseValidCredential.credential.consumer_id)
    local consumer, err = singletons.cache:get(consumer_cache_key, nil,
        get_consumer,
        responseValidCredential.credential.consumer_id)
    if err then
        return responses.send_HTTP_INTERNAL_SERVER_ERROR(err)
    end

    set_consumer_in_header(consumer, responseValidCredential.credential)

    return -- ACCESS GRANTED
end

--- Start execution. Call by handler.lua header_filter event
-- @param conf: Global configuration oxd_id, client_id and client_secret
-- @return ACCESS GRANTED and Unauthorized
function _M.execute_header_filter(config)
    if ngx.status ~= 401 then
        ngx.log(ngx.DEBUG, "Not get 401/Unauthtorized")
        return -- ACCESS GRANTED
    end
    local httpMethod = ngx.req.get_method()
    local path = getPath()
    local reqToken = retrieve_token(ngx.req, config, "authorization")

    if helper.is_empty(reqToken) then
        return -- Return response comes from access method 401/Unauthorized
    end

    ngx.log(ngx.DEBUG, "Get 401/Unauthtorized" .. reqToken)

    -- check token in cache
    local cacheTokenData = get_set_token_cache(reqToken, httpMethod, path, nil)
    if helper.is_empty(cacheTokenData) then
        return -- Return response comes from access method 401/Unauthorized
    end

    local credential = get_set_oauth2_consumer(cacheTokenData.client_id)

    if not credential.kong_acts_as_uma_client then
        ngx.log(ngx.DEBUG, "kong_acts_as_uma_client" .. tostring(credential.kong_acts_as_uma_client))
        return -- Return response comes from access method 401/Unauthorized
    end

    local ticket = helper.get_ticket_from_www_authenticate_header(ngx.header["www-authenticate"])
    ngx.log(ngx.DEBUG, "Ticket from www-authenticate header" .. ticket)
--    local umaPlugin = responseValidCredential.umaPlugin
--    helper.print_table(umaPlugin)
--    local rpt = helper.get_rpt(umaPlugin.config)

--    if helper.is_empty(rpt) then
--        return responses.send_HTTP_UNAUTHORIZED("Unauthorized! Forbidden")
--    end

--    Invalidate(clear) the cache if exist
--    singletons.cache:invalidate(PLUGINNAME .. accessToken .. httpMethod .. path)
    ngx.status = 205
    ngx.exit(205)
end

return _M