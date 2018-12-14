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

    -- per service
    metrics.oauth_client_granted = prometheus:counter("oauth_client_granted",
        "Client(Consumer) OAuth granted per service in Kong",
        { "consumer", "service" })

    metrics.oauth_client_authenticated = prometheus:counter("oauth_client_authenticated",
        "Client(Consumer) OAuth authenticated per service in Kong",
        { "consumer", "service" })

    metrics.uma_client_granted = prometheus:counter("uma_client_granted",
        "Client(Consumer) UMA granted per service in Kong",
        { "consumer", "service" })

    metrics.uma_client_authenticated = prometheus:counter("uma_client_authenticated",
        "Client(Consumer) UMA authenticated per service in Kong",
        { "consumer", "service" })

    metrics.uma_ticket = prometheus:counter("uma_ticket",
        "Permission Ticket getting per services in Kong",
        { "service" })

    metrics.endpoint_method = prometheus:counter("endpoint_method",
        "Endpoint call per service in Kong",
        { "endpoint", "method", "service" })

end

local function log(message)
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

    metrics.endpoint_method:inc(1, { request.uri, request.method, service_name })

    local oauth_client_authenticated = kong.ctx.shared.gluu_oauth_client_authenticated;
    if oauth_client_authenticated then
        metrics.oauth_client_authenticated:inc(1, { oauth_client_authenticated.custom_id, service_name })
    end

    local oauth_client_granted = kong.ctx.shared.gluu_oauth_client_granted
    if consumer and oauth_client_granted then
        metrics.oauth_client_granted:inc(1, { oauth_client_granted.custom_id, service_name })
    end

    local uma_client_authenticated = kong.ctx.shared.gluu_uma_client_authenticated
    if uma_client_authenticated then
        metrics.uma_client_authenticated:inc(1, { uma_client_authenticated.custom_id, service_name })
    end

    local uma_client_granted = kong.ctx.shared.gluu_uma_client_granted
    if consumer and uma_client_granted then
        metrics.uma_client_granted:inc(1, { uma_client_granted.custom_id, service_name })
    end

    if kong.ctx.shared.gluu_uma_ticket then
        metrics.uma_ticket:inc(1, { service_name })
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
