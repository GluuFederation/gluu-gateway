local common = require "gluu.kong-common"
local typedefs = require "kong.db.schema.typedefs"

return {
    name = "gluu-oauth-auth",
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
                    { anonymous = { type = "string", default = " " }, }, -- TODO kong_auth_pep_common.check_user
                    { pass_credentials = { type = "string", default = "pass",
                        one_of = common.PASS_CREDENTIALS_ENUM }, },
                    { consumer_mapping = { type = "boolean", default = true }, },
                    {
                        custom_headers = {
                            required = false,
                            type = "array",
                            elements = {
                                type = "record",
                                fields = {
                                    { header_name = { required = true, type = "string" } },
                                    { value_lua_exp = { required = true, type = "string" } },
                                    { format = { required = false, type = "string",
                                        one_of = common.CUSTOM_HEADERS_FORMATS } },
                                    { sep = { required = false, type = "string" } },
                                    { iterate = { required = false, type = "boolean" } }
                                },
                            },
                        }
                    },
                },
                custom_validator = function(config)
                    local ok, err = common.check_headers_valid_lua_expression(config.custom_headers)
                    if not ok then
                        return false, err
                    end
                    return true
                end,
            },
        },
    }
}
