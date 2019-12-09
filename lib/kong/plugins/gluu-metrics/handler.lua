local BasePlugin = require "kong.plugins.base_plugin"
local metrics = require "kong.plugins.gluu-metrics.metrics"
local basic_serializer = require "kong.plugins.log-serializers.basic"

local handler = BasePlugin:extend()
handler.PRIORITY = 14

-- Your plugin handler's constructor. If you are extending the
-- Base Plugin handler, it's only role is to instanciate itself
-- with a name. The name is your plugin name as it will be printed in the logs.
function handler:new()
    handler.super.new(self, "gluu-metrics")
    metrics.init()
    self.last_check = 0
    self.server_ip_address = ""
end

function handler:log(conf)
    handler.super.log(self)
    local message = basic_serializer.serialize(ngx)
    metrics.log(message)
end

return handler
