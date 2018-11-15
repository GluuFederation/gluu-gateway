local pl_tablex = require "pl.tablex"
local oxd = require "gluu.oxdweb"
local kong_auth_pep_common = require"gluu.kong-auth-pep-common"

local unexpected_error = kong_auth_pep_common.unexpected_error

-- call /uma-rs-check-access oxd API, handle errors
local function try_check_access(conf, path, method, token, access_token)
    token = token or ""
    local response = oxd.uma_rs_check_access(conf.oxd_url,
        {
            oxd_id = conf.oxd_id,
            rpt = token,
            path = path,
            http_method = method,
        },
        access_token)
    local status = response.status
    if status == 200 then
        -- TODO check status and ticket
        local body = response.body
        if not body.access then
            return unexpected_error("uma_rs_check_access() missed access")
        end
        if body.access == "granted" then
            return body
        elseif body.access == "denied" then
            if not body["www-authenticate_header"] then
                return unexpected_error("uma_rs_check_access() access == denied, but missing www-authenticate_header")
            end
            return body
        end
        return unexpected_error("uma_rs_check_access() unexpected access value: ", body.access)
    end
    if status == 400 then
        return unexpected_error("uma_rs_check_access() responds with status 400 - Invalid parameters are provided to endpoint")
    elseif status == 500 then
        return unexpected_error("uma_rs_check_access() responds with status 500 - Internal error occured. Please check oxd-server.log file for details")
    elseif status == 403 then
        return unexpected_error("uma_rs_check_access() responds with status 403 - Invalid access token provided in Authorization header")
    end
    return unexpected_error("uma_rs_check_access() responds with unexpected status: ", status)
end

local function try_introspect_rpt(conf, token, access_token)
    local response = oxd.introspect_rpt(conf.oxd_url,
        {
            oxd_id = conf.oxd_id,
            rpt = token,
        },
        access_token)
    local status = response.status
    if status == 200 then
        -- TODO check required fields
        return response.body
    end
    if status == 400 then
        return unexpected_error("introspect_rpt() responds with status 400 - Invalid parameters are provided to endpoint")
    elseif status == 500 then
        return unexpected_error("introspect_rpt() responds with status 500 - Internal error occured. Please check oxd-server.log file for details")
    elseif status == 403 then
        return unexpected_error("introspect_rpt() responds with status 403 - Invalid access token provided in Authorization header")
    end
    return unexpected_error("introspect_rpt() responds with unexpected status: ", status)
end

--[[
access_handler function (conf)
    local authorization = ngx.var.http_authorization
    local token = get_token(authorization)
    local method = ngx.req.get_method()
    local path = ngx.var.uri

    kong.log.debug("hide_credentials: ", conf.hide_credentials)
    if conf.hide_credentials then
        kong.log.debug("Hide authorization header")
        kong.service.request.clear_header("authorization")
    end

    path = helper.get_path_by_request_path_method(conf.uma_scope_expression, path, method)
    kong.log.debug("registered resource path: ", path)

    if path and not token then
        get_protection_token(conf) -- this may exit with 500

        local check_access_no_rpt_response = try_check_access(conf, path, method, nil)

        if check_access_no_rpt_response.access == "denied" then
            kong.log.debug("Set WWW-Authenticate header with ticket")
            return kong.response.exit(401, "Unauthorized", {
                ["WWW-Authenticate"] = check_access_no_rpt_response["www-authenticate_header"]
            })
        end
        return unexpected_error("check_access without RPT token, responds with access == \"granted\"")
    end

    if not path and not token then
        if not conf.deny_by_default then
            if conf.anonymous ~= "" then
                set_anonymous(conf)
            end
            return -- access granted
        end
        return kong.response.exit(403, "Unprotected path are not allowed") -- TODO ?!
    end

    local cache_key = build_cache_key(token, path)
    local data, stale_data = worker_cache:get(cache_key)
    if data and not stale_data then
        -- we're already authenticated
        kong.log.debug("Token cache found. we're already authenticated")
        set_consumer(data.client_id, data.consumer, data.exp)
        return -- access granted
    end

    get_protection_token(conf)

    local introspect_rpt_response_data = try_introspect_rpt(conf, token)
    if not introspect_rpt_response_data.active then
        return kong.response.exit(401, "Invalid access token provided in Authorization header")
    end

    local client_id = assert(introspect_rpt_response_data.client_id)
    local exp = assert(introspect_rpt_response_data.exp)

    local consumer, err = kong.db.consumers:select_by_custom_id(client_id)
    if not consumer and not err then
        kong.log.err('consumer with custom_id "' .. client_id .. '" not found')
        return kong.response.exit(401, "Unknown consumer")
    end
    if err then
        return return unexpected_error("select_by_custom_id error: ", err)
    end
    introspect_rpt_response_data.consumer = consumer

    if not path then
        if not conf.deny_by_default then
            worker_cache:set(cache_key, introspect_rpt_response_data,
                introspect_rpt_response_data.exp - introspect_rpt_response_data.iat --TODO decrement some delta?
            )
            set_consumer(client_id, consumer, exp)
            return -- access granted
        end
        return kong.response.exit(403, "Unauthorized")
    end

    local check_access_response = try_check_access(conf, path, method, token)

    if check_access_response.access == "granted" then
        worker_cache:set(cache_key, introspect_rpt_response_data,
             introspect_rpt_response_data.exp - introspect_rpt_response_data.iat --TODO decrement some delta?
        )
        set_consumer(client_id, consumer, exp)
        return -- access granted
    end

    -- access == "denied"
    return kong.response.exit(403)
end
]]



local hooks = {}


--- lookup registered protected path by path and http methods
-- @param self: Kong plugin object instance
-- @param conf:
-- @param exp: OAuth scope expression Example: [{ path: "/posts", ...}, { path: "/todos", ...}] it must be sorted - longest strings first
-- @param request_path: requested api endpoint(path) Example: "/posts/one/two"
-- @param method: requested http method Example: GET
-- @return protected_path; may returns no values
function hooks.get_path_by_request_path_method(self, conf, request_path, method)
    local exp = conf.uma_scope_expression
    -- TODO the complexity is O(N), think how to optimize
    local found_paths = {}
    print(request_path)
    for i = 1, #exp do
        print(exp[i]["path"])
        if kong_auth_pep_common.is_path_match(request_path, exp[i]["path"]) then
            print(exp[i]["path"])
            found_paths[#found_paths + 1] = exp[i]
        end
    end

    for i = 1, #found_paths do
        local path_item = found_paths[i]
        kong.log.inspect(path_item)
        for k = 1, #path_item.conditions do
            local rule = path_item.conditions[k]
            kong.log.inspect(rule)
            if pl_tablex.find(rule.httpMethods, method) then
                return path_item.path
            end
        end
    end

    return nil
end

function hooks.no_token_protected_path(self, conf, protected_path, method, get_protection_token)
    get_protection_token(self, conf)

    local check_access_no_rpt_response = try_check_access(conf, protected_path, method, nil, self.access_token.token)

    if check_access_no_rpt_response.access == "denied" then
        kong.log.debug("Set WWW-Authenticate header with ticket")
        return kong.response.exit(401, "Unauthorized", {
            ["WWW-Authenticate"] = check_access_no_rpt_response["www-authenticate_header"]
        })
    end
    return unexpected_error("check_access without RPT token, responds with access == \"granted\"")
end

function hooks.introspect_token(self, conf, token)
    local introspect_rpt_response_data = try_introspect_rpt(conf, token, self.access_token.token)
    if not introspect_rpt_response_data.active then
        return nil, 401, "Invalid access token provided in Authorization header"
    end
    return introspect_rpt_response_data
end

function hooks.is_access_granted(self, conf, protected_path, method, scope_expression, _, rpt)
    local check_access_response = try_check_access(conf, protected_path, method, rpt, self.access_token.token)

    return check_access_response.access == "granted"
end

return function(self, conf)
    kong_auth_pep_common.access_handler(self, conf, hooks)
end

