return {
    no_consumer = true,
    fields = {
        oxd_url = { required = true, type = "url" },
        client_id = { type = "string" },
        client_secret = { type = "string" },
        oxd_id = { type = "string" },
        op_url = { required = true, type = "url" },
        protection_document = { required = true, type = "table" }, --TODO check structure
    },
    self_check = function(schema, plugin_t, dao, is_updating)
        table.sort(plugin_t.protection_document, function(first, second)
            return #first.path > #second.path
        end)
        return true
    end
}
