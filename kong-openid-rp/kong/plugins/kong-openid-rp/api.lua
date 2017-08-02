local crud = require "kong.api.crud_helpers"
local oxd = require "kong.plugins.kong-openid-rp.oxdclient"
local common = require "kong.plugins.kong-openid-rp.common"
local responses = require "kong.tools.responses"
local cache = require "kong.tools.database_cache"
local USER_INFO = "USER_INFO"
local VALID_REQUEST = "VALID_REQUEST"
local OXDS = "oxds:"

return {
    ["/consumers/:username_or_id/kong-openid-rp/"] = {
        before = function(self, dao_factory, helpers)
            crud.find_consumer_by_username_or_id(self, dao_factory, helpers)
            self.params.consumer_id = self.consumer.id
        end,
        GET = function(self, dao_factory)
            crud.paginated_set(self, dao_factory.oxds)
        end,
        DELETE = function(self, dao_factory)
            local credentials, err = crud.find_by_id_or_field(dao_factory.oxds,
                {},
                self.params.consumer_id,
                "consumer_id")

            self.oxds = credentials[1]
            crud.delete(credentials[1], dao_factory.oxds)
        end,
        PUT = function(self, dao_factory)
            local oxd_result = oxd.updateSite(self.params)
            if (oxd_result.result == false) then
                return responses.send_HTTP_BAD_REQUEST("Invalid parameter value")
            end

            self.params.oxd_id = oxd_result.oxd_id
            local oxd = {
                consumer_id = self.params.consumer_id,
                oxd_id = self.params.oxd_id,
                op_host = self.params.op_host,
                oxd_port = self.params.oxd_port,
                oxd_host = self.params.oxd_host
            }
            crud.put(oxd, dao_factory.oxds)
        end,
        POST = function(self, dao_factory)
            if (not common.isempty(self.params.scope)) then
                self.params.scope = common.split(self.params.scope, ",")
            end

            if (not common.isempty(self.params.client_logout_uris)) then
                self.params.client_logout_uris = common.split(self.params.client_logout_uris, ",")
            end

            if (not common.isempty(self.params.response_type)) then
                self.params.response_type = common.split(self.params.response_type, ",")
            end

            if (not common.isempty(self.params.grant_types)) then
                self.params.grant_types = common.split(self.params.grant_types, ",")
            end

            if (not common.isempty(self.params.acr_values)) then
                self.params.acr_values = common.split(self.params.acr_values, ",")
            end

            if (not common.isempty(self.params.client_request_uris)) then
                self.params.client_request_uris = common.split(self.params.client_request_uris, ",")
            end

            if (not common.isempty(self.params.client_logout_uris)) then
                self.params.client_logout_uris = common.split(self.params.client_logout_uris, ",")
            end

            if (not common.isempty(self.params.contacts)) then
                self.params.scope = common.split(self.params.contacts, ",")
            end

            if (common.isempty(self.params.authorization_redirect_uri)) then
                self.params.authorization_redirect_uri = "https://" .. self.req.headers.host .. "/consumers/" .. self.params.consumer_id .. "/login"
            end

            if (common.isempty(self.params.post_logout_redirect_uri)) then
                self.params.post_logout_redirect_uri = "https://" .. self.req.headers.host .. "/consumers/" .. self.params.consumer_id .. "/logout"
            end

            if (not common.isHttps(self.params.authorization_redirect_uri)) then
                return responses.send_HTTP_BAD_REQUEST("It does not start from 'https://'")
            end

            local oxd_result = oxd.register(self.params)
            if (oxd_result.result == false) then
                return responses.send_HTTP_BAD_REQUEST("Invalid parameter value")
            end

            self.params.oxd_id = oxd_result.oxd_id
            local oxd = {
                consumer_id = self.params.consumer_id,
                oxd_id = self.params.oxd_id,
                op_host = self.params.op_host,
                oxd_port = self.params.oxd_port,
                oxd_host = self.params.oxd_host,
                session_timeout = self.params.session_timeout
            }

            crud.post(oxd, dao_factory.oxds)
        end
    },
    ["/consumers/:username_or_id/authorization_url"] = {
        before = function(self, dao_factory, helpers)
            crud.find_consumer_by_username_or_id(self, dao_factory, helpers)
            self.params.consumer_id = self.consumer.id

            local credentials, err = crud.find_by_id_or_field(dao_factory.oxds,
                {},
                self.params.consumer_id,
                "consumer_id")

            self.oxds = credentials[1]
        end,
        GET = function(self, dao_factory, helpers)
            local response = oxd.get_authorization_url(self.oxds)

            if response["status"] == "error" then
                ngx.log(ngx.ERR, "get_authorization_url : oxd_id: " .. self.oxds.oxd_id)
                return responses.send_HTTP_INTERNAL_SERVER_ERROR(response)
            end

            return responses.send_HTTP_OK(response)
        end
    },
    ["/consumers/:username_or_id/logout"] = {
        GET = function(self, dao_factory, helpers)
            crud.find_consumer_by_username_or_id(self, dao_factory, helpers)
            self.params.consumer_id = self.consumer.id

            local credentials, err = crud.find_by_id_or_field(dao_factory.oxds,
                {},
                self.params.consumer_id,
                "consumer_id")

            self.oxds = credentials[1]

            local response = oxd.get_logout_uri(self.oxds)
            if response["status"] == "error" then
                ngx.log(ngx.ERR, "get_logout_uri : oxd_id: " .. self.oxds.oxd_id)
                return responses.send_HTTP_INTERNAL_SERVER_ERROR(response)
            end

            return ngx.redirect(response.data.uri)
--            cache.delete(OXDS .. self.oxds.oxd_id)
--            cache.delete(USER_INFO .. self.oxds.oxd_id)
--            cache.delete(cache.consumer_key(self.params.consumer_id))
--            return responses.send_HTTP_OK("successful logout")
        end
    },
    ["/consumers/:username_or_id/login"] = {
        GET = function(self, dao_factory, helpers)
            crud.find_consumer_by_username_or_id(self, dao_factory, helpers)
            self.params.consumer_id = self.consumer.id

            local credentials, err = crud.find_by_id_or_field(dao_factory.oxds,
                {},
                self.params.consumer_id,
                "consumer_id")

            self.oxds = credentials[1]
            local response
            if (not common.isempty(self.params.code) and not common.isempty(self.params.state)) then
                response = oxd.get_user_info(self.oxds, self.params.code, self.params.state)

                if response["status"] == "error" then
                    ngx.log(ngx.ERR, "get_user_info : oxd_id: " .. self.oxds.oxd_id)
                    return responses.send_HTTP_INTERNAL_SERVER_ERROR(response)
                end

                cache.set(USER_INFO, response, tonumber(self.oxds.session_timeout))
                cache.set(OXDS, self.oxds, tonumber(self.oxds.session_timeout))
                cache.set(cache.consumer_key(self.params.consumer_id), tonumber(self.oxds.session_timeout))
                common.set_header(self.consumer, self.oxds, response)
                return responses.send_HTTP_OK(response)
            else
                response = oxd.get_authorization_url(self.oxds)
                if response["status"] == "error" then
                    ngx.log(ngx.ERR, "get_authorization_url : oxd_id: " .. self.oxds.oxd_id)
                    return responses.send_HTTP_INTERNAL_SERVER_ERROR(response)
                end

                return ngx.redirect(response.data.authorization_url)
            end
        end
    }
}