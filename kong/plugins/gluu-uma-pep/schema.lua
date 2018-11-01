return {
    no_consumer = true,
    fields = {
        oxd_url = { required = true, type = "url" },
        client_id = { required = true, type = "string" },
        client_secret = { required = true, type = "string" },
        oxd_id = { required = true, type = "string" },
        op_url = { required = true, type = "url" },
        uma_scope_expression = { required = true, type = "table" }, --TODO check structure
        deny_by_default = { type = "boolean", default = true },
        anonymous = { type = "string", func = check_user, default = "" },
        hide_credentials = { type = "boolean", default = false },
    },
    self_check = function(schema, plugin_t, dao, is_updating)
        table.sort(plugin_t.uma_scope_expression, function(first, second)
            return #first.path > #second.path
        end)
        return true
    end
}
