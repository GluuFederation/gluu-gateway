local utils = require"test_utils"
local sh, stdout, stderr, sleep, sh_ex, sh_until_ok =
utils.sh, utils.stdout, utils.stderr, utils.sleep, utils.sh_ex, utils.sh_until_ok

local kong_utils = require"kong_utils"
local JSON = require"JSON"

local host_git_root = os.getenv"HOST_GIT_ROOT"
local git_root = os.getenv"GIT_ROOT"
local host_test_root = host_git_root .. "/t/specs/gluu-metrics"
local test_root = git_root .. "/t/specs/gluu-opa-pep"

-- finally() available only in current module environment
-- this is a hack to pass it to a functions in kong_utils
local function setup_db_less()
    kong_utils.setup_db_less(finally)
end

test("Check metrics plugin - oauth-auth", function()
    setup_db_less()

    local kong_config = {
        _format_version = "1.1",
        services = {
            {
                name =  "demo-service",
                url = "http://backend",
            },
            {
                name =  "demo-service2",
                url = "http://backend",
            },
        },
        routes = {
            {
                name =  "demo-route",
                service = "demo-service",
                hosts = { "backend.com" },
            },
            {
                name =  "demo-route2",
                service = "demo-service2",
                hosts = { "backend2.com" },
            },
        },
        plugins = {
            {
                name = "gluu-oauth-auth",
                service = "demo-service",
                config = {
                    customer_id = "a28a0f83-b619-4b58-94b3-e4ecaf8b6a2a",
                },
            },
            {
                name = "gluu-uma-auth",
                service = "demo-service2",
                config = {
                    customer_id = "a28a0f83-b619-4b58-94b3-e4ecaf8b6a2b",
                },
            },
            {
                name = "gluu-metrics",
            }
        },
        consumers = {
            {
                id = "a28a0f83-b619-4b58-94b3-e4ecaf8b6a2a",
                custom_id = "1234567oauth", -- should match mock-oauth-auth
            },
            {
                id = "a28a0f83-b619-4b58-94b3-e4ecaf8b6a2b",
                custom_id = "1234567uma", -- should match mock-uma-auth
            },
        }
    }

    kong_utils.gg_db_less(kong_config,
        {
            ["gluu-oauth-auth"] = host_test_root .. "/mock-oauth-auth",
            ["gluu-uma-auth"] = host_test_root .. "/mock-uma-auth",

        }
    )
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
    assert(res:lower():find(string.lower([[gluu_oauth_client_authenticated{consumer="]]
            .. kong_config.consumers[1].custom_id .. [[",service="demo-service"} 3]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_uma_client_authenticated{consumer="]]
            .. kong_config.consumers[2].custom_id .. [[",service="demo-service2"} 3]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_total_client_authenticated 6]]), 1, true))

    ctx.print_logs = false
end)
