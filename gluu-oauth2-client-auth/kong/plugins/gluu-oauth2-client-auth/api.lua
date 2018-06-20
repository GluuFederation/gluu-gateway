local utils = require "kong.tools.utils"
local oxd = require "oxdweb"
local crud = require "kong.api.crud_helpers"
local responses = require "kong.tools.responses"
local helper = require "kong.plugins.gluu-oauth2-client-auth.helper"

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
            if (helper.is_empty(self.params.op_host)) then
                return responses.send_HTTP_BAD_REQUEST("op_host is required")
            end

            if (helper.is_empty(self.params.oxd_http_url)) then
                return responses.send_HTTP_BAD_REQUEST("oxd_http_url is required")
            end

            if (self.params.oauth_mode and self.params.uma_mode and self.params.mix_mode) then
                return responses.send_HTTP_BAD_REQUEST("oauth mode, uma mode and mix mode, All flags cannot be YES at the same time")
            end

            if (self.params.oauth_mode and self.params.uma_mode) then
                return responses.send_HTTP_BAD_REQUEST("oauth mode and uma mode, Both flags cannot be YES at the same time")
            end

            if (self.params.oauth_mode and self.params.mix_mode) then
                return responses.send_HTTP_BAD_REQUEST("oauth mode and mix mode, Both flags cannot be YES at the same time")
            end

            if (self.params.uma_mode and self.params.mix_mode) then
                return responses.send_HTTP_BAD_REQUEST("uma mode and mix mode, Both flags cannot be YES at the same time")
            end

            if (not self.params.oauth_mode) and (not self.params.uma_mode) and (not self.params.mix_mode) then
                self.params.oauth_mode = true
            end

            if (not helper.is_empty(self.params.restrict_api) and self.params.restrict_api) then
                if helper.is_empty(self.params.restrict_api_list) then
                    return responses.send_HTTP_BAD_REQUEST("Requires at least one restricted API")
                end

                local list = helper.split(self.params.restrict_api_list, ",")
                for k, v in ipairs(list) do
                    if not utils.is_valid_uuid(v) then
                        return responses.send_HTTP_BAD_REQUEST("Invalid API, id: " .. v)
                    end
                end
            end

            local redirect_uris
            local scope
            local grant_types
            local client_name

            -- Default: redirect uri - https://localhost
            if (helper.is_empty(self.params.redirect_uris)) then
                redirect_uris = helper.split("https://localhost", ",")
            else
                redirect_uris = helper.split(self.params.redirect_uris, ",")
            end

            -- Default: scope - client_credentials
            if (helper.is_empty(self.params.scope)) then
                self.params.scope = "clientinfo,uma_protection"
                scope = helper.split(self.params.scope, ",")
            else
                self.params.scope = self.params.scope .. ",clientinfo,uma_protection"
                scope = helper.split(self.params.scope, ",")
            end

            -- Default: grant_types - client_credentials
            if (helper.is_empty(self.params.grant_types)) then
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
            if helper.is_empty(body.client_id) and helper.is_empty(body.client_id) then
                regClientResponseBody = oxd.setup_client(body)
            else
                -- Register site or update
                local tokenResponse = oxd.get_client_token(body)
                if helper.is_empty(tokenResponse.status) or tokenResponse.status == "error" then
                    return responses.send_HTTP_BAD_REQUEST("Invalid client credentials.")
                end

                if not helper.is_empty(self.params.oxd_id) then
                    body.oxd_id = self.params.oxd_id
                    regClientResponseBody = oxd.update_site(body, tokenResponse.data.access_token)
                else
                    regClientResponseBody = oxd.register_site(body, tokenResponse.data.access_token)
                end
            end

            if helper.is_empty(regClientResponseBody.status) or regClientResponseBody.status == "error" then
                return responses.send_HTTP_BAD_REQUEST("Client registration failed. Check oxd-http and oxd-server log")
            end

            regData = {
                consumer_id = self.params.consumer_id,
                name = self.params.name or "gluu-oauth2-client-auth",
                oxd_id = regClientResponseBody.data.oxd_id,
                oxd_http_url = self.params.oxd_http_url,
                scope = self.params.scope,
                op_host = self.params.op_host,
                client_id = regClientResponseBody.data.client_id or self.params.client_id,
                client_id_of_oxd_id = regClientResponseBody.data.client_id_of_oxd_id or self.params.client_id_of_oxd_id,
                client_secret = regClientResponseBody.data.client_secret or self.params.client_secret,
                client_jwks_uri = body.client_jwks_uri,
                jwks_file = self.params.jwks_file or "",
                client_token_endpoint_auth_method = body.client_token_endpoint_auth_method,
                client_token_endpoint_auth_signing_alg = body.client_token_endpoint_auth_signing_alg or "",
                uma_mode = self.params.uma_mode or false,
                mix_mode = self.params.mix_mode or false,
                oauth_mode = self.params.oauth_mode or false,
                allow_unprotected_path = self.params.allow_unprotected_path or false,
                restrict_api = self.params.restrict_api or false,
                restrict_api_list = self.params.restrict_api_list or "",
            }

            if helper.is_empty(self.params.show_consumer_custom_id) then
                regData.show_consumer_custom_id = true
            else
                regData.show_consumer_custom_id = self.params.show_consumer_custom_id
            end

            -- allow_oauth_scope_expression
            if helper.is_empty(self.params.allow_oauth_scope_expression) then
                regData.allow_oauth_scope_expression = false
            else
                regData.allow_oauth_scope_expression = regData.oauth_mode and self.params.allow_oauth_scope_expression
            end

            crud.post(regData, dao_factory.gluu_oauth2_client_auth_credentials)
        end
    },
    ["/consumers/:username_or_id/gluu-oauth2-client-auth/:clientid_or_id"] = {
        before = function(self, dao_factory, helpers)
            crud.find_consumer_by_username_or_id(self, dao_factory, helpers)
            self.params.consumer_id = self.consumer.id

            local credentials, err = crud.find_by_id_or_field(dao_factory.gluu_oauth2_client_auth_credentials,
                { consumer_id = self.params.consumer_id },
                self.params.clientid_or_id,
                "client_id")

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
            local body = {
                client_id = self.params.client_id or "",
                client_secret = self.params.client_secret or "",
                oxd_host = self.params.oxd_http_url,
                op_host = self.params.op_host
            }

            local tokenResponse = oxd.get_client_token(body)
            if helper.is_empty(tokenResponse.status) or tokenResponse.status == "error" then
                return responses.send_HTTP_BAD_REQUEST("Invalid client credentials.")
            end

            crud.patch(self.params, dao_factory.gluu_oauth2_client_auth_credentials, self.gluu_oauth2_client_auth_credential)
        end,
        DELETE = function(self, dao_factory)
            crud.delete(self.gluu_oauth2_client_auth_credential, dao_factory.gluu_oauth2_client_auth_credentials)
        end
    }
}