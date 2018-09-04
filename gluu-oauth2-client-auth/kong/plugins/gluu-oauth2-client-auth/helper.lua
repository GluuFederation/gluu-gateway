local cjson = require "cjson.safe"
local logic = require('rucciva.json_logic')
local pl_types = require "pl.types"
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
function _M.check_json_expression(scope_expression, requested_scopes)
    scope_expression = scope_expression or {}
    local data = {}
    for _, v in pairs(scope_expression.data) do
        table.insert(data, not pl_types.is_empty(pl_tablex.find(requested_scopes, v)))
    end
    local result = logic_apply(scope_expression.rule, mark_as_array(data))
    return result
end

--- Fetch oauth scope expression based on path and http methods
-- @param json_exp: OAuth scope expression Example: [{ path: "/posts", ...}, { path: "/todos", ...}]
-- @param path: requested api endpoint(path) Example: "/posts"
-- @param method: requested http method Example: GET
-- @return json expression Example: {path: "/posts", ...}
function _M.get_expression_by_path_method(json_exp, path, method)
    if pl_types.is_empty(json_exp) then
        return nil
    end

    local json_expression = cjson.decode(json_exp or "{}")
    local found_path_condition
    for k, v in pairs(json_expression) do
        if v['path'] == path then
            found_path_condition = v['conditions']
            break
        end
    end

    if not found_path_condition then
        return nil
    end

    for k, v in pairs(found_path_condition) do
        if pl_tablex.find(v['httpMethods'], method) then
            return v['scope_expression']
        end
    end

    return nil
end

--- Check requested path match to register path
-- @param request_path: Example: "/posts/one/two"
-- @param register_path: Example: "/posts"
-- @return boolean
function _M.is_path_match(request_path, register_path)
    if request_path == nil then
        return false
    end

    if register_path == nil then
        return false
    end

    local start, last = request_path:find(register_path)
    if start == nil or last == nil or start ~= 1 then
        return false
    end

    return request_path == register_path or string.sub(request_path, start, last + 1) == register_path .. "/" or string.sub(request_path, start, last + 1) == register_path .. "?"
end

--- Get path from scope exression as relative to requested path
-- Details: https://github.com/GluuFederation/gluu-gateway/issues/179#issuecomment-403453890
-- @param json_exp: OAuth scope expression Example: [{ path: "/posts", ...}, { path: "/todos", ...}]
-- @param request_path: requested api endpoint(path) Example: "/posts/one/two"
-- @return path: ralative path Example: "/posts"
function _M.get_relative_path(json_exp, request_path)
    if pl_types.is_empty(json_exp) then
        return request_path
    end

    local json_expression = cjson.decode(json_exp or "{}")
    local register_paths = {}
    for k, v in pairs(json_expression) do
        table.insert(register_paths, v['path'])
    end

    table.sort(register_paths, function(first, second)
        return string.len(first) > string.len(second)
    end)

    for k, v in pairs(register_paths) do
        if _M.is_path_match(request_path, v) then
            return v
        end
    end
    return request_path
end

return _M