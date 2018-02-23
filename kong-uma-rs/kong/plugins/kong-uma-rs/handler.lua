local BasePlugin = require "kong.plugins.base_plugin"
local access = require "kong.plugins.kong-uma-rs.access"

local Handler = BasePlugin:extend()

Handler.PRIORITY = 998

--- Instanciate plugin itself with a name
function Handler:new()
  Handler.super.new(self, "kong-uma-rs")
end

--- Executed for every request from a client and before it is being proxied to the upstream service.
-- @param conf: Values that you setuped using schema.lua
-- @return response
function Handler:access(conf)
  Handler.super.access(self)
  local response = access.execute(conf)
  if response ~= nil then
    return response
  end
end

return Handler