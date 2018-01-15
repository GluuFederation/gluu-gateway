local crud = require "kong.api.crud_helpers"
local responses = require "kong.tools.responses"
local helper = require "kong.plugins.gluu-oauth2-bc.helper"
local http = require "resty.http"
local json = require "JSON"

return {
    ["/consumers/:username_or_id/gluu-oauth2-bc/"] = {
        before = function(self, dao_factory, helpers)
            crud.find_consumer_by_username_or_id(self, dao_factory, helpers)
            self.params.consumer_id = self.consumer.id
        end,
        GET = function(self, dao_factory)
            crud.paginated_set(self, dao_factory.oxds)
        end,
        PUT = function(self, dao_factory)
            crud.put(self.params, dao_factory.oxds)
        end,
        POST = function(self, dao_factory)
            if (helper.isempty(self.params.op_host)) then
                return responses.send_HTTP_BAD_REQUEST("op_host is required")
            end

            local redirect_uris
            local scope
            local grant_types
            local client_name
            local regData = {}

            -- Default: redirect uri - https://localhost
            if (helper.isempty(self.params.redirect_uris)) then
                redirect_uris = helper.split("https://localhost", ",")
                regData["redirect_uris"] = "https://localhost"
            else
                redirect_uris = helper.split(self.params.redirect_uris, ",")
                regData["redirect_uris"] = self.params.redirect_uris
            end

            -- Default: scope - client_credentials
            if (helper.isempty(self.params.scope)) then
                scope = "clientinfo uma_protection"
            else
                scope = self.params.scope:gsub(",", " ")
            end

            -- Default: grant_types - client_credentials
            if (helper.isempty(self.params.grant_types)) then
                grant_types = helper.split("client_credentials", ",")
                regData["grant_types"] = "client_credentials"
            else
                grant_types = helper.split(self.params.grant_types, ",")
                regData["grant_types"] = self.params.grant_types
            end

            -- Default: client_name - kong_oauth2_bc_client
            if (helper.isempty(self.params.client_name)) then
                client_name = "kong_oauth2_bc_client"
            else
                client_name = self.params.client_name
            end

            -- http request
            local httpc = http.new()
            helper.print_table(self.params)
            -- Request to OP and get openid-configuration
            local opRespose, err = httpc:request_uri(self.params.op_host .. "/.well-known/openid-configuration", {
                method = "GET",
                ssl_verify = false
            })

            ngx.log(ngx.DEBUG, "Request : " .. self.params.op_host .. "/.well-known/openid-configuration")
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
                    scope = scope,
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

            local regData = {
                scope = scope,
                client_name = client_name,
                client_id = regClientResponseBody.client_id,
                client_secret = regClientResponseBody.client_secret,
                token_endpoint = opResposebody.token_endpoint,
                introspection_endpoint = opResposebody.introspection_endpoint,
                op_host = opResposebody.self.params.op_host,
                consumer_id = self.params.consumer_id,
            }

            crud.post(regData, dao_factory.gluu_oauth2_bc_credentials)
        end
    }
}