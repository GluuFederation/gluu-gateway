local typedefs = require "kong.db.schema.typedefs"

return {
  name = "gluu-metrics",
  fields = {
    { run_on = typedefs.run_on_first },
    { consumer = typedefs.no_consumer },
    {
      config = {
        type = "record",
        fields = {
          { ip_restrict_plugin_id = { required = true, type = "string" }, },
          { gluu_prometheus_server_host = { required = true, type = "string" }, },
          { kong_admin_url = typedefs.url { required = true, default = "http://localhost:8001" }, },
          { check_ip_time = typedefs.timeout  { required = true, default = 86400 }, }, -- seconds, default 24 hr
        },
        custom_validator = function(config)
          if not ngx.shared.gluu_metrics then
            return false, "ngx shared dict 'gluu_metrics' not found"
          end
          return true
        end
      },
    },
  }
}
