local BasePlugin = require "kong.plugins.base_plugin"
local access = require "kong.plugins.gluu-oauth2-client-auth.access"
local helper = require "kong.plugins.gluu-oauth2-client-auth.helper"

local Handler = BasePlugin:extend()
Handler.PRIORITY = 999
function Handler:new()
    Handler.super.new(self, "gluu-oauth2-client-auth")
end

function Handler:access(conf)
    Handler.super.access(self)
    local response = access.execute_access(conf)
    if response ~= nil then
        return response
    end
end

return Handler