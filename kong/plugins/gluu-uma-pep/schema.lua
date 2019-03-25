--- Check UMA protection document
-- @param v: JSON expression
local function check_expression(v)
    -- TODO check the structure, required fields, etc
    return true
end

return {
    no_consumer = true,
    fields = {
        oxd_url = { required = true, type = "url" },
        client_id = { required = true, type = "string" },
        client_secret = { required = true, type = "string" },
        oxd_id = { required = true, type = "string" },
        op_url = { required = true, type = "url" },
        uma_scope_expression = { required = true, func = check_expression, type = "table" },
        deny_by_default = { type = "boolean", default = true },
        pct_id_token_jwt = { type = "boolean", default = false },
        obtain_rpt = { type = "boolean", default = false },
        redirect_claim_gatering_url = { type = "boolean", default = false },
    },
    self_check = function(schema, plugin_t, dao, is_updating)
        table.sort(plugin_t.uma_scope_expression, function(first, second)
            return #first.path > #second.path
        end)
        return true
    end
}
