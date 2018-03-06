local helper = require "kong.plugins.gluu-oauth2-client-auth.helper"

--- Check op_server_validator is must https and not empty
-- @param given_value: Value of op_server_validator
-- @param given_config: whole config values including op_server_validator
local function op_server_validator(given_value, given_config)
    ngx.log(ngx.DEBUG, "op_server_validator: given_value:" .. given_value)

    if not (string.sub(given_value, 0, 8) == "https://") then
        ngx.log(ngx.DEBUG, "op_server must be 'https'")
        return false, "op_server must be 'https'"
    end

    return true
end

return {
    no_consumer = true,
    fields = {
        hide_credentials = { type = "boolean", default = false },
        oxd_id = { type = "string" },
        op_server = { required = true, type = "string", func = op_server_validator },
        oxd_http_url = { required = true, type = "string" }
    },
    self_check = function(schema, plugin_t, dao, is_updating)
        ngx.log(ngx.DEBUG, "gluu-oauth2-client-auth oxd_id: " .. tostring(helper.is_empty(plugin_t.oxd_id)))
        if not helper.is_empty(plugin_t.oxd_id) then
            return true
        end

        return helper.register(plugin_t), "Failed to register API on oxd server (make sure oxd server is running on oxd_host specified in configuration)"
    end
}