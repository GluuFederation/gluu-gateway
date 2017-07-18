return {
    {
        name = "2017-07-18720_init_oxds",
        up = [[
      CREATE TABLE IF NOT EXISTS oxds(
        id uuid,
        consumer_id uuid REFERENCES consumers (id) ON DELETE CASCADE,
        oxd_id text UNIQUE,
        op_host text,
        authorization_redirect_uri text,
        oxd_port text,
        oxd_host text,
        scope text,
        created_at timestamp without time zone default (CURRENT_TIMESTAMP(0) at time zone 'utc'),
        PRIMARY KEY (id)
      );

      DO $$
      BEGIN
        IF (SELECT to_regclass('oxds_oxd_idx')) IS NULL THEN
          CREATE INDEX oxds_oxd_id_idx ON oxds(oxd_id);
        END IF;
        IF (SELECT to_regclass('oxds_consumer_idx')) IS NULL THEN
          CREATE INDEX oxds_consumer_idx ON oxds(consumer_id);
        END IF;
      END$$;
    ]],
        down = [[
      DROP TABLE oxds;
    ]]
    }
}