local http = require "resty.http"
local cjson = require "cjson"
local json = require "JSON"
local common = require "kong.plugins.kong-uma-rs.common"

local _M = {}

function _M.get_data()
    local httpc = http.new()
    local res, err = httpc:request_uri("http://localhost:8585/setup-client", {
        method = "GET"
    });

    ngx.log(ngx.DEBUG, res.body)
end

function _M.execute_http(conf, jsonBody, token, command)
    ngx.log(ngx.DEBUG, "Executing command: " .. command .. " oxd_host" .. conf.oxd_host)
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

function _M.register(conf)
    ngx.log(ngx.DEBUG, "Registering on oxd ... ")

    -- ------------------Register Site----------------------------------
    local commandAsJson = '{"scope":["openid","uma_protection"],"contacts":[],"op_host":"' .. conf.uma_server_host .. '","authorization_redirect_uri":"https://client.example.com/cb","redirect_uris":null,"response_types":["code"],"client_name":"kong_uma_rs","grant_types":["authorization_code"]}';
    local response = _M.execute_http(conf, commandAsJson, nil, "setup-client")

    if response.status == "error" then
        return false
    end

    local data = response.data

    if common.isempty(data) then
        return false
    end

    ngx.log(ngx.DEBUG, "Registered successfully.")

    -- -----------------------------------------------------------------

    -- ------------------GET Client Token-------------------------------

    commandAsJson = '{"client_id": "' .. data.client_id .. '","client_secret": "' .. data.client_secret .. '","scope":["openid","uma_protection"],"op_host":"' .. conf.uma_server_host .. '","authorization_redirect_uri":"https://client.example.com/cb","grant_types":["authorization_code"]}';
    local token = _M.execute_http(conf, commandAsJson, nil, "get-client-token")

    if token.status == "error" then
        ngx.log(ngx.ERR, "Error in get_client_token")
        return false
    end
    -- -----------------------------------------------------------------

    -- --------------- UMA-RS Protect ----------------------------------
    local jsonBody = '{"oxd_id":"' .. data.oxd_id .. '",'
            .. '"resources":' .. conf.protection_document .. '}'

    ngx.log(ngx.DEBUG, jsonBody)

    response = _M.execute_http(conf, jsonBody, token.data.access_token, "uma-rs-protect")

    if response.status == "error" then
        return false
    end

    ngx.log(ngx.ERR, "Registered resources : " .. response.data.oxd_id)
    conf.oxd_id = data.oxd_id
    conf.client_id = data.client_id
    conf.client_secret = data.client_secret

    return true
    -- -----------------------------------------------------------------
end


local function get_token_by_code(conf, authorization_code, state, token)
    local jsonBody = '{"oxd_id":"' .. conf.oxd_id .. '",' .. '"code":"' .. authorization_code .. '",' .. '"state":"' .. state .. '"}'

    local response = _M.execute_http(conf, jsonBody, token, "get-tokens-by-code")
    return response
end


function _M.checkaccess(conf, rpt, path, httpMethod)
    -- ------------------GET Client Token-------------------------------
    local commandAsJson = '{"client_id": "' .. conf.client_id .. '","client_secret": "' .. conf.client_secret .. '","scope":["openid","uma_protection"],"op_host":"' .. conf.uma_server_host .. '"}';
    local token = _M.execute_http(conf, commandAsJson, nil, "get-client-token")

    if token.status == "error" then
        ngx.log(ngx.ERR, "Error in get_client_token")
        return false
    end
    -- -----------------------------------------------------------------

    -- ------------------GET access-------------------------------
    local commandAsJson = '{"oxd_id":"' .. conf.oxd_id .. '","rpt":"' .. rpt .. '","path":"' .. path .. '","http_method":"' .. httpMethod .. '"}';
    local response = _M.execute_http(conf, commandAsJson, token.data.access_token, "uma-rs-check-access")

    if response.status == "error" then
        ngx.log(ngx.ERR, "Error in uma-rs-check-access ticket")
        return false
    end

    return true;
    -- -----------------------------------------------------------------
end

return _M