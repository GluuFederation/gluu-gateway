local utils = require"test_utils"
local sh, stdout, stderr, sleep, sh_ex, sh_until_ok =
utils.sh, utils.stdout, utils.stderr, utils.sleep, utils.sh_ex, utils.sh_until_ok

local kong_utils = require"kong_utils"
local JSON = require"JSON"

local host_git_root = os.getenv"HOST_GIT_ROOT"
local git_root = os.getenv"GIT_ROOT"
local test_root = host_git_root .. "/t/specs/gluu-opa-pep"

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
            ["gluu-oauth-auth"] = host_git_root .. "/t/specs/gluu-opa-pep/mock-oauth-auth",
            ["gluu-opa-pep"] = host_git_root .. "/kong/plugins/gluu-opa-pep",
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

local function configure_pep_plugin(create_service_response)
    local plugin_config = {
        opa_url = "http://opa:8181/v1/data/httpapi/authz?pretty=true&explain=full",
    }

    local payload = {
        name = "gluu-opa-pep",
        config = plugin_config,
        service = { id = create_service_response.id},
    }
    local payload_json = JSON:encode(payload)

    print"enable plugin for the Service"
    local res, err = sh_ex([[
        curl -v -i -sS -X POST  --url http://localhost:]], ctx.kong_admin_port,
        [[/plugins/ ]],
        [[ --header 'content-type: application/json;charset=UTF-8' --data ']], payload_json, [[']]
    )
end

local function configure_auth_plugin(create_service_response, plugin_config)
    local payload = {
        name = "gluu-oauth-auth",
        config = plugin_config,
        service = { id = create_service_response.id},
    }
    local payload_json = JSON:encode(payload)

    print"enable plugin for the Service"
    local res, err = sh_ex([[
        curl -v -i -sS -X POST  --url http://localhost:]], ctx.kong_admin_port,
        [[/plugins/ ]],
        [[ --header 'content-type: application/json;charset=UTF-8' --data ']], payload_json, [[']]
    )

    return
end

test("opa, client_id match", function()

    setup("oxd-model1.lua")

    local create_service_response = configure_service_route()

    print"test it works"
    local stdout, stderr = sh_ex([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    local test_runner_ip = stdout:match("x%-real%-ip: ([%d%.]+)")
    print("test_runner_ip: ", test_runner_ip)

    print "configure gluu-metrics and ip restriction plugin for the Service"
    local ip_restrictriction_response = kong_utils.configure_ip_restrict_plugin(create_service_response, {
        whitelist = {test_runner_ip}
    })
    kong_utils.configure_metrics_plugin({
        gluu_prometheus_server_host = "localhost",
        ip_restrict_plugin_id = ip_restrictriction_response.id
    })

    print"create a consumer"
    local res, err = sh_ex([[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=1234567']]
    )
    local consumer_response = JSON:decode(res)

    configure_auth_plugin(create_service_response,
        {
            customer_id = consumer_response.id,
            request_token_data = {
                client_id = "0123456789",
            }
        })

    configure_pep_plugin(create_service_response)

    -- upload a policy
    sh([[curl -X PUT --data-binary @]], git_root, [[/t/specs/gluu-opa-pep/policy.rego localhost:]], ctx.opa_port, [[/v1/policies/example]] )

    print"test it works"
    sh([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/folder/command --header 'Host: backend.com']])


    print"check metrics, it should return gluu_opa_granted = 1"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_admin_port,
        [[/gluu-metrics]]
    )
    assert(res:lower():find("gluu_opa_client_granted", 1, true))
    assert(res:lower():find(string.lower([[gluu_endpoint_method{endpoint="/folder/command",method="GET",service="]] .. create_service_response.name .. [["} 1]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_oauth_client_authenticated{consumer="1234567",service="]] .. create_service_response.name .. [["} 1]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_opa_client_granted{consumer="1234567",service="]] .. create_service_response.name .. [["} 1]]), 1, true))

    print"it should fail, path doesn't match"
    local res = sh_ex([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])
    assert(res:find("HTTP/1.1 403", 1, true))

    print"it should fail, method doesn't match"
    local res = sh_ex([[curl -i -sS -X POST --url http://localhost:]],
        ctx.kong_proxy_port, [[/folder/command --header 'Host: backend.com' --data 'bla-bla']])
    assert(res:find("HTTP/1.1 403", 1, true))

    ctx.print_logs = false
end)

test("opa, client_id doesn't match", function()

    setup("oxd-model1.lua")

    local create_service_response = configure_service_route()

    print"test it works"
    sh([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    print"create a consumer"
    local res, err = sh_ex([[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=1234567']]
    )
    local consumer_response = JSON:decode(res)

    configure_auth_plugin(create_service_response,
        {
            customer_id = consumer_response.id,
            request_token_data = {
                client_id = "bla-bla-bla",
            }
        })

    configure_pep_plugin(create_service_response)

    -- upload a policy
    sh([[curl -X PUT --data-binary @]], git_root, [[/t/specs/gluu-opa-pep/policy.rego localhost:]], ctx.opa_port, [[/v1/policies/example]] )

    print"test it fail"
    sh([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/folder/command --header 'Host: backend.com']])

    ctx.print_logs = false
end)
