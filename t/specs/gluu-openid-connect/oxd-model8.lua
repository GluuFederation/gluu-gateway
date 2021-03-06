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
    -- #2, plugin request for access token
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
            expires_in = 60 * 60,
        }
    },
    -- #3
    {
        expect = "/get-authorization-url",
        required_fields = {
            "oxd_id",
            "scope",
        },
        request_check = function(json)
            assert(json.oxd_id == model[1].response.oxd_id)
        end,
        response = {
            authorization_url = "https://stub.com/oxauth/restv1/authorize?response_type=code&client_id=@!1736.179E.AA60.16B2!0001!8F7C.B9AB!0008!A2BB.9AE6.AAA4&redirect_uri=https://192.168.200.95/callback&scope=openid+profile+email+uma_protection+uma_authorization&state=473ot4nuqb4ubeokc139raur13&nonce=lbrdgorr974q66q6q9g454iccm",
        }
    },
    -- #4
    {
        expect = "/get-tokens-by-code",
        required_fields = {
            "oxd_id",
            "code",
            "state",
        },
        request_check = function(json)
            assert(json.oxd_id == model[1].response.oxd_id)
            assert(json.state == [[473ot4nuqb4ubeokc139raur13]])
            assert(json.code == [[1234567890]])
        end,
        response = {
            access_token = "88bba7f5-961c-4b71-8053-9ab35f1ad395",
            expires_in = 10,
            id_token = "eyJraWQiOiI5MTUyNTU1Ni04YmIwLTQ2MzYtYTFhYy05ZGVlNjlhMDBmYWUiLCJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczovL2NlLWRldjMuZ2x1dS5vcmciLCJhdWQiOiJAITE3MzYuMTc5RS5BQTYwLjE2QjIhMDAwMSE4RjdDLkI5QUIhMDAwOCE5Njk5LkFFQzcuOTM3MS4yODA3IiwiZXhwIjoxNTAxODYwMzMwLCJpYXQiOjE1MDE4NTY3MzAsIm5vbmNlIjoiOGFkbzJyMGMzYzdyZG03OHU1OTUzbTc5MXAiLCJhdXRoX3RpbWUiOjE1MDE4NTY2NzIsImF0X2hhc2giOiItQ3gyZHo1V3Z3X2tCWEFjVHMzbUZBIiwib3hPcGVuSURDb25uZWN0VmVyc2lvbiI6Im9wZW5pZGNvbm5lY3QtMS4wIiwic3ViIjoialNadE9rOUlGTmdLRTZUVVNGMHlUbHlzLVhCYkpic0dSckY5eG9JV2c4dyJ9.gi5tvt-duNygoDGjCqQqdKH6D6jJnpW5p6zYzxYiHtYecxkp8ks6AUJ4bmvkVHBd7a3vNbbFDY9Z3wsHGIMRXZRUXFVSQL1-JG0ye9zFH6Pp--Ky3Hexrl7V8PJ-AAFJwX3s854svIXugKNJMwPMmOvKcdzhhPgMBjh8GfVCpTW415iIBg2XcCmoq40zMIdya2WFeBy7IndcaoKcyUKQwqvtGfA53K3qe6RnKS_ps116n24RyBGypovLlThnoGdh20SZfaGVzoumRwW5-wBR6Iff97jgjx_SEOhhJK7Dr4dxliePd6H5ZtgUmFFoxm6Jyln9LKx-WrrUZRYNuFkh-w",
            refresh_token = "33d7988e-6ffb-4fe5-8c2a-0e158691d446",
            id_token_claims = {
                at_hash = "-Cx2dz5Wvw_kBXAcTs3mFA",
                aud = "@!1736.179E.AA60.16B2!0001!8F7C.B9AB!0008!9699.AEC7.9371.2807",
                sub = "john doe",
                iss = "https://<op-hostname>",
                nonce = "lbrdgorr974q66q6q9g454iccm",
            }
        },
        response_callback = function(response, request_json)
            response.id_token_claims.iat = ngx.time()
            response.id_token_claims.exp = ngx.time() + 60
            response.id_token_claims.auth_time = ngx.time()
        end
    },
    -- #5
    {
        expect = "/get-user-info",
        required_fields = {
            "oxd_id",
            "access_token",
        },
        request_check = function(json)
            assert(json.oxd_id == model[1].response.oxd_id)
            assert(json.access_token == model[4].response.access_token)
        end,
        response = {
            sub = "john doe",
            name = "Jane Doe",
            given_name = "Jane",
            family_name = "Doe",
            preferred_username = "j.doe",
            email = "janedoe@example.com",
            picture = "http://example.com/janedoe/me.jpg"
        }
    },

    -- #6 silent reauth
    {
        expect = "/get-authorization-url",
        required_fields = {
            "oxd_id",
            "scope",
        },
        request_check = function(json)
            assert(json.oxd_id == model[1].response.oxd_id)
        end,
        response = {
            authorization_url = "https://stub.com/oxauth/restv1/authorize?response_type=code&client_id=@!1736.179E.AA60.16B2!0001!8F7C.B9AB!0008!A2BB.9AE6.AAA4&redirect_uri=https://192.168.200.95/callback&scope=openid+profile+email+uma_protection+uma_authorization&state=473ot4nuqb4ubeokc139raur13&nonce=lbrdgorr974q66q6q9g454iccm123",
        }
    },
    -- #7
    {
        expect = "/get-tokens-by-code",
        required_fields = {
            "oxd_id",
            "code",
            "state",
        },
        request_check = function(json)
            assert(json.oxd_id == model[1].response.oxd_id)
            assert(json.state == [[473ot4nuqb4ubeokc139raur13123]])
            assert(json.code == [[1234567890123]])
        end,
        response = {
            access_token = "88bba7f5-961c-4b71-8053-9ab35f1ad395",
            expires_in = 30,
            id_token = "eyJraWQiOiI5MTUyNTU1Ni04YmIwLTQ2MzYtYTFhYy05ZGVlNjlhMDBmYWUiLCJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczovL2NlLWRldjMuZ2x1dS5vcmciLCJhdWQiOiJAITE3MzYuMTc5RS5BQTYwLjE2QjIhMDAwMSE4RjdDLkI5QUIhMDAwOCE5Njk5LkFFQzcuOTM3MS4yODA3IiwiZXhwIjoxNTAxODYwMzMwLCJpYXQiOjE1MDE4NTY3MzAsIm5vbmNlIjoiOGFkbzJyMGMzYzdyZG03OHU1OTUzbTc5MXAiLCJhdXRoX3RpbWUiOjE1MDE4NTY2NzIsImF0X2hhc2giOiItQ3gyZHo1V3Z3X2tCWEFjVHMzbUZBIiwib3hPcGVuSURDb25uZWN0VmVyc2lvbiI6Im9wZW5pZGNvbm5lY3QtMS4wIiwic3ViIjoialNadE9rOUlGTmdLRTZUVVNGMHlUbHlzLVhCYkpic0dSckY5eG9JV2c4dyJ9.gi5tvt-duNygoDGjCqQqdKH6D6jJnpW5p6zYzxYiHtYecxkp8ks6AUJ4bmvkVHBd7a3vNbbFDY9Z3wsHGIMRXZRUXFVSQL1-JG0ye9zFH6Pp--Ky3Hexrl7V8PJ-AAFJwX3s854svIXugKNJMwPMmOvKcdzhhPgMBjh8GfVCpTW415iIBg2XcCmoq40zMIdya2WFeBy7IndcaoKcyUKQwqvtGfA53K3qe6RnKS_ps116n24RyBGypovLlThnoGdh20SZfaGVzoumRwW5-wBR6Iff97jgjx_SEOhhJK7Dr4dxliePd6H5ZtgUmFFoxm6Jyln9LKx-WrrUZRYNuFkh-w",
            refresh_token = "33d7988e-6ffb-4fe5-8c2a-0e158691d446",
            id_token_claims = {
                at_hash = "-Cx2dz5Wvw_kBXAcTs3mFA",
                aud = "@!1736.179E.AA60.16B2!0001!8F7C.B9AB!0008!9699.AEC7.9371.2807",
                sub = "john doe",
                iss = "https://<op-hostname>",
                nonce = "lbrdgorr974q66q6q9g454iccm123",
            }
        },
        response_callback = function(response, request_json)
            response.id_token_claims.iat = ngx.time()
            response.id_token_claims.exp = ngx.time() + 60
            response.id_token_claims.auth_time = ngx.time()
        end
    },
    -- #8
    {
        expect = "/get-user-info",
        required_fields = {
            "oxd_id",
            "access_token",
        },
        request_check = function(json)
            assert(json.oxd_id == model[1].response.oxd_id)
            assert(json.access_token == model[7].response.access_token)
        end,
        response = {
            sub = "john doe",
        }
    },
    -- #10: Logout
    {
        expect = "/get-logout-uri",
        required_fields = {
            "oxd_id",
            "id_token_hint",
            "post_logout_redirect_uri"
        },
        request_check = function(json)
            assert(json.oxd_id == model[1].response.oxd_id)
            assert(json.id_token_hint == model[4].response.id_token)
        end,
        response = {
            uri = "https://stub.com/oxauth/restv1/end_session?id_token_hint=eyJraWQiOiI5MTUyNTU1Ni04YmIwLTQ2MzYtYTFhYy05ZGVlNjlhMDBmYWUiLCJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczovL2NlLWRldjMuZ2x1dS5vcmciLCJhdWQiOiJAITE3MzYuMTc5RS5BQTYwLjE2QjIhMDAwMSE4RjdDLkI5QUIhMDAwOCE5Njk5LkFFQzcuOTM3MS4yODA3IiwiZXhwIjoxNTAxODYwMzMwLCJpYXQiOjE1MDE4NTY3MzAsIm5vbmNlIjoiOGFkbzJyMGMzYzdyZG03OHU1OTUzbTc5MXAiLCJhdXRoX3RpbWUiOjE1MDE4NTY2NzIsImF0X2hhc2giOiItQ3gyZHo1V3Z3X2tCWEFjVHMzbUZBIiwib3hPcGVuSURDb25uZWN0VmVyc2lvbiI6Im9wZW5pZGNvbm5lY3QtMS4wIiwic3ViIjoialNadE9rOUlGTmdLRTZUVVNGMHlUbHlzLVhCYkpic0dSckY5eG9JV2c4dyJ9.gi5tvt-duNygoDGjCqQqdKH6D6jJnpW5p6zYzxYiHtYecxkp8ks6AUJ4bmvkVHBd7a3vNbbFDY9Z3wsHGIMRXZRUXFVSQL1-JG0ye9zFH6Pp--Ky3Hexrl7V8PJ-AAFJwX3s854svIXugKNJMwPMmOvKcdzhhPgMBjh8GfVCpTW415iIBg2XcCmoq40zMIdya2WFeBy7IndcaoKcyUKQwqvtGfA53K3qe6RnKS_ps116n24RyBGypovLlThnoGdh20SZfaGVzoumRwW5-wBR6Iff97jgjx_SEOhhJK7Dr4dxliePd6H5ZtgUmFFoxm6Jyln9LKx-WrrUZRYNuFkh-w&post_logout_redirect_uri=https://localhost/logout_redirect_uri",
        }
    },
}

return model
