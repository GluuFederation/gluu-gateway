local http = require "resty.http"
local utils = require "kong.tools.utils"
local singletons = require "kong.singletons"
local responses = require "kong.tools.responses"
local constants = require "kong.constants"
local cache = require "kong.cache"

local helper = require "kong.plugins.gluu-oauth2-client-auth.helper"

local _M = {}
local ACCESS_TOKEN = "accesstoken"

local function generate_token(api, credential, access_token, scope, expiration)
    local token, err = singletons.dao.oauth2_tokens:insert({
        api_id = api.id,
        credential_id = credential.id,
        expires_in = expiration,
        token_type = "bearer",
        access_token = access_token,
        scope = scope
    }, {ttl = expiration > 0 and 1209600 or nil}) -- Access tokens are being permanently deleted after 14 days (1209600 seconds)

    if err then
        return responses.send_HTTP_INTERNAL_SERVER_ERROR(err)
    end

    return {
        access_token = token.access_token,
        token_type = "bearer",
        expires_in = expiration > 0 and token.expires_in or nil,
    }
end

-- Fast lookup for credential retrieval depending on the type of the authentication
--
-- All methods must respect:
--
-- @param request ngx request object
-- @param {table} conf Plugin config
-- @return {string} public_key
-- @return {string} private_key
local function retrieve_credentials(request, header_name, conf)
    local client_id, client_secret
    local authorization_header = request.get_headers()[header_name]

    if authorization_header then
        local iterator, iter_err = ngx.re.gmatch(authorization_header, "\\s*[Bb]asic\\s*(.+)")
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
                client_secret = basic_parts[2]
            end
        end
    end

    if conf.hide_credentials then
        request.clear_header(header_name)
    end

    return client_id, client_secret
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

local function retrieve_token(conf, access_token)
    local token, err
    if access_token then
        local token_cache_key = singletons.dao.gluu_oauth2_client_auth_tokens:cache_key(access_token)
        token, err = singletons.cache:get(token_cache_key, nil,
            load_token_into_memory, conf, ngx.ctx.api,
            access_token)
        if err then
            return responses.send_HTTP_INTERNAL_SERVER_ERROR(err)
        end
    end
    return token
end

local function validate_credentials(credential, basicToken)
    -- http request
    local httpc = http.new()

    -- check token in cache
    local cacheToken = retrieve_token(credential.client_id)

    local access_token
    if helper.isempty(cacheToken) then
        -- Request to OP and get access-token
        local accessTokenRespose, err = httpc:request_uri(credential.token_endpoint, {
            method = "POST",
            ssl_verify = false,
            headers = {
                ["Content-Type"] = "application/x-www-form-urlencoded",
                ["Authorization"] = basicToken
            },
            body = "grant_type=client_credentials&scope=uma_protection clientinfo"
        })

        ngx.log(ngx.DEBUG, "gluu-oauth2-client-auth Request : " .. credential.token_endpoint)

        if not pcall(helper.decode, accessTokenRespose.body) then
            ngx.log(ngx.DEBUG, "Error : " .. helper.print_table(err))
            return false
        end

        local accessTokenResposeBody = helper.decode(accessTokenRespose.body)

        ngx.log(ngx.DEBUG, helper.print_table(accessTokenResposeBody))

        if helper.isempty(accessTokenResposeBody["access_token"]) then
            return false
        end

        access_token = accessTokenResposeBody["access_token"]

        -- Insert token
        generate_token(ngx.ctx.api, credential, access_token, accessTokenResposeBody["scope"] or "", accessTokenResposeBody["expires_in"] or 299)
    else
        access_token = cacheToken
    end

    -- Request to OP and get introspect the access_token
    local tokenRespose, err = httpc:request_uri(credential.introspection_endpoint, {
        method = "POST",
        ssl_verify = false,
        headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded",
            ["Authorization"] = "Bearer " .. access_token
        },
        body = "token=" .. access_token
    })

    ngx.log(ngx.DEBUG, "gluu-oauth2-client-auth Request : " .. credential.token_endpoint)

    if not pcall(helper.decode, tokenRespose.body) then
        ngx.log(ngx.DEBUG, "Error : " .. helper.print_table(err))
        return false
    end

    local tokenResposeBody = helper.decode(tokenRespose.body)

    ngx.log(ngx.DEBUG, helper.print_table(tokenResposeBody))

    if helper.isempty(tokenResposeBody["active"]) then
        return false
    end

    return tokenResposeBody["active"]
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
    ngx_set_header(constants.HEADERS.CONSUMER_CUSTOM_ID, consumer.custom_id)
    ngx_set_header(constants.HEADERS.CONSUMER_USERNAME, consumer.username)
    ngx.ctx.authenticated_consumer = consumer
    if credential then
        ngx.ctx.authenticated_credential = credential
        ngx_set_header(constants.HEADERS.ANONYMOUS, nil) -- in case of auth plugins concatenation
    else
        ngx_set_header(constants.HEADERS.ANONYMOUS, true)
    end
end

function _M.execute(config)
    -- Fetch basic token from header
    local basicToken = ngx.req.get_headers()["authorization"]

    -- check token is empty ot not
    if helper.isempty(basicToken) then
        return responses.send_HTTP_UNAUTHORIZED("Failed to get token from header. Please pass basic token in authorization header")
    end

    ngx.log(ngx.DEBUG, "gluu-oauth2-client-auth : " .. basicToken)

    local credential
    local client_id, client_secret = retrieve_credentials(ngx.req, "authorization", config)

    if client_id and client_secret then
        credential = load_credential_from_db(client_id)
    end

    if helper.isempty(credential) or validate_credentials(credential, basicToken) then
        return responses.send_HTTP_UNAUTHORIZED("Invalid authentication credentials")
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