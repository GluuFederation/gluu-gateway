return {
    {
        name = "2017-01-22557_init_gluu_oauth2_client_auth_credentials",
        up = [[
      CREATE TABLE IF NOT EXISTS gluu_oauth2_client_auth_credentials(
        id uuid,
        consumer_id uuid REFERENCES consumers (id) ON DELETE CASCADE,
        name text,
        oxd_id text,
        oxd_http_url text,
        scope text,
        op_host text,
        client_id text UNIQUE,
        client_secret text,
        client_jwks_uri text,
        jwks_file text,
        client_token_endpoint_auth_method text,
        client_token_endpoint_auth_signing_alg text,
        created_at timestamp without time zone default (CURRENT_TIMESTAMP(0) at time zone 'utc'),
        PRIMARY KEY (id)
      );
      DO $$
      BEGIN
        IF (SELECT to_regclass('gluu_oauth2_client_auth_credentials_consumer_idx')) IS NULL THEN
          CREATE INDEX gluu_oauth2_client_auth_credentials_consumer_idx ON gluu_oauth2_client_auth_credentials(consumer_id);
        END IF;
        IF (SELECT to_regclass('gluu_oauth2_client_auth_credentials_client_idx')) IS NULL THEN
          CREATE INDEX gluu_oauth2_client_auth_credentials_client_idx ON gluu_oauth2_client_auth_credentials(client_id);
        END IF;
        IF (SELECT to_regclass('gluu_oauth2_client_auth_credentials_oxd_idx')) IS NULL THEN
          CREATE INDEX gluu_oauth2_client_auth_credentials_oxd_idx ON gluu_oauth2_client_auth_credentials(oxd_id);
        END IF;
      END$$;

      CREATE TABLE IF NOT EXISTS gluu_oauth2_client_auth_tokens(
        id uuid,
        credential_id uuid REFERENCES gluu_oauth2_client_auth_credentials (id) ON DELETE CASCADE,
        access_token text UNIQUE,
        expires_in int,
        created_at timestamp without time zone default (CURRENT_TIMESTAMP(0) at time zone 'utc'),
        PRIMARY KEY (id)
      );

      DO $$
      BEGIN
        IF (SELECT to_regclass('gluu_oauth2_client_auth_accesstoken_idx')) IS NULL THEN
          CREATE INDEX gluu_oauth2_client_auth_accesstoken_idx ON gluu_oauth2_client_auth_tokens(access_token);
        END IF;

      END$$;
    ]],
        down = [[
      DROP TABLE gluu_oauth2_client_auth_credentials;
      DROP TABLE gluu_oauth2_client_auth_tokens;
    ]]
    },
    {
        name = "2017-01-22557-gluu_oauth2_client_auth_api_id",
        up = [[
      ALTER TABLE gluu_oauth2_client_auth_tokens ADD COLUMN api_id uuid REFERENCES apis (id) ON DELETE CASCADE;
    ]],
        down = [[
      ALTER TABLE gluu_oauth2_client_auth_tokens DROP COLUMN api_id;
    ]]
    },
}