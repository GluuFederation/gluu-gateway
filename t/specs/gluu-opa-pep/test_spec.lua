local utils = require"test_utils"
local sh, stdout, stderr, sleep, sh_ex, sh_until_ok =
utils.sh, utils.stdout, utils.stderr, utils.sleep, utils.sh_ex, utils.sh_until_ok

local kong_utils = require"kong_utils"

local host_git_root = os.getenv"HOST_GIT_ROOT"
local git_root = os.getenv"GIT_ROOT"
local host_test_root = host_git_root .. "/t/specs/gluu-opa-pep"
local test_root = git_root .. "/t/specs/gluu-opa-pep"

-- finally() available only in current module environment
-- this is a hack to pass it to a functions in kong_utils
local function setup_db_less()
    kong_utils.setup_db_less(finally)
end

test("opa, client_id match", function()

    setup_db_less()

    kong_utils.opa()
    -- upload a policy
    sh([[curl -X PUT --data-binary @]], test_root, [[/policy.rego localhost:]], ctx.opa_port, [[/v1/policies/example]] )

    local kong_config = {
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
                name = "gluu-oauth-auth",
                service = "demo-service",
                config = {
                    customer_id = "a28a0f83-b619-4b58-94b3-e4ecaf8b6a2a",
                    request_token_data = {
                        client_id = "1234567",
                    }
                },
            },
            {
                name = "gluu-opa-pep",
                service = "demo-service",
                config = {
                    opa_url = "http://opa:8181/v1/data/httpapi/authz?pretty=true&explain=full",
                }
            },
            {
                name = "gluu-metrics",
            }
        },
        consumers = {
            {
                id = "a28a0f83-b619-4b58-94b3-e4ecaf8b6a2a",
                custom_id = "1234567",
            }
        }
    }

    kong_utils.gg_db_less(kong_config,
        {
            ["gluu-oauth-auth"] = host_test_root .. "/mock-oauth-auth",
        }
    )

    print"test it works"
    sh([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/folder/command --header 'Host: backend.com']])


    print"check metrics, it should return gluu_opa_granted = 1"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_admin_port,
        [[/gluu-metrics]]
    )
    assert(res:lower():find("gluu_opa_client_granted", 1, true))
    assert(res:lower():find(
        string.lower([[gluu_endpoint_method{endpoint="/folder/command",method="GET",service="demo-service"} 1]]), 1, true))
    assert(res:lower():find(
        string.lower([[gluu_oauth_client_authenticated{consumer="]],kong_config.consumers[1].id, [[",service="demo-service"} 1]]), 1, true))
    assert(res:lower():find(
        string.lower([[gluu_opa_client_granted{consumer="]],kong_config.consumers[1].id, [[",service="demo-service"} 1]]), 1, true))

    print"it should fail, path doesn't match"
    local res = sh_ex([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])
    assert(res:find("HTTP/1.1 403", 1, true))

    print"it should fail, method doesn't match"
    local res = sh_ex([[curl -i -sS -X POST --url http://localhost:]],
        ctx.kong_proxy_port, [[/folder/command --header 'Host: backend.com' --data 'bla-bla']])
    assert(res:find("HTTP/1.1 403", 1, true))

    -- change client_id, policy doesn't match
    kong_config.plugins[1].config.request_token_data.client_id = "bla-bla-bla"

    kong_utils.db_less_reconfigure(kong_config)

    print"test it fail"
    sh([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/folder/command --header 'Host: backend.com']])

    ctx.print_logs = false
end)
