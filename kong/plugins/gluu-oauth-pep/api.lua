local metrics = require "gluu.metrics"

return {
  ["/oauth-pep-metrics"] = {
    GET = function(self, dao_factory)
        metrics.collect()
    end,
  },
}
