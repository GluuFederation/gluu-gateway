local utils = require"test_utils"
local sh, stdout, stderr, sleep, sh_ex, sh_until_ok =
utils.sh, utils.stdout, utils.stderr, utils.sleep, utils.sh_ex, utils.sh_until_ok

local kong_utils = require"kong_utils"
local JSON = require"JSON"

local host_git_root = os.getenv"HOST_GIT_ROOT"
local git_root = os.getenv"GIT_ROOT"
local test_root = host_git_root .. "/t/specs/gluu-metrics"

local function setup(model)
    _G.ctx = {}
    local ctx = _G.ctx
    ctx.finalizeres = {}
    ctx.host_git_root = host_git_root

    ctx.print_logs = true
    finally(function()
        if ctx.print_logs then
            if ctx.kong_id then
                sh("docker logs ", ctx.kong_id, " || true") -- don't fail
            end
            if ctx.oxd_id then
                sh("docker logs ", ctx.oxd_id, " || true")  -- don't fail
            end
        end

        local finalizeres = ctx.finalizeres
        -- call finalizers in revers order
        for i = #finalizeres, 1, -1 do
            xpcall(finalizeres[i], debug.traceback)
        end
    end)


    kong_utils.docker_unique_network()
    kong_utils.kong_postgress_custom_plugins{
        plugins = {
            ["gluu-oauth-auth"] = host_git_root .. "/t/specs/gluu-metrics/mock-oauth-auth",
            ["gluu-metrics"] = host_git_root .. "/kong/plugins/gluu-metrics",
        },
        modules = {
            ["prometheus.lua"] = host_git_root .. "/third-party/nginx-lua-prometheus/prometheus.lua",
            ["resty/lrucache.lua"] = host_git_root .. "/third-party/lua-resty-lrucache/lib/resty/lrucache.lua",
            ["resty/lrucache/pureffi.lua"] = host_git_root .. "/third-party/lua-resty-lrucache/lib/resty/lrucache/pureffi.lua",
        },
        host_git_root = host_git_root,
    }
    kong_utils.backend()
    kong_utils.opa()
end

local function configure_service_route(service_name, service, route)
    service_name = service_name or "demo-service"
    service = service or "backend"
    route = route or "backend.com"
    print"create a Sevice"
    local res, err = sh_until_ok(10,
        [[curl --fail -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/services/ --header 'content-type: application/json' --data '{"name":"]],service_name,[[","url":"http://]],
        service, [["}']]
    )

    local create_service_response = JSON:decode(res)

    print"create a Route"
    local res, err = sh_until_ok(10,
        [[curl --fail -i -sS -X POST  --url http://localhost:]],
        ctx.kong_admin_port, [[/services/]], service_name, [[/routes --data 'hosts[]=]], route, [[']]
    )

    return create_service_response
end

local function configure_auth_plugin(create_service_response)
    local payload = {
        name = "gluu-oauth-auth",
        service_id = create_service_response.id,
    }
    local payload_json = JSON:encode(payload)

    print"enable plugin for the Service"
    local res, err = sh_ex([[
        curl -v -i -sS -X POST  --url http://localhost:]], ctx.kong_admin_port,
        [[/plugins/ ]],
        [[ --header 'content-type: application/json;charset=UTF-8' --data ']], payload_json, [[']]
    )
end

local function configure_metrics_plugin(plugin_config)
    local payload = {
        name = "gluu-metrics",
        config = plugin_config,
    }
    local payload_json = JSON:encode(payload)

    print"enable metrics plugin globally"
    local res, err = sh_ex([[
        curl -v -i -sS -X POST  --url http://localhost:]], ctx.kong_admin_port,
        [[/plugins/ ]],
        [[ --header 'content-type: application/json;charset=UTF-8' --data ']], payload_json, [[']]
    )
end

local function configure_ip_restrict_plugin(create_service_response, plugin_config)
    local payload = {
        name = "ip-restriction",
        config = plugin_config,
        service_id = create_service_response.id,
    }
    local payload_json = JSON:encode(payload)

    print"enable ip restriction plugin for the Service"
    local res, err = sh_ex([[
        curl --fail -sS -X POST --url http://localhost:]], ctx.kong_admin_port,
        [[/plugins/ ]],
        [[ --header 'content-type: application/json;charset=UTF-8' --data ']], payload_json, [[']]
    )

    return JSON:decode(res)
end

test("Check metrics plugin", function()

    setup("oxd-model1.lua")

    local create_service_response = configure_service_route()

    print"test it works"
    sh([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    local ip_restrictriction_response = configure_ip_restrict_plugin(create_service_response, {
        whitelist = {"127.0.0.1"}
    })

    configure_metrics_plugin({
        check_ip_time = 2,
        ip_restrict_plugin_id = ip_restrictriction_response.id
    })

    configure_auth_plugin(create_service_response, {})

    print"Check metrics"
    local res = sh_ex([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    sh_ex("sleep 1")

    local res = sh_ex([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    local res = sh_ex([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    sh_ex("sleep 1")

    local res = sh_ex([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    ctx.print_logs = true
end)

