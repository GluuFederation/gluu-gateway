local common = require "gluu.kong-common"
local typedefs = require "kong.db.schema.typedefs"

return {
    name = "gluu-oauth-auth",
    fields = {
        { run_on = typedefs.run_on_first },
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
                    { pass_credentials = { type = "string", default = "pass" }, }, -- enum = {"pass", "hide", "phantom_token"},
                    { consumer_mapping = { type = "boolean", default = true }, },
                    {
                        custom_headers = {
                            required = false,
                            type = "array",
                            elements = {
                                type = "record",
                                fields = {
                                    { header_name = { required = true, type = "string" } },
                                    { value = { required = true, type = "string" } },
                                    { format = { required = false, type = "string", one_of = { "string", "jwt", "base64", "urlencoded", "list" }, } },
                                    { sep = { required = false, type = "string" } },
                                    { iterate = { required = false, type = "boolean" } }
                                },
                            },
                        }
                    },
                },
            },
        },
    }
}
