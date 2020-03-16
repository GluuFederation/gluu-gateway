local common = require "gluu.kong-common"
local typedefs = require "kong.db.schema.typedefs"
local cjson = require "cjson.safe"

return {
    name = "gluu-uma-pep",
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
                    { deny_by_default = { type = "boolean", default = true }, },
                    { require_id_token = { type = "boolean", default = false }, },
                    { obtain_rpt = { type = "boolean", default = false }, },
                    { claims_redirect_path = { required = false, type = "string" }, },
                    { redirect_claim_gathering_url = { type = "boolean", default = false }, },
                    { uma_scope_expression = { required = false, type = "string" }, },
                    { pushed_claims_lua_exp = { required = false, type = "string" } },
                },
                custom_validator = function(config)
                    local ok, err = common.check_valid_lua_expression(config.pushed_claims_lua_exp)
                    if not ok then
                        return false, err
                    end

                    if not config.uma_scope_expression then
                        return true
                    end

                    local uma_scope_expression = cjson.decode(config.uma_scope_expression)
                    local ok, err = common.check_expression(uma_scope_expression)
                    if not ok then
                        return false, err
                    end

                    return true
                end
            },
        },
    }
}
