local BasePlugin = require "kong.plugins.base_plugin"
local access = require "kong.plugins.kong-uma-rs.access"

local Handler = BasePlugin:extend()

function Handler:new()
  Handler.super.new(self, "kong-uma-rs")
end

function Handler:access(conf)
  Handler.super.access(self)
  access.execute(conf)
end

return Handler