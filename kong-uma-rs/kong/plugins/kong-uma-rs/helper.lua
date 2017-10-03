local oxd = require "oxdweb"
local json = require "JSON"
local common = require "kong.plugins.kong-uma-rs.common"

local _M = {}

function _M.register(conf)
    ngx.log(ngx.DEBUG, "Registering on oxd ... ")

    -- ------------------Register Site----------------------------------
    local siteRequest = {
        oxd_host = conf.oxd_host,
        scope = { "openid", "uma_protection" },
        op_host = conf.uma_server_host,
        authorization_redirect_uri = "https://client.example.com/cb",
        response_types = { "code" },
        client_name = "kong_uma_rs",
        grant_types = { "authorization_code" }
    }

    local response = oxd.setup_client(siteRequest)

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

    local tokenRequest = {
        oxd_host = conf.oxd_host,
        client_id = data.client_id,
        client_secret = data.client_secret,
        scope = { "openid", "uma_protection" },
        op_host = conf.uma_server_host,
        authorization_redirect_uri = "https://client.example.com/cb",
        grant_types = { "authorization_code" }
    };
    local token = oxd.get_client_token(tokenRequest)

    if token.status == "error" then
        ngx.log(ngx.ERR, "Error in get_client_token")
        return false
    end
    -- -----------------------------------------------------------------

    -- --------------- UMA-RS Protect ----------------------------------
    local umaRSRequest = {
        oxd_host = conf.oxd_host,
        oxd_id = data.oxd_id,
        resources = json:decode(conf.protection_document)
    }

    response = oxd.uma_rs_protect(umaRSRequest, token.data.access_token)

    if response.status == "error" then
        return false
    end

    ngx.log(ngx.ERR, "Registered resources : " .. data.oxd_id)
    conf.oxd_id = data.oxd_id
    conf.client_id = data.client_id
    conf.client_secret = data.client_secret

    return true
    -- -----------------------------------------------------------------
end

function _M.checkaccess(conf, rpt, path, httpMethod)
    -- ------------------GET Client Token-------------------------------
    local tokenRequest = {
        oxd_host = conf.oxd_host,
        client_id = conf.client_id,
        client_secret = conf.client_secret,
        scope = { "openid", "uma_protection" },
        op_host = conf.uma_server_host
    };

    local token = oxd.get_client_token(tokenRequest)

    if token.status == "error" then
        ngx.log(ngx.ERR, "Error in get_client_token")
        return false
    end
    -- -----------------------------------------------------------------

    -- ------------------GET access-------------------------------
    local umaAccessRequest = {
        oxd_host = conf.oxd_host,
        oxd_id = conf.oxd_id,
        rpt = rpt,
        path = path,
        http_method = httpMethod
    };
    local response = oxd.uma_rs_check_access(umaAccessRequest, token.data.access_token)

    return response;
end

return _M