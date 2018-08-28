local utils = require "kong.tools.utils"
local pl_types = require "pl.types"
local cjson = require "cjson.safe"

--- Check OAuth scope expression
-- @param v: JSON expression
-- @param t: All config valus
local function check_expression(v, t)
    if pl_types.is_empty(v) then
        return true
    end

    local _, err = cjson.decode(v)
    if err then
        return false, "Invalid OAuth scope json expression"
    end
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
        op_url = { required = true, type = "url" },
        oxd_url = { required = true, type = "url" },
        anonymous = { type = "string", default = "", func = check_user },
        oauth_scope_expression = { required = false, type = "string", func = check_expression },
        allow_oauth_scope_expression = { required = true, type = "boolean", default = false },
    },
}
