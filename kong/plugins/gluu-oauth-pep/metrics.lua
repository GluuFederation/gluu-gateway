local responses = require "kong.tools.responses"
local metrics = {}
local prometheus


local function init()
    local shm = "gluu_oauth_pep_metrics"

    if not ngx.shared[shm] then
        kong.log.err("gluu_oauth_pep: ngx shared dict 'gluu_oauth_pep_metrics' not found")
        return
    end

    -- Use this for testing
    --    local shm = "prometheus_metrics"
    --    if not ngx.shared.prometheus_metrics then
    --        kong.log.err("prometheus: ngx shared dict 'prometheus_metrics' not found")
    --        return
    --    end

    prometheus = require("prometheus").init(shm, "gluu_oauth_pep_")

    -- accross all services
    metrics.client_authenticated_total = prometheus:counter("client_authenticated_total",
        "Client(Consumer) authenticated aggregate across all services in Kong",
        { "consumer" })

    -- per service
    metrics.client_authenticated = prometheus:counter("client_authenticated",
        "Client(Consumer) authenticated per service in Kong",
        { "consumer", "service" })
end


local function log(message)
    if not metrics then
        kong.log.err("gluu_oauth_pep: can not log metrics because of an initialization "
                .. "error, please make sure that you've declared "
                .. "'gluu_oauth_pep_metrics' shared dict in your nginx template")
        return
    end

    local service_name = message.service and message.service.name or
            message.service.host
    service_name = service_name or ""

    local consumer = message.consumer
    if consumer then
        metrics.client_authenticated:inc(1, { consumer.custom_id, service_name })
        metrics.client_authenticated_total:inc(1, { consumer.custom_id })
    end
end


local function collect()
    if not prometheus or not metrics then
        kong.log.err("gluu_oauth_pep: plugin is not initialized, please make sure ",
            " 'gluu_oauth_pep_metrics' shared dict is present in nginx template")
        return responses.send_HTTP_INTERNAL_SERVER_ERROR()
    end

    prometheus:collect()
    return ngx.exit(200)
end


return {
    init = init,
    log = log,
    collect = collect,
}
