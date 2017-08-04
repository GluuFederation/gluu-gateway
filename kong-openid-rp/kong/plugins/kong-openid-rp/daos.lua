local OXD_SCHEMA = {
    primary_key = { "id" },
    table = "oxds",
    fields = {
        id = { type = "id", dao_insert_value = true },
        oxd_id = { type = "string", required = true },
        op_host = { type = "string", required = true },
        oxd_port = { type = "string", required = true },
        oxd_host = { type = "string", required = true }
    },
    marshall_event = function(self, t)
        return { id = t.id, oxd_id = t.oxd_id }
    end
}

return { oxds = OXD_SCHEMA }