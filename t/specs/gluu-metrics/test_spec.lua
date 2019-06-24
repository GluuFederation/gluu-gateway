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
            ["gluu-uma-auth"] = host_git_root .. "/t/specs/gluu-metrics/mock-uma-auth",
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

local function configure_auth_plugin(create_service_response, config)
    local payload = {
        name = "gluu-oauth-auth",
        service_id = create_service_response.id,
        config = config,
    }
    local payload_json = JSON:encode(payload)

    print"enable plugin for the Service"
    local res, err = sh_ex([[
        curl -v -i -sS --fail -X POST  --url http://localhost:]], ctx.kong_admin_port,
        [[/plugins/ ]],
        [[ --header 'content-type: application/json;charset=UTF-8' --data ']], payload_json, [[']]
    )
end

local function configure_uma_plugin(create_service_response, config)
    local payload = {
        name = "gluu-uma-auth",
        service_id = create_service_response.id,
        config = config,
    }
    local payload_json = JSON:encode(payload)

    print"enable plugin for the Service"
    local res, err = sh_ex([[
        curl -v -i -sS --fail -X POST  --url http://localhost:]], ctx.kong_admin_port,
        [[/plugins/ ]],
        [[ --header 'content-type: application/json;charset=UTF-8' --data ']], payload_json, [[']]
    )
end

test("Check metrics and ip restriction plugin", function()
    setup("oxd-model1.lua")

    local create_service_response = configure_service_route()

    print"test it works"
    local stdout, stderr = sh_ex([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    local test_runner_ip = stdout:match("x%-real%-ip: ([%d%.]+)")
    print("test_runner_ip: ", test_runner_ip)

    print"create a consumer"
    local res, err = sh_ex([[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=1234567']]
    )

    local consumer_response = JSON:decode(res)

    configure_auth_plugin(create_service_response, {customer_id = consumer_response.id})

    print"test it works"
    sh([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])


    local ip_restrictriction_response = kong_utils.configure_ip_restrict_plugin(create_service_response, {
        whitelist = {test_runner_ip}
    })

    kong_utils.configure_metrics_plugin({
        gluu_prometheus_server_host = "license.gluu.org",
        check_ip_time = 2,
        ip_restrict_plugin_id = ip_restrictriction_response.id
    })

    print"Check request, Not fail because ip restrict execute first then metrics plugin will update it"
    local res = sh_ex([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    sh_ex("sleep 3")

    print"Failed, because ip updated"
    local res = sh_ex([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])
    assert(res:find("403", 1, true))

    print"Check whitelist ips, after 3 sec"
    local res = sh_ex([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_admin_port, [[/plugins/]], ip_restrictriction_response.id)
    assert(not res:lower():find(test_runner_ip))

    ctx.print_logs = false
end)

test("Check Total metrics", function()
    setup("oxd-model1.lua")

    local create_service_response = configure_service_route()
    local create_service2_response = configure_service_route("demo-service2", "backend", "backend2.com")

    print"test it works"
    local stdout, stderr = sh_ex([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    local test_runner_ip = stdout:match("x%-real%-ip: ([%d%.]+)")
    print("test_runner_ip: ", test_runner_ip)

    print"create a consumer for oauth"
    local res, err = sh_ex([[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=1234567']]
    )

    local oauth_consumer_response = JSON:decode(res)

    print"create a consumer for uma"
    local res, err = sh_ex([[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=891011']]
    )

    local uma_consumer_response = JSON:decode(res)

    configure_auth_plugin(create_service_response, {customer_id = oauth_consumer_response.id})
    configure_uma_plugin(create_service2_response, {customer_id = uma_consumer_response.id})

    local ip_restrictriction_response = kong_utils.configure_ip_restrict_plugin(create_service_response, {
        whitelist = {test_runner_ip}
    })

    kong_utils.configure_metrics_plugin({
        gluu_prometheus_server_host = "localhost",
        ip_restrict_plugin_id = ip_restrictriction_response.id
    })

    print"OAuth authentications"
    local oauth_service = "backend.com"
    sh_ex([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: ]],oauth_service,[[']])

    sh_ex([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: ]],oauth_service,[[']])

    sh_ex([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: ]],oauth_service,[[']])

    print"UMA authentications"
    local uma_service = "backend2.com"
    sh_ex([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: ]],uma_service,[[']])

    sh_ex([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: ]],uma_service,[[']])

    sh_ex([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: ]],uma_service,[[']])

    print"check metrics, gluu_total_client_authenticated = 6"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_admin_port,
        [[/gluu-metrics]]
    )
    assert(res:lower():find(string.lower([[gluu_oauth_client_authenticated{consumer="]] .. oauth_consumer_response.custom_id .. [[",service="]] .. create_service_response.name .. [["} 3]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_uma_client_authenticated{consumer="]] .. uma_consumer_response.custom_id .. [[",service="]] .. create_service2_response.name .. [["} 3]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_total_client_authenticated 6]]), 1, true))

    ctx.print_logs = false
end)
