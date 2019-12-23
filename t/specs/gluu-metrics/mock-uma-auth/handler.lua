local BasePlugin = require "kong.plugins.base_plugin"

local handler = BasePlugin:extend()
handler.PRIORITY = 998

-- Your plugin handler's constructor. If you are extending the
-- Base Plugin handler, it's only role is to instanciate itself
-- with a name. The name is your plugin name as it will be printed in the logs.
function handler:new()
    handler.super.new(self, "gluu-uma-auth")
end

function handler:access(config)
    -- Eventually, execute the parent implementation
    -- (will log that your plugin is entering this context)
    handler.super.access(self)
    kong.ctx.shared.authenticated_consumer = { custom_id = "1234567uma", id = config.customer_id, username = "john" }
    ngx.ctx.authenticated_consumer = kong.ctx.shared.authenticated_consumer
    ngx.ctx.authenticated_credential = { id = kong.ctx.shared.authenticated_consumer.custom_id }
    kong.ctx.shared.gluu_uma_client_authenticated = true
    ngx.ctx.gluu_uma_client_authenticated = true

    print(kong.client.get_ip())
end

return handler
