local path_wildcard_tree = require "gluu.path-wildcard-tree"
local common = require "gluu.kong-common"

return {
    no_consumer = true,
    fields = {
        oxd_id = { required = true, type = "string" },
        client_id = { required = true, type = "string" },
        client_secret = { required = true, type = "string" },
        op_url = { required = true, type = "url" },
        oxd_url = { required = true, type = "url" },
        oauth_scope_expression = { required = false, type = "table", func = common.check_expression },
        deny_by_default = { type = "boolean", default = true },
        method_path_tree = { required = false, type = "table" },
    },
    self_check = function(schema, plugin_t, dao, is_updating)
        local method_path_tree = {}
        local oauth_scope_expression = plugin_t.oauth_scope_expression
        for k = 1, #oauth_scope_expression do
            local item = oauth_scope_expression[k]

            for i = 1, #item.conditions do
                local condition = item.conditions[i]

                for j = 1, #condition.httpMethods do
                    local t = { path = item.path, scope_expression = condition.scope_expression }
                    path_wildcard_tree.addPath(method_path_tree, condition.httpMethods[j], item.path, t)
                end
            end
        end
        plugin_t.method_path_tree = method_path_tree
        return true
    end
}
