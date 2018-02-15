local helper = require "kong.plugins.kong-uma-rs.helper"

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

--- Check unprotected_path_cache_time_sec is must be >= 0
-- @param given_value: Value of uma_server_host
-- @param given_config: whole config values including uma_server_host
local function path_time_validator(given_value, given_config)
    ngx.log(ngx.DEBUG, "path_time_validator: given_value:" .. given_value)

    if given_value < 0 then
        ngx.log(ngx.ERR, "Invalid unprotected_path_time_sec. It must be >= 0.")
        return false
    end

    return true
end

return {
    no_consumer = true,
    fields = {
        oxd_host = { required = true, type = "string" },
        uma_server_host = { required = true, type = "string", func = uma_server_host_validator },
        protection_document = { required = true, type = "string" },
        unprotected_path_cache_time_sec = { default = 3600, type = "number", func = path_time_validator }
    },
    self_check = function(schema, plugin_t, dao, is_updating)
        if not helper.is_empty(plugin_t.oxd_id) then
            return true
        end

        return helper.register(plugin_t), "Failed to register API on oxd server (make sure oxd server is running on oxd_host specified in configuration)"
    end
}