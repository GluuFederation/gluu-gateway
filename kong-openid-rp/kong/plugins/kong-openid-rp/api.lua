local crud = require "kong.api.crud_helpers"
local oxd = require "kong.plugins.kong-openid-rp.oxdclient"
local responses = require "kong.tools.responses"
local cache = require "kong.tools.database_cache"
local USER_INFO = "USER_INFO"
local VALID_REQUEST = "VALID_REQUEST"
local OXDS = "oxds:"

local function isempty(s)
    return s == nil or s == ''
end

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
                "consumer_id");

            self.oxds = credentials[1]
            crud.delete(credentials[1], dao_factory.oxds)
        end,
        PUT = function(self, dao_factory)
            if (isempty(self.params.client_id)) then
                return responses.send_HTTP_BAD_REQUEST("client_id is required")
            end

            if (isempty(self.params.client_secret)) then
                return responses.send_HTTP_BAD_REQUEST("client_secret is required")
            end

            local oxd_result = oxd.updateSite(self.params)
            if (oxd_result.result == false) then
                return responses.send_HTTP_BAD_REQUEST("Invalid parameter value")
            end

            self.params.oxd_id = oxd_result.oxd_id
            local oxd = {
                consumer_id = self.params.consumer_id,
                oxd_id = self.params.oxd_id,
                op_host = self.params.op_host,
                authorization_redirect_uri = self.params.authorization_redirect_uri,
                oxd_port = self.params.oxd_port,
                oxd_host = self.params.oxd_host,
                scope = self.params.scope
            }
            crud.put(oxd, dao_factory.oxds)
        end,
        POST = function(self, dao_factory)
            if (isempty(self.params.client_id)) then
                return responses.send_HTTP_BAD_REQUEST("client_id is required")
            end

            if (isempty(self.params.client_secret)) then
                return responses.send_HTTP_BAD_REQUEST("client_secret is required")
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
                authorization_redirect_uri = self.params.authorization_redirect_uri,
                oxd_port = self.params.oxd_port,
                oxd_host = self.params.oxd_host,
                scope = self.params.scope
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
                "consumer_id");

            self.oxds = credentials[1]
        end,
        GET = function(self, dao_factory, helpers)
            local response = oxd.get_authorization_url(self.oxds)

            if response["status"] == "error" then
                ngx.log(ngx.ERR, "get_authorization_url : oxd_id: " .. self.oxds.oxd_id)
                return responses.send_HTTP_INTERNAL_SERVER_ERROR(response);
            end

            return responses.send_HTTP_OK(response)
        end
    },
    ["/consumers/:username_or_id/logout"] = {
        DELETE = function(self, dao_factory, helpers)
            crud.find_consumer_by_username_or_id(self, dao_factory, helpers)
            self.params.consumer_id = self.consumer.id

            local credentials, err = crud.find_by_id_or_field(dao_factory.oxds,
                {},
                self.params.consumer_id,
                "consumer_id");

            self.oxds = credentials[1]
            cache.delete(OXDS .. self.oxds.oxd_id)
            cache.delete(VALID_REQUEST .. self.oxds.oxd_id)
            cache.delete(USER_INFO .. self.oxds.oxd_id)
            cache.delete(cache.consumer_key(self.params.consumer_id));
            return responses.send_HTTP_OK()
        end
    }
}