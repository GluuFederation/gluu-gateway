local crud = require "kong.api.crud_helpers"
local oxd = require "kong.plugins.kong-openid-rp.oxdclient"
local responses = require "kong.tools.responses"
local ck = require "resty.cookie"
local USER_INFO = "USER_INFO"

return {
    ["/kong_openid_rp/logout"] = {
        GET = function(self, dao_factory, helpers)
            local credentials, err = crud.find_by_id_or_field(dao_factory.oxds,
                {},
                self.params.oxd_id,
                "oxd_id")

            self.oxds = credentials[1]
            local response = oxd.get_logout_uri(self.oxds)

            if response["status"] == "error" then
                ngx.log(ngx.ERR, "get_logout_uri : oxd_id: " .. self.oxds.oxd_id)
                return responses.send_HTTP_INTERNAL_SERVER_ERROR(response);
            end

            return ngx.redirect(response.data.uri)
        end
    }
}