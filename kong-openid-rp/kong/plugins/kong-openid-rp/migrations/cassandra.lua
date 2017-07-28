return {
    {
        name = "2017-07-18_init_oxds",
        up = [[
      CREATE TABLE IF NOT EXISTS oxds(
        id uuid,
        consumer_id uuid,
        oxd_id text,
        op_host text,
        oxd_port text,
        oxd_host text,
        session_timeout text,
        created_at timestamp,
        PRIMARY KEY (id)
      );

      CREATE INDEX IF NOT EXISTS ON oxds(oxd_id);
      CREATE INDEX IF NOT EXISTS ON oxds(consumer_id);
    ]],
        down = [[
      DROP TABLE oxds;
    ]]
    }
}