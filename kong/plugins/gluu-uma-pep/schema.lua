local common = require "gluu.kong-common"
local typedefs = require "kong.db.schema.typedefs"
local json_cache = require "gluu.json-cache"
local cjson = require "cjson.safe"

return {
    name = "gluu-uma-pep",
    fields = {
        { run_on = typedefs.run_on_first },
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
                    { method_path_tree = { required = false, type = "string" }, },
                },
                custom_validator = function(config)
                    if not config.uma_scope_expression then
                        config.method_path_tree = nil
                        return true
                    end

                    local uma_scope_expression = json_cache(config.uma_scope_expression, config.uma_scope_expression, true)
                    local ok, err = common.check_expression(uma_scope_expression)
                    if not ok then
                        return false, err
                    end

                    local method_path_tree = common.convert_scope_expression_to_path_wildcard_tree(uma_scope_expression)
                    config.method_path_tree = cjson.encode(method_path_tree)
                    return true
                end
            },
        },
    }
}
