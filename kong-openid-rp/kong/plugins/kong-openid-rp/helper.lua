local oxd = require "oxdweb"
local common = require "kong.plugins.kong-openid-rp.common"

local _M = {}

function _M.register(conf)
    ngx.log(ngx.DEBUG, "Registering on oxd ... ")

    local response = oxd.setup_client(conf)

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

function _M.get_user_info(conf, authorization_code, state)
    -- ----------- Get client token ------------------------
    local token = oxd.get_client_token(conf)

    if token.status == "error" then
        ngx.log(ngx.ERR, "get_client_token")
        return token
    end

    -- ----------- Get and validate code --------------------
    conf.code = authorization_code
    conf.state = state
    local response = oxd.get_token_by_code(conf, token.data.access_token)

    if response.status == "error" then
        ngx.log(ngx.ERR, "get_token_by_code : authorization_code: " .. authorization_code .. ", conf.oxd_id: " .. conf.oxd_id .. ", state: " .. state)
        return response
    end

    local access_token = response.data.access_token

    -- ---------- Get user info ----------------------------
    conf.access_token = access_token
    local response = oxd.get_user_info(conf, token.data.access_token)
    return response
end

function _M.get_authorization_url(conf)
    local token = oxd.get_client_token(conf)

    if token.status == "error" then
        ngx.log(ngx.ERR, "get_client_token")
        return token
    end

    local response = oxd.get_authorization_url(conf, token.data.access_token)
    return response
end

function _M.get_logout_uri(conf)
    local token = oxd.get_client_token(conf)

    if token.status == "error" then
        ngx.log(ngx.ERR, "get_logout_uri")
        return token
    end

    local response = oxd.get_logout_uri(conf, token.data.access_token)
    return response
end

return _M