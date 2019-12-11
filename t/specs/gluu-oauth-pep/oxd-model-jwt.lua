local cjson = require"cjson"
local validators = require "resty.jwt-validators"

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
                header = { typ = "JWT", alg = "ES256", kid = "1234567890" },
                payload = {
                    client_id = request_json.client_id,
                    exp = ngx.now() + 60*5,
                    scope = "openid oxd",
                }
            }
            local private_key = [[-----BEGIN EC PARAMETERS-----
BggqhkjOPQMBBw==
-----END EC PARAMETERS-----
-----BEGIN EC PRIVATE KEY-----
MHcCAQEEICcwmLp3HFM6xNIS/+XXTCmHveGL4Sa9NTxBe3lIZQ0DoAoGCCqGSM49
AwEHoUQDQgAEkpNLc/4PUjPG9iVd0iKA+5dszHsRU1w9LZEVEyUudcFQWcOuSiZv
jkP7XK4OMP0nN8+x2yhp2rkoPgzWafSwBQ==
-----END EC PRIVATE KEY-----
]]
            local jwt = jwt_lib:sign(private_key, t)
            print(jwt)
            response.access_token = jwt

            local jwt_obj = jwt_lib:load_jwt(jwt)
            local claim_spec = {
                exp = validators.is_not_expired(),
            }
            local verified = jwt_lib:verify_jwt_obj([[-----BEGIN CERTIFICATE-----
MIIB0TCCAXegAwIBAgIJAOo9VQCTpIExMAoGCCqGSM49BAMCMEUxCzAJBgNVBAYT
AlJVMRMwEQYDVQQIDApTb21lLVN0YXRlMSEwHwYDVQQKDBhJbnRlcm5ldCBXaWRn
aXRzIFB0eSBMdGQwHhcNMTgxMjA2MTczNDE3WhcNMjgxMjAzMTczNDE3WjBFMQsw
CQYDVQQGEwJSVTETMBEGA1UECAwKU29tZS1TdGF0ZTEhMB8GA1UECgwYSW50ZXJu
ZXQgV2lkZ2l0cyBQdHkgTHRkMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEkpNL
c/4PUjPG9iVd0iKA+5dszHsRU1w9LZEVEyUudcFQWcOuSiZvjkP7XK4OMP0nN8+x
2yhp2rkoPgzWafSwBaNQME4wHQYDVR0OBBYEFGWwerwH1k2YEUTrOtVidlb901u4
MB8GA1UdIwQYMBaAFGWwerwH1k2YEUTrOtVidlb901u4MAwGA1UdEwQFMAMBAf8w
CgYIKoZIzj0EAwIDSAAwRQIhAL115TQo/DX3lyhVfc5Ie+808U9oBR0MzI8B9qFh
ri1tAiBLSeXQ89nvecDC6K+xtcCd9NvaSmObROj71CDGRLd4mA==
-----END CERTIFICATE-----
]]
                , jwt_obj, claim_spec)

            print(cjson.encode(verified))
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
                    alg = "ES256",
                    x5c = {[[IIB0TCCAXegAwIBAgIJAOo9VQCTpIExMAoGCCqGSM49BAMCMEUxCzAJBgNVBAYT
AlJVMRMwEQYDVQQIDApTb21lLVN0YXRlMSEwHwYDVQQKDBhJbnRlcm5ldCBXaWRn
aXRzIFB0eSBMdGQwHhcNMTgxMjA2MTczNDE3WhcNMjgxMjAzMTczNDE3WjBFMQsw
CQYDVQQGEwJSVTETMBEGA1UECAwKU29tZS1TdGF0ZTEhMB8GA1UECgwYSW50ZXJu
ZXQgV2lkZ2l0cyBQdHkgTHRkMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEkpNL
c/4PUjPG9iVd0iKA+5dszHsRU1w9LZEVEyUudcFQWcOuSiZvjkP7XK4OMP0nN8+x
2yhp2rkoPgzWafSwBaNQME4wHQYDVR0OBBYEFGWwerwH1k2YEUTrOtVidlb901u4
MB8GA1UdIwQYMBaAFGWwerwH1k2YEUTrOtVidlb901u4MAwGA1UdEwQFMAMBAf8w
CgYIKoZIzj0EAwIDSAAwRQIhAL115TQo/DX3lyhVfc5Ie+808U9oBR0MzI8B9qFh
ri1tAiBLSeXQ89nvecDC6K+xtcCd9NvaSmObROj71CDGRLd4mA==]]}
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
