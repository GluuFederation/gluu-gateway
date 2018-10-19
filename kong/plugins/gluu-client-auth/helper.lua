local logic = require('rucciva.json_logic')
local pl_tablex = require "pl.tablex"
local _M = {}
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

--- Check JSON expression
-- @param scope_expression: example: { rule = { ["or"] = { { var = 0 }, { var = 1 }, { ["!"] = { { var = 2 } } } } }, data = { "admin", "hrr", "employee" } }
-- @param data: Array of scopes example: { "admin", "hrr" }
-- @return true or false
function _M.check_scope_expression(scope_expression, requested_scopes)
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

--- Fetch oauth scope expression based on path and http methods
-- Details: https://github.com/GluuFederation/gluu-gateway/issues/179#issuecomment-403453890
-- @param exp: OAuth scope expression Example: [{ path: "/posts", ...}, { path: "/todos", ...}] it must be sorted - longest strings first
-- @param request_path: requested api endpoint(path) Example: "/posts/one/two"
-- @param method: requested http method Example: GET
-- @return json expression Example: {path: "/posts", ...}
function _M.get_expression_by_request_path_method(exp, request_path, method)
    -- TODO the complexity is O(N), think how to optimize
    local found_paths = {}
    for i = 1, #exp do
        if _M.is_path_match(request_path, exp[i]["path"]) then
            found_paths[#found_paths + 1] = exp[i]
        end
    end

    for i = 1, #found_paths do
        local conditions = found_paths[i].conditions
        for k = 1, #conditions do
            local rule = conditions[k]
            if pl_tablex.find(rule.httpMethods, method) then
                return rule.scope_expression, found_paths[i].path
            end
        end
    end

    return nil
end

return _M
