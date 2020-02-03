local common = require "gluu.kong-common"
local typedefs = require "kong.db.schema.typedefs"
local cjson = require "cjson.safe"

return {
    name = "gluu-uma-pep",
    fields = {
        { consumer = typedefs.no_consumer },
        {
            config = {
                type = "record",
                fields = {
                    { oxd_id = { required = true, type = "string" }, },
                    { oxd_url = typedefs.url { required = true }, },
                    { client_id = { required = true, type = "string" }, },
                    { client_secret = { required = true, type = "string" }, },
                    { op_url = typedefs.url { required = true }, },
                    { deny_by_default = { type = "boolean", default = true }, },
                    { oauth_scope_expression = { required = false, type = "string" }, },
                },
                custom_validator = function(config)
                    if not config.oauth_scope_expression then
                        return true
                    end

                    local oauth_scope_expression = cjson.decode(config.oauth_scope_expression)
                    local ok, err = common.check_expression(oauth_scope_expression)
                    if not ok then
                        return false, err
                    end

                    return true
                end
            },
        },
    }
}
