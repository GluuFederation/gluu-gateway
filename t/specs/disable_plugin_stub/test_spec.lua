local utils = require"test_utils"
local sh, stdout, stderr, sleep, sh_ex, sh_until_ok =
utils.sh, utils.stdout, utils.stderr, utils.sleep, utils.sh_ex, utils.sh_until_ok

local kong_utils = require"kong_utils"
local JSON = require"JSON"

local host_git_root = os.getenv"HOST_GIT_ROOT"
local git_root = os.getenv"GIT_ROOT"
local test_root = host_git_root .. "/t/specs/gluu-opa-pep"

local function setup(config)
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
    kong_utils.gg_db_less(config)
    kong_utils.backend()
end

test("key-auth disabled", function()

    setup{
        _format_version = "1.1",
        services = {
            {
                name =  "demo-service",
                url = "http://backend",
            },
        },
        routes = {
            {
                name =  "demo-route",
                service = "demo-service",
                hosts = { "backend.com" },
            },
        },
        plugins = {
            {
                name = "key-auth",
                service = "demo-service",
                config = {
                    key_names = { "apikey" },
                },
            },
        },
    }

    print"test it fail with 500"
    local stdout, stderr = sh_ex([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])
    assert(stdout:find("500", 1, true))

    ctx.print_logs = false
end)

