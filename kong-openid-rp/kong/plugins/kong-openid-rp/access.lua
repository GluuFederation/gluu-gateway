local oxd = require "kong.plugins.kong-openid-rp.oxdclient"
local responses = require "kong.tools.responses"
local stringy = require "stringy"
local singletons = require "kong.singletons"
local cache = require "kong.tools.database_cache"

local function isempty(s)
    return s == nil or s == ''
end

local _M = {}

local function getPath()
    local path = ngx.var.request_uri
    local indexOf = string.find(path, "?")
    if indexOf ~= nil then
        return string.sub(path, 1, (indexOf - 1))
    end
    return path
end

local function load_oxd_by_oxd_id(oxd_id)
    local creds, err = singletons.dao.oxds:find_all {
        oxd_id = oxd_id
    }
    if not creds then
        return nil, err
    end
    return creds[1]
end

function _M.execute(conf)
    local httpMethod = ngx.req.get_method()
    local authorization_code = ngx.req.get_headers()["authorization_code"]
    local state = ngx.req.get_headers()["state"]
    local oxd_id = ngx.req.get_headers()["oxd_id"]
    local path = getPath()

    -- ------- validation ------
    if isempty(authorization_code) then
        return responses.send_HTTP_BAD_REQUEST("Please pass authorization code")
    end
    if isempty(state) then
        return responses.send_HTTP_BAD_REQUEST("Please pass sate")
    end
    if isempty(oxd_id) then
        return responses.send_HTTP_BAD_REQUEST("Please pass oxd_id")
    end
    ngx.log(ngx.DEBUG, "kong-openid-rp : Access - http_method: " .. httpMethod .. ", code: " .. authorization_code .. ", path: " .. path .. ", state: " .. state)
    -- ------------------------

    -- local oxdConfig = load_oxd_by_client_id(client_id);
    local oxdConfig = cache.get_or_set(cache.oxd_key(oxd_id), nil, load_oxd_by_oxd_id, oxd_id);
    local response = oxd.get_user_info(oxdConfig, authorization_code, state)

    if response == nil then
        return responses.send_HTTP_FORBIDDEN("OP Authorization Server Unreachable")
    end

    if response["status"] == "error" then
        ngx.log(ngx.ERR, "kong-openid-rp : Failed to authenticate! - http_method: " .. httpMethod .. ", authorization_code: " .. authorization_code .. ", state: " .. state)
        ngx.header["OAuth-Warning"] = "Failed to authenticate by OAuth. Please check code and state."
        return responses.send_HTTP_UNAUTHORIZED("Unauthorized")
    end

    if response["status"] == "ok" then
        return -- ACCESS GRANTED
    else
        return responses.send_HTTP_UNAUTHORIZED("Unauthorized")
    end

    return responses.send_HTTP_FORBIDDEN("Unknown (unsupported) status code from oxd server for uma_rs_check_access operation.")
end

return _M

