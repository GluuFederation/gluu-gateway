local constants = require "kong.constants"
local oxd = require "oxdweb"
local helper = require "kong.plugins.gluu-client-auth.helper"
local pl_types = require "pl.types"
-- we don't store our token in lrucache - we don't want it be pushed out
local access_token
local access_token_expire = 0
local EXPIRE_DELTA = 10

local PLUGINNAME = "gluu-client-auth"

local lrucache = require "resty.lrucache"
-- it can be shared by all the requests served by each nginx worker process:
local worker_cache, err = lrucache.new(1000) -- allow up to 1000 items in the cache
if not worker_cache then
    return error("failed to create the cache: " .. (err or "unknown"))
end

local function unexpected_error(...)
    kong.log.err(...)
    kong.response.exit(500, { message = "An unexpected error ocurred" })
end

local function load_consumer_by_id(consumer_id)
    local result, err = kong.db.consumers:select({ id = consumer_id })
    if not result then
        print(err)
        if not err then
            err = 'consumer "' .. consumer_id .. '" not found'
        end

        return nil, err
    end
    kong.log.debug("consumer loaded")
    return result
end

local function set_consumer(consumer, client_id, exp)
    local const = constants.HEADERS
    local new_headers = {
        [const.CONSUMER_ID] = consumer.id,
        [const.CONSUMER_CUSTOM_ID] = tostring(consumer.custom_id),
        [const.CONSUMER_USERNAME] = tostring(consumer.username),
    }
    -- https://github.com/Kong/kong/blob/2cdd07e34a362e86d95d5e88615e217fa4f6f0d2/kong/plugins/key-auth/handler.lua#L52
    kong.ctx.shared.authenticated_consumer = consumer -- forward compatibility
    ngx.ctx.authenticated_consumer = consumer -- backward compatibility

    if client_id then
        new_headers["X-OAuth-Client-ID"] = tostring(client_id)
        new_headers["X-OAuth-Expiration"] = tostring(exp)
        -- TODO what about kong.ctx.shared.authenticated_credential?
        kong.service.request.clear_header(const.ANONYMOUS) -- in case of auth plugins concatenation
    else
        new_headers[const.ANONYMOUS] = true
    end
    kong.service.request.set_headers(new_headers)
end

local function get_token(authorization)
    if authorization and #authorization > 0 then
        local from, to, err = ngx.re.find(authorization, "\\s*[Bb]earer\\s+(.+)", "jo", nil, 1)
        if from then
            return authorization:sub(from, to) -- Return token
        end
        if err then
            return unexpected_error(err)
        end
    end

    return nil
end

local function get_protection_token(conf)
    local now = ngx.now()
    kong.log.debug("Current datetime: ", now, " access_token_expire: ", access_token_expire)
    if not access_token or access_token_expire < now + EXPIRE_DELTA then
        -- TODO possible race condition when access_token == nil
        access_token_expire = access_token_expire + EXPIRE_DELTA -- avoid multiple token requests
        local response = oxd.get_client_token(conf.oxd_url,
            {
                client_id = conf.client_id,
                client_secret = conf.client_secret,
                scope = "openid profile email",
                op_host = conf.op_url,
            })

        local status = response.status
        local body = response.body

        kong.log.debug("Protection access token -- status: ", status)
        if status >= 300 or not body.access_token then
            access_token = nil
            access_token_expire = 0
            return unexpected_error("Failed to get access token.")
        end

        access_token = body.access_token
        if body.expires_in then
            access_token_expire = ngx.now() + body.expires_in
        else
            -- use once
            access_token_expire = 0
        end
    end
end

local function build_cache_key(token, allow_oauth_scope_expression)
    if not allow_oauth_scope_expression then
        return token
    end
    local t = {
        token,
        ":",
        ngx.var.uri,
        ":",
        ngx.req.get_method()
    }
    return table.concat(t)
end

local function do_authentication(conf)
    local authorization = ngx.var.http_authorization
    local token = get_token(authorization)

    -- Hide credentials
    kong.log.debug("hide_credentials: ", conf.hide_credentials)
    if conf.hide_credentials then
        kong.ctx.shared.authorization_token = token
        kong.log.debug("Hide authorization header")
        kong.service.request.clear_header("authorization")
    end

    if not token then
        return 401, "Failed to get bearer token from Authorization header"
    end

    local body, stale_data = worker_cache:get(build_cache_key(token, conf.allow_oauth_scope_expression))
    if body and not stale_data then
        -- we're already authenticated
        kong.log.debug("Token cache found. we're already authenticated")
        set_consumer(body.consumer, body.client_id, body.exp)
        return 200
    end

    -- Get protection access token for OXD API
    get_protection_token(conf)

    kong.log.debug("Token cache not found.")
    local response = oxd.introspect_access_token(conf.oxd_url,
        {
            oxd_id = conf.oxd_id,
            access_token = token,
        },
        access_token)
    local status = response.status

    if status == 403 then
        -- TODO should we cache negative resposes? https://github.com/GluuFederation/gluu-gateway/issues/213
        return 401, "Invalid access token provided in Authorization header"
    end

    if status ~= 200 then
        return unexpected_error("introspect-access-token error, status: ", status)
    end

    body = response.body
    if not body.active then
        return 401, "Token is not active"
    end

    local consumer = worker_cache:get(body.client_id)

    if not consumer then
        local consumer_local, err = kong.db.consumers:select_by_custom_id(body.client_id)
        if not consumer_local and not err then
            err = 'consumer with custom_id "' .. custom_id .. '" not found'
        end
        if err then
            return unexpected_error("select_by_custom_id error: ", err)
        end
        consumer = consumer_local
        worker_cache:set(body.client_id, consumer)
    end

    body.consumer = consumer

    if not body.exp or not body.iat then
        return unexpected_error("missed exp or iat fields")
    end

    if conf.allow_oauth_scope_expression then
        kong.log.debug("Requested path : ", request_path," Requested http method : ", request_http_method)
        local path_scope_expression = helper.get_expression_by_request_path_method(
            conf.oauth_scope_expression, request_path, request_http_method
        )
        if pl_types.is_empty(path_scope_expression) then
            if conf.allow_unprotected_path then
                kong.log.info("Path is not proteced, but allow_unprotected_path")
                worker_cache:set(build_cache_key(token, conf.allow_oauth_scope_expression), body.exp - body.iat)
                set_consumer(body.consumer, body.client_id, body.exp)
                return 200
            else
                kong.log.err("Path: ", request_path, " and method: ", request_http_method, " are not protected with oauth scope expression. Configure your oauth scope expression.")
                return 403, "Path/method is not protected with scope expression"
            end
        end

        if not helper.check_scope_expression(path_scope_expression, body.scope) then
            -- TODO should we cache negative result?
            kong.log.debug("Not authorized for this path/method")
            return 403, "You are not authorized for this path/method"
        end
        worker_cache:set(build_cache_key(token, conf.allow_oauth_scope_expression), body.exp - body.iat)
    else
        worker_cache:set(token, body, body.exp - body.iat)
    end

    set_consumer(body.consumer, body.client_id, body.exp)
    return 200
end

return function(conf)

    local status, err = do_authentication(conf);

    if status ~= 200 then
        -- Check anonymous user and set header with anonymous consumer details
        if conf.anonymous ~= "" then
            -- get anonymous user
            print(conf.anonymous)
            local consumer_cache_key = kong.db.consumers:cache_key(conf.anonymous)
            local consumer, err = kong.cache:get(consumer_cache_key, nil, load_consumer_by_id, conf.anonymous)

            if err then
                return unexpected_error("Anonymous customer: ", err)
            end
            set_consumer(consumer)
            return
        else
            kong.response.exit(status, { message = err })
        end
    end
end
