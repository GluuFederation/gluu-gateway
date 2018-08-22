return {
    no_consumer = true,
    fields = {
        hide_credentials = { type = "boolean", default = false },
        oxd_id = { required = true, type = "string" },
        client_id = { required = true, type = "string" },
        client_secret = { required = true, type = "string" },
        op_server = { required = true, type = "string"},
        oxd_http_url = { required = true, type = "string" },
        anonymous = {type = "string", default = ""}
    },
}
