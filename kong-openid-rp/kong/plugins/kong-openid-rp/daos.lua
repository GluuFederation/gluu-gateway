local OXD_SCHEMA = {
    primary_key = { "id" },
    table = "oxds",
    fields = {
        id = { type = "id", dao_insert_value = true },
        consumer_id = { type = "id", required = true, foreign = "consumers:id" },
        oxd_id = { type = "string", required = true },

        authorization_redirect_uri = { type = "string" },
        op_host = { type = "string", required = true },
        post_logout_redirect_uri = { type = "string" },
        application_type = { type = "string" },
        response_types = { type = "string" },
        grant_types = { type = "string" },
        scope = { type = "string" },
        acr_values = { type = "string" },
        client_name = { type = "string" },
        client_jwks_uri = { type = "string" },
        client_token_endpoint_auth_method = { type = "string" },
        client_request_uris = { type = "string" },
        client_logout_uris = { type = "string" },
        client_sector_identifier_uri = { type = "string" },
        contacts = { type = "string" },
        client_id = { type = "string" },
        client_secret = { type = "string" },

        oxd_port = { type = "string", required = true },
        oxd_host = { type = "string", required = true },
        session_timeout = { type = "string", required = true },
        created_at = { type = "timestamp", immutable = true, dao_insert_value = true },
    },
    marshall_event = function(self, t)
        return { id = t.id, consumer_id = t.consumer_id, oxd_id = t.oxd_id }
    end
}

return { oxds = OXD_SCHEMA }