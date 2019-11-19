local utils = require"test_utils"
local sh, stdout, stderr, sleep, sh_ex, sh_until_ok =
utils.sh, utils.stdout, utils.stderr, utils.sleep, utils.sh_ex, utils.sh_until_ok

local kong_utils = require"kong_utils"
local JSON = require"JSON"

local host_git_root = os.getenv"HOST_GIT_ROOT"
local git_root = os.getenv"GIT_ROOT"
local test_root = host_git_root .. "/t/specs/gluu-opa-pep"

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
        end

        local finalizeres = ctx.finalizeres
        -- call finalizers in revers order
        for i = #finalizeres, 1, -1 do
            xpcall(finalizeres[i], debug.traceback)
        end
    end)


    kong_utils.docker_unique_network()
    kong_utils.kong_postgress_custom_plugins{
        volumes = {
            ["/usr/local/openresty/lualib/kong/plugins/key-auth/handler.lua"] = host_git_root .. "/kong/disable_plugin_stub/handler.lua",
            ["/usr/local/openresty/lualib/kong/plugins/key-auth/migrations/init.lua"] = host_git_root .. "/kong/disable_plugin_stub/migrations/init.lua",
        },
        host_git_root = host_git_root,
    }
    kong_utils.backend()
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

local function configure_key_auth_plugin(create_service_response)
    local plugin_config = {
        key_names = { "apikey" },
    }

    local payload = {
        name = "key-auth",
        config = plugin_config,
        service = { id = create_service_response.id},
    }
    local payload_json = JSON:encode(payload)

    print"enable plugin for the Service"
    local res, err = sh_ex([[
        curl --fail -v -i -sS -X POST  --url http://localhost:]], ctx.kong_admin_port,
        [[/plugins/ ]],
        [[ --header 'content-type: application/json;charset=UTF-8' --data ']], payload_json, [[']]
    )
end

test("key-auth disabled", function()

    setup()

    local create_service_response = configure_service_route()

    print"test it works"
    local stdout, stderr = sh_ex([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    configure_key_auth_plugin(create_service_response)

    print"test it fail with 500"
    local stdout, stderr = sh_ex([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])
    assert(stdout:find("500", 1, true))

    ctx.print_logs = false
end)

