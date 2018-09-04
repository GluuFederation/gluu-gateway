local model

local introspect_item = {
    expect = "/introspect-access-token",
    required_fields = {
        "oxd_id",
        "access_token",
    },
    request_check = function(json, token)
        assert(json.oxd_id == model[1].response.oxd_id)
        assert(json.access_token == model[2].response.access_token)
        assert(token == model[3].response.access_token, 401)
    end,
    response = {
        active = true,
        client_id = "@!1736.179E.AA60.16B2!0001!8F7C.B9AB!0008!A2BB.9AE6.5F14.B387", -- should be the same as return by register-site
        username = "John Black",
        scope = { "openid" },
        token_type = "bearer",
        sub = "jblack",
        aud = "l238j323ds-23ij4",
        iss = "https://as.gluu.org/",
        --acr_values": ["basic","duo"],
        --extension_field": "twenty-seven",
    },
    response_callback = function(response)
        response.exp = ngx.now() + 60 * 60
        response.iat = ngx.now()
        return response
    end,
}

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
            return response
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
    -- #4, plugin check the client token
    introspect_item,

    -- #5, plugin check the wrong client token
    introspect_item,

    -- #6, plugin check the wrong client token with another service
    introspect_item,

    -- #7, client request access token
    -- Test case: Test demo-service3 with host backend3.com
    {
        expect = "/get-client-token",
        required_fields = {
            "client_id",
            "client_secret",
            "op_host",
            "scope"
        },
        request_check = function(json)
            assert(json.client_id == model[1].response.client_id)
            assert(json.client_secret == model[1].response.client_secret)
        end,
        response = {
            scope = { "admin" },
            access_token = "b75434ff-f465-4b70-92e4-b7ba6b6c58f4",
            expires_in = 299,
        }
    },
    -- #8, plugin check the client token with insufficient scope
    -- Test case: Test demo-service3 with host backend3.com
    {
        expect = "/introspect-access-token",
        required_fields = {
            "oxd_id",
            "access_token",
        },
        request_check = function(json, token)
            assert(json.oxd_id == model[1].response.oxd_id)
            assert(json.access_token == model[7].response.access_token)
        end,
        response = {
            active = true,
            client_id = "@!1736.179E.AA60.16B2!0001!8F7C.B9AB!0008!A2BB.9AE6.5F14.B387", -- should be the same as return by register-site
            username = "John Black",
            scope = { "admin" },
            token_type = "bearer",
            sub = "jblack",
            aud = "l238j323ds-23ij4",
            iss = "https://as.gluu.org/"
        },
        response_callback = function(response)
            response.exp = ngx.now() + 60 * 60
            response.iat = ngx.now()
            return response
        end,
    },

    -- #9, client request access token
    -- Test case: Test demo-service3 with host backend3.com
    {
        expect = "/get-client-token",
        required_fields = {
            "client_id",
            "client_secret",
            "op_host",
            "scope"
        },
        request_check = function(json)
            assert(json.client_id == model[1].response.client_id)
            assert(json.client_secret == model[1].response.client_secret)
        end,
        response = {
            scope = { "admin", "employee" },
            access_token = "b75434ff-f465-4b70-92e4-b7ba6b6c58f5",
            expires_in = 299,
        }
    },

    -- #10, plugin check the client token with full scope
    -- Test case: Test demo-service3 with host backend3.com
    {
        expect = "/introspect-access-token",
        required_fields = {
            "oxd_id",
            "access_token",
        },
        request_check = function(json, token)
            assert(json.oxd_id == model[1].response.oxd_id)
            assert(json.access_token == model[9].response.access_token)
        end,
        response = {
            active = true,
            client_id = "@!1736.179E.AA60.16B2!0001!8F7C.B9AB!0008!A2BB.9AE6.5F14.B387", -- should be the same as return by register-site
            username = "John Black",
            scope = { "admin", "employee" },
            token_type = "bearer",
            sub = "jblack",
            aud = "l238j323ds-23ij4",
            iss = "https://as.gluu.org/"
        },
        response_callback = function(response)
            response.exp = ngx.now() + 60 * 60
            response.iat = ngx.now()
            return response
        end,
    },
}

return model
