local common = require "gluu.kong-common"
local typedefs = require "kong.db.schema.typedefs"
local json_cache = require "gluu.json-cache"
local cjson = require "cjson.safe"

return {
    name = "gluu-uma-pep",
    fields = {
        { run_on = typedefs.run_on_first },
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
                    { oauth_scope_expression = { required = false, type = "string" }, },
                    { method_path_tree = { required = false, type = "string" }, },
                },
                custom_validator = function(config)
                    if not config.oauth_scope_expression then
                        config.method_path_tree = nil
                        return true
                    end

                    local oauth_scope_expression = json_cache(config.oauth_scope_expression)
                    local ok, err = common.check_expression(oauth_scope_expression)
                    if not ok then
                        return false, err
                    end

                    local method_path_tree = common.convert_scope_expression_to_path_wildcard_tree(oauth_scope_expression)
                    config.method_path_tree = cjson.encode(method_path_tree)
                    return true
                end
            },
        },
    }
}
