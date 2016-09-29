local oxd = require "kong.plugins.kong-uma-rs.oxdclient"

local _M = {}

function _M.execute(conf)

  oxd.execute(conf)

end

return _M

