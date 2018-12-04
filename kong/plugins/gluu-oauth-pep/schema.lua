local kong_auth_pep_common = require"gluu.kong-auth-pep-common"

--- Check OAuth scope expression
-- @param v: JSON expression
local function check_expression(v)
    -- TODO check the structure, required fields, etc
    return true
end


return {
    no_consumer = true,
    fields = {
        hide_credentials = { type = "boolean", default = false },
        oxd_id = { required = true, type = "string" },
        client_id = { required = true, type = "string" },
        client_secret = { required = true, type = "string" },
        op_url = { required = true, type = "url" },
        oxd_url = { required = true, type = "url" },
        anonymous = { type = "string", func = kong_auth_pep_common.check_user, default = "" },
        oauth_scope_expression = { required = false, type = "table", func = check_expression },
        ignore_scope = { type = "boolean", default = false },
        deny_by_default = { type = "boolean", default = true },
        calculate_metrics = { type = "boolean", default = true }
    },
    self_check = function(schema, plugin_t, dao, is_updating)
        if not plugin_t.ignore_scope then
            table.sort(plugin_t.oauth_scope_expression, function(first, second)
                return #first.path > #second.path
            end)
        end
        return true
    end
}
