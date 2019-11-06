local cjson = require "cjson.safe"
local http = require "resty.http"

local function path_split(s)
    local result = {};
    for match in (s):gmatch([[/([^/]*)]]) do
        result[#result + 1] = match
    end
    return result
end

return function(self, conf)
    local input = {}
    -- current request info
    input.method = ngx.req.get_method()
    input.path = path_split(ngx.var.uri:match"^([^%s]+)") -- split normilized URI
    input.uri_args = ngx.req.get_uri_args()
    input.headers = ngx.req.get_headers()
    if conf.forward_request_body then
        input.body = kong.request.get_body()
    end

    -- oauth token data or OpenId Connect id_token, if any
    input.request_token_data = kong.ctx.shared.request_token_data

    -- OpenID Connect userinfo, if any
    input.userinfo = kong.ctx.shared.userinfo


    local cjson2 = cjson.new()
    local opa_body_json, err = cjson2.encode{ input = input }
    if not opa_body_json then
        ngx.log(ngx.ERR, "JSON encode error: ", err)
        kong.response.exit(502)
    end

    ngx.log(ngx.DEBUG, opa_body_json)

    local httpc = http.new()
    local res, err = httpc:request_uri(conf.opa_url,
        {
            method = "POST",
            body = opa_body_json,
            headers = {
                ["Content-Type"] = "application/json",
            }
        }
    )

    if not res then
        ngx.log(ngx.ERR, "resty-http error: ", err)
        kong.response.exit(502)
    end

    local status = res.status
    if status ~= 200 then
        ngx.log(ngx.ERR, "opa responds with status: ", status)
        kong.response.exit(502)
    end

    local body = res.body
    ngx.log(ngx.DEBUG, "OPA responds with body:\n", body)

    local body_json, err = cjson2.decode(body)
    if not body_json then
        ngx.log(ngx.ERR, "JSON decode error: ", err)
        kong.response.exit(502)
    end

    if body_json.result and body_json.result.allow then
        ngx.log(ngx.DEBUG, "request allowed")
        kong.ctx.shared[self.metric_client_granted] = true
        return
    end

    kong.response.exit(403)
end
