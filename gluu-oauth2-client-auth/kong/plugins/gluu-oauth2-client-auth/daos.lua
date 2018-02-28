local GLUU_OAUTH2_CLIENT_AUTH_CREDENTIALS_SCHEMA = {
    primary_key = { "id" },
    table = "gluu_oauth2_client_auth_credentials",
    cache_key = { "client_id" },
    fields = {
        id = { type = "id", dao_insert_value = true },
        consumer_id = { type = "id", required = true, foreign = "consumers:id" },
        name = { type = "string", required = true },
        oxd_id = { type = "string", required = true },
        oxd_http_url = { type = "string", required = true },
        scope = { type = "string" },
        op_host = { type = "string", required = true },
        client_id = { type = "string", required = true },
        client_secret = { type = "string", required = true },
        client_jwks_uri = { type = "string" },
        jwks_file = { type = "string" },
        native_uma_client = { type = "boolean" },
        client_token_endpoint_auth_method = { type = "string" },
        client_token_endpoint_auth_signing_alg = { type = "string" },
        created_at = { type = "timestamp", immutable = true, dao_insert_value = true },
    },
    marshall_event = function(self, t)
        return { id = t.id, consumer_id = t.consumer_id, client_id = t.client_id }
    end
}

local GLUU_OAUTH2_CLIENT_AUTH_TOKENS_SCHEMA = {
    primary_key = { "id" },
    table = "gluu_oauth2_client_auth_tokens",
    cache_key = { "access_token", "method", "path" },
    fields = {
        id = { type = "id", dao_insert_value = true },
        api_id = { type = "id", required = false, foreign = "apis:id" },
        client_id = { type = "string", required = false },
        expires_in = { type = "number", required = true },
        access_token = { type = "string", required = false },
        rpt_token = { type = "string", required = false },
        path = { type = "string", required = false },
        method = { type = "string", required = false },
        created_at = { type = "timestamp", immutable = true, dao_insert_value = true }
    },
    marshall_event = function(self, t)
        return { id = t.id, access_token = t.access_token, method = t.method, path = t.path }
    end
}

return {
    gluu_oauth2_client_auth_credentials = GLUU_OAUTH2_CLIENT_AUTH_CREDENTIALS_SCHEMA,
    gluu_oauth2_client_auth_tokens = GLUU_OAUTH2_CLIENT_AUTH_TOKENS_SCHEMA
}