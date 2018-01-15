return {
    {
        name = "2018-01-15541_init_gluu_oauth2_bc_credentials",
        up = [[
      CREATE TABLE IF NOT EXISTS gluu_oauth2_bc_credentials(
        id uuid,
        consumer_id uuid REFERENCES consumers (id) ON DELETE CASCADE,
        redirect_uris text,
        scope text,
        grant_types text,
        client_name text,
        op_host text,
        client_id text UNIQUE,
        client_secret text,
        token_endpoint text,
        introspection_endpoint text,
        created_at timestamp without time zone default (CURRENT_TIMESTAMP(0) at time zone 'utc'),
        PRIMARY KEY (id)
      );
      DO $$
      BEGIN
        IF (SELECT to_regclass('gluu_oauth2_bc_credentials_consumer_idx')) IS NULL THEN
          CREATE INDEX gluu_oauth2_bc_credentials_consumer_idx ON gluu_oauth2_bc_credentials(consumer_id);
        END IF;
        IF (SELECT to_regclass('gluu_oauth2_bc_credentials_client_idx')) IS NULL THEN
          CREATE INDEX gluu_oauth2_bc_credentials_client_idx ON gluu_oauth2_bc_credentials(client_id);
        END IF;
        IF (SELECT to_regclass('gluu_oauth2_bc_credentials_secret_idx')) IS NULL THEN
          CREATE INDEX gluu_oauth2_bc_credentials_secret_idx ON gluu_oauth2_bc_credentials(client_secret);
        END IF;
      END$$;
    ]],
        down = [[
      DROP TABLE gluu_oauth2_bc_credentials;
    ]]
    }
}