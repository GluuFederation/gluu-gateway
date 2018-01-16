local http = require "resty.http"
local utils = require "kong.tools.utils"
local singletons = require "kong.singletons"
local responses = require "kong.tools.responses"
local constants = require "kong.constants"

local helper = require "kong.plugins.gluu-oauth2-client-auth.helper"

local _M = {}

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

local function validate_credentials(config, basicToken)
    ngx.log(ngx.DEBUG, "In validate_credentials")
    -- http request
    local httpc = http.new()

    -- Request to OP and get openid-configuration
    local tokenRespose, err = httpc:request_uri(config.token_endpoint, {
        method = "POST",
        ssl_verify = false,
        headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded",
            ["Authorization"] = basicToken
        },
        body = "grant_type=client_credentials&scope=uma_protection clientinfo"
    })

    ngx.log(ngx.DEBUG, "Request : " .. config.token_endpoint)

    if not pcall(helper.decode, tokenRespose.body) then
        ngx.log(ngx.DEBUG, "Error : " .. helper.print_table(err))
        return false
    end

    local tokenResposeBody = helper.decode(tokenRespose.body)

    ngx.log(ngx.DEBUG, helper.print_table(tokenResposeBody))

    if helper.isempty(tokenResposeBody["access_token"]) then
        return false
    end

    return true;
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