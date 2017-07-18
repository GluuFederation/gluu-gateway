local stringy = require "stringy"
local oxd = require "kong.plugins.kong-openid-rp.oxdclient"

local function isempty(s)
    return s == "" or s == nil
end

local function op_host_validator(given_value, given_config)
    ngx.log(ngx.DEBUG, "op_host_validator: given_value:" .. given_value)

    if isempty(given_value) then
        ngx.log(ngx.ERR, "Invalid op_host_validator. It is blank.")
        return false, "Invalid url. It must not be blank"
    end

    if not stringy.startswith(given_value, "https://") then
        ngx.log(ngx.ERR, "Invalid op_host_validator. It does not start from 'https://' , value: " .. given_value)
        return false, "Invalid url. It must be start from 'https://'"
    end

    return true
end

local function authorization_redirect_uri_validator(given_value, given_config)
    ngx.log(ngx.DEBUG, "authorization_redirect_uri_validator: given_value:" .. given_value)

    if isempty(given_value) then
        ngx.log(ngx.ERR, "Invalid authorization_redirect_uri_validator. It is blank.")
        return false, "Invalid url. It must not be blank"
    end

    if not stringy.startswith(given_value, "https://") then
        ngx.log(ngx.ERR, "Invalid authorization_redirect_uri_validator. It does not start from 'https://' , value: " .. given_value)
        return false, "Invalid url. It must be start from 'https://'"
    end

    return true
end

return {
    no_consumer = true,
    fields = {
    }
}