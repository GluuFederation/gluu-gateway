local helper = require "kong.plugins.gluu-oauth2-rs.helper"

--- Check uma_server_host is must https and not empty
-- @param given_value: Value of uma_server_host
-- @param given_config: whole config values including uma_server_host
local function uma_server_host_validator(given_value, given_config)
    ngx.log(ngx.DEBUG, "uma_server_host_validator: given_value:" .. given_value)

    if helper.is_empty(given_value) then
        ngx.log(ngx.ERR, "Invalid uma_server_host. It is blank.")
        return false
    end

    if helper.is_empty(given_value) then
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
        oxd_host = { required = true, type = "string" },
        uma_server_host = { required = true, type = "string", func = uma_server_host_validator },
        protection_document = { type = "string" },
        oauth_scope_expression = { type = "string" },
        client_id = { type = "string" },
        client_secret = { type = "string" },
        oxd_id = { type = "string" },
        client_id_of_oxd_id = { type = "string" }
    },
    self_check = function(schema, plugin_t, dao, is_updating)
        ngx.log(ngx.DEBUG, "is updating" .. tostring(is_updating))
        if not helper.is_empty(plugin_t.oxd_id) and not is_updating then
            return true
        end

        if helper.is_empty(plugin_t.protection_document) then
            return true
        end

        if is_updating then
            return helper.update_uma_rs(plugin_t), "Failed to update UMA RS on oxd server (make sure oxd server is running on oxd_host specified in configuration)"
        else
            return helper.register(plugin_t), "Failed to register API on oxd server (make sure oxd server is running on oxd_host specified in configuration)"
        end
    end
}