local path_wildcard_tree = require"gluu.path-wildcard-tree"

local _M = {}

local tree = {}

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

function _M.add()
    ngx.req.read_body()

    local data = ngx.req.get_body_data()

    path_wildcard_tree.addPath(tree, "GET", data, { path = data } )

    ngx.say(serialize(tree))
end

function _M.match()
    ngx.req.read_body()

    local data = ngx.req.get_body_data()

    local node, captures = path_wildcard_tree.matchPath(tree, "GET", data)

    if node then
        ngx.say(node.path)
        if captures then
            for i = 1, #captures do
                ngx.say("PC", i, "=[", captures[i], "]")
            end
        end
    else
        ngx.say"Not match"
    end
end

function _M.named_captures()
    print"1"
    local captures, err = ngx.re.match("/folder/asdqwe123/command/321321321", "^/folder/([^/]+)/command/.+$")
    if not captures and err then
        print(err)
        ngx.say(err)
        return
    end
    print"2"
    if captures then
        ngx.say(serialize(captures))
        return
    end
    ngx.say"no captures"
end

return _M

