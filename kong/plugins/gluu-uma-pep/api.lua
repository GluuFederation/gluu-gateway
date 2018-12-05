local metrics = require "gluu.metrics"

return {
  ["/uma-pep-metrics"] = {
    GET = function(self, dao_factory)
        metrics.collect()
    end,
  },
}
