local constants = require "kong.constants"
local utils = require "kong.tools.utils"
local oxd = require "gluu.oxdweb"
local jwt = require "resty.jwt"
local evp = require "resty.evp"
local validators = require "resty.jwt-validators"

local EXPIRE_DELTA = 10
local MAX_PENDING_SLEEPS = 40
local PENDING_EXPIRE = 0.2
local PENDING_TABLE = {}

local lrucache = require "resty.lrucache.pureffi"
-- it is shared by all the requests served by each nginx worker process:
local worker_cache, err = lrucache.new(10000) -- allow up to 10000 items in the cache
if not worker_cache then
    return error("failed to create the cache: " .. (err or "unknown"))
end

local function unexpected_error(...)
    local pending_key = kong.ctx.plugin.pending_key
    if pending_key then
        worker_cache:delete(pending_key)
    end
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

-- here we store access tokens per client_id
local access_tokens_per_client_id = {}

local function get_protection_token(self, conf)
    local access_token = access_tokens_per_client_id[conf.client_id]
    if not access_token then
        access_token = { expire = 0 }
        access_tokens_per_client_id[conf.client_id] = access_token
    end

    local now = ngx.now()
    kong.log.debug("Current datetime: ", now, " access_token.expire: ", access_token.expire)
    if not access_token.token or access_token.expire < now + EXPIRE_DELTA then
        if access_token.token then
            access_token.expire = access_token.expire + EXPIRE_DELTA -- avoid multiple token requests
        end
        local response = oxd.get_client_token(conf.oxd_url,
            {
                client_id = conf.client_id,
                client_secret = conf.client_secret,
                scope = { "openid", "oxd" },
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
    return access_token.token
end

-- here we store jwks per op_url
local jwks_per_op = {}

local supported_algs = {
    RS256 = true,
    RS384 = true,
    RS512 = true,
}

local function refresh_jwks(self, conf, jwks)
    local ptoken = get_protection_token(self, conf)

    local response, err = oxd.get_jwks(conf.oxd_url,
        { op_host = conf.op_url },
        ptoken)
    if not response then
        kong.log.err(err)
        return
    end
    if response.status ~= 200 then
        kong.log.err("get_jwks responds with status: ", response.status)
        return
    end

    kong.log.inspect(response)
    local keys = response.body.keys
    if not keys then
        kong.log.err("get_jwks missed keys")
        return
    end

    jwks:flush_all()

    for i = 1, #keys do
        local key = keys[i]
        local ttl = key.exp - ngx.now()
        local alg = key.alg
        if ttl > 0 and supported_algs[alg] and
                key.x5c and type(key.x5c) == "table" and key.x5c[1] then
            local pem = "-----BEGIN CERTIFICATE-----\n" ..
                    key.x5c[1] ..
                    "\n-----END CERTIFICATE-----\n"
            local pkey, err = jwt.pem_cert_to_public_key(pem)
            if pkey then
                key.pkey = pkey
                jwks:set(key.kid, key, ttl)
            else
                kong.log.err("Cannot convert x5c into public key: ", err)
            end
        end
    end
    return true
end

local function process_jwt(self, conf, jwt_obj)
    if not supported_algs[jwt_obj.header.alg] then
        kong.log.info("JWT - unsupported alg=", jwt_obj.header.alg)
        return nil, 401, "Bad JWT"
    end
    local kid = jwt_obj.header.kid
    if kid == nil then
        kong.log.info("JWT - missed kid")
        return nil, 401, "JWT - missed kid"
    end

    local jwks = jwks_per_op[conf.op_url]
    if jwks then
        local key = jwks:get(kid)
        if not key then
            if not refresh_jwks(self, conf, jwks) then
                return nil, 502, "Unexpected error"
            end
        end
    else
        local cache, err = lrucache.new(20) -- allow up to 20 items in the cache
        if not cache then
            return nil, 502, "failed to create the jwks cache: " .. (err or "unknown")
        end
        jwks_per_op[conf.op_url] = cache
        jwks = cache
        if not refresh_jwks(self, conf, jwks) then
            return nil, 502, "Unexpected error"
        end
    end
    local key = jwks:get(kid)
    if not key then
        kong.log.info("Unknown kid")
        return nil, 401, "Unknown kid"
    end


    local claim_spec = {
        exp = validators.is_not_expired(),
    }

    if jwt_obj.header.alg ~= key.alg then
        kong.log.info("JWT - alg mismatch")
        return nil, 401, "Bad JWT"
    end

    kong.log.debug("verify with cert: \n", key.pem)
    local verified = jwt:verify_jwt_obj_evp_pkey(key.pkey, jwt_obj, claim_spec)

    if not verified.verified then
        kong.log.info("JWT is not verified, reason: ", jwt_obj.reason)
        return nil, 401, "JWT is not verified, reason: ", jwt_obj.reason
    end

    local payload = jwt_obj.payload
    kong.log.inspect(payload)
    if payload.client_id and payload.exp then
        return payload, 200
    end

    kong.log.info("JWT - malformed payload")
    return nil, 401, "JWT - malformed payload"
end


local function request_authenticated(conf, token_data)
    kong.log.debug("request_authenticated")
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

    local client_id = token_data.client_id
    if client_id then
        new_headers["X-OAuth-Client-ID"] = tostring(client_id)

        -- introspect-rpt API return mandatory `permissions` field
        if token_data.permissions then
            new_headers["X-RPT-Expiration"] = tostring(token_data.exp)
        else
            new_headers["X-OAuth-Expiration"] = tostring(token_data.exp)

            local scope = token_data.scope
            local t = {}
            for i = 1, #scope do
                t[#t + 1] = scope[i]
            end
            new_headers["X-Authenticated-Scope"] = table.concat(t, ", ")
        end

        kong.service.request.clear_header(const.ANONYMOUS) -- in case of auth plugins concatenation
    else
        new_headers[const.ANONYMOUS] = true
    end
    kong.service.request.set_headers(new_headers)
end

-- lru cache get operation with `pending` state support
local function worker_cache_get_pending(key)
    for i = 1, MAX_PENDING_SLEEPS do
        local token_data, stale_data = worker_cache:get(key)

        if not token_data or stale_data then
            return
        end

        if token_data == PENDING_TABLE then
            kong.log.debug("sleep 5ms")
            ngx.sleep(0.005) -- 5ms
        else
            return token_data
        end
    end
end

local function set_pending_state(key)
    kong.ctx.plugin.pending_key = key
    worker_cache:set(key, PENDING_TABLE, PENDING_EXPIRE)
end

local function clear_pending_state(key)
    kong.ctx.plugin.pending_key = nil
    worker_cache:delete(key)
end

local function handle_anonymous(conf, scope_expression, status, err)
    kong.log.debug("conf.anonymous: ", conf.anonymous)
    local consumer_cache_key = kong.db.consumers:cache_key(conf.anonymous)
    local consumer, err = kong.cache:get(consumer_cache_key, nil, load_consumer_by_id, conf.anonymous)

    if err then
        return unexpected_error("Anonymous customer: ", err)
    end
    request_authenticated(conf, { consumer = consumer })
end

local _M = {}

_M.unexpected_error = unexpected_error

--[[
hooks must be a table with methods below:

@return protected_path, scope_expression; may returns no values
function hooks.get_path_by_request_path_method(self, conf, path, method)
end

it shoud never return, it must call kong.exit
function hooks.no_token_protected_path(self, conf, protected_path, method)
end

@return nil or cache key
also may return second value `pending` which means the plugin will call async. operations
function build_cache_key(method, protected_path, token, scopes)

@return boolean
function hooks.is_access_granted(self, conf, protected_path, method, scope_expression, scopes, rpt)
end
 ]]
_M.access_pep_handler = function(self, conf, hooks)
    local token = kong.ctx.shared.request_token

    local method = ngx.req.get_method()
    local path = ngx.var.uri
    local protected_path, scope_expression = hooks.get_path_by_request_path_method(self, conf, path, method)

    if token and not protected_path and conf.deny_by_default then
        kong.log.err("Path: ", path, " and method: ", method, " are not protected with scope expression. Configure your scope expression.")
        return kong.response.exit(403, { message = "Unprotected path/method are not allowed" })
    end

    if not token then
        if protected_path then
            kong.log.debug("no token, protected path")
            return hooks.no_token_protected_path(self, conf, protected_path, method)
        end
        return kong.response.exit(403, { message = "Invalid request, no token and no protected path" })
    end

    kong.log.debug("protected resource path: ", protected_path, " URI: ", path, " token: ", token)

    local client_id, exp
    local token_data = kong.ctx.shared.authenticated_token
    if not token_data then
        return kong.response.exit(403, { message = "Token not authenticated" })
    else
        exp = token_data.exp
    end

    if not protected_path then
        return -- access_granted
    end

    local cache_key, pending = hooks.build_cache_key(method, protected_path, token, token_data.scope)

    if cache_key then
        local is_access_granted = worker_cache_get_pending(cache_key)
        if is_access_granted then
            kong.ctx.shared[self.metric_client_granted] = true
            return -- access_granted
        end
    end

    if pending then
        set_pending_state(cache_key)
    end
    if hooks.is_access_granted(self, conf, protected_path, method, scope_expression, token_data.scope, token) then
        if cache_key then
            worker_cache:set(cache_key, true, exp - ngx.now() - EXPIRE_DELTA)
        end
        kong.ctx.shared[self.metric_client_granted] = true
        return -- access_granted
    end
    if pending then
        clear_pending_state(token)
    end
    return kong.response.exit(403, { message = "You are not authorized to access this resource" })
end

--[[
Authentication

introspect_token hooks must be a table with methods below:

@return introspect_response, status, err
upon success returns only introspect_response,
otherwise return nil, status, err
function introspect_token(self, conf, token)
end
 ]]
_M.access_auth_handler = function(self, conf, introspect_token)
    local authorization = ngx.var.http_authorization
    local token = get_token(authorization)

    if not token then
        if #conf.anonymous > 0 then
            return handle_anonymous(conf)
        end
        return kong.response.exit(401, { message = "Failed to get bearer token from Authorization header" })
    end

    local client_id, exp
    local token_data = worker_cache_get_pending(token)
    if not token_data then
        set_pending_state(token)

        local introspect_response, status, err

        local jwt_obj = jwt:load_jwt(token)
        if jwt_obj.valid then
            introspect_response, status, err = process_jwt(self, conf, jwt_obj)
        else
            introspect_response, status, err = introspect_token(self, conf, token)
        end
        token_data = introspect_response

        if not introspect_response then
            clear_pending_state(token)

            if status ~= 401 then
                return unexpected_error(err)
            end

            if #conf.anonymous > 0 then
                return handle_anonymous(conf)
            end

            return kong.response.exit(401, { message = err })
        end

        -- if we here introspection was successful
        client_id = introspect_response.client_id
        exp = introspect_response.exp

        local consumer, err = kong.db.consumers:select_by_custom_id(client_id)
        if not consumer and not err then
            clear_pending_state(token)
            kong.log.err('consumer with custom_id "' .. client_id .. '" not found')
            return kong.response.exit(401, { message = "Unknown consumer" })
        end
        if err then
            clear_pending_state(token)
            return unexpected_error("select_by_custom_id error: ", err)
        end
        introspect_response.consumer = consumer

        kong.log.debug("save token in cache")
        worker_cache:set(token, introspect_response,
            exp - ngx.now() - EXPIRE_DELTA)
    else
        client_id = token_data.client_id
        exp = token_data.exp
    end

    -- Client(Consumer) is authenticated
    kong.ctx.shared.authenticated_consumer = token_data.consumer -- forward compatibility
    ngx.ctx.authenticated_consumer = token_data.consumer -- backward compatibility
    kong.ctx.shared[self.metric_client_authenticated] = true
    kong.ctx.shared.authenticated_token = token_data -- Used to check wether token is authenticated or not for PEP plugin
    kong.ctx.shared.request_token = token -- May hide from autorization header so need it for PEP plugin
    return request_authenticated(conf, token_data)
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
            err = 'consumer "' .. anonymous .. '" not found'
        end
        kong.log.err(err)
        return false
    end

    return false, "the anonymous user must be empty or a valid uuid"
end

_M.get_protection_token = get_protection_token
_M.worker_cache_get_pending = worker_cache_get_pending
_M.set_pending_state = set_pending_state
_M.clear_pending_state = clear_pending_state
_M.worker_cache = worker_cache
_M.EXPIRE_DELTA = EXPIRE_DELTA

return _M
