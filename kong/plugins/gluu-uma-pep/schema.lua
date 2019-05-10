local path_wildcard_tree = require "gluu.path-wildcard-tree"

--- Check UMA protection document
-- @param v: JSON expression
local function check_expression(v)
    -- TODO check the structure, required fields, etc
    return true
end

return {
    no_consumer = true,
    fields = {
        oxd_url = { required = true, type = "url" },
        client_id = { required = true, type = "string" },
        client_secret = { required = true, type = "string" },
        oxd_id = { required = true, type = "string" },
        op_url = { required = true, type = "url" },
        uma_scope_expression = { required = true, func = check_expression, type = "table" },
        method_path_tree = { required = false, type = "table" },
        deny_by_default = { type = "boolean", default = true },
        require_id_token = { type = "boolean", default = false },
        obtain_rpt = { type = "boolean", default = false },
        claims_redirect_path = { type = "string" },
        redirect_claim_gathering_url = { type = "boolean", default = false },
    },
    self_check = function(schema, plugin_t, dao, is_updating)
        local method_path_tree = {}
        local uma_scope_expression = plugin_t.uma_scope_expression
        for k = 1, #uma_scope_expression do
            local item = uma_scope_expression[k]

            for i = 1, #item.conditions do
                local condition = item.conditions[i]

                for j = 1, #condition.httpMethods do
                    local t = { path = item.path }
                    path_wildcard_tree.addPath(method_path_tree, condition.httpMethods[j], item.path, t)
                end
            end
        end
        plugin_t.method_path_tree = method_path_tree
        return true
    end
}
