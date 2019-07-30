local cjson = require"cjson"

local _M = {}

local CLIENT_TOKEN_EXPIRES_IN = 30 --TODO make it shorter to force AT refresh?

local function read_file(path)
    local file = io_open(path, "rb") -- r read mode and b binary mode
    if not file then return nil, "Cannot open file: " .. path  end
    local content = file:read "*a" -- *a or *all reads the whole file
    file:close()
    return content
end

local function get_body_data()
    -- explicitly read the req body
    ngx.req.read_body()

    local data = ngx.req.get_body_data()
    if not data then
        -- body may get buffered in a temp file:
        local filename = ngx.req.get_body_file()
        if not filename then
            print("no body found")
            return nil
        end
        -- this is really bad for performance
        data = check(500, read_file(filename)) -- body should be here
    end
    return data
end

local function encode_access_token(access_token_table)
    local json_text = cjson.encode(access_token_table)
    return ngx.encode_base64(json_text)
end

local function response(status_code, body)
    if not body then
        return ngx.exit(status_code)
    end
    local body_type = type(body)
    if body_type == "table" then
        local json_text = cjson.encode(body)
        ngx.header.content_type = "application/json; charset=UTF-8"
        ngx.status = status_code
        ngx.say(json_text)
        return ngx.exit(ngx.HTTP_OK)
    end
    error("unsupported body type: " .. body_type)
end

local function get_client_token()
    local now = ngx.time()
    local access_token_data = {
        client_id = "@!1736.179E.AA60.16B2!0001!8F7C.B9AB!0008!A2BB.9AE6.5F14.B387",
        username = "John Black",
        scope = { "openid", "oxd" },
        token_type = "bearer",
        sub = "jblack",
        aud = "l238j323ds-23ij4",
        iss = "https://as.gluu.org/",
        exp = now + CLIENT_TOKEN_EXPIRES_IN,
        iat = now,
    }

    response(200,
        {
            scope = { "openid", "oxd" },
            access_token = encode_access_token(access_token_data),
            expires_in = CLIENT_TOKEN_EXPIRES_IN,
        })
end

local function introspect_access_token(body_json)
    local token_data_string, exp_string = assert(body_json.access_token:match("^([^-]+)%-(%d+)$"))
    local token_data_json = ngx.decode_base64(token_data_string)
    local token_data = cjson.decode(token_data_json)
    local exp = tonumber(exp_string)

    if  not exp or ngx.time() >= exp then
        return response(200,
            {
                active = false,
            }
        )
    end

    token_data.active = true
    token_data.exp = exp

    response(200, token_data)
end

local function get_jwks()
    response (200, {
        keys = {
        {
        kid = "1234567890",
        alg = "RS256",
        exp = ngx.time() + 60*5,
        x5c = {
[[MIICXzCCAgmgAwIBAgIJAO0JJN4B5G3gMA0GCSqGSIb3DQEBCwUAMIGKMQswCQYD
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
v8Z38NV9V6D4rXValytY0IIAsI30Z4nWpzDIQLQSZXbFGqM=]]},
    }}})
end

local endpoints_handles = {
    ["/get-client-token"] = get_client_token,
    ["/introspect-access-token"] = introspect_access_token,
    ["/get-jwks"] = get_jwks,
}

return function()
    local uri = ngx.var.uri
    local handler = assert(endpoints_handles[uri])

    local body = get_body_data()
    local body_json = cjson.decode(body)
    ngx.header.content_type = "application/json; charset=UTF-8"

    ngx.say(handler(body_json))
end

