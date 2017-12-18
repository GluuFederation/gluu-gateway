local oxd = require "kong.plugins.kong-uma-rs.helper"

local function isempty(s)
    return s == nil or s == ''
end

local function protection_document_validator(given_value, given_config)

    ngx.log(ngx.DEBUG, "protection_document_validator: given_value:" .. given_value)

    if isempty(given_value) then
        ngx.log(ngx.ERR, "Invalid protection_document. It is blank.")
        return false
    end

    return true
end

local function host_validator(given_value, given_config)
    ngx.log(ngx.DEBUG, "host_validator: given_value:" .. given_value)

    if isempty(given_value) then
        ngx.log(ngx.ERR, "Invalid oxd_host. It is blank.")
        return false
    end

    return true
end

local function uma_server_host_validator(given_value, given_config)
    ngx.log(ngx.DEBUG, "uma_server_host_validator: given_value:" .. given_value)

    if isempty(given_value) then
        ngx.log(ngx.ERR, "Invalid uma_server_host. It is blank.")
        return false
    end

    if isempty(given_value) then
        ngx.log(ngx.ERR, "Invalid uma_server_host. It is blank.")
        return false
    end

    if not (string.sub(given_value, 0, 8) == "https://") then
        ngx.log(ngx.ERR, "Invalid uma_server_host. It does not start from 'https://', value: " .. given_value)
        return false
    end

    return true
end

return {
    no_consumer = true,
    fields = {
        oxd_host = { required = true, type = "string", func = host_validator },
        uma_server_host = { required = true, type = "string", func = uma_server_host_validator },
        protection_document = { required = true, type = "string", func = protection_document_validator },
    },
    self_check = function(schema, plugin_t, dao, is_updating)
        if not isempty(plugin_t.oxd_id) then
            return true
        end

        return oxd.register(plugin_t), "Failed to register API on oxd server (make sure oxd server is running on oxd_host specified in configuration)"
    end
}