local metrics = require "gluu.metrics"

return {
  ["/oauth-metrics"] = {
    GET = function(self, dao_factory)
        metrics.collect()
    end,
  },
}
