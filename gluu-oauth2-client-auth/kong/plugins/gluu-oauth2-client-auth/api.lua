local oxd = require "oxdweb"
local crud = require "kong.api.crud_helpers"
local responses = require "kong.tools.responses"
local helper = require "kong.plugins.gluu-oauth2-client-auth.helper"
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

            if (helper.isempty(self.params.oxd_http_url)) then
                return responses.send_HTTP_BAD_REQUEST("oxd_http_url is required")
            end

            local redirect_uris
            local scope
            local grant_types
            local client_name

            -- Default: redirect uri - https://localhost
            if (helper.isempty(self.params.redirect_uris)) then
                redirect_uris = helper.split("https://localhost", ",")
            else
                redirect_uris = helper.split(self.params.redirect_uris, ",")
            end

            -- Default: scope - client_credentials
            if (helper.isempty(self.params.scope)) then
                scope = helper.split("clientinfo,uma_protection", ",")
            else
                scope = helper.split(self.params.scope, ",")
            end

            -- Default: grant_types - client_credentials
            if (helper.isempty(self.params.grant_types)) then
                grant_types = helper.split("client_credentials", ",")
            else
                grant_types = helper.split(self.params.grant_types, ",")
            end

            local body = {
                client_id = self.params.client_id or "",
                client_secret = self.params.client_secret or "",
                oxd_host = self.params.oxd_http_url,
                op_host = self.params.op_host,
                authorization_redirect_uri = redirect_uris[1],
                redirect_uris = redirect_uris,
                scope = scope,
                grant_types = grant_types,
                client_name = self.params.client_name or self.params.name or "kong_oauth2_bc_client",
                client_jwks_uri = self.params.client_jwks_uri or "",
                client_token_endpoint_auth_method = self.params.client_token_endpoint_auth_method or "",
                client_token_endpoint_auth_signing_alg = self.params.client_token_endpoint_auth_signing_alg or ""
            }

            local regClientResponseBody
            local regData
            -- setup client
            if helper.isempty(body.client_id) and helper.isempty(body.client_id) then
                regClientResponseBody = oxd.setup_client(body)
            else
                -- Register site or update
                local tokenResponse = oxd.get_client_token(body)
                if tokenResponse.status == "ok" then
                    if not helper.isempty(self.params.oxd_id) then
                        body.oxd_id = self.params.oxd_id
                        regClientResponseBody = oxd.update_site(body, tokenResponse.data.access_token)
                    else
                        regClientResponseBody = oxd.register_site(body, tokenResponse.data.access_token)
                    end
                else
                    return responses.send_HTTP_BAD_REQUEST("Register site: failed to fetch client token")
                end
            end

            if regClientResponseBody.status == "ok" then
                regData = {
                    consumer_id = self.params.consumer_id,
                    name = self.params.name or "gluu-oauth2-client-auth",
                    oxd_id = regClientResponseBody.data.oxd_id,
                    oxd_http_url = self.params.oxd_http_url,
                    scope = self.params.scope,
                    op_host = self.params.op_host,
                    client_id = regClientResponseBody.data.client_id or self.params.client_id,
                    client_secret = regClientResponseBody.data.client_secret or self.params.client_secret,
                    client_jwks_uri = body.client_jwks_uri,
                    jwks_file = self.params.jwks_file or "",
                    client_token_endpoint_auth_method = body.client_token_endpoint_auth_method,
                    client_token_endpoint_auth_signing_alg = body.client_token_endpoint_auth_signing_alg or ""
                }

                crud.post(regData, dao_factory.gluu_oauth2_client_auth_credentials)
            else
                return responses.send_HTTP_BAD_REQUEST("Client registration failed. Check oxd-http and oxd-server log")
            end
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