local helper = require "kong.plugins.gluu-oauth2-bc.helper"
local http = require "resty.http"
local json = require "JSON"

local function register(config)
    if not helper.isempty(config.client_id) then
        return true
    end

    local redirect_uris
    local scopes
    local grant_types
    local client_name

    -- Default: redirect uri - https://localhost
    if (helper.isempty(config.redirect_uris)) then
        redirect_uris = helper.split("https://localhost", ",")
    else
        redirect_uris = helper.split(config.redirect_uris, ",")
    end

    -- Default: scopes - client_credentials
    if (helper.isempty(config.scopes)) then
        scopes = "clientinfo uma_protection"
    else
        scopes = config.scopes:gsub(",", " ")
    end

    -- Default: grant_types - client_credentials
    if (helper.isempty(config.grant_types)) then
        grant_types = "client_credentials"
        grant_types = helper.split(grant_types, ",")
    else
        grant_types = helper.split(config.grant_types, ",")
    end

    -- Default: client_name - kong_oauth2_bc_client
    if (helper.isempty(config.client_name)) then
        client_name = "kong_oauth2_bc_client"
    else
        client_name = config.client_name
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

    -- Request for client registration
    local headers = {
        ["Content-Type"] = "application/json"
    }

    local regClientResponse, err = httpc:request_uri(opResposebody.registration_endpoint, {
        method = "POST",
        body = json:encode({
            redirect_uris = redirect_uris,
            scopes = scopes,
            grant_types = grant_types,
            client_name = client_name
        }),
        headers = headers,
        ssl_verify = false
    })

    ngx.log(ngx.DEBUG, "Request : " .. opResposebody.registration_endpoint)

    if not pcall(helper.decode, regClientResponse.body) then
        ngx.log(ngx.DEBUG, "Error : " .. helper.print_table(err))
        return false
    end

    local regClientResponseBody = helper.decode(regClientResponse.body)
    config.client_id = regClientResponseBody.client_id
    config.client_secret = regClientResponseBody.client_secret
    config.token_endpoint = opResposebody.token_endpoint
    config.introspection_endpoint = opResposebody.introspection_endpoint

    return true
end

return {
    no_consumer = true,
    fields = {
        redirect_uris = { type = "string" },
        scope = { type = "string" },
        grant_types = { type = "string" },
        op_host = { type = "string", required = true },
        client_name = { type = "string" },
        jwks_uri = { type = "string" },
        token_endpoint_auth_method = { type = "string" },
        token_endpoint_auth_signing_alg = { type = "string" },
        client_id = { type = "string" },
        client_secret = { type = "string" },
        token_endpoint = { type = "string" },
        introspection_endpoint = { type = "string" }
    },
    self_check = function(schema, plugin_t, dao, is_updating)
        return register(plugin_t), "Failed to register client pleae see the kong.log file"
    end
}