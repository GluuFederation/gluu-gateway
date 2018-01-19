local http = require "resty.http"
local helper = require "kong.plugins.gluu-oauth2-client-auth.helper"

local function register(config)
    if not helper.isempty(config.token_endpoint) then
        return true
    end

    -- http request
    local httpc = http.new()

    -- Request to OP and get openid-configuration
    local opRespose, err = httpc:request_uri(config.op_host .. "/.well-known/openid-configuration", {
        method = "GET",
        ssl_verify = false
    })

    ngx.log(ngx.DEBUG, "Request : " .. config.op_host .. "/.well-known/openid-configuration")
    ngx.log(ngx.DEBUG, (not pcall(helper.decode, opRespose.body)))

    if not pcall(helper.decode, opRespose.body) then
        ngx.log(ngx.DEBUG, "Error : " .. helper.print_table(err))
        return false
    end

    local opResposebody = helper.decode(opRespose.body)
    config.token_endpoint = opResposebody.token_endpoint
    config.introspection_endpoint = opResposebody.introspection_endpoint

    return true
end

local function op_host_validator(given_value, given_config)
    ngx.log(ngx.DEBUG, "op_host_validator: given_value:" .. given_value)

    if helper.isempty(given_value) then
        ngx.log(ngx.ERR, "Invalid op_host. It is blank.")
        return false
    end

    if not (string.sub(given_value, 0, 8) == "https://") then
        ngx.log(ngx.ERR, "Invalid op_host. It does not start from 'https://', value: " .. given_value)
        return false
    end

    return true
end

return {
    no_consumer = true,
    fields = {
        op_host = { type = "string", required = true, func = op_host_validator },
        token_endpoint = { type = "string" },
        introspection_endpoint = { type = "string" }
    },
    self_check = function(schema, plugin_t, dao, is_updating)
        return register(plugin_t), "Failed to register client pleae see the kong.log file"
    end
}