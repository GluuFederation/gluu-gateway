local kong_auth_pep_common = require"gluu.kong-common"

return {
    no_consumer = true,
    fields = {
        oxd_id = { required = true, type = "string" },
        client_id = { required = true, type = "string" },
        client_secret = { required = true, type = "string" },
        op_url = { required = true, type = "url" },
        oxd_url = { required = true, type = "url" },
        anonymous = { type = "string", func = kong_auth_pep_common.check_user, default = "" },
        hide_credentials = { type = "boolean", default = false },
    }
}
