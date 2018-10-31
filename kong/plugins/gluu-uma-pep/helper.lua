local pl_tablex = require "pl.tablex"

local _M = {}

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

--- lookup registered protected path by path and http methods
-- @param exp: OAuth scope expression Example: [{ path: "/posts", ...}, { path: "/todos", ...}] it must be sorted - longest strings first
-- @param request_path: requested api endpoint(path) Example: "/posts/one/two"
-- @param method: requested http method Example: GET
-- @return registered path
function _M.get_path_by_request_path_method(exp, request_path, method)
    -- TODO the complexity is O(N), think how to optimize
    local found_paths = {}
    print(request_path)
    for i = 1, #exp do
        print(exp[i]["path"])
        if _M.is_path_match(request_path, exp[i]["path"]) then
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


return _M