local GLUU_OAUTH2_CLIENT_AUTH_CREDENTIALS_SCHEMA = {
    primary_key = { "id" },
    table = "gluu_oauth2_client_auth_credentials",
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
        jwks_uri = { type = "string" },
        jwks_file = { type = "string" },
        token_endpoint_auth_method = { type = "string" },
        token_endpoint_auth_signing_alg = { type = "string" },
        created_at = { type = "timestamp", immutable = true, dao_insert_value = true },
    },
    marshall_event = function(self, t)
        return { id = t.id, consumer_id = t.consumer_id, client_id = t.client_id }
    end
}

local GLUU_OAUTH2_CLIENT_AUTH_TOKENS_SCHEMA = {
    primary_key = {"id"},
    table = "gluu_oauth2_client_auth_tokens",
    cache_key = { "access_token" },
    fields = {
        id = { type = "id", dao_insert_value = true },
        api_id = { type = "id", required = false, foreign = "apis:id" },
        credential_id = { type = "id", required = true, foreign = "gluu_oauth2_client_auth_credentials:id" },
        token_type = { type = "string", required = true },
        expires_in = { type = "number", required = true },
        access_token = { type = "string", required = false, unique = true },
        scope = { type = "string" },
        created_at = { type = "timestamp", immutable = true, dao_insert_value = true }
    },
    marshall_event = function(self, t)
        return { id = t.id, credential_id = t.credential_id, access_token = t.access_token }
    end
}

return {
    gluu_oauth2_client_auth_credentials = GLUU_OAUTH2_CLIENT_AUTH_CREDENTIALS_SCHEMA,
    gluu_oauth2_client_auth_tokens = GLUU_OAUTH2_CLIENT_AUTH_TOKENS_SCHEMA
}