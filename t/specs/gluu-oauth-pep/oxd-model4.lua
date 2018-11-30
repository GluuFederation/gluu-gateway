local cjson = require"cjson"

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
            scope = { "openid", "oxd", "email" },
            expires_in = 299,
        },
        response_callback = function(response, request_json)
            local jwt_lib = require "resty.jwt"
            local t = {
                header = { typ = "JWT", alg = "RS256", kid = "1234567890" },
                payload = {
                    client_id = request_json.client_id,
                    exp = ngx.now() + 60*5,
                    scope = "openid oxd",
                }
            }
            local private_key = [[
-----BEGIN RSA PRIVATE KEY-----
MIIBOAIBAAJAR/0YV0EUBITUOXbLGFXS4zoSnWy25c6KQsHCiFQ6kxBxWk6m+yby
eH58iLekQ9Dl+tRLl7CPa1zKyvWlfdv4gQIDAQABAkAx9inqhLQL3tQbfaK+pPHT
2f4JW+Yj4BB8/FSyoSJ15fsBoNQvXs4i9fQgWN9N6tyHT3NPgfM9jr1+F7jeiuBB
AiEAi8qyglCk5NuxMeC7iQcVVH331XusKLlAkwtnlHLi2OUCIQCD1RwZaIEfI/jQ
sCbLNXifRrdvP6vc6puU2+o+CNAzbQIgSqdSE4Pru4iTpZZlsHUG8BthmjG0q/7a
vGxvwXhlKv0CIG7l5J9TE9t4TSRwKhIjRvblbAV/kDlkecA9Rs0saMf5AiBSSSBx
FNTjDUl9TmbXV5XHsJJGZC2ejaDMvXWKmorYxw==
-----END RSA PRIVATE KEY-----
            ]]
            local jwt = jwt_lib:sign(private_key, t)
            print(jwt)
            response.access_token = jwt
        end

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
            local scope = json.scope
            assert(#scope == 2)
            for i =1, 2 do
                assert((scope[i] == "oxd") or (scope[i] == "openid"))
            end
        end,
        response = {
            scope = { "openid", "oxd"},
            access_token = "b75434ff-f465-4b70-92e4-b7ba6b6c58f3",
            expires_in = 299,
        }
    },
    -- #4 plugin request jwks
    {
        expect = "/get-jwks",
        required_fields = {
            "op_host",
        },
        response = {
            keys = {
                {
                    kid = "1234567890",
                    alg = "RS256",
                    x5c = {[[MFswDQYJKoZIhvcNAQEBBQADSgAwRwJAR/0YV0EUBITUOXbLGFXS4zoSnWy25c6KQsHCiFQ6kxBxWk6m+ybyeH58iLekQ9Dl+tRLl7CPa1zKyvWlfdv4gQIDAQAB]]}
                }
            }
        },
        response_callback = function(response, request_json)
            setmetatable(response.keys, cjson.array_mt)
            response.keys[1].exp = ngx.now() + 60*5
        end
    }
}

return model
