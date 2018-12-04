local responses = require "kong.tools.responses"
local metrics = {}
local prometheus


local function init(name)
    name = name:gsub("-", "_")
    local shm = name .. "_metrics"

    if not ngx.shared[shm] then
        kong.log.err("gluu_oauth_pep: ngx shared dict 'gluu_oauth_pep_metrics' not found")
        return
    end

    prometheus = require("prometheus").init(shm, name .. "_")

    -- accross all services
    metrics.client_authenticated_total = prometheus:counter("client_authenticated_total",
        "Client(Consumer) authenticated aggregate across all services in Kong",
        { "consumer" })

    metrics.client_granted_total = prometheus:counter("client_granted_total",
        "Client(Consumer) granted aggregate across all services in Kong",
        { "consumer" })

    metrics.endpoint_method_total = prometheus:counter("endpoint_method_total",
        "Endpoint and method aggregate call across all services in Kong",
        { "endpoint", "method", "status" })

    if name == "gluu_uma_pep" then
        metrics.ticket_total = prometheus:counter("ticket_total",
            "Ticket aggregate call across all services in Kong")
    end

    -- per service
    metrics.client_authenticated = prometheus:counter("client_authenticated",
        "Client(Consumer) authenticated per service in Kong",
        { "consumer", "service" })

    metrics.client_granted = prometheus:counter("client_granted",
        "Client(Consumer) granted per service in Kong",
        { "consumer", "service" })

    metrics.endpoint_method = prometheus:counter("endpoint_method",
        "Endpoint call per service in Kong",
        { "endpoint", "method", "status", "service" })

    if name == "gluu_uma_pep" then
        metrics.ticket = prometheus:counter("ticket",
            "Ticket aggregate call across all services in Kong",
            { "service" })
    end
end


local function log(name, conf, message)
    if not metrics then
        kong.log.err("gluu_oauth_pep: can not log metrics because of an initialization "
                .. "error, please make sure that you've declared "
                .. "'gluu_oauth_pep_metrics' shared dict in your nginx template")
        return
    end

    local service_name = message.service and message.service.name or
            message.service.host
    service_name = service_name or ""

    local consumer, request, response = message.consumer, message.request, message.response

    if consumer then
        if not conf.ignore_scope then
            metrics.client_granted_total:inc(1, { consumer.custom_id })
            metrics.client_granted:inc(1, { consumer.custom_id, service_name })
        end

        metrics.client_authenticated_total:inc(1, { consumer.custom_id })
        metrics.client_authenticated:inc(1, { consumer.custom_id, service_name })
    end

    metrics.endpoint_method_total:inc(1, { request.uri, request.method, response.status })
    metrics.endpoint_method:inc(1, { request.uri, request.method, response.status, service_name })

    if name == "gluu_uma_pep" and kong.ctx.plugin.ticket then
        metrics.ticket_total:inc(1)
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
