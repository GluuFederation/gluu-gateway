local cjson = require"cjson"
local jwt_lib = require "resty.jwt"

local function get_token(authorization)
    if authorization and #authorization > 0 then
        local from, to, err = ngx.re.find(authorization, "\\s*[Bb]earer\\s+(.+)", "jo", nil, 1)
        if from then
            return authorization:sub(from, to) -- Return token
        end
        if err then
            ngx.log(ngx.ERR, err)
            return nil
        end
    end

    return nil
end


-- should be called in context of access_by_lua_block
return function()
    local authorization = ngx.var.http_authorization
    local token = get_token(authorization)
    if not token then
        return
    end

    local jwt_tokens = ngx.shared.jwt_tokens
    local jwt = jwt_tokens:get(token)
    if jwt then
        ngx.req.set_header("Authorization", "Bearer " .. jwt)
        return
    end

    local token_data_string, exp_string = assert(token:match("^([^-]+)%-(%d+)$"))
    local token_data_json = ngx.decode_base64(token_data_string)
    local token_data = cjson.decode(token_data_json)
    local exp = tonumber(exp_string)
    token_data.exp = exp

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
    local t = {
        header = { typ = "JWT", alg = "RS256", kid = "1234567890" },
        payload = token_data,
    }

    local jwt = jwt_lib:sign(private_key, t)
    --print(jwt)

    ngx.req.set_header("Authorization", "Bearer " .. jwt)
    jwt_tokens:set(token, jwt, exp - ngx.time())
end