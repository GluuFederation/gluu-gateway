local common = require "gluu.kong-common"
local typedefs = require "kong.db.schema.typedefs"
local cjson = require "cjson.safe"

return {
    name = "gluu-openid-connect",
    fields = {
        { consumer = typedefs.no_consumer },
        {
            config = {
                type = "record",
                fields = {
                    { oxd_id = { required = true, type = "string" }, },
                    { oxd_url = typedefs.url { required = true }, },
                    { client_id = { required = true, type = "string" }, },
                    { client_secret = { required = true, type = "string" }, },
                    { op_url = typedefs.url { required = true }, },
                    { authorization_redirect_path = { required = true, type = "string" }, },
                    { logout_path = { required = false, type = "string" }, },
                    { post_logout_redirect_path_or_url = { required = false, type = "string" }, },
                    { requested_scopes = { type = "array", elements = { type = "string" }, }, },
                    { max_id_token_age = typedefs.timeout  { required = true }, },
                    { max_id_token_auth_age = typedefs.timeout  { required = true }, },
                    { required_acrs_expression = { required = false, type = "string" }, },
                    {
                        custom_headers = {
                            required = false,
                            type = "array",
                            elements = {
                                type = "record",
                                fields = {
                                    { header_name = { required = true, type = "string" } },
                                    { value_lua_exp = { required = true, type = "string" } },
                                    { format = { required = false, type = "string",
                                        one_of = common.CUSTOM_HEADERS_FORMATS } },
                                    { sep = { required = false, type = "string" } },
                                    { iterate = { required = false, type = "boolean" } }
                                },
                            },
                        }
                    }
                },
                custom_validator = function(config)
                    local ok, err = common.check_headers_valid_lua_expression(config.custom_headers)
                    if not ok then
                        return false, err
                    end

                    if not config.required_acrs_expression then
                        return true
                    end

                    local required_acrs_expression = cjson.decode(config.required_acrs_expression)
                    local ok, err = common.check_expression(required_acrs_expression)
                    if not ok then
                        return false, err
                    end

                    return true
                end,
            },
        },
    }
}

