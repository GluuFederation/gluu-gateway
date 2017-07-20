OXD_STATE_OK = "\"status\":\"ok\""

local socket = require("socket")
local cjson = require "cjson"

local function isempty(s)
    return s == nil or s == ''
end

local function commandWithLengthPrefix(json)
    local lengthPrefix = "" .. json:len();

    while lengthPrefix:len() ~= 4 do
        lengthPrefix = "0" .. lengthPrefix
    end

    return lengthPrefix .. json
end

local _M = {}

function _M.execute(conf, commandAsJson, timeout)
    ngx.log(ngx.DEBUG, 'op_host: ' .. conf.op_host .. ''
            .. ', oxd_port: ' .. conf.oxd_port .. ''
            .. ', oxd_host: ' .. conf.oxd_host);

    local host = socket.dns.toip(conf.oxd_host)
    ngx.log(ngx.DEBUG, "host: " .. host .. " command" .. commandAsJson)

    local client = socket.connect(host, conf.oxd_port);

    if (client == nil) then
        ngx.log(ngx.ERR, "OXD Server is not started")
        return '{ "status": "error", "data": { "description": "Oxd server is not start"}}'
    end

    local commandWithLengthPrefix = commandWithLengthPrefix(commandAsJson);
    ngx.log(ngx.DEBUG, "commandWithLengthPrefix: " .. commandWithLengthPrefix)

    client:settimeout(timeout)
    assert(client:send(commandWithLengthPrefix))
    local responseLength = client:receive("4")

    if responseLength == nil then -- sometimes if op_host does not reply or is down oxd calling it waits until timeout, since our timeout is 5 seconds we may got nil here.
        client:close();
        return "error"
    end

    ngx.log(ngx.DEBUG, "responseLength: " .. responseLength)

    local response = client:receive(tonumber(responseLength))
    ngx.log(ngx.DEBUG, "response: " .. response)

    client:close();
    ngx.log(ngx.DEBUG, "finished.")
    return response
end

-- Registers API on oxd server.
-- @param [ t y p e = t a b l e ] conf Schema configuration
-- @return boolean `ok`: A boolean describing if the registration was successfull or not
function _M.register(conf)
    ngx.log(ngx.DEBUG, "Registering on oxd ERR  ... ")

    local commandAsJson = '{"command":"register_site",'
            .. '"params":{"scope":' .. conf.scope .. ','
            .. '"op_host":"' .. conf.op_host .. '",'
            .. '"authorization_redirect_uri":"' .. conf.authorization_redirect_uri .. '",'
            .. '"client_id":"' .. conf.client_id .. '",'
            .. '"client_secret":"' .. conf.client_secret .. '",'
            .. '"response_types":["code"],'
            .. '"client_name":"kong_open_id"}}';

    local response = _M.execute(conf, commandAsJson, 5)

    if string.match(response, OXD_STATE_OK) then
        local asJson = cjson.decode(response)
        local oxd_id = asJson["data"]["oxd_id"]

        ngx.log(ngx.DEBUG, "Registered successfully. oxd_id from oxd server: " .. oxd_id)

        if not isempty(oxd_id) then
            conf.oxd_id = oxd_id
            return { result = true, oxd_id = oxd_id };
        end
    end

    return { result = false, oxd_id = nil };
end

function _M.get_authorization_url(conf)
    local commandAsJson = '{"command":"get_authorization_url",'
            .. '"params":{"oxd_id":"' .. conf.oxd_id .. '",'
            .. '"acr_values":["basic"]}}';

    local response = _M.execute(conf, commandAsJson, 5);
    local asJson = cjson.decode(response);

    return asJson;
end

local function get_token_by_code(conf, authorization_code, state)
    local commandAsJson = '{"command":"get_tokens_by_code",'
            .. '"params":{"oxd_id":"' .. conf.oxd_id .. '",'
            .. '"code":"' .. authorization_code .. '",'
            .. '"state":"' .. state .. '"}}';

    local response = _M.execute(conf, commandAsJson, 5);
    local asJson = cjson.decode(response);

    return asJson;
end

function _M.get_user_info(conf, authorization_code, state)
    -- ----------- Get and validate code --------------------
    local response = get_token_by_code(conf, authorization_code, state);

    if response["status"] == "error" then
        ngx.log(ngx.ERR, "get_token_by_code : authorization_code: " .. authorization_code .. ", conf.oxd_id: " .. conf.oxd_id .. ", state: " .. state)
        return response;
    end

    local token = response["data"]["access_token"];

    -- ---------- Get user info ----------------------------
    local commandAsJson = '{"command":"get_user_info",'
            .. '"params":{"oxd_id":"' .. conf.oxd_id .. '",'
            .. '"access_token":"' .. token .. '"}}';

    response = _M.execute(conf, commandAsJson, 5);
    local asJson = cjson.decode(response);

    return asJson;
end

return _M