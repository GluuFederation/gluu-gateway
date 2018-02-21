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
        client_secret text,
        client_jwks_uri text,
        jwks_file text,
        client_token_endpoint_auth_method text,
        client_token_endpoint_auth_signing_alg text,
        kong_acts_as_uma_client boolean,
        created_at timestamp,
        PRIMARY KEY (id)
      );
      CREATE INDEX IF NOT EXISTS ON gluu_oauth2_client_auth_credentials(consumer_id);
      CREATE INDEX IF NOT EXISTS ON gluu_oauth2_client_auth_credentials(client_id);
      CREATE INDEX IF NOT EXISTS ON gluu_oauth2_client_auth_credentials(oxd_id);

      CREATE TABLE IF NOT EXISTS gluu_oauth2_client_auth_tokens(
        id uuid,
        access_token text,
        rpt_token text,
        path text,
        method text,
        client_id text,
        expires_in int,
        created_at timestamp,
        PRIMARY KEY (id)
      );

      CREATE INDEX IF NOT EXISTS ON gluu_oauth2_client_auth_tokens(access_token);
      CREATE INDEX IF NOT EXISTS ON gluu_oauth2_client_auth_tokens(method);
      CREATE INDEX IF NOT EXISTS ON gluu_oauth2_client_auth_tokens(path);
    ]],
        down = [[
      DROP TABLE gluu_oauth2_client_auth_credential;
      DROP TABLE gluu_oauth2_client_auth_tokens;
    ]]
    }
}