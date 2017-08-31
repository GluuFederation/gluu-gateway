local http = require "resty.http"
local cjson = require "cjson"
local json = require "JSON"
local common = require "kong.plugins.kong-openid-rp.common"

local _M = {}

function _M.get_data()
    local httpc = http.new()
    local res, err = httpc:request_uri("http://localhost:8585/setup-client", {
        method = "GET"
    });

    ngx.log(ngx.DEBUG, res.body)
end

function _M.execute_http(conf, jsonBody, token, command)
    ngx.log(ngx.DEBUG, "Executing command: " .. command)
    local httpc = http.new()
    local headers = {
        ["Content-Type"] = "application/json"
    }

    if token ~= nil then
        headers.Authorization = "Bearer " .. token
        ngx.log(ngx.DEBUG, "Header token: " .. headers.Authorization)
    end

    local res, err = httpc:request_uri(conf.oxd_host .. "/" .. command, {
        method = "POST",
        body = jsonBody,
        headers = headers
    })

    common.print_table(res);
    ngx.log(ngx.DEBUG, "Host: " .. conf.oxd_host .. "/" .. command .. " Request_Body:" .. jsonBody .. " response_body: " .. res.body)
    local response = cjson.decode(res.body)
    --    http.close()

    return response
end

-- Registers API on oxd server.
-- @param [ t y p e = t a b l e ] conf Schema configuration
-- @return boolean `ok`: A boolean describing if the registration was successfull or not
function _M.register(conf)
    ngx.log(ngx.DEBUG, "Registering on oxd ... ")

    local commandAsJson = json:encode(conf)
    local response = _M.execute_http(conf, commandAsJson, nil, "setup-client")

    if response.status == "ok" then
        local data = response.data

        ngx.log(ngx.DEBUG, "Registered successfully.")

        if not common.isempty(data) then
            conf.oxd_id = data.oxd_id
            return { result = true, data = data }
        end
    end

    return { result = false, data = nil }
end

local function get_client_token(conf)
    local commandAsJson = json:encode(conf)
    local response = _M.execute_http(conf, commandAsJson, nil, "get-client-token")
    return response
end

local function get_token_by_code(conf, authorization_code, state, token)
    local jsonBody = '{"oxd_id":"' .. conf.oxd_id .. '",'
            .. '"code":"' .. authorization_code .. '",'
            .. '"state":"' .. state .. '"}'

    local response = _M.execute_http(conf, jsonBody, token, "get-tokens-by-code")
    return response
end

function _M.get_user_info(conf, authorization_code, state)

    local token = get_client_token(conf);

    if token.status == "error" then
        ngx.log(ngx.ERR, "get_client_token")
        return token
    end

    -- ----------- Get and validate code --------------------
    local response = get_token_by_code(conf, authorization_code, state, token.data.access_token)

    if response.status == "error" then
        ngx.log(ngx.ERR, "get_token_by_code : authorization_code: " .. authorization_code .. ", conf.oxd_id: " .. conf.oxd_id .. ", state: " .. state)
        return response
    end

    local access_token = response.data.access_token

    -- ---------- Get user info ----------------------------
    local jsonBody = '{"oxd_id":"' .. conf.oxd_id .. '",'
            .. '"access_token":"' .. access_token .. '"}'

    local response = _M.execute_http(conf, jsonBody, token.data.access_token, "get-user-info")
    return response
end

function _M.get_authorization_url(conf)
    local token = get_client_token(conf)

    if token.status == "error" then
        ngx.log(ngx.ERR, "get_client_token")
        return token
    end

    local jsonBody = json:encode(conf);

    local response = _M.execute_http(conf, jsonBody, token.data.access_token, "get-authorization-url")
    return response
end

function _M.get_logout_uri(conf)
    local token = get_client_token(conf)

    if token.status == "error" then
        ngx.log(ngx.ERR, "get_logout_uri")
        return token
    end

    local commandAsJson = '{"oxd_id":"' .. conf.oxd_id .. '"}'

    local response = _M.execute_http(conf, commandAsJson, token.data.access_token, "get-logout-uri")
    return response
end

return _M