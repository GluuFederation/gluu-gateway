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

local function match_named_captures(scope_captures, path_captures)
    local ret = false
    local no_named_capture = true
    for k,v in pairs(scope_captures) do
        if type(k) == "string" then
            local pc_number = k:match("^PC([1-9])$")
            if pc_number then
                no_named_capture = false
                kong.log.debug("PC", pc_number, "= [", v, "], path capture = [",path_captures[tonumber(pc_number)], "]")
                if path_captures[tonumber(pc_number)] ~= v then
                    return false, no_named_capture
                end
                ret = true, no_named_capture
            end
        end
    end
    kong.log.debug("match_named_captures() return ", ret)
    return ret, no_named_capture
end

--- Check JSON expression
-- @param self: Kong plugin object instance
-- @param conf
-- @param protected_path
-- @param method
-- @param scope_expression: example: { rule = { ["or"] = { { var = 0 }, { var = 1 }, { ["!"] = { { var = 2 } } } } }, data = { "admin", "hrr", "employee" } }
-- @param token_scopes: Array of scopes example: { "admin", "hrr" }
-- @return true or false
function hooks.is_access_granted(self, conf, protected_path, method, scope_expression, token_scopes, _, path_captures)
    scope_expression = scope_expression or {}

    local data = {}
    local scope_expression_data = scope_expression.data
    for i = 1, #scope_expression_data do
        local scope = scope_expression_data[i]
        kong.log.debug(scope)
        if scope:sub(1,1) == "^" then
            local matched = false
            for k = 1, #token_scopes do
                kong.log.debug(token_scopes[k])
                local scope_captures, err = ngx.re.match(token_scopes[k], scope, "jo")
                if not scope_captures and err then
                    kong.log.error(err)
                    break
                end
                if scope_captures then
                    kong.log.debug("scope_captures")

                    if not path_captures then
                        kong.log.debug("no path captures, match")
                        matched = true
                        break
                    end
                    -- the whole match is always returned as scope_captures[0]
                    -- the captures are returned as scope_captures[1] ... scope_captures[N]
                    -- if no capturing group(s) present we use whole match, otherwise only captures
                    if not scope_captures[1] then
                        kong.log.debug("no scope captures")
                        scope_captures[1] = scope_captures[0]
                    end
                    -- make it Lua array, index from 1
                    scope_captures[0] = nil

                    local named_capture_matched, no_named_capture = match_named_captures(scope_captures, path_captures)
                    if named_capture_matched or no_named_capture then
                        matched = true
                        break
                    end
                end
            end
            kong.log.debug("data[#data + 1]=", matched)
            data[#data + 1] = matched
        else
            data[#data + 1] = pl_tablex.find(token_scopes, scope) and true or false
        end
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
