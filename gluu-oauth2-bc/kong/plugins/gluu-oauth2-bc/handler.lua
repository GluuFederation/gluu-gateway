local BasePlugin = require "kong.plugins.base_plugin"
local access = require "kong.plugins.gluu-oauth2-bc.access"

local Handler = BasePlugin:extend()

function Handler:new()
    Handler.super.new(self, "gluu-oauth2-bc")
end

function Handler:access(conf)
    Handler.super.access(self)
    local response = access.execute(conf)
    if response ~= nil then
        return response
    end
end

return Handler