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
MIIBOgIBAAJBAMDAjHT+V4nH8P/Pj70Fxhy/FT8mN7fmwAebXXjQi/IlFH8zWgip
2Tkb4nKqzkePUM2YLi0CVx+NO4UozWPPqccCAwEAAQJAP6GQ/LJWLaruuVRJDEqS
qzy9g9pW/IPVku1MPy0Bdg8KBn4KbbVlpv6bAKikJgNZLwyQ1feanVNTRor46IZM
EQIhAPjp8GN6eYe7SI2nYm9kx85+kUlYj4/6MwwtugTpJbhpAiEAxj1O+WXyp2pw
xuGysIYKbqxv4vdBQFNAgDs1eNzuiq8CIQCHfvkvfa0IOOe+zH4l+ytU+crmrUHA
80a0e3PGVpAE+QIgDlWyl0Ay+r4sp4T8id03dedMM+pTMpaSjHM7m6DGMwsCIACu
9Ts+4ZFMjfcK58WuRMqFJyyyiktk0syyxGfytlf4
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
                    x5c = {[[MIICXzCCAgmgAwIBAgIJAO0JJN4B5G3gMA0GCSqGSIb3DQEBCwUAMIGKMQswCQYD
VQQGEwJBVTETMBEGA1UECAwKU29tZS1TdGF0ZTEPMA0GA1UEBwwGS2FsdWdhMQ0w
CwYDVQQKDAR0ZXN0MQ0wCwYDVQQLDAR0ZXN0MREwDwYDVQQDDAh0ZXN0Lm9yZzEk
MCIGCSqGSIb3DQEJARYVYWRtaW4gYXQgdGVzdCBkb3Qgb3JnMB4XDTE4MTIwMzEz
NTkxNVoXDTIzMTIwMjEzNTkxNVowgYoxCzAJBgNVBAYTAkFVMRMwEQYDVQQIDApT
b21lLVN0YXRlMQ8wDQYDVQQHDAZLYWx1Z2ExDTALBgNVBAoMBHRlc3QxDTALBgNV
BAsMBHRlc3QxETAPBgNVBAMMCHRlc3Qub3JnMSQwIgYJKoZIhvcNAQkBFhVhZG1p
biBhdCB0ZXN0IGRvdCBvcmcwXDANBgkqhkiG9w0BAQEFAANLADBIAkEAwMCMdP5X
icfw/8+PvQXGHL8VPyY3t+bAB5tdeNCL8iUUfzNaCKnZORvicqrOR49QzZguLQJX
H407hSjNY8+pxwIDAQABo1AwTjAdBgNVHQ4EFgQUF00hnc5zQW+tOthNSIYGZwUC
gPwwHwYDVR0jBBgwFoAUF00hnc5zQW+tOthNSIYGZwUCgPwwDAYDVR0TBAUwAwEB
/zANBgkqhkiG9w0BAQsFAANBACiPKNijUkIPOGj3xFiLmffW2fWxObpuMP7zvBUE
v8Z38NV9V6D4rXValytY0IIAsI30Z4nWpzDIQLQSZXbFGqM=]]}
                }
            }
        },
        response_callback = function(response, request_json)
            setmetatable(response.keys, cjson.array_mt)
            response.keys[1].exp = ngx.now() + 60*5
        end
    },
}

return model
