local common = require "gluu.kong-common"
local typedefs = require "kong.db.schema.typedefs"

return {
    name = "gluu-oauth-auth",
    fields = {
        { run_on = typedefs.run_on_first },
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
                },
            },
        },
    }
}
