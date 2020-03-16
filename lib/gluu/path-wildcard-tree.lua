local cjson = require"cjson"

local gmatch = string.gmatch

local function path_split(s)
    local result = {};
    for match in (s):gmatch([[/([^/]*)]]) do
        result[#result + 1] = match
    end
    return result
end

local WILDCARD_ELEMENT = "?"
local WILDCARD_MULTIPLE_ELEMENTS = "??"

local _M = {}

local EXPRESSION_KEY = "#"
local REGEXP_KEY = "##"

_M.addPath = function(self, method, path, exp)
    -- TODO here must be special version of split with {regexp} support
    -- or should we forbid slash within regexp?

    -- for methods we support exact mact or wildcard
    assert(method ~= "??")
    assert(not method:match"^{(.+)}$")

    path = "/" .. method .. path

    local path_as_array = path_split(path)

    local node = self
    for i = 1, #path_as_array do
        local item = path_as_array[i]

        if item == WILDCARD_ELEMENT then
            if not node[WILDCARD_ELEMENT] then
                node[WILDCARD_ELEMENT] = {}
            end
            node = node[WILDCARD_ELEMENT]
        elseif item == WILDCARD_MULTIPLE_ELEMENTS then
            if not node[WILDCARD_MULTIPLE_ELEMENTS] then
                node[WILDCARD_MULTIPLE_ELEMENTS] = {}
            end
            node = node[WILDCARD_MULTIPLE_ELEMENTS]
        else
            local regexp = item:match"^{(.+)}$"
            if regexp then
                local found_node
                for k = 1, #node do
                    if node[k][REGEXP_KEY] == regexp then
                        found_node = node[k]
                    end
                end
                if not found_node then
                    found_node = { [REGEXP_KEY] = regexp }
                    node[#node + 1] = found_node
                end
                node = found_node
            else
                if not node[item] then
                    node[item] = {}
                end
                node = node[item]
            end
        end
    end
    node[EXPRESSION_KEY] = exp
end

local function isKeysExist(t)
    for k,v in pairs(t) do
        if k ~= EXPRESSION_KEY then
            return true
        end
    end
    return false
end

local function processItem(node, path_as_array, index)
    local item = path_as_array[index]
    local key_node = node[item]

    -- first looking for exact match
    if key_node then
        return key_node
    end

    -- next check regexp match
    for i = 1, #node do
        local regexp = node[i][REGEXP_KEY]
        local m, err = ngx.re.match(item, regexp, "jo")
        if m then
            return node[i]
        end
    end

    local wildcard_node = node[WILDCARD_ELEMENT]
    if wildcard_node then
        print"wildcard match"
        return wildcard_node
    end

    local wildcard_multiple_node = node[WILDCARD_MULTIPLE_ELEMENTS]
    if wildcard_multiple_node then

        if isKeysExist(wildcard_multiple_node) then
            for skip = -1, #path_as_array - index do
                local node_local = wildcard_multiple_node
                local matched, last_index
                for  j = 1, #path_as_array - index - skip do
                    node_local, matched = processItem(node_local, path_as_array, index + skip + j)

                    -- we allow only one multiple wildcard, so processItem cannot return matched == true
                    if not node_local then
                        break
                    end
                    last_index = index + skip + j
                end

                if last_index == #path_as_array and node_local[EXPRESSION_KEY] then
                    return node_local, true
                end
            end
        end

        if wildcard_multiple_node[EXPRESSION_KEY] then
            return wildcard_multiple_node, true
        end

    end
end

_M.matchPath = function(self, method, path)
    path = "/" .. method .. path

    local path_as_array = path_split(path)

    local node = self
    local matched, last_index

    for i = 1, #path_as_array do
        node, matched = processItem(node, path_as_array, i)
        if matched then
            return node[EXPRESSION_KEY]
        end
        if not node then
            break
        end
        last_index = i
    end

    if last_index == #path_as_array then
        -- check for corner case, example
        -- protected path /test/??, real path /test
        -- does this node has multiple wildcard subnode?
        if node and node[WILDCARD_MULTIPLE_ELEMENTS] and node[WILDCARD_MULTIPLE_ELEMENTS][EXPRESSION_KEY] then
            return node[WILDCARD_MULTIPLE_ELEMENTS][EXPRESSION_KEY]
        end

        if node and node[EXPRESSION_KEY] then
            return node[EXPRESSION_KEY]
        end
    end
end

-- @param exp: scope expression or acrs expression
_M.convert_scope_expression_to_path_wildcard_tree = function (exp)
    if not exp or exp == cjson.null then
        -- it is possible that expression is not required, but this function is called
        return
    end

    local method_path_tree = {}

    for k = 1, #exp do
        local item = exp[k]

        for i = 1, #item.conditions do
            local condition = item.conditions[i]

            for j = 1, #condition.httpMethods do
                local t = { path = item.path }
                -- copy all conditions keys except httpMethods
                for k, v in pairs(condition) do
                    if k ~= "httpMethods" then
                        t[k] = v
                    end
                end
                _M.addPath(method_path_tree, condition.httpMethods[j], item.path, t)
            end
        end
    end
    return method_path_tree
end


return _M
