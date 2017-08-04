return {
    {
        name = "2017-07-18_init_oxds",
        up = [[
      CREATE TABLE IF NOT EXISTS oxds(
        id uuid,
        oxd_id text UNIQUE,
        op_host text,
        oxd_port text,
        oxd_host text,
        PRIMARY KEY (id)
      );

      DO $$
      BEGIN
        IF (SELECT to_regclass('oxds_oxd_idx')) IS NULL THEN
          CREATE INDEX oxds_oxd_id_idx ON oxds(oxd_id);
        END IF;
      END$$;
    ]],
        down = [[
      DROP TABLE oxds;
    ]]
    }
}