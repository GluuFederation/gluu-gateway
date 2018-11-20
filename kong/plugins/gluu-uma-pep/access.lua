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
            if token == "" and not body["www-authenticate_header"] then
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
        local body = response.body
        if body.active then
            if not (body.exp and body.iat and body.client_id and body.permissions) then
                return unexpected_error("introspect_rpt() missed required fields")
            end
        end
        return body
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

function hooks.no_token_protected_path(self, conf, protected_path, method)
    kong_auth_pep_common.get_protection_token(self, conf)

    local check_access_no_rpt_response = try_check_access(conf, protected_path, method, nil, self.access_token.token)

    if check_access_no_rpt_response.access == "denied" then
        kong.log.debug("Set WWW-Authenticate header with ticket")
        return kong.response.exit(401,
            { message = "Unauthorized" },
            { ["WWW-Authenticate"] = check_access_no_rpt_response["www-authenticate_header"]}
        )
    end
    return unexpected_error("check_access without RPT token, responds with access == \"granted\"")
end

function hooks.introspect_token(self, conf, token)
    kong_auth_pep_common.get_protection_token(self, conf)

    local introspect_rpt_response_data = try_introspect_rpt(conf, token, self.access_token.token)
    if not introspect_rpt_response_data.active then
        return nil, 401, "Invalid access token provided in Authorization header"
    end
    return introspect_rpt_response_data
end

function hooks.build_cache_key(method, path, token)
    path = path or ""
    local t = {
        method,
        ":",
        path,
        ":",
        token
    }
    return table.concat(t), true
end

function hooks.is_access_granted(self, conf, protected_path, method, scope_expression, _, rpt)
    kong_auth_pep_common.get_protection_token(self, conf)

    local check_access_response = try_check_access(conf, protected_path, method, rpt, self.access_token.token)

    return check_access_response.access == "granted"
end

return function(self, conf)
    kong_auth_pep_common.access_handler(self, conf, hooks)
end

