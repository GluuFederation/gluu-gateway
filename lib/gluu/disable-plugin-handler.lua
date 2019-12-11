-- the main purpose of this code is to replace some stock Kong
-- plugins entry point to completely disable them

local BasePlugin = require "kong.plugins.base_plugin"

local handler = BasePlugin:extend()
handler.PRIORITY = 999

-- Your plugin handler's constructor. If you are extending the
-- Base Plugin handler, it's only role is to instanciate itself
-- with a name. The name is your plugin name as it will be printed in the logs.
function handler:new()
    handler.super.new(self, "Disable plugin stub")
end

function handler:access(config)
    -- Eventually, execute the parent implementation
    -- (will log that your plugin is entering this context)
    handler.super.access(self)

    kong.log.debug("All stock Kong authentication plugins are disabled, use Gluu authentication plugins")
    kong.response.exit(500)
end

return handler
