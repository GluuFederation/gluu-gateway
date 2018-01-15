local responses = require "kong.tools.responses"
local http = require "resty.http"
local helper = require "kong.plugins.gluu-oauth2-bc.helper"

local _M = {}

function _M.execute(config)
    -- Fetch basic token from header
    local basicToken = ngx.req.get_headers()["Authorization"]

    -- check token is empty ot not
    if helper.isempty(basicToken) then
        return responses.send_HTTP_UNAUTHORIZED("Failed to get token from header. Please pass basic token in authorization header")
    end

    ngx.log(ngx.DEBUG, "gluu-oauth2-bc : " .. basicToken)

    -- http request
    local httpc = http.new()

    -- Request to OP and get openid-configuration

    local tokenRespose, err = httpc:request_uri(config.token_endpoint, {
        method = "POST",
        ssl_verify = false,
        headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded",
            ["Authorization"] = basicToken
        },
        body = "grant_type=client_credentials&scope=uma_protection clientinfo"
    })

    ngx.log(ngx.DEBUG, "Request : " .. config.token_endpoint)

    if not pcall(helper.decode, tokenRespose.body) then
        ngx.log(ngx.DEBUG, "Error : " .. helper.print_table(err))
        return false
    end

    local tokenResposeBody = helper.decode(tokenRespose.body)

    ngx.log(ngx.DEBUG, helper.print_table(tokenResposeBody))

    if helper.isempty(tokenResposeBody["access_token"]) then
        return responses.send_HTTP_UNAUTHORIZED("Failed to allow grant")
    end

    return -- ACCESS GRANTED
end

return _M

