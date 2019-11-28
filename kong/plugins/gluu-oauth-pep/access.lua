local kong_auth_pep_common = require "gluu.kong-common"
local path_wildcard_tree = require"gluu.path-wildcard-tree"
local pl_tablex = require "pl.tablex"
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

local function strip_method(path)

end

function hooks.no_token_protected_path()
    -- no pending cache state at the moment, may use PDK directly
    kong.response.exit(401, { message = "Missed OAuth token" })
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

    local data = {}
    local scope_expression_data = scope_expression.data
    for i = 1, #scope_expression_data do
        data[#data + 1] = pl_tablex.find(requested_scopes, scope_expression_data[i]) and true or false
    end
    local result = logic_apply(scope_expression.rule, mark_as_array(data))
    return result
end

function hooks.get_scope_expression(config)
    return config.oauth_scope_expression
end

return function(self, conf)
    kong_auth_pep_common.access_pep_handler(self, conf, hooks)
end
