local oxd = require "gluu.oxdweb"
local kong_auth_pep_common = require "gluu.kong-common"

-- @return introspect_response, status, err
-- upon success returns only introspect_response,
-- otherwise return nil, status, err
local function introspect_token(self, conf, token)
    local ptoken = kong_auth_pep_common.get_protection_token(conf)

    local response = oxd.introspect_access_token(conf.oxd_url,
        {
            oxd_id = conf.oxd_id,
            access_token = token,
        },
        ptoken)
    local status = response.status

    if status == 403 then
        kong.log.err("Invalid access token provided in Authorization header");
        return nil, 502, "An unexpected error ocurred"
    end

    if status ~= 200 then
        kong.log.err("introspect-access-token error, status: ", status)
        return nil, 502, "An unexpected error ocurred"
    end

    local body = response.body
    if not body.active then
        -- TODO should we cache negative resposes? https://github.com/GluuFederation/gluu-gateway/issues/213
        return nil, 401, "Invalid access token provided in Authorization header"
    end

    return body
end

return function(self, conf)
    kong_auth_pep_common.access_auth_handler(self, conf, introspect_token)
end
