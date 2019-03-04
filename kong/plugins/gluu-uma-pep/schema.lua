local kong_auth_pep_common = require"gluu.kong-auth-pep-common"

--- Check UMA protection document
-- @param v: JSON expression
local function check_expression(v)
    -- TODO check the structure, required fields, etc
    return true
end

return {
    no_consumer = false,
    fields = {
        oxd_url = { required = true, type = "url" },
        client_id = { required = true, type = "string" },
        client_secret = { required = true, type = "string" },
        oxd_id = { required = true, type = "string" },
        op_url = { required = true, type = "url" },
        uma_scope_expression = { required = true, func = check_expression, type = "table" },
        deny_by_default = { type = "boolean", default = true },
        anonymous = { type = "string", func = kong_auth_pep_common.check_user, default = "" }
    },
    self_check = function(schema, plugin_t, dao, is_updating)
        table.sort(plugin_t.uma_scope_expression, function(first, second)
            return #first.path > #second.path
        end)
        return true
    end
}
