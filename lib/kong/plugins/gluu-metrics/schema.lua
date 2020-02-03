local typedefs = require "kong.db.schema.typedefs"

return {
  name = "gluu-metrics",
  fields = {
    { consumer = typedefs.no_consumer },
    {
      config = {
        type = "record",
        fields = {
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
