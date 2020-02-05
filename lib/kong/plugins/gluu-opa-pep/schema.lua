local typedefs = require "kong.db.schema.typedefs"

return {
    name = "gluu-metrics",
    fields = {
        { consumer = typedefs.no_consumer },
        {
            config = {
                type = "record",
                fields = {
                    { forward_request_body = { type = "boolean", default = false }, },
                    { opa_url = typedefs.url { required = true, default = "http://localhost:8001" }, },
                },
            },
        },
    }
}
