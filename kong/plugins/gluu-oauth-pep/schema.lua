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
        plugin_t.method_path_tree = common.convert_scope_expression_to_path_wildcard_tree(plugin_t.oauth_scope_expression)
        return true
    end
}
