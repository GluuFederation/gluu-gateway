local oxd = require "gluu.oxdweb"
local kong_auth_pep_common = require"gluu.kong-common"

local unexpected_error = kong_auth_pep_common.unexpected_error

local function try_introspect_rpt(conf, token, access_token)
    local response = oxd.introspect_rpt(conf.oxd_url,
        {
            oxd_id = conf.oxd_id,
            rpt = token,
        },
        access_token)
    local status = response.status
    if status == 200 then
        local body = response.body
        if body.active then
            if not (body.exp and body.iat and body.client_id and body.permissions) then
                return unexpected_error("introspect_rpt() missed required fields")
            end
        end
        return body
    end
    if status == 400 then
        return unexpected_error("introspect_rpt() responds with status 400 - Invalid parameters are provided to endpoint")
    elseif status == 500 then
        return unexpected_error("introspect_rpt() responds with status 500 - Internal error occured. Please check oxd-server.log file for details")
    elseif status == 403 then
        return unexpected_error("introspect_rpt() responds with status 403 - Invalid access token provided in Authorization header")
    end
    return unexpected_error("introspect_rpt() responds with unexpected status: ", status)
end

local function introspect_token(self, conf, token)
    local ptoken = kong_auth_pep_common.get_protection_token(conf)

    local introspect_rpt_response_data = try_introspect_rpt(conf, token, ptoken)
    if not introspect_rpt_response_data.active then
        return nil, 401, "Invalid access token provided in Authorization header"
    end
    return introspect_rpt_response_data
end

return function(self, conf)
    kong_auth_pep_common.access_auth_handler(self, conf, introspect_token)
end

