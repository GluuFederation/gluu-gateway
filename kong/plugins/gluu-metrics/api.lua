local metrics = require "kong.plugins.gluu-metrics.metrics"

return {
  ["/gluu-metrics"] = {
    GET = function(self, dao_factory)
        return metrics.collect()
    end,
  },
}
