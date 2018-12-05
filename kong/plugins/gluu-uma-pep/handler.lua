local BasePlugin = require "kong.plugins.base_plugin"
local access = require "kong.plugins.gluu-uma-pep.access"
local metrics = require "gluu.metrics"
local basic_serializer = require "kong.plugins.log-serializers.basic"

local handler = BasePlugin:extend()
handler.PRIORITY = 998

-- Your plugin handler's constructor. If you are extending the
-- Base Plugin handler, it's only role is to instanciate itself
-- with a name. The name is your plugin name as it will be printed in the logs.
function handler:new()
  local name = "gluu-uma-pep"
  handler.super.new(self, name)

  -- plugin name
  self.name = name

  -- access token should be per plugin instance
  self.access_token = { expire = 0 }

  metrics.init(name)
end

function handler:access(config)
  -- Eventually, execute the parent implementation
  -- (will log that your plugin is entering this context)
  handler.super.access(self)

  return access(self, config)
end

function handler:log(conf)
    handler.super.log(self)
    if conf.calculate_metrics then
        local message = basic_serializer.serialize(ngx)
        metrics.log(self.name, conf, message)
    end
end

return handler
