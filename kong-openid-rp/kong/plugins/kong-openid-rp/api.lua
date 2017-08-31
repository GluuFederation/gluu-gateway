local crud = require "kong.api.crud_helpers"
local oxd = require "kong.plugins.kong-openid-rp.oxdweb"
local responses = require "kong.tools.responses"
local cjson = require "cjson"
local common = require "kong.plugins.kong-openid-rp.common"

return {
    ["/kong_openid_rp/logout"] = {
        GET = function(self, dao_factory, helpers)
            if common.isempty(self.params.id) then
                ngx.log(ngx.DEBUG, "Invalid credential. 'id' not found")
                return responses.send_HTTP_INTERNAL_SERVER_ERROR("Invalid credential. 'id' not found")
            end

            local credentials, err = crud.find_by_id_or_field(dao_factory.plugins,
                {},
                self.params.id,
                "id")

            if common.isempty(credentials[1]) then
                ngx.log(ngx.DEBUG, "Not found credential with id: " .. self.params.id)
                return responses.send_HTTP_INTERNAL_SERVER_ERROR("Not found credential with id: " .. self.params.id)
            end

            self.oxds = credentials[1].config
            local response = oxd.get_logout_uri(self.oxds)

            if response["status"] == "error" then
                ngx.log(ngx.DEBUG, "get_logout_uri : oxd_id: " .. self.oxds.id)
                return responses.send_HTTP_INTERNAL_SERVER_ERROR(response)
            end

            return ngx.redirect(response.data.uri)
        end
    }
}