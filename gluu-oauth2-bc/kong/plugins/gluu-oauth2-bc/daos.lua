local GLUU_OAUTH2_BC_CREDENTIALS_SCHEMA = {
    primary_key = { "id" },
    table = "gluu_oauth2_bc_credentials",
    fields = {
        id = { type = "id", dao_insert_value = true },
        consumer_id = { type = "id", required = true, foreign = "consumers:id" },
        redirect_uris = { type = "string" },
        scope = { type = "string" },
        grant_types = { type = "string" },
        client_name = { type = "string" },
        op_host = { type = "string", required = true },
        client_id = { type = "string", required = true },
        client_secret = { type = "string", required = true },
        token_endpoint = { type = "string", required = true },
        introspection_endpoint = { type = "string", required = true },
        created_at = { type = "timestamp", immutable = true, dao_insert_value = true },
    },
    marshall_event = function(self, t)
        return { id = t.id, consumer_id = t.consumer_id, client_id = t.client_id }
    end
}

return { gluu_oauth2_bc_credentials = GLUU_OAUTH2_BC_CREDENTIALS_SCHEMA }