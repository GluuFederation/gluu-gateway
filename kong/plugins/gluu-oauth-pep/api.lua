local metrics = require "kong.plugins.gluu-oauth-pep.metrics"

return {
  ["/oauth-metrics"] = {
    GET = function(self, dao_factory)
        metrics.collect()
    end,
  },
}
