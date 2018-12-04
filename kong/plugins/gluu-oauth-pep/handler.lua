local BasePlugin = require "kong.plugins.base_plugin"
local access = require "kong.plugins.gluu-oauth-pep.access"
local lrucache = require "resty.lrucache.pureffi"


local handler = BasePlugin:extend()
handler.PRIORITY = 999

-- Your plugin handler's constructor. If you are extending the
-- Base Plugin handler, it's only role is to instanciate itself
-- with a name. The name is your plugin name as it will be printed in the logs.
function handler:new()
    handler.super.new(self, "gluu-oauth-pep")

    -- access token should be per plugin instance
    self.access_token = { expire = 0 }

    -- create per plugin jwks storage with expiration
    local jwks, err = lrucache.new(20) -- allow up to 20 items in the cache
    if not jwks then
        return error("failed to create the cache: " .. (err or "unknown"))
    end
    self.jwks = jwks
end

function handler:access(config)
    -- Eventually, execute the parent implementation
    -- (will log that your plugin is entering this context)
    handler.super.access(self)

    return access(self, config)
end

return handler
