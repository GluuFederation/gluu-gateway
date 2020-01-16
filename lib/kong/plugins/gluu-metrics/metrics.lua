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

    metrics.openid_connect_users_authenticated = prometheus:counter("openid_connect_users_authenticated",
        "User authenticated per service in Kong",
        { "service" })

    metrics.opa_client_granted = prometheus:counter("opa_client_granted",
        "User or Client(Consumer) OPA granted per service in Kong",
        { "consumer", "service" })

    metrics.total_client_authenticated = prometheus:counter("total_client_authenticated",
        "Total authentication(OAuth, UMA and OpenID Connect) in Kong")

    metrics.total_client_granted = prometheus:counter("total_client_granted",
        "Total authorization(OAuth, UMA and OPA PEP) in Kong")
end

local function log(message)
    if not metrics then
        kong.log.err("gluu-metrics: cannot log metrics because of an initialization "
                .. "error, please make sure that you've declared "
                .. "'gluu_metrics' shared dict in your nginx template")
        return
    end

    local service_name
    if message and message.service then
        service_name = message.service.name or message.service.host
    else
        -- do not record any stats if the service is not present
        return
    end

    local consumer, request = message.consumer, message.request

    local uri = ngx.var.uri:match"^([^%s]+)"
    local openid_auth = "openid_connect_authentication"

    metrics.endpoint_method:inc(1, { uri, request.method, service_name })

    if kong.ctx.shared.gluu_oauth_client_authenticated then
        metrics.oauth_client_authenticated:inc(1, { ngx.ctx.authenticated_credential.id, service_name })
        metrics.total_client_authenticated:inc(1)
    end

    if kong.ctx.shared.gluu_oauth_client_granted then
        metrics.oauth_client_granted:inc(1, { ngx.ctx.authenticated_credential.id, service_name })
        metrics.total_client_granted:inc(1)
    end

    if kong.ctx.shared.gluu_uma_client_authenticated then
        metrics.uma_client_authenticated:inc(1, { ngx.ctx.authenticated_credential.id, service_name })
        metrics.total_client_authenticated:inc(1)
    end

    if kong.ctx.shared.gluu_uma_client_granted then
        local data = consumer and { consumer.custom_id, service_name } or { openid_auth, service_name }
        metrics.uma_client_granted:inc(1, data)
        metrics.total_client_granted:inc(1)
    end

    if kong.ctx.shared.gluu_uma_ticket then
        metrics.uma_ticket:inc(1, { service_name })
    end

    if kong.ctx.shared.gluu_openid_connect_users_authenticated then
        metrics.openid_connect_users_authenticated:inc(1, { service_name })
        metrics.total_client_authenticated:inc(1)
    end

    if kong.ctx.shared.gluu_opa_client_granted then
        local data = consumer and { consumer.custom_id, service_name } or { openid_auth, service_name }
        metrics.opa_client_granted:inc(1, data)
        metrics.total_client_granted:inc(1)
    end
end

local function collect()
    if not prometheus or not metrics then
        kong.log.err("plugin is not initialized, please make sure ",
            " 'gluu_metrics' shared dict is present in nginx template")
        return ngx.exit(500)
    end

    prometheus:collect()
end

return {
    init = init,
    log = log,
    collect = collect,
}
