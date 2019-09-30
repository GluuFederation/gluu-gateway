local utils = require"test_utils"
local sh, stdout, stderr, sleep, sh_ex, sh_until_ok =
utils.sh, utils.stdout, utils.stderr, utils.sleep, utils.sh_ex, utils.sh_until_ok

local kong_utils = require"kong_utils"
local JSON = require"JSON"

local pl_file = require"pl.file"

local host_git_root = os.getenv"HOST_GIT_ROOT"
local git_root = os.getenv"GIT_ROOT"
local test_root = host_git_root .. "/t/specs/gluu-oauth-pep"

local function setup()
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
            ["gluu-oauth-auth"] = host_git_root .. "/kong/plugins/gluu-oauth-auth",
            ["gluu-oauth-pep"] = host_git_root .. "/kong/plugins/gluu-oauth-pep",
            ["gluu-metrics"] = host_git_root .. "/kong/plugins/gluu-metrics",
        },
        modules = {
            ["prometheus.lua"] = host_git_root .. "/third-party/nginx-lua-prometheus/prometheus.lua",
            ["gluu/oxdweb.lua"] = host_git_root .. "/third-party/oxd-web-lua/oxdweb.lua",
            ["gluu/kong-common.lua"] = host_git_root .. "/kong/common/kong-common.lua",
            ["gluu/path-wildcard-tree.lua"] = host_git_root .. "/kong/common/path-wildcard-tree.lua",
            ["gluu/json-cache.lua"] = host_git_root .. "/kong/common/json-cache.lua",
            ["resty/lrucache.lua"] = host_git_root .. "/third-party/lua-resty-lrucache/lib/resty/lrucache.lua",
            ["resty/lrucache/pureffi.lua"] = host_git_root .. "/third-party/lua-resty-lrucache/lib/resty/lrucache/pureffi.lua",
            ["rucciva/json_logic.lua"] = host_git_root .. "/third-party/json-logic-lua/logic.lua",
            ["resty/jwt.lua"] = host_git_root .. "/third-party/lua-resty-jwt/lib/resty/jwt.lua",
            ["resty/evp.lua"] = host_git_root .. "/third-party/lua-resty-jwt/lib/resty/evp.lua",
            ["resty/jwt-validators.lua"] = host_git_root .. "/third-party/lua-resty-jwt/lib/resty/jwt-validators.lua",
            ["resty/hmac.lua"] = host_git_root .. "/third-party/lua-resty-hmac/lib/resty/hmac.lua",
        },
        host_git_root = host_git_root,
        nginx_worker_processes = "auto",
        nginx_log_level = "error",
    }
    kong_utils.backend()
    kong_utils.oxd_mock_perf()
    kong_utils.jwt_proxy()
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

local function configure_pep_plugin(create_service_response, plugin_config)
    plugin_config.op_url = "http://stub"
    plugin_config.oxd_url = "http://oxd-mock"
    plugin_config.client_id = "stub"
    plugin_config.client_secret = "stub"
    plugin_config.oxd_id = "stub"

    local payload = {
        name = "gluu-oauth-pep",
        config = plugin_config,
        service = { id = create_service_response.id},
    }
    local payload_json = JSON:encode(payload)

    print"enable plugin for the Service"
    local res, err = sh_ex([[
        curl -v -i --fail -sS -X POST  --url http://localhost:]], ctx.kong_admin_port,
        [[/plugins/ ]],
        [[ --header 'content-type: application/json;charset=UTF-8' --data ']], payload_json, [[']]
    )
end

local function configure_auth_plugin(create_service_response, plugin_config)

    local get_client_token = {
        op_host = "just_stub",
        client_id = "stub",
        client_secret = "stub",
    }

    local get_client_token_json = JSON:encode(get_client_token)

    local res, err = sh_ex(
        [[curl --fail -v -sS -X POST --url http://localhost:]], ctx.oxd_port,
        [[/get-client-token --header 'Content-Type: application/json' --data ']],
        get_client_token_json, [[']]
    )
    local response = JSON:decode(res)


    plugin_config.op_url = "http://stub"
    plugin_config.oxd_url = "http://oxd-mock"
    plugin_config.client_id = "stub"
    plugin_config.client_secret = "stub"
    plugin_config.oxd_id = "stub"

    local payload = {
        name = "gluu-oauth-auth",
        config = plugin_config,
        service = { id = create_service_response.id},
    }
    local payload_json = JSON:encode(payload)

    print"enable plugin for the Service"
    local res, err = sh_ex([[
        curl -v -i --fail -sS -X POST  --url http://localhost:]], ctx.kong_admin_port,
        [[/plugins/ ]],
        [[ --header 'content-type: application/json;charset=UTF-8' --data ']], payload_json, [[']]
    )

    return response.access_token
end

local function create_customer(custom_id)
    local res, err = sh_ex([[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=]], custom_id ,[[']]
    )
end

test("basic OAuth+ PEP perf run, all tokens as JWT", function()
    setup()

    local create_service_response = configure_service_route()

    print"test it works"
    local stdout, stderr = sh_ex([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    configure_auth_plugin(create_service_response, {})

    local generator_config_text = pl_file.read(git_root .. "/kong/perf/generator_config.json")
    local generator_config = JSON:decode(generator_config_text)
    local oauth_scope_expression = generator_config.oauth_scope_expression
    local token_data = generator_config.token_data

    local created_customers = {}

    for i = 1, #token_data do
        local client_id = token_data[i].client_id
        if not created_customers[client_id] then
            create_customer(client_id)
            created_customers[client_id] = true
        end
    end

    configure_pep_plugin(create_service_response, {
        oauth_scope_expression = JSON:encode(oauth_scope_expression),
        deny_by_default = false,
    })

    --sh_ex("wrk -c1 -d1s -t1 -s ", git_root, "/kong/perf/wrk.lua http://127.0.0.1:", ctx.jwt_proxy_port)
    sh_ex("wrk -c100 -d120s -t5 -s ", git_root, "/kong/perf/wrk.lua http://127.0.0.1:", ctx.jwt_proxy_port)

    --sh_ex("docker logs jwt-proxy")
    ctx.print_logs = false -- comment it out if want to see logs
    --sh_ex("docker logs ", ctx.kong_id)
    --sh_ex("docker logs ", ctx.oxd_id)
end)
