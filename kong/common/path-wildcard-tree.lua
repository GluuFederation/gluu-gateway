local gmatch = string.gmatch
local function path_plit(s)
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

_M.addPath = function(self, path, exp)
    -- TODO here must be special version of split with {regexp} support
    -- or should we forbid slash within regexp?
    local path_as_array = path_plit(path)

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
                node[#node + 1] = { regexp }
                node = node[#node]
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

local function isNotKeysExist(t)
    for k,v in pairs(t) do
        if k ~= EXPRESSION_KEY then
            return false
        end
    end
    return true
end

local function serialize(val, stringOnlyKeys)
    stringOnlyKeys = stringOnlyKeys or false
    -- here cannot be userdata

    local function serializeInternal(val, name, t, depth, stringOnlyKeys)
        local vt = type(val)
        if vt == "function" or vt == "thread" or vt == "userdata" then
            return
        end

        depth = depth - 1
        if depth == 0 then
            return
        end

        if name then
            t[#t + 1] = "["
            if type(name) == "string" then
                t[#t + 1] = string.format("%q", name)
            else
                t[#t + 1] = tostring(name)
            end
            t[#t + 1] = "]"
            t[#t + 1] = " = "
        end
        if vt == "table" then
            t[#t + 1] = "{"
            for k, v in pairs(val) do
                if stringOnlyKeys and type(k) == "string" then
                    serializeInternal(v, k, t, depth)
                elseif not stringOnlyKeys then
                    serializeInternal(v, k, t, depth)
                end
            end
            t[#t + 1] = "}"
        elseif vt == "number" then
            t[#t + 1] = tostring(val)
        elseif vt == "string" then
            t[#t + 1] = string.format("%q", val)
        elseif vt == "boolean" then
            t[#t + 1] = tostring(val)
        end

        if name then
            t[#t + 1] = ","
        end
    end

    local t = {}
    local depth = 100 -- limit nested levels

    serializeInternal(val, nil, t, depth)

    return table.concat(t)
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
        local regexp = node[i][1]
        local m, err = ngx.re.match(item, regexp, "jo")
        if m then
            return node[i]
        end
    end

    local wildcard_node = node[WILDCARD_ELEMENT]
    if wildcard_node then
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

_M.matchPath = function(self, path)
    local path_as_array = path_plit(path)

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

    if last_index == #path_as_array and node[EXPRESSION_KEY] then
        return node[EXPRESSION_KEY]
    end
end

return _M
