return {
    {
        name = "2017-01-22557_init_gluu_oauth2_client_auth_credentials",
        up = [[
      CREATE TABLE IF NOT EXISTS gluu_oauth2_client_auth_credentials(
        id uuid,
        consumer_id uuid,
        name text,
        oxd_id text,
        oxd_http_url text,
        scope text,
        op_host text,
        client_id text,
        client_id_of_oxd_id text,
        client_secret text,
        client_jwks_uri text,
        jwks_file text,
        client_token_endpoint_auth_method text,
        client_token_endpoint_auth_signing_alg text,
        uma_mode boolean,
        mix_mode boolean,
        oauth_mode boolean,
        allow_unprotected_path boolean,
        allow_oauth_scope_expression boolean,
        show_consumer_custom_id boolean,
        restrict_api boolean,
        restrict_api_list text,
        created_at timestamp,
        PRIMARY KEY (id)
      );
      CREATE INDEX IF NOT EXISTS ON gluu_oauth2_client_auth_credentials(consumer_id);
      CREATE INDEX IF NOT EXISTS ON gluu_oauth2_client_auth_credentials(client_id);
      CREATE INDEX IF NOT EXISTS ON gluu_oauth2_client_auth_credentials(oxd_id);
    ]],
        down = [[
      DROP TABLE gluu_oauth2_client_auth_credential;
    ]]
    }
}