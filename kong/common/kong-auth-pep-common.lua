local constants = require "kong.constants"
local utils = require "kong.tools.utils"
local oxd = require "gluu.oxdweb"

local EXPIRE_DELTA = 10
local MAX_PENDING_SLEEPS = 20
local PENDING_EXPIRE = 0.2

local lrucache = require "resty.lrucache.pureffi"
-- it is shared by all the requests served by each nginx worker process:
local worker_cache, err = lrucache.new(10000) -- allow up to 10000 items in the cache
if not worker_cache then
    return error("failed to create the cache: " .. (err or "unknown"))
end

local function unexpected_error(...)
    kong.log.err(...)
    kong.response.exit(502, { message = "An unexpected error ocurred" })
end

local function load_consumer_by_id(consumer_id)
    local result, err = kong.db.consumers:select({ id = consumer_id })
    if not result then
        if not err then
            err = 'consumer "' .. consumer_id .. '" not found'
        end

        return nil, err
    end
    kong.log.debug("consumer loaded")
    return result
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

local function get_protection_token(self, conf)
    local access_token = self.access_token
    local now = ngx.now()
    -- kong.log.debug("Current datetime: ", now, " access_token.expire: ", access_token.expire)
    if not access_token.token or access_token.expire < now + EXPIRE_DELTA then
        access_token.expire = access_token.expire + EXPIRE_DELTA -- avoid multiple token requests
        local response = oxd.get_client_token(conf.oxd_url,
            {
                client_id = conf.client_id,
                client_secret = conf.client_secret,
                scope = {"openid", "oxd"},
                op_host = conf.op_url,
            })

        local status = response.status
        local body = response.body

        kong.log.debug("Protection access token -- status: ", status)
        if status >= 300 or not body.access_token then
            access_token.token = nil
            access_token.expire = 0
            return unexpected_error("Failed to get access token.")
        end

        access_token.token = body.access_token
        if body.expires_in then
            access_token.expire = ngx.now() + body.expires_in
        else
            -- use once
            access_token.expire = 0
        end
    end
end

local function access_granted(conf, token_data)
    kong.log.debug("access_granted")
    if conf.hide_credentials then
        kong.log.debug("Hide authorization header")
        kong.service.request.clear_header("authorization")
    end

    local consumer = token_data.consumer
    local const = constants.HEADERS
    local new_headers = {
        [const.CONSUMER_ID] = consumer.id,
        [const.CONSUMER_CUSTOM_ID] = tostring(consumer.custom_id),
        [const.CONSUMER_USERNAME] = tostring(consumer.username),
    }
    -- https://github.com/Kong/kong/blob/2cdd07e34a362e86d95d5e88615e217fa4f6f0d2/kong/plugins/key-auth/handler.lua#L52
    kong.ctx.shared.authenticated_consumer = consumer -- forward compatibility
    ngx.ctx.authenticated_consumer = consumer -- backward compatibility

    local client_id = token_data.client_id
    if client_id then
        new_headers["X-OAuth-Client-ID"] = tostring(client_id)
        new_headers["X-OAuth-Expiration"] = tostring(token_data.exp)
        kong.service.request.clear_header(const.ANONYMOUS) -- in case of auth plugins concatenation
    else
        new_headers[const.ANONYMOUS] = true
    end
    kong.service.request.set_headers(new_headers)
end

local function build_cache_key(token, path, method)
    path = path or ""
    local t = {
        token,
        ":",
        path,
        ":",
        method
    }
    return table.concat(t)
end

local function handle_anonymous(conf, scope_expression, status, err)
    kong.log.debug("conf.anonymous: ", conf.anonymous)
    local consumer_cache_key = kong.db.consumers:cache_key(conf.anonymous)
    local consumer, err = kong.cache:get(consumer_cache_key, nil, load_consumer_by_id, conf.anonymous)

    if err then
        return unexpected_error("Anonymous customer: ", err)
    end
    access_granted(conf, { consumer = consumer })
end

local _M = {}
_M.unexpected_error = unexpected_error

--[[
hooks must be a table with methods below:

@return protected_path, scope_expression; may returns no values
function hooks.get_path_by_request_path_method(self, conf, path, method)
end

it shoud never return, it must call kong.exit
function hooks.no_token_protected_path(self, conf, protected_path, method, get_protection_token)
end

@return introspect_response, status, err
upon success returns only introspect_response,
otherwise return nil, status, err
function hooks.introspect_token(self, conf, token)
end

@return boolean
function hooks.is_access_granted(self, conf, protected_path, method, scope_expression, scopes, rpt)
end
 ]]

_M.access_handler = function(self, conf, hooks)
    local access_token = assert(self.access_token)
    local authorization = ngx.var.http_authorization
    local token = get_token(authorization)

    local method = ngx.req.get_method()
    local path = ngx.var.uri
    local protected_path, scope_expression
    if not conf.ignore_scope then
        protected_path, scope_expression = hooks.get_path_by_request_path_method(
            self, conf, path, method
        )
    end

    if token and not protected_path and conf.deny_by_default then
        return kong.response.exit(403, { message = "Unprotected path/method are not allowed" })
    end

    if not token then
        if protected_path then
            kong.log.debug("no token, protected path")
            return hooks.no_token_protected_path(self, conf, protected_path, method, get_protection_token)
        end
        if #conf.anonymous > 0 then
            return handle_anonymous(conf)
        end
        return kong.response.exit(401, { message = "Failed to get bearer token from Authorization header" })
    end

    kong.log.debug("protected resource path: ", protected_path)

    local cache_key
    if conf.ignore_scope then
        cache_key = token
    else
        if protected_path then
            cache_key = build_cache_key(token, protected_path, method)
        else
            if conf.deny_by_default then
                kong.log.err("Path: ", path, " and method: ", method, " are not protected with oauth scope expression. Configure your oauth scope expression.")
                kong.response.exit(403, { message = "Unprotected path/method are not allowed" })
            end
            cache_key = build_cache_key(token, protected_path, method)
         end
    end

    for i = 1, MAX_PENDING_SLEEPS do
        local token_data, stale_data = worker_cache:get(cache_key)

        if not token_data or stale_data then
            break
        end

        if token_data == "pending" then
            ngx.sleep(0.005) -- 5ms
        else
            -- we're already authenticated
            kong.log.debug("Token cache found. we're already authenticated")
            return access_granted(conf, token_data)
        end
    end

    worker_cache:set(cache_key, "pending", PENDING_EXPIRE)

    -- Get protection access token for OXD API
    get_protection_token(self, conf)

    local introspect_response, status, err = hooks.introspect_token(self, conf, token)
    if not introspect_response then
        worker_cache:delete(cache_key)

        if status ~= 401 then
            return unexpected_error(err)
        end

        if not protected_path then
            if #conf.anonymous > 0 then
                return handle_anonymous(conf)
            end
       end

        return kong.response.exit(401, { message = "Bad token" })
    end

    -- if we here introspection was successful
    local client_id = introspect_response.client_id
    local exp = introspect_response.exp
    local iat = introspect_response.iat

    local consumer, err = kong.db.consumers:select_by_custom_id(client_id)
    if not consumer and not err then
        kong.log.err('consumer with custom_id "' .. client_id .. '" not found')
        return kong.response.exit(401, { message = "Unknown consumer"} )
    end
    if err then
        return unexpected_error("select_by_custom_id error: ", err)
    end
    introspect_response.consumer = consumer

    if not protected_path then
        worker_cache:set(cache_key, introspect_response,
            exp - iat - EXPIRE_DELTA
        )
        return access_granted(conf, introspect_response)
    end

    if hooks.is_access_granted(self, conf, protected_path, method, scope_expression, introspect_response.scope, token) then
        worker_cache:set(cache_key, introspect_response,
            exp - iat - EXPIRE_DELTA
        )
        return access_granted(conf, introspect_response)
    end

    return kong.response.exit(403, { message = "You are not authorized to access this resource" } )
end

--- Check requested path match to register path
-- @param request_path: Example: "/posts/one/two"
-- @param register_path: Example: "/posts"
-- @return boolean
function _M.is_path_match(request_path, register_path)
    assert(request_path)
    assert(register_path)

    if register_path == "/" then
        return true
    end

    if request_path == register_path then
        return true
    end

    local register_path_len = #register_path
    -- check is register_path a prefix of request_path
    if register_path ~= request_path:sub(1, register_path_len) then
        return false
    end

    -- check that prefix match is not partial
    if request_path:sub(register_path_len + 1, register_path_len + 1) == "/" then
        return true
    end

    -- we cannot have '?' in request_path, because we get it from ngx.var.uri
    -- it doesn't contain arguments

    return false
end

--- Check user valid UUID
-- @param anonymous: anonymous consumer id
function _M.check_user(anonymous)
    if anonymous == "" then
        return true
    end
    if utils.is_valid_uuid(anonymous) then
        local result, err = kong.db.consumers:select({ id = anonymous })
        if result then
            return true
        end
        if not err then
            err = 'consumer "' .. consumer_id .. '" not found'
        end
        kong.log.err(err)
        return false
    end

    return false, "the anonymous user must be empty or a valid uuid"
end


return _M
