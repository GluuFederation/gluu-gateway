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
                header = { typ = "JWT", alg = "RS512", kid = "1234567890" },
                payload = {
                    client_id = request_json.client_id,
                    exp = ngx.now() + 60*5,
                    permissions = {},
                }
            }
            local private_key = [[
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA+H/dG3SB3xiugukW0xXxiCheGy9XkoUF3zF3Pfh8DK8HnIH2
LDBEY5zVEkfwm+bd3mgPfpG76Vky56z3DM+FRl4LHUivbl8B+fW0kQF5z1JMZBJC
h5s3rY3S/pkRdr0kfZgPT7SGnUJte8nTqlqLJFE384lIAxEpFORHcbZTReyFktZC
cvyTvzFidyM4idEUT3Aua64uCdx0VuGT4OmH1oymEsAtU4Pg0VTWOoL+x4smRbwB
ep3nSlbCPESDZ6DQEKWEHVUr+bKbYMfBpmOA4nOeIYfb+8uqeIsQ/bYv2mmkEvzD
0gqxJsfeN+Co/R0JYEzQY3xDKyojB1lFnGdBKQIDAQABAoIBAEkEgTrFBDhCr1yG
Ew/ZXcxNWEGSqp/B+JS5mzkZX5H2iD0DrwsS77V5at5hRyD4OG9Wkl71gYqyjBOp
LjqUa6vejFOBfRLoVdNV0EXfciRqIUoyV1wzTqvvhXUMEyaZszQ4Tx9zgy6IS1VZ
W5mt2z7DorYru34zN6gM37VZBqT/o5GpazvcLjUEOwCAVI5egTlV0lLy3Io57C8/
YbaJI6GCA7+HgcGEG2bs59YpzKmwInWLb+N1kax9XqakxLJA3qcx5N6uAdtcuCve
jZRSnEiR6MVd4bWdrokiblY8Ae+m5M6VBkrorbk5db5kULW9UcaJvln8LPy5eUzk
8piPjhECgYEA/e3Mjlgz9fYD+BzIU8SDJg8q27vEzD1uZzpE+pdb5frIrv06LP6V
ZppxGxK81vX+Vpokq+CSxcuV0zUZfpECoAc1hS06o473OWeBn0CX7yqheujzBMOx
AF6O0sTnDb0XZkOqY5HYlOtlhDjOZUwVfEHuOv+Hsybl/49IJ1YgWc0CgYEA+oa6
YWLv8E/COgvuG/G7UWmB/MkFc8HlHnHYLrK8fa1f5hm/XExmEfM/DMCQt2z8EM0b
Ovm6Be+oav4+BkzmM6blZKRDhibs8s12BrVKPQiht39E/ykd5JIEHruyKeVeoA75
nU91HcMV5iEF6b6WvvWQTdix7x9QJIBEES/EuM0CgYEAuAULRuT40vi0q6wAKWSy
PnSjdJZA6lpilgCOWKQz/xidMuNks5LTpoWqDhqoK4geB5ixlrWq6Bi/vU4v6Z8h
LePLj3XVlw5Wb41pTIW9FZ/pYm9LHlrK/R+JlYkIgNZWDNBgvMPHFzT4XrfkK1jW
ATSudqcUKmq4J1ooygkKbMkCgYBI9KUgKRywgbmRB9peXuXqzmvhPnUNAcEEPajz
6G8FtlCABK16ZnEu9wQ8ZXN/Rwicp+4vHXwzsFf+WG2djhVXo1mYFlHnpjxIdNbT
G0Y0Qeg+NJzWJZYj8vWqMYSvuLD2sYW1bucvNJmS+7jqGetyTraoRNuERD0ldAje
bGfAXQKBgQCDcJm7J57fRsFhVg+qxhlayIRudMh7Anx8fZeRxEmgxGl5BBhtHmLv
NZDUoRYg0a8oceWDLsWTqrGkRJN6zYqa8pr+WOSe/r7QgQ+W6AgoYlHKJ5BpybZD
Lk8vESLpKHTn32PJKBa2pPBbraWf/UVa5XQcBmpYOjfvj6SZ/pnvjA==
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
                    alg = "RS512",
                    x5c = {[[MIIDpzCCAo+gAwIBAgIJAMDerhuS5UbdMA0GCSqGSIb3DQEBCwUAMGkxCzAJBgNV
BAYTAlJVMRMwEQYDVQQIDApTb21lLVN0YXRlMQ8wDQYDVQQHDAZLYWx1Z2ExITAf
BgNVBAoMGEludGVybmV0IFdpZGdpdHMgUHR5IEx0ZDERMA8GA1UEAwwIdGVzdC5v
cmcwIBcNMTgxMjA1MDkwMjU3WhgPNDc1NjExMDEwOTAyNTdaMGkxCzAJBgNVBAYT
AlJVMRMwEQYDVQQIDApTb21lLVN0YXRlMQ8wDQYDVQQHDAZLYWx1Z2ExITAfBgNV
BAoMGEludGVybmV0IFdpZGdpdHMgUHR5IEx0ZDERMA8GA1UEAwwIdGVzdC5vcmcw
ggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQD4f90bdIHfGK6C6RbTFfGI
KF4bL1eShQXfMXc9+HwMrwecgfYsMERjnNUSR/Cb5t3eaA9+kbvpWTLnrPcMz4VG
XgsdSK9uXwH59bSRAXnPUkxkEkKHmzetjdL+mRF2vSR9mA9PtIadQm17ydOqWosk
UTfziUgDESkU5EdxtlNF7IWS1kJy/JO/MWJ3IziJ0RRPcC5rri4J3HRW4ZPg6YfW
jKYSwC1Tg+DRVNY6gv7HiyZFvAF6nedKVsI8RINnoNAQpYQdVSv5sptgx8GmY4Di
c54hh9v7y6p4ixD9ti/aaaQS/MPSCrEmx9434Kj9HQlgTNBjfEMrKiMHWUWcZ0Ep
AgMBAAGjUDBOMB0GA1UdDgQWBBRe1ddB+6VWjhN99A3mnxkZkET/jzAfBgNVHSME
GDAWgBRe1ddB+6VWjhN99A3mnxkZkET/jzAMBgNVHRMEBTADAQH/MA0GCSqGSIb3
DQEBCwUAA4IBAQA+/f0FU3jQmhnHi7kYfc5wgs/hJrMEwH/Yt1O1aiWFFzLAwEHK
CjzHrIwYqUgvdGiHF+0XB78WeBxp2kzOuQKn1zO+YDUAuM72LRQkNZ54M3Tio6L6
hbAQ64ASFCA/dm1b0eO+3UkGiq/STTS9UANpUSqJRwFU5cCdmJPAJs4i7KvgM1XO
Uvz65U/u9ZqCo1ePg1VwYe2QDxiW6i7p60gEuYqaR6nuKbtKO57NH5WRHFU6qgCD
DAManrq7vbGpJJFzJCH85aVRdNGKPjZYvKXiUFiy0y+NowxTFgvDRdzouRtgohD3
p+vmB051SzaYHbmXdhhnDtLScikAVLbPoAD9]]}
                }
            }
        },
        response_callback = function(response, request_json)
            setmetatable(response.keys, cjson.array_mt)
            response.keys[1].exp = ngx.now() + 60*5
        end
    },
    -- #5, client request access token
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
                header = { typ = "JWT", alg = "RS512", kid = "1234567890" },
                payload = {
                    client_id = request_json.client_id,
                    exp = ngx.now() + 60*5,
                    permissions = {},
                }
            }
            local private_key = [[
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA+H/dG3SB3xiugukW0xXxiCheGy9XkoUF3zF3Pfh8DK8HnIH2
LDBEY5zVEkfwm+bd3mgPfpG76Vky56z3DM+FRl4LHUivbl8B+fW0kQF5z1JMZBJC
h5s3rY3S/pkRdr0kfZgPT7SGnUJte8nTqlqLJFE384lIAxEpFORHcbZTReyFktZC
cvyTvzFidyM4idEUT3Aua64uCdx0VuGT4OmH1oymEsAtU4Pg0VTWOoL+x4smRbwB
ep3nSlbCPESDZ6DQEKWEHVUr+bKbYMfBpmOA4nOeIYfb+8uqeIsQ/bYv2mmkEvzD
0gqxJsfeN+Co/R0JYEzQY3xDKyojB1lFnGdBKQIDAQABAoIBAEkEgTrFBDhCr1yG
Ew/ZXcxNWEGSqp/B+JS5mzkZX5H2iD0DrwsS77V5at5hRyD4OG9Wkl71gYqyjBOp
LjqUa6vejFOBfRLoVdNV0EXfciRqIUoyV1wzTqvvhXUMEyaZszQ4Tx9zgy6IS1VZ
W5mt2z7DorYru34zN6gM37VZBqT/o5GpazvcLjUEOwCAVI5egTlV0lLy3Io57C8/
YbaJI6GCA7+HgcGEG2bs59YpzKmwInWLb+N1kax9XqakxLJA3qcx5N6uAdtcuCve
jZRSnEiR6MVd4bWdrokiblY8Ae+m5M6VBkrorbk5db5kULW9UcaJvln8LPy5eUzk
8piPjhECgYEA/e3Mjlgz9fYD+BzIU8SDJg8q27vEzD1uZzpE+pdb5frIrv06LP6V
ZppxGxK81vX+Vpokq+CSxcuV0zUZfpECoAc1hS06o473OWeBn0CX7yqheujzBMOx
AF6O0sTnDb0XZkOqY5HYlOtlhDjOZUwVfEHuOv+Hsybl/49IJ1YgWc0CgYEA+oa6
YWLv8E/COgvuG/G7UWmB/MkFc8HlHnHYLrK8fa1f5hm/XExmEfM/DMCQt2z8EM0b
Ovm6Be+oav4+BkzmM6blZKRDhibs8s12BrVKPQiht39E/ykd5JIEHruyKeVeoA75
nU91HcMV5iEF6b6WvvWQTdix7x9QJIBEES/EuM0CgYEAuAULRuT40vi0q6wAKWSy
PnSjdJZA6lpilgCOWKQz/xidMuNks5LTpoWqDhqoK4geB5ixlrWq6Bi/vU4v6Z8h
LePLj3XVlw5Wb41pTIW9FZ/pYm9LHlrK/R+JlYkIgNZWDNBgvMPHFzT4XrfkK1jW
ATSudqcUKmq4J1ooygkKbMkCgYBI9KUgKRywgbmRB9peXuXqzmvhPnUNAcEEPajz
6G8FtlCABK16ZnEu9wQ8ZXN/Rwicp+4vHXwzsFf+WG2djhVXo1mYFlHnpjxIdNbT
G0Y0Qeg+NJzWJZYj8vWqMYSvuLD2sYW1bucvNJmS+7jqGetyTraoRNuERD0ldAje
bGfAXQKBgQCDcJm7J57fRsFhVg+qxhlayIRudMh7Anx8fZeRxEmgxGl5BBhtHmLv
NZDUoRYg0a8oceWDLsWTqrGkRJN6zYqa8pr+WOSe/r7QgQ+W6AgoYlHKJ5BpybZD
Lk8vESLpKHTn32PJKBa2pPBbraWf/UVa5XQcBmpYOjfvj6SZ/pnvjA==
-----END RSA PRIVATE KEY-----
            ]]
            local jwt = jwt_lib:sign(private_key, t)
            print(jwt)
            response.access_token = jwt
        end

    },
}

return model
