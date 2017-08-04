local http = require "resty.http"
local cjson = require "cjson"

local _M = {}

function _M.get_data()
    local httpc = http.new()
    local res, err = httpc:request_uri("http://localhost:8585/setup-client", {
        method = "GET"
    });

    ngx.log(ngx.DEBUG, res.body)
end

--function _M.get_token_by_code(conf, authorization_code, state)
--    local jsonBody = '{"oxd_id":"' .. conf.oxd_id .. '",'
--            .. '"code":"' .. authorization_code .. '",'
--            .. '"state":"' .. state .. '"}'
--
--    local httpc = http.new()
--    local res, err = httpc:request_uri(conf.oxd_host .. "/get-tokens-by-code", {
--        method = "POST",
--        body = jsonBody,
--        headers = {
--            ["Content-Type"] = "application/json",
--        }
--    })
--    ngx.log(ngx.DEBUG, "get-tokens-by-code:response - " .. res.body)
--    local response = cjson.decode(res.body)
--    http.close()
--
--    return response
--end

local function get_token_by_code(conf, authorization_code, state)
    local jsonBody = '{"oxd_id":"' .. conf.oxd_id .. '",'
            .. '"code":"' .. authorization_code .. '",'
            .. '"state":"' .. state .. '"}'

    local httpc = http.new()
    local res, err = httpc:request_uri("http://" .. conf.oxd_host .. ":8585/get-tokens-by-code", {
        method = "POST",
        body = jsonBody,
        headers = {
            ["Content-Type"] = "application/json",
        }
    })
    ngx.log(ngx.DEBUG, "get-tokens-by-code:response - " .. res.body)
    local response = cjson.decode(res.body)
--    http.close()

    return response
end

function _M.get_user_info(conf, authorization_code, state)
    -- ----------- Get and validate code --------------------
    local response = get_token_by_code(conf, authorization_code, state)

    if response["status"] == "error" then
        ngx.log(ngx.ERR, "get_token_by_code : authorization_code: " .. authorization_code .. ", conf.oxd_id: " .. conf.oxd_id .. ", state: " .. state)
        return response
    end

    local token = response["access_token"]

    -- ---------- Get user info ----------------------------
    local jsonBody = '{"oxd_id":"' .. conf.oxd_id .. '",'
            .. '"access_token":"' .. token .. '"}'

    local httpc = http.new()
    local res, err = httpc:request_uri("http://" .. conf.oxd_host .. ":8585/get-user-info", {
        method = "POST",
        body = jsonBody,
        headers = {
            ["Content-Type"] = "application/json",
        }
    })
    ngx.log(ngx.DEBUG, "get-user-info:response - " .. res.body)
    local response = cjson.decode(res.body)
  --  http.close()

    return response
end

function _M.get_authorization_url(conf)
    local jsonBody = '{"oxd_id":"' .. conf.oxd_id .. '"}'

    local httpc = http.new()
    local res, err = httpc:request_uri("http://" .. conf.oxd_host .. ":8585/get-authorization-url", {
        method = "POST",
        body = jsonBody,
        headers = {
            ["Content-Type"] = "application/json; charset=utf-8",
        }
    })
    ngx.log(ngx.DEBUG, "get-authorization-url:response - " .. res.body)
    local response = cjson.decode(res.body)
  --  http.close()

    return response
end

return _M