local oxd = require "gluu.oxdweb"
local kong_auth_pep_common = require "gluu.kong-auth-pep-common"
local pl_tablex = require "pl.tablex"
local jwt = require "resty.jwt"
local validators = require "resty.jwt-validators"

local logic = require "rucciva.json_logic"
local array_mt = {}

--- Utility function for json logic. Check value is array or not
-- @param tab: Any type of data
local function is_array(tab)
    return getmetatable(tab) == array_mt
end

--- Utility function for json logic. Set metadata to array value
-- @param tab: Array values
local function mark_as_array(tab)
    return setmetatable(tab, array_mt)
end

--- Apply json logic
-- @param lgc: Json rules
-- @param data: Data which you want to validate with lgc
-- @param option: Extra options example: is_array
local function logic_apply(lgc, data, options)
    if type(options) ~= 'table' or options == nil then
        options = {}
    end
    options.is_array = is_array
    options.mark_as_array = mark_as_array
    return logic.apply(lgc, data, options)
end

local hooks = {}

--- Fetch oauth scope expression based on path and http methods
-- Details: https://github.com/GluuFederation/gluu-gateway/issues/179#issuecomment-403453890
-- @param self: Kong plugin object
-- @param exp: OAuth scope expression Example: [{ path: "/posts", ...}, { path: "/todos", ...}] it must be sorted - longest strings first
-- @param request_path: requested api endpoint(path) Example: "/posts/one/two"
-- @param method: requested http method Example: GET
-- @return json expression Example: {path: "/posts", ...}
function hooks.get_path_by_request_path_method(self, conf, path, method)
    local exp = conf.oauth_scope_expression
    -- TODO the complexity is O(N), think how to optimize
    local found_paths = {}
    for i = 1, #exp do
        if kong_auth_pep_common.is_path_match(path, exp[i]["path"]) then
            found_paths[#found_paths + 1] = exp[i]
        end
    end

    for i = 1, #found_paths do
        local conditions = found_paths[i].conditions
        for k = 1, #conditions do
            local rule = conditions[k]
            if pl_tablex.find(rule.httpMethods, method) then
                return found_paths[i].path, rule.scope_expression
            end
        end
    end

    return nil
end

function hooks.no_token_protected_path()
    -- no pending cache state at the moment, may use PDK directly
    kong.response.exit(401, { message = "Missed OAuth token" })
end

local supported_algs = {
    RS256 = true,
    RS512 = true,
}


local function refresh_jwks(self, conf)
    kong_auth_pep_common.get_protection_token(self, conf)

    local response, err = oxd.get_jwks(
        conf.oxd_url,
        {op_host = conf.op_url},
        self.access_token.token
    )
    if not response then
        return nil, err
    end
    if response.status ~= 200 then
        return
    end

    kong.log.inspect(response)
    local keys = response.body.keys
    if not keys then
        return
    end

    self.jwks:flush_all()

    for i = 1, #keys do
        local key = keys[i]
        local ttl = key.exp - ngx.now()
        local alg = key.alg
        if ttl > 0 and supported_algs[alg] and
                key.x5c and type(key.x5c) == "table" and key.x5c[1] then
            key.pem = "-----BEGIN CERTIFICATE-----\n" ..
                    key.x5c[1] ..
                    "\n-----END CERTIFICATE-----\n"
            self.jwks:set(key.kid, key, ttl)
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

    local key = self.jwks:get(kid)
    if not key then
        if not refresh_jwks(self, conf) then
            return nil, 502, "Unexpected error"
        end
        key = self.jwks:get(kid)
        if not key then
            kong.log.info("Unknown kid")
            return nil, 401, "Unknown kid"
        end
    end

    local claim_spec = {
        exp = validators.is_not_expired(),
    }

    if jwt_obj.header.alg ~= key.alg then
        kong.log.info("JWT - alg mismatch")
        return nil, 401, "Bad JWT"
    end

    kong.log.debug("verify with cert: \n", key.pem)
    local verified = jwt:verify_jwt_obj(key.pem, jwt_obj, claim_spec)

    if not verified.verified then
        kong.log.info("JWT is not verified, reason: ", jwt_obj.reason)
        return nil, 401, "JWT is not verified, reason: ", jwt_obj.reason
    end

    local payload = jwt_obj.payload
    kong.log.inspect(payload)
    if payload.client_id and payload.exp and payload.scope then
        return payload, 200
    end

    kong.log.info("JWT - malformed payload")
    return nil, 401, "JWT - malformed payload"
end

-- @return introspect_response, status, err
-- upon success returns only introspect_response,
-- otherwise return nil, status, err
function hooks.introspect_token(self, conf, token)
    local jwt_obj = jwt:load_jwt(token)
    if jwt_obj.valid then
        return process_jwt(self, conf, jwt_obj)
    end

    kong_auth_pep_common.get_protection_token(self, conf)

    local response = oxd.introspect_access_token(conf.oxd_url,
        {
            oxd_id = conf.oxd_id,
            access_token = token,
        },
        self.access_token.token)
    local status = response.status

    if status == 403 then
        kong.log.err("Invalid access token provided in Authorization header");
        return nil, 502, "An unexpected error ocurred"
    end

    if status ~= 200 then
        kong.log.err("introspect-access-token error, status: ", status)
        return nil, 502, "An unexpected error ocurred"
    end

    local body = response.body
    if not body.active then
        -- TODO should we cache negative resposes? https://github.com/GluuFederation/gluu-gateway/issues/213
        return nil, 401, "Invalid access token provided in Authorization header"
    end

    return body
end

function hooks.build_cache_key(method, path, _, scopes)
    -- we may disable access cache just by returning nothing
    -- in this case proxy will always check the protection document against scopes

    -- IMO (altexy) cache will be faster then verify protection document every time
    path = path or ""
    local t = {
        method,
        ":",
        path,
    }
    for i = 1, #scopes do
        t[#t + 1] = ":"
        t[#t + 1] = scopes[i]
    end
    return table.concat(t)
end

--- Check JSON expression
-- @param self: Kong plugin object instance
-- @param conf
-- @param scope_expression: example: { rule = { ["or"] = { { var = 0 }, { var = 1 }, { ["!"] = { { var = 2 } } } } }, data = { "admin", "hrr", "employee" } }
-- @param data: Array of scopes example: { "admin", "hrr" }
-- @return true or false
function hooks.is_access_granted(self, conf, protected_path, method, scope_expression, requested_scopes)
    scope_expression = scope_expression or {}
    kong.log.inspect(scope_expression)
    local data = {}
    local scope_expression_data = scope_expression.data
    for i = 1, #scope_expression_data do
        data[#data + 1] = pl_tablex.find(requested_scopes, scope_expression_data[i]) and true or false
    end
    local result = logic_apply(scope_expression.rule, mark_as_array(data))
    return result
end

return function(self, conf)
    kong_auth_pep_common.access_handler(self, conf, hooks)
end
