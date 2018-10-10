return {
    no_consumer = true,
    fields = {
        oxd_url = { required = true, type = "url" },
        client_id = { type = "string" },
        client_secret = { type = "string" },
        oxd_id = { type = "string" },
        uma_server_url = { required = true, type = "url" },
        protection_document = { type = "table" },
    },
    self_check = function(schema, plugin_t, dao, is_updating)
        table.sort(plugin_t.protection_document, function(first, second)
            return #first.path > #second.path
        end)
        return true
    end
}
