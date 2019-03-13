return {
    no_consumer = true,
    fields = {
        oxd_id = { required = true, type = "string" },
        oxd_url = { required = true, type = "url" },
        client_id = { required = true, type = "string" },
        client_secret = { required = true, type = "string" },
        op_url = { required = true, type = "url" },
        authorization_redirect_path = { required = true, type = "url" },
        logout_path = { required = false, type = "string" },
        logout_pass_upstream = { required = false, type = "boolean", default = false },
        post_logout_redirect_uri = { required = false, type = "url" }, --TODO must be registered as well as authorization_redirect_uri
        requested_scopes = {required = true, type = "string"},
        required_acrs = {required = false, type = "string"}, -- UI should show associated levels
        max_id_token_age = { required = true, type = "timestamp"},
        max_id_token_auth_age = { required = true, type = "timestamp"},
        -- headers - at the moment we will include some hardcoded header set
    }
}
