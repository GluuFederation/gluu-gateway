local crud = require "kong.api.crud_helpers"
local responses = require "kong.tools.responses"
local helper = require "kong.plugins.gluu-oauth2-client-auth.helper"
local http = require "resty.http"
local json = require "JSON"

return {
    ["/consumers/:username_or_id/gluu-oauth2-client-auth/"] = {
        before = function(self, dao_factory, helpers)
            crud.find_consumer_by_username_or_id(self, dao_factory, helpers)
            self.params.consumer_id = self.consumer.id
        end,
        GET = function(self, dao_factory)
            crud.paginated_set(self, dao_factory.gluu_oauth2_client_auth_credentials)
        end,
        PUT = function(self, dao_factory)
            crud.put(self.params, dao_factory.gluu_oauth2_client_auth_credentials)
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
                    client_name = self.params.client_name or "kong_oauth2_bc_client",
                    jwks_uri = self.params.jwks_uri or "",
                    token_endpoint_auth_method = self.params.token_endpoint_auth_method or "",
                    token_endpoint_auth_signing_alg = self.params.token_endpoint_auth_signing_alg or ""
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
                client_name = self.params.client_name or "kong_oauth2_bc_client",
                client_id = regClientResponseBody.client_id,
                client_secret = regClientResponseBody.client_secret,
                token_endpoint = opResposebody.token_endpoint,
                introspection_endpoint = opResposebody.introspection_endpoint,
                op_host = self.params.op_host,
                consumer_id = self.params.consumer_id,
                jwks_uri = self.params.jwks_uri or "",
                token_endpoint_auth_method = self.params.token_endpoint_auth_method or "",
                token_endpoint_auth_signing_alg = self.params.token_endpoint_auth_signing_alg or "",
                jwks_file = self.params.jwks_file or ""
            }

            crud.post(regData, dao_factory.gluu_oauth2_client_auth_credentials)
        end
    },

    ["/consumers/:username_or_id/gluu-oauth2-client-auth/:clientid_or_id"] = {
        before = function(self, dao_factory, helpers)
            crud.find_consumer_by_username_or_id(self, dao_factory, helpers)
            self.params.consumer_id = self.consumer.id

            local credentials, err = crud.find_by_id_or_field(
                dao_factory.gluu_oauth2_client_auth_credentials,
                { consumer_id = self.params.consumer_id },
                self.params.clientid_or_id,
                "client_id"
            )

            if err then
                return helpers.yield_error(err)
            elseif next(credentials) == nil then
                return helpers.responses.send_HTTP_NOT_FOUND()
            end
            self.params.clientid_or_id = nil

            self.gluu_oauth2_client_auth_credential = credentials[1]
        end,

        GET = function(self, dao_factory, helpers)
            return helpers.responses.send_HTTP_OK(self.gluu_oauth2_client_auth_credential)
        end,

        PATCH = function(self, dao_factory)
            crud.patch(self.params, dao_factory.gluu_oauth2_client_auth_credentials, self.gluu_oauth2_client_auth_credential)
        end,

        DELETE = function(self, dao_factory)
            crud.delete(self.gluu_oauth2_client_auth_credential, dao_factory.gluu_oauth2_client_auth_credentials)
        end
    }
}