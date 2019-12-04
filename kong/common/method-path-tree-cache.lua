local lrucache = require "resty.lrucache.pureffi"
local path_wildcard_tree = require "gluu.path-wildcard-tree"
local cjson = require"cjson"

local EXPIRE_IN = 60 * 60 * 24

-- it is shared by all the requests served by each nginx worker process:
local worker_cache, err = lrucache.new(100) -- allow up to 100 items in the cache
if not worker_cache then
    return error("failed to create the cache: " .. (err or "unknown"))
end

return function(json_text)
    local method_path_tree, stale_data = worker_cache:get(json_text)
    if method_path_tree and not stale_data then
        return method_path_tree
    end

    local scope_expression = cjson.decode(json_text)

    method_path_tree = path_wildcard_tree.convert_scope_expression_to_path_wildcard_tree(scope_expression)

    worker_cache:set(json_text, method_path_tree, EXPIRE_IN)

    return method_path_tree
end
