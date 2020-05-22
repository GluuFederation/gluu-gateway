local utils = require"test_utils"
local sh, stdout, stderr, sleep, sh_ex, sh_until_ok =
utils.sh, utils.stdout, utils.stderr, utils.sleep, utils.sh_ex, utils.sh_until_ok

local kong_utils = require"kong_utils"
local JSON = require"JSON"

local host_git_root = os.getenv"HOST_GIT_ROOT"
local git_root = os.getenv"GIT_ROOT"
local test_root = host_git_root .. "/t/specs/gluu-uma-pep"

-- finally() available only in current module environment
-- this is a hack to pass it to a functions in kong_utils
local function setup_db_less(model)
    kong_utils.setup_db_less(finally, test_root .. "/" .. model)
end

test("with and without token, metrics, uma-auth and check UMA scope", function()
    setup_db_less("oxd-model1.lua")

    local register_site_response, access_token = kong_utils.register_site_get_client_token()

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
                name = "gluu-uma-auth",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    anonymous = "a28a0f83-b619-4b58-94b3-e4ecaf8b6a2a",
                    custom_headers = {
                        { header_name = "x-consumer-id", value_lua_exp = "consumer.id", format = "string" },
                        { header_name = "x-oauth-client-id", value_lua_exp = "introspect_data.client_id", format = "string" },
                        { header_name = "x-consumer-custom-id", value_lua_exp = "introspect_data.client_id", format = "string" },
                        { header_name = "x-rpt-expiration", value_lua_exp = "introspect_data.exp", format = "string" },
                    },
                },
            },
            {
                name = "gluu-uma-pep",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    uma_scope_expression = JSON:encode{
                        {
                            path = "/??",
                            conditions = {
                                {
                                    httpMethods = {"GET"},
                                }
                            }
                        },
                        {
                            path = "/posts",
                            conditions = {
                                {
                                    httpMethods = {"POST"},
                                }
                            }
                        }
                    },
                },
            },
            {
                name = "gluu-metrics",
            }
        },
        consumers = {
            {
                id = "a28a0f83-b619-4b58-94b3-e4ecaf8b6a2a",
                custom_id = "qwertyuiop",
            },
            {
                id = "a28a0f83-b619-4b58-94b3-e4ecaf8b6a2a",
                custom_id = register_site_response.client_id,
            }
        }
    }

    kong_utils.gg_db_less(kong_config)

    print"ensure it fails without token"
    local stdout, _ = sh_ex([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])
    assert(stdout:find("401", 1, true))
    assert(stdout:find("ticket", 1, true))

    local stdout, stderr = sh_ex([[curl -v --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com' --header 'Authorization: Bearer 1234567890']])
    assert(stdout:lower():find("x-consumer-id: " .. string.lower(kong_config.consumers[2].id), 1, true))
    assert(stdout:lower():find("x-oauth-client-id: " .. string.lower(kong_config.consumers[2].custom_id), 1, true))
    assert(stdout:lower():find("x-consumer-custom-id: " .. string.lower(kong_config.consumers[2].custom_id), 1, true))
    assert(stdout:lower():find("x%-rpt%-expiration: %d+"))

    -- plugin shouldn't call oxd, must use cache
    local stdout, stderr = sh_ex([[curl -v --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com' --header 'Authorization: Bearer 1234567890']])
    assert(stdout:lower():find("x-consumer-id: " .. string.lower(kong_config.consumers[2].id), 1, true))
    assert(stdout:lower():find("x-oauth-client-id: " .. string.lower(kong_config.consumers[2].custom_id), 1, true))
    assert(stdout:lower():find("x-consumer-custom-id: " .. string.lower(kong_config.consumers[2].custom_id), 1, true))
    assert(stdout:lower():find("x%-rpt%-expiration: %d+"))

    print"check metrics, it should return gluu_client_authenticated = 2"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_admin_port,
        [[/gluu-metrics]]
    )
    assert(res:lower():find("gluu_uma_client_granted", 1, true))
    assert(res:lower():find(string.lower([[gluu_uma_client_granted{consumer="]]
            .. register_site_response.client_id .. [[",service="demo-service"} 2]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_uma_client_authenticated{consumer="]]
            .. register_site_response.client_id .. [[",service="demo-service"} 2]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_endpoint_method{endpoint="/",method="GET"]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_uma_ticket{service="demo-service"} 1]]), 1, true))

    -- posts: request with wrong token
    local stdout, _ = sh_ex([[curl -i -sS -X POST --url http://localhost:]],
        ctx.kong_proxy_port, [[/posts --header 'Host: backend.com' --header 'Authorization: Bearer POSTS_INVALID_1234567890']])
    assert(stdout:find("401", 1, true))

    -- posts: request
    local stdout, _ = sh_ex([[curl -v --fail -sS -X POST --url http://localhost:]],
        ctx.kong_proxy_port, [[/posts --header 'Host: backend.com' --header 'Authorization: Bearer POSTS1234567890']])
    assert(stdout:lower():find("x-consumer-id: " .. string.lower(kong_config.consumers[2].id), 1, true))
    assert(stdout:lower():find("x-oauth-client-id: " .. string.lower(kong_config.consumers[2].custom_id), 1, true))
    assert(stdout:lower():find("x-consumer-custom-id: " .. string.lower(kong_config.consumers[2].custom_id), 1, true))
    assert(stdout:lower():find("x%-rpt%-expiration: %d+"))

    -- posts: plugin shouldn't call oxd, must use cache
    local stdout, _ = sh_ex([[curl -v --fail -sS -X POST --url http://localhost:]],
        ctx.kong_proxy_port, [[/posts --header 'Host: backend.com' --header 'Authorization: Bearer POSTS1234567890']])
    assert(stdout:lower():find("x-consumer-id: " .. string.lower(kong_config.consumers[2].id), 1, true))
    assert(stdout:lower():find("x-oauth-client-id: " .. string.lower(kong_config.consumers[2].custom_id), 1, true))
    assert(stdout:lower():find("x-consumer-custom-id: " .. string.lower(kong_config.consumers[2].custom_id), 1, true))
    assert(stdout:lower():find("x%-rpt%-expiration: %d+"))

    print"Check metrics for client authentication, it should return count 4 because client auth failed"
    local res, err = sh_ex(
        [[curl -i -sS  -X GET --url http://localhost:]], ctx.kong_admin_port,
        [[/gluu-metrics]]
    )
    assert(res:lower():find("gluu_uma_client_granted", 1, true))
    assert(res:lower():find(string.lower([[gluu_uma_client_granted{consumer="]]
            .. register_site_response.client_id .. [[",service="demo-service"} 4]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_uma_client_authenticated{consumer="]]
            .. register_site_response.client_id .. [[",service="demo-service"} 4]]), 1, true))

    -- todos: not register then apply rules under path / with same token `1234567890`
    local stdout, _ = sh_ex([[curl -v --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/todos --header 'Host: backend.com' --header 'Authorization: Bearer 1234567890']])
    assert(stdout:lower():find("x-consumer-id: " .. string.lower(kong_config.consumers[2].id), 1, true))
    assert(stdout:lower():find("x-oauth-client-id: " .. string.lower(kong_config.consumers[2].custom_id), 1, true))
    assert(stdout:lower():find("x-consumer-custom-id: " .. string.lower(kong_config.consumers[2].custom_id), 1, true))
    assert(stdout:lower():find("x%-rpt%-expiration: %d+"))
    assert(not res:find("cookie: ", 1, true))

    print"GET to the same path but with another already cached token"
    local stdout, _ = sh_ex([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/todos --header 'Host: backend.com' --header 'Authorization: Bearer POSTS1234567890']])
    assert(stdout:find("403", 1, true))

    ctx.print_logs = false
end)

test("deny_by_default = true, uma-auth", function()

    setup_db_less("oxd-model2.lua")

    local register_site_response, access_token = kong_utils.register_site_get_client_token()

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
                name = "gluu-uma-auth",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    anonymous = "a28a0f83-b619-4b58-94b3-e4ecaf8b6a2a",
                },
            },
            {
                name = "gluu-uma-pep",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    deny_by_default = true,
                    uma_scope_expression = JSON:encode{
                        {
                            path = "/posts",
                            conditions = {
                                {
                                    httpMethods = { "GET" },
                                }
                            }
                        }
                    },
                },
            },
            {
                name = "gluu-metrics"
            }
        },
        consumers = {
            {
                id = "a28a0f83-b619-4b58-94b3-e4ecaf8b6a2a",
                custom_id = "qwertyuiop",
            },
            {
                id = "a28a0f83-b619-4b58-94b3-e4ecaf8b6a2a",
                custom_id = register_site_response.client_id,
            }
        }
    }

    kong_utils.gg_db_less(kong_config)

    local stdout, _ = sh_ex([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/posts --header 'Host: backend.com']])
    assert(stdout:find("401", 1, true))
    assert(stdout:find("ticket", 1, true))

    print "test it fail with 403"
    local res, err = sh_ex([[curl -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/todos --header 'Host: backend.com' --header 'Authorization: Bearer 1234567890']])
    assert(res:find("403", 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("deny_by_default = false and pass_credentials = hide, uma-auth", function()

    setup_db_less("oxd-model2.lua")

    local register_site_response, access_token = kong_utils.register_site_get_client_token()

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
                name = "gluu-uma-auth",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    anonymous = "a28a0f83-b619-4b58-94b3-e4ecaf8b6a2a",
                    pass_credentials = "hide",
                    custom_headers = {
                        { header_name = "x-consumer-id", value_lua_exp = "consumer.id", format = "string" },
                        { header_name = "x-oauth-client-id", value_lua_exp = "introspect_data.client_id", format = "string" },
                        { header_name = "x-consumer-custom-id", value_lua_exp = "introspect_data.client_id", format = "string" },
                        { header_name = "x-rpt-expiration", value_lua_exp = "introspect_data.exp", format = "string" },
                    },
                },
            },
            {
                name = "gluu-uma-pep",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    deny_by_default = false,
                    uma_scope_expression = JSON:encode{
                        {
                            path = "/posts",
                            conditions = {
                                {
                                    httpMethods = {"GET"},
                                }
                            }
                        }
                    },
                },
            },
            {
                name = "gluu-metrics"
            }
        },
        consumers = {
            {
                id = "a28a0f83-b619-4b58-94b3-e4ecaf8b6a2a",
                custom_id = "qwertyuiop",
            },
            {
                id = "a28a0f83-b619-4b58-94b3-e4ecaf8b6a2a",
                custom_id = register_site_response.client_id,
            }
        }
    }

    kong_utils.gg_db_less(kong_config)

    -- posts: request to protected path
    local stdout, _ = sh_ex([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/posts --header 'Host: backend.com']])
    assert(stdout:find("401", 1, true))
    assert(stdout:find("ticket", 1, true))

    -- posts: request and check hide_credential
    local stdout, _ = sh_ex([[curl -v --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/posts --header 'Host: backend.com' --header 'Authorization: Bearer 1234567890']])
    assert.equal(nil, stdout:lower():find("authorization: "))
    assert(stdout:lower():find("x-consumer-id: " .. string.lower(kong_config.consumers[2].id), 1, true))
    assert(stdout:lower():find("x-oauth-client-id: " .. string.lower(kong_config.consumers[2].custom_id), 1, true))
    assert(stdout:lower():find("x-consumer-custom-id: " .. string.lower(kong_config.consumers[2].custom_id), 1, true))
    assert(stdout:lower():find("x%-rpt%-expiration: %d+"))

    -- ensure no authorization headers is sent to backend
    -- backend responds in lowecase, so we may distinguish from request's header in curl output
    assert(not stdout:lower():find("authorization: : Bearer"))

    -- plugin shouldn't call oxd, must use cache
    local stdout, _ = sh_ex([[curl -v --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/posts --header 'Host: backend.com' --header 'Authorization: Bearer 1234567890']])
    assert.equal(nil, stdout:lower():find("authorization: "))
    assert(stdout:lower():find("x-consumer-id: " .. string.lower(kong_config.consumers[2].id), 1, true))
    assert(stdout:lower():find("x-oauth-client-id: " .. string.lower(kong_config.consumers[2].custom_id), 1, true))
    assert(stdout:lower():find("x-consumer-custom-id: " .. string.lower(kong_config.consumers[2].custom_id), 1, true))
    assert(stdout:lower():find("x%-rpt%-expiration: %d+"))

    -- /todos: request to not protected
    local res, err = sh_ex(
        [[curl -v --fail -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/todos --header 'Host: backend.com' --header 'Authorization: Bearer 1234567890']]
    )

    ctx.print_logs = false -- comment it out if want to see logs
end)
