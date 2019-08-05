local common = require "gluu.kong-common"

return {
    no_consumer = true,
    fields = {
        oxd_url = { required = true, type = "url" },
        client_id = { required = true, type = "string" },
        client_secret = { required = true, type = "string" },
        oxd_id = { required = true, type = "string" },
        op_url = { required = true, type = "url" },
        uma_scope_expression = { required = true, func = common.check_expression, type = "table" },
        method_path_tree = { required = false, type = "table" },
        deny_by_default = { type = "boolean", default = true },
        require_id_token = { type = "boolean", default = false },
        obtain_rpt = { type = "boolean", default = false },
        claims_redirect_path = { type = "string" },
        redirect_claim_gathering_url = { type = "boolean", default = false },
    },
    self_check = function(schema, plugin_t, dao, is_updating)
        plugin_t.method_path_tree = common.convert_scope_expression_to_path_wildcard_tree(plugin_t.uma_scope_expression)
        return true
    end
}
