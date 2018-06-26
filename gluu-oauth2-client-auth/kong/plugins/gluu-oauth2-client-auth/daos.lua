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
        client_id_of_oxd_id = { type = "string", required = true },
        setup_client_oxd_id = { type = "string", required = true },
        client_secret = { type = "string", required = true },
        client_jwks_uri = { type = "string" },
        jwks_file = { type = "string" },
        uma_mode = { type = "boolean" },
        mix_mode = { type = "boolean" },
        oauth_mode = { type = "boolean" },
        allow_unprotected_path = { type = "boolean" },
        allow_oauth_scope_expression = { type = "boolean" },
        show_consumer_custom_id = { type = "boolean" },
        restrict_api = { type = "boolean" },
        restrict_api_list = { type = "string" },
        client_token_endpoint_auth_method = { type = "string" },
        client_token_endpoint_auth_signing_alg = { type = "string" },
        created_at = { type = "timestamp", immutable = true, dao_insert_value = true },
    },
    marshall_event = function(self, t)
        return { id = t.id, consumer_id = t.consumer_id, client_id = t.client_id }
    end
}

return {
    gluu_oauth2_client_auth_credentials = GLUU_OAUTH2_CLIENT_AUTH_CREDENTIALS_SCHEMA
}