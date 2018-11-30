local model
model = {
    -- array part start, scenario

    -- #1, client register itself
    {
        expect = "/register-site",
        required_fields = {
            "scope",
            "op_host",
            "authorization_redirect_uri",
            "client_name",
            "grant_types",
            -- "bla-bla", -- uncomment and check that test fail
        },
        response = {
            oxd_id = "bcad760f-91ba-46e1-a020-05e4281d91b6",
            client_id_of_oxd_id = "@!1736.179E.AA60.16B2!0001!8F7C.B9AB!0008!A2BB.9AE6.AAA4",
            op_host = "https://example.com",
            setup_client_oxd_id = "qwerty",
            client_id = "@!1736.179E.AA60.16B2!0001!8F7C.B9AB!0008!A2BB.9AE6.5F14.B387",
            client_secret = "f436b936-03fc-433f-9772-53c2bc9e1c74",
            client_registration_access_token = "d836df94-44b0-445a-848a-d43189839b17",
            client_registration_client_uri = "https://<op-hostname>/oxauth/restv1/register?client_id=@!1736.179E.AA60.16B2!0001!8F7C.B9AB!0008!A2BB.9AE6.5F14.B387",
        },
        response_callback = function(response)
            response.client_id_issued_at = ngx.now()
            response.client_secret_expires_at = ngx.now() + 60 * 60
        end,
    },
    -- #2, client request access token
    {
        expect = "/get-client-token",
        required_fields = {
            "client_id",
            "client_secret",
            "op_host",
        },
        request_check = function(json)
            assert(json.client_id == model[1].response.client_id)
            assert(json.client_secret == model[1].response.client_secret)
        end,
        response = {
            scope = { "openid", "profile", "email" },
            access_token = "b75434ff-f465-4b70-92e4-b7ba6b6c58f2",
            expires_in = 299,
        }
    },
    -- #3, plugin request access token
    {
        expect = "/get-client-token",
        required_fields = {
            "client_id",
            "client_secret",
            "op_host",
        },
        request_check = function(json)
            assert(json.client_id == model[1].response.client_id)
            assert(json.client_secret == model[1].response.client_secret)
        end,
        response = {
            scope = { "openid", "profile", "email" },
            access_token = "b75434ff-f465-4b70-92e4-b7ba6b6c58f3",
            expires_in = 299,
        }
    },
    -- #4, plugin check_access with empty RPT, "/posts", GET
    {
        expect = "/uma-rs-check-access",
        required_fields = {
            "oxd_id",
            "rpt",
            "path",
            "http_method",
        },
        request_check = function(json, token)
            assert(json.oxd_id == model[1].response.oxd_id)
            assert(token == model[3].response.access_token, 403)
            assert(json.path == "/posts")
            assert(json.http_method == "GET")
            assert(json.rpt == "")
        end,
        response = {
            access = "denied",
            ["www-authenticate_header"] = "UMA realm=\"rs\",as_uri=\"https://op-hostname\",error=\"insufficient_scope\",ticket=\"e986fd2b-de83-4947-a889-8f63c7c409c0\"",
        },
    },
    -- #5, plugin introspect with RPT, "/posts", GET
    {
        expect = "/introspect-rpt",
        required_fields = {
            "oxd_id",
            "rpt",
        },
        request_check = function(json, token)
            assert(json.oxd_id == model[1].response.oxd_id)
            assert(token == model[3].response.access_token, 403)
            assert(json.rpt ~= "")
        end,
        response = {
            active = true,
            client_id = "1234567890",
            permissions = {},
        },
        response_callback = function(response)
            response.iat = ngx.now()
            response.exp = ngx.now() + 60 * 60
        end,
    },
    -- #6, plugin check_access with RPT, "/posts", GET
    {
        expect = "/uma-rs-check-access",
        required_fields = {
            "oxd_id",
            "rpt",
            "path",
            "http_method",
        },
        request_check = function(json, token)
            assert(json.oxd_id == model[1].response.oxd_id)
            assert(token == model[3].response.access_token, 403)
            assert(json.path == "/posts")
            assert(json.http_method == "GET")
            assert(json.rpt == "1234567890")
        end,
        response = {
            access = "granted",
        },
    },
    -- #7, plugin introspect with RPT, "/posts", GET
    {
        expect = "/introspect-rpt",
        required_fields = {
            "oxd_id",
            "rpt",
        },
        request_check = function(json, token)
            assert(json.oxd_id == model[1].response.oxd_id)
            assert(token == model[3].response.access_token, 403)
            assert(json.rpt ~= "")
        end,
        response = {
            active = true,
            client_id = "1234567890",
            permissions = {},
        },
        response_callback = function(response)
            response.iat = ngx.now()
            response.exp = ngx.now() + 60 * 60
        end,
    },
}

return model
