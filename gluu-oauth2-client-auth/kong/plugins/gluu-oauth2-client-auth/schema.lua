local utils = require "kong.tools.utils"
local pl_types = require "pl.types"
local cjson = require "cjson.safe"

--- Check OAuth scope expression
-- @param v: JSON expression
local function check_expression(v)
    -- TODO check the structure, required fields, etc
    return true
end

--- Check user valid UUID
-- @param anonymous: anonymous consumer id
local function check_user(anonymous)
    if anonymous == "" or utils.is_valid_uuid(anonymous) then
        return true
    end

    return false, "the anonymous user must be empty or a valid uuid"
end

return {
    no_consumer = true,
    fields = {
        hide_credentials = { type = "boolean", default = false },
        oxd_id = { required = true, type = "string" },
        client_id = { required = true, type = "string" },
        client_secret = { required = true, type = "string" },
        op_url = { required = true, type = "string" },
        oxd_url = { required = true, type = "string" },
        anonymous = { type = "string", func = check_user, default = "" },
        oauth_scope_expression = { required = false, type = "table", func = check_expression },
        allow_oauth_scope_expression = { type = "boolean", default = false },
        allow_unprotected_path = { type = "boolean", default = false },
    },
    self_check = function(schema, plugin_t, dao, is_updating)
        if plugin_t.allow_oauth_scope_expression then
            table.sort(plugin_t.oauth_scope_expression, function(first, second)
                return #first.path > #second.path
            end)
        end
        return true
    end
}
