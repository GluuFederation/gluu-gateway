local responses = require "kong.tools.responses"
local metrics = {}
local prometheus


local function init()
    local shm = "gluu_metrics"

    if not ngx.shared[shm] then
        kong.log.err("gluu-metrics: ngx shared dict 'gluu_metrics' not found")
        return
    end

    prometheus = require("prometheus").init(shm, "gluu_")

    metrics.endpoint_method_total = prometheus:counter("endpoint_method_total",
        "Endpoint and method aggregate call across all services in Kong",
        { "endpoint", "method" })

    -- per service
    metrics.client_granted = prometheus:counter("client_granted",
        "Client(Consumer) granted per service in Kong",
        { "consumer", "service" })

    metrics.endpoint_method = prometheus:counter("endpoint_method",
        "Endpoint call per service in Kong",
        { "endpoint", "method", "service" })

    metrics.ticket = prometheus:counter("ticket",
        "Ticket aggregate call across all services in Kong",
        { "service" })
end


local function log(conf, message)
    if not metrics then
        kong.log.err("gluu-metrics: cannot log metrics because of an initialization "
                .. "error, please make sure that you've declared "
                .. "'gluu_metrics' shared dict in your nginx template")
        return
    end

    local service_name = message.service and message.service.name or
            message.service.host
    service_name = service_name or ""

    local consumer, request = message.consumer, message.request

    if consumer then
        metrics.client_granted:inc(1, { consumer.custom_id, service_name })
    end

    metrics.endpoint_method_total:inc(1, { request.uri, request.method })
    metrics.endpoint_method:inc(1, { request.uri, request.method, service_name })

    if kong.ctx.shared.ticket then
        metrics.ticket:inc(1, { service_name })
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
