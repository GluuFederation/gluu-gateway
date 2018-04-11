local cjson = require "cjson"
local singletons = require "kong.singletons"
local responses = require "kong.tools.responses"
local constants = require "kong.constants"

local helper = require "kong.plugins.gluu-oauth2-client-auth.helper"
local ngx_re_gmatch = ngx.re.gmatch
local ngx_set_header = ngx.req.set_header
local PLUGINNAME = "gluu-oauth2-client-auth"
local RS_PLUGINNAME = "gluu-oauth2-rs"
local OAUTH_CLIENT_ID = "x-oauth-client-id"
local OAUTH_EXPIRATION = "x-oauth-expiration"
local OAUTH_SCOPES = "x-authenticated-scope"

local _M = {}

--- Get path from requested URL
-- Example: request URL is https://api.com/photos then path is /photos
-- @return path
local function getPath()
    local path = ngx.var.request_uri
    ngx.log(ngx.DEBUG, PLUGINNAME .. " : request_uri " .. path)
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
            client_id_of_oxd_id = token.client_id_of_oxd_id,
            exp = token.exp,
            exp_sec = token.exp_sec,
            consumer_id = token.consumer_id,
            token_type = token.token_type,
            scopes = token.scopes,
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
    -- Find consumer by client_id
    local credentials, err = singletons.dao.gluu_oauth2_client_auth_credentials:find_all { client_id = client_id }
    if err then
        return nil, err
    end

    if not helper.is_empty(credentials[1]) then
        ngx.log(ngx.DEBUG, PLUGINNAME .. ": Found consumer by client_id")
        return credentials[1]
    end

    -- Find consumer by client_id_of_oxd_id
    credentials, err = singletons.dao.gluu_oauth2_client_auth_credentials:find_all { client_id_of_oxd_id = client_id }
    if err then
        return nil, err
    end

    ngx.log(ngx.DEBUG, PLUGINNAME .. ": Found consumer by client_id_of_oxd_id")
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
-- @param token: Token Json for cache
-- @return { token JSON }
local function get_set_token_cache(req_token, token)
    local result, err
    if req_token then
        local token_cache_key = req_token
        ngx.log(ngx.DEBUG, PLUGINNAME .. " : Cache search: " .. token_cache_key)

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
    ngx_set_header(constants.HEADERS.CONSUMER_USERNAME, consumer.username or "")
    ngx.ctx.authenticated_consumer = consumer
    if credential then
        if credential.show_consumer_custom_id then
            ngx_set_header(constants.HEADERS.CONSUMER_CUSTOM_ID, consumer.custom_id or "")
        end
        ngx.ctx.authenticated_credential = credential
        ngx_set_header(constants.HEADERS.ANONYMOUS, nil)
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
    local tokenResposeBody
    local credential

    -- check token in cache
    local cacheToken = get_set_token_cache(req_token, nil)

    -- If token is exist in cache the allow
    if not helper.is_empty(cacheToken) then
        ngx.log(ngx.DEBUG, PLUGINNAME .. ": Token found in cache")
        credential = get_set_oauth2_consumer(cacheToken.client_id)
        cacheToken.credential = credential

        -- Check Restricted API
        if (not helper.is_empty(credential.restrict_api) and credential.restrict_api) then
            local restrictedAPIs = helper.split(credential.restrict_api_list, ",")
            if helper.find(restrictedAPIs, tostring(ngx.ctx.api.id)) == 0 then
                ngx.log(ngx.DEBUG, "401 / Unauthorized - Out of available Restricted API")
                return { active = false }
            end
        end

        if cacheToken.token_type == "OAuth" and credential.mix_mode then
            ngx.log(ngx.DEBUG, PLUGINNAME .. ": mix_mode = true rpt: " .. tostring(cacheToken.associated_rpt))
            ngx_set_header("Authorization", "Bearer " .. (cacheToken.associated_rpt or req_token))
        end

        -- If (tokenType == OAuth)(oauth_mode == true) then set header
        if cacheToken.token_type == "OAuth" and credential.oauth_mode == true then
            ngx_set_header(OAUTH_CLIENT_ID, cacheToken.client_id)
            ngx_set_header(OAUTH_SCOPES, table.concat(cacheToken.scopes, ","))
            ngx_set_header(OAUTH_EXPIRATION, cacheToken.exp)
        end

        return cacheToken
    end

    ngx.log(ngx.DEBUG, PLUGINNAME .. ": Token not found in cache, so goes to introspect it")
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
        ngx.log(ngx.DEBUG, PLUGINNAME .. ": Client Id: " .. tokenResponse.data.client_id)
    else
        ngx.log(ngx.DEBUG, PLUGINNAME .. ": Failed to fetch client id from introspect token")
        return { active = false }
    end

    ngx.log(ngx.DEBUG, PLUGINNAME .. ": Introspect token type: " .. tokenType)

    -- Fetch oauth2-consumer using client_id
    credential = get_set_oauth2_consumer(tokenResponse.data.client_id)

    if helper.is_empty(credential) then
        ngx.log(ngx.DEBUG, PLUGINNAME .. ": Failed to fetch oauth2 credential for client id : " .. tokenResponse.data.client_id)
        return { active = false }
    end

    -- count expire time in second
    local exp_sec = (tokenResponse.data.exp - tokenResponse.data.iat)
    ngx.log(ngx.DEBUG, PLUGINNAME .. ": Client_id: " .. tokenResponse.data.client_id .. ", req_token: " .. req_token .. ", Token exp: " .. tostring(exp_sec) .. " uma_mode: " .. tostring(credential.uma_mode))

    -- tokenType == "UMA" and uma_mode=false so Unauthorized 401/token can't be validate
    local umaPlugin, err
    if tokenType == "UMA" and not credential.uma_mode then
        ngx.log(ngx.DEBUG, PLUGINNAME .. " tokenType = UMA and uma_mode=false so response is Unauthorized 401/token can't be validate")
        tokenResponse.active = false
        return tokenResponse
    end

    -- Check scope security
    --    if not helper.subset(helper.split(credential.scope, ","), tokenResponse.data.scopes) then
    --        ngx.log(ngx.DEBUG, "401 / Unauthorized - Token with insufficient_scope")
    --        return { active = false }
    --    end

    -- Check Restricted API
    if (not helper.is_empty(credential.restrict_api) and credential.restrict_api) then
        local restrictedAPIs = helper.split(credential.restrict_api_list, ",")
        if helper.find(restrictedAPIs, tostring(ngx.ctx.api.id)) == 0 then
            ngx.log(ngx.DEBUG, "401 / Unauthorized - Out of available Restricted API")
            return { active = false }
        end
    end

    -- If (tokenType == OAuth)(oauth_mode == true) then set header
    if tokenType == "OAuth" and credential.oauth_mode == true then
        ngx_set_header(OAUTH_CLIENT_ID, tokenResponse.data.client_id)
        ngx_set_header(OAUTH_SCOPES, table.concat(tokenResponse.data.scopes, ","))
        ngx_set_header(OAUTH_EXPIRATION, tokenResponse.data.exp)
    end

    -- Invalidate(clear) the cache if exist
    singletons.cache:invalidate(req_token)

    -- set remaining data for caching
    local cacheTokenData = tokenResponse.data
    cacheTokenData.exp_sec = exp_sec
    cacheTokenData.scopes = tokenResponse.data.scopes
    cacheTokenData.token_type = tokenType
    cacheTokenData.associated_rpt = helper.ternary(tokenType == "UMA", req_token, nil)
    cacheTokenData.associated_oauth_token = helper.ternary(tokenType == "OAuth", req_token, nil)
    cacheTokenData.permissions = {}
    cacheTokenData.claim_tokens = {}

    -- set token data in cache for exp_sec(time in second)
    get_set_token_cache(req_token, cacheTokenData)

    -- oauth2-consumer data : later on use to send consumer detail in req header. See below set_consumer method for detail
    cacheTokenData.credential = credential

    return cacheTokenData
end

--- Start execution. Call by handler.lua access event
-- @param conf: Global configuration oxd_id, client_id and client_secret
-- @return ACCESS GRANTED and Unauthorized
function _M.execute_access(config)
    ngx.log(ngx.DEBUG, "Enter in gluu-oauth2-client-auth plugin")
    -- Fetch basic token from header
    local token = retrieve_token(ngx.req, config, "authorization")

    if helper.is_empty(token) then
        local credentials, err = singletons.dao.plugins:find_all { name = RS_PLUGINNAME }
        if err then
            return responses.send_HTTP_UNAUTHORIZED("Unauthorized")
        end

        -- Check gluu-oauth2-rs plugin is configured or not. If configured then control passing to gluu-oauth2-rs plugin and return Unauhorized 401 + ticket
        if not helper.is_empty(credentials[1]) then
            ngx.log(ngx.DEBUG, "Token not found in header, so control passing to gluu-oauth2-rs plugin and return Unauthorized 401 + ticket")
            return -- Controle goes to gluu-oauth2-rs plugin and return ticket
        end

        -- If gluu-oauth2-rs is not configured then return Unauthorized 401
        return responses.send_HTTP_UNAUTHORIZED("Unauthorized")
    end

    ngx.log(ngx.DEBUG, PLUGINNAME .. ": Requested token : " .. token)

    -- Check token
    local responseValidCredential = validate_credentials(config, token)

    if responseValidCredential.active then
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
    else
        ngx.log(ngx.DEBUG, "Unauthorized")
        if config.anonymous ~= "" then
            -- get anonymous user
            local consumer_cache_key = singletons.dao.consumers:cache_key(config.anonymous)
            local consumer, err = singletons.cache:get(consumer_cache_key, nil,
                get_consumer,
                config.anonymous, true)
            if err then
                return responses.send_HTTP_INTERNAL_SERVER_ERROR(err)
            end
            set_consumer_in_header(consumer, nil)
        else
            return responses.send_HTTP_UNAUTHORIZED("Unauthorized")
        end
    end
end

return _M