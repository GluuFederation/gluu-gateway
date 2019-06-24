local utils = require"test_utils"
local sh, stdout, stderr, sleep, sh_ex, sh_until_ok =
utils.sh, utils.stdout, utils.stderr, utils.sleep, utils.sh_ex, utils.sh_until_ok

local kong_utils = require"kong_utils"
local JSON = require"JSON"

local host_git_root = os.getenv"HOST_GIT_ROOT"
local git_root = os.getenv"GIT_ROOT"
local test_root = host_git_root .. "/t/specs/gluu-oauth-pep"

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
            ["gluu-oauth-auth"] = host_git_root .. "/kong/plugins/gluu-oauth-auth",
            ["gluu-oauth-pep"] = host_git_root .. "/kong/plugins/gluu-oauth-pep",
            ["gluu-metrics"] = host_git_root .. "/kong/plugins/gluu-metrics",
        },
        modules = {
            ["prometheus.lua"] = host_git_root .. "/third-party/nginx-lua-prometheus/prometheus.lua",
            ["gluu/oxdweb.lua"] = host_git_root .. "/third-party/oxd-web-lua/oxdweb.lua",
            ["gluu/kong-common.lua"] = host_git_root .. "/kong/common/kong-common.lua",
            ["gluu/path-wildcard-tree.lua"] = host_git_root .. "/kong/common/path-wildcard-tree.lua",
            ["resty/lrucache.lua"] = host_git_root .. "/third-party/lua-resty-lrucache/lib/resty/lrucache.lua",
            ["resty/lrucache/pureffi.lua"] = host_git_root .. "/third-party/lua-resty-lrucache/lib/resty/lrucache/pureffi.lua",
            ["rucciva/json_logic.lua"] = host_git_root .. "/third-party/json-logic-lua/logic.lua",
            ["resty/jwt.lua"] = host_git_root .. "/third-party/lua-resty-jwt/lib/resty/jwt.lua",
            ["resty/evp.lua"] = host_git_root .. "/third-party/lua-resty-jwt/lib/resty/evp.lua",
            ["resty/jwt-validators.lua"] = host_git_root .. "/third-party/lua-resty-jwt/lib/resty/jwt-validators.lua",
            ["resty/hmac.lua"] = host_git_root .. "/third-party/lua-resty-hmac/lib/resty/hmac.lua",
        },
        host_git_root = host_git_root,
    }
    kong_utils.backend()
    kong_utils.oxd_mock(test_root .. "/" .. model)
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

local function configure_pep_plugin(register_site_response, create_service_response, plugin_config)
    plugin_config.op_url = "http://stub"
    plugin_config.oxd_url = "http://oxd-mock"
    plugin_config.client_id = register_site_response.client_id
    plugin_config.client_secret = register_site_response.client_secret
    plugin_config.oxd_id = register_site_response.oxd_id

    local payload = {
        name = "gluu-oauth-pep",
        config = plugin_config,
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

local function configure_auth_plugin(create_service_response, plugin_config)
    local register_site = {
        scope = { "openid", "uma_protection" },
        op_host = "just_stub",
        authorization_redirect_uri = "https://client.example.com/cb",
        client_name = "demo plugin",
        grant_types = { "client_credentials" }
    }
    local register_site_json = JSON:encode(register_site)

    local res, err = sh_ex(
        [[curl --fail -v -sS -X POST --url http://localhost:]], ctx.oxd_port,
        [[/register-site --header 'Content-Type: application/json' --data ']],
        register_site_json, [[']]
    )
    local register_site_response = JSON:decode(res)

    local get_client_token = {
        op_host = "just_stub",
        client_id = register_site_response.client_id,
        client_secret = register_site_response.client_secret,
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
    plugin_config.client_id = register_site_response.client_id
    plugin_config.client_secret = register_site_response.client_secret
    plugin_config.oxd_id = register_site_response.oxd_id

    local payload = {
        name = "gluu-oauth-auth",
        config = plugin_config,
        service_id = create_service_response.id,
    }
    local payload_json = JSON:encode(payload)

    print"enable plugin for the Service"
    local res, err = sh_ex([[
        curl -v -i -sS -X POST  --url http://localhost:]], ctx.kong_admin_port,
        [[/plugins/ ]],
        [[ --header 'content-type: application/json;charset=UTF-8' --data ']], payload_json, [[']]
    )

    return register_site_response, response.access_token
end

test("with, without token and metrics", function()

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

    local register_site_response, access_token = configure_auth_plugin(create_service_response, {})

    configure_pep_plugin(register_site_response, create_service_response, {
        oauth_scope_expression = {},
        deny_by_default = false
    })

    print"test it fail with 401 without token"
    local res, err = sh_ex([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])
    assert(res:find("401", 1, true))

    print"create a consumer"
    local res, err = sh_ex([[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=]], register_site_response.client_id, [[']]
    )

    local consumer_response = JSON:decode(res)

    print"test it work with token, consumer is registered"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )

    -- backend returns all headrs within body
    print"check that GG set all required upstream headers"
    assert(res:lower():find("x-consumer-id: " .. string.lower(consumer_response.id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x%-oauth%-expiration: %d+"))

    print"second time call"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )

    print"check metrics, it should return gluu_client_authenticated = 2"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_admin_port,
        [[/gluu-metrics]]
    )
    assert(res:lower():find("gluu_oauth_client_authenticated", 1, true))
    assert(res:lower():find(string.lower([[gluu_oauth_client_authenticated{consumer="]] .. register_site_response.client_id .. [[",service="]] .. create_service_response.name .. [["} 2]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_endpoint_method{endpoint="/",method="GET"]]), 1, true))

    print"test it fail with 403 with wrong Bearer token"
    local res, err = sh_ex(
        [[curl -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer bla-bla']]
    )
    assert(res:find("401"))

    print"Check metrics for client authentication, it should return count 2 because client auth failed"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_admin_port,
        [[/gluu-metrics]]
    )
    assert(res:lower():find("gluu_oauth_client_authenticated", 1, true))
    assert(res:lower():find(string.lower([[gluu_oauth_client_authenticated{consumer="]] .. register_site_response.client_id .. [[",service="]] .. create_service_response.name .. [["} 2]]), 1, true))

    print"test it works with the same token again, oxd-model id completed, token taken from cache"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("Anonymous test", function()

    setup("oxd-model2.lua")

    local create_service_response = configure_service_route()

    print "Create a anonymous consumer"
    local ANONYMOUS_CONSUMER_CUSTOM_ID = "anonymous_123"
    local res, err = sh_ex(
        [[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=]], ANONYMOUS_CONSUMER_CUSTOM_ID, [[']])
    local anonymous_consumer_response = JSON:decode(res)

    print("anonymous_consumer_response.id: ", anonymous_consumer_response.id)

    local register_site_response, access_token = configure_auth_plugin(create_service_response, {
        anonymous = anonymous_consumer_response.id
    })

    configure_pep_plugin(register_site_response, create_service_response,
        {
            oauth_scope_expression = {},
            deny_by_default = false
        }
    )

    sleep(1)

    print"Allow access, deny_by_default = false"
    local res, err = sh_ex([[curl -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer bla-bla']])
    assert(res:find("200"))

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("deny_by_default = true and metrics", function()

    setup("oxd-model1.lua") -- yes, model1 should work

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

    local register_site_response, access_token = configure_auth_plugin(create_service_response,{})

    configure_pep_plugin(register_site_response, create_service_response, {
        oauth_scope_expression = {},
        deny_by_default = true
    })

    print"create a consumer"
    local res, err = sh_ex([[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=]], register_site_response.client_id, [[']]
    )

    local consumer_response = JSON:decode(res)

    print"test it fail with 403"
    local res, err = sh_ex(
        [[curl -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )
    assert(res:find("403", 1, true))

    print"check metrics, it should not return gluu_oauth_client_granted"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_admin_port,
        [[/gluu-metrics]]
    )
    assert(res:lower():find("gluu_oauth_client_authenticated", 1, true))
    assert(res:lower():find("gluu_oauth_client_granted", 1, true) == nil)
    assert(res:lower():find(string.lower([[gluu_endpoint_method{endpoint="/",method="GET"]]), 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("deny_by_default = false, pass_credentials = hide and metrics", function()

    setup("oxd-model1.lua") -- yes, model1 should work

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

    local register_site_response, access_token = configure_auth_plugin(create_service_response,
        {
            pass_credentials = "hide"
        }
    )

    configure_pep_plugin(register_site_response, create_service_response, {
        oauth_scope_expression = {},
        deny_by_default = false,
    })

    print"create a consumer"
    local res, err = sh_ex([[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=]], register_site_response.client_id, [[']]
    )

    local consumer_response = JSON:decode(res)

    print"test with unprotected path"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/todos --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )
    assert(res:lower():find("x-consumer-id: " .. string.lower(consumer_response.id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x%-oauth%-expiration: %d+"))
    assert.equal(nil, res:lower():find("authorization: "))

    print"test with unprotected path second time, plugin shouldn't call oxd, must use cache"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/todos --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )
    assert(res:lower():find("x-consumer-id: " .. string.lower(consumer_response.id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x%-oauth%-expiration: %d+"))
    assert.equal(nil, res:lower():find("authorization: "))

    print"check metrics, it should not return gluu_oauth_client_granted"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_admin_port,
        [[/gluu-metrics]]
    )
    assert(res:lower():find(string.lower([[gluu_oauth_client_authenticated{consumer="]] .. register_site_response.client_id .. [[",service="]] .. create_service_response.name .. [["} 2]]), 1, true))
    assert(res:lower():find("gluu_oauth_client_granted", 1, true) == nil)
    assert(res:lower():find(string.lower([[gluu_endpoint_method{endpoint="/todos",method="GET"]]), 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("check oauth_scope_expression and metrics", function()

    setup("oxd-model3.lua")

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

    local register_site_response, access_token = configure_auth_plugin(create_service_response,{})

    configure_pep_plugin(register_site_response, create_service_response, {
        oauth_scope_expression = {
            {
                path = "/??",
                conditions = {
                    {
                        scope_expression = {
                            rule = {
                                ["and"] = {
                                    {
                                        var = 0
                                    }
                                }
                            },
                            data = {
                                "admin"
                            }
                        },
                        httpMethods = {
                            "GET",
                            "DELETE",
                            "POST"
                        }
                    }
                }
            },
            {
                path = "/posts",
                conditions = {
                    {
                        scope_expression = {
                            rule = {
                                ["and"] = {
                                    {
                                        var = 0
                                    },
                                    {
                                        var = 1
                                    }
                                }
                            },
                            data = {
                                "admin",
                                "employee"
                            }
                        },
                        httpMethods = {
                            "GET",
                            "DELETE",
                            "POST"
                        }
                    }
                }
            },
            {
                path = "/comments",
                conditions = {
                    {
                        scope_expression = {
                            rule = {
                                ["or"] = {
                                    {
                                        var = 0
                                    },
                                    {
                                        var = 1
                                    }
                                }
                            },
                            data = {
                                "admin",
                                "employee"
                            }
                        },
                        httpMethods = {
                            "GET",
                            "POST",
                            "DELETE"
                        }
                    }
                }
            },
            {
                path = "/todos",
                conditions = {
                    {
                        scope_expression = {
                            rule = {
                                ["!"] = { var = 0 }
                            },
                            data = {
                                "customer"
                            }
                        },
                        httpMethods = {
                            "GET",
                            "POST",
                            "DELETE"
                        }
                    }
                }
            }
        },
        deny_by_default = true,
    })

    print "create a consumer"
    local res, err = sh_ex([[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=]], register_site_response.client_id, [[']])

    local consumer_response = JSON:decode(res)

    print "test with path /posts"
    local res, err = sh_ex([[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/posts --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])
    assert(res:lower():find("x-consumer-id: " .. string.lower(consumer_response.id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x%-oauth%-expiration: %d+"))

    print "test with path /comments"
    local res, err = sh_ex([[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/comments --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])
    assert(res:lower():find("x-consumer-id: " .. string.lower(consumer_response.id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x%-oauth%-expiration: %d+"))

    print "test with path /todos"
    local res, err = sh_ex([[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/todos --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])
    assert(res:lower():find("x-consumer-id: " .. string.lower(consumer_response.id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x%-oauth%-expiration: %d+"))

    print "test with path /todos, second time request, plugin shouldn't call oxd, must use cache"
    local res, err = sh_ex([[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/todos --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])
    assert(res:lower():find("x-consumer-id: " .. string.lower(consumer_response.id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x%-oauth%-expiration: %d+"))

    print "test with path /"
    local res, err = sh_ex([[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])
    assert(res:lower():find("x-consumer-id: " .. string.lower(consumer_response.id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x%-oauth%-expiration: %d+"))

    print "test with path /, second time request, plugin shouldn't call oxd, must use cache"
    local res, err = sh_ex([[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])
    assert(res:lower():find("x-consumer-id: " .. string.lower(consumer_response.id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x%-oauth%-expiration: %d+"))

    print "test with path /photos, not register then apply rules under path /. plugin shouldn't call oxd, must use cache because / path is already authenticated. "
    local res, err = sh_ex([[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/photos --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])
    assert(res:lower():find("x-consumer-id: " .. string.lower(consumer_response.id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x%-oauth%-expiration: %d+"))

    print "test with path /photos, second time request, plugin shouldn't call oxd, must use cache"
    local res, err = sh_ex([[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/photos --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])
    assert(res:lower():find("x-consumer-id: " .. string.lower(consumer_response.id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x%-oauth%-expiration: %d+"))

    print"check metrics"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_admin_port,
        [[/gluu-metrics]]
    )
    assert(res:lower():find(string.lower([[gluu_oauth_client_authenticated{consumer="]] .. register_site_response.client_id .. [[",service="]] .. create_service_response.name .. [["} 8]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_oauth_client_granted{consumer="]] .. register_site_response.client_id .. [[",service="]] .. create_service_response.name .. [["} 8]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_endpoint_method{endpoint="/",method="GET"]]), 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("JWT RS256", function()

    setup("oxd-model4.lua")

    local create_service_response = configure_service_route()

    print"test it works"
    sh([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    local register_site_response, access_token = configure_auth_plugin(create_service_response,{})

    configure_pep_plugin(register_site_response, create_service_response, {
        oauth_scope_expression = {},
        deny_by_default = false,
    })

    print"test it fail with 401 without token"
    local res, err = sh_ex([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])
    assert(res:find("401", 1, true))

    print"create a consumer"
    local res, err = sh_ex([[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=]], register_site_response.client_id, [[']]
    )

    local consumer_response = JSON:decode(res)

    print"test it work with token, consumer is registered"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )

    -- backend returns all headrs within body
    print"check that GG set all required upstream headers"
    assert(res:lower():find("x-consumer-id: " .. string.lower(consumer_response.id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x%-oauth%-expiration: %d+"))

    print"test it works with the same token again, oxd-model id completed, token taken from cache"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("check metrics client auth and grant", function()

    setup("oxd-model7.lua")

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

    local register_site_response, access_token = configure_auth_plugin(create_service_response,
        {});

    configure_pep_plugin(register_site_response, create_service_response, {

        oauth_scope_expression = {
            {
                path = "/posts",
                conditions = {
                    {
                        scope_expression = {
                            rule = {
                                ["and"] = {
                                    {
                                        var = 0
                                    },
                                    {
                                        var = 1
                                    }
                                }
                            },
                            data = {
                                "admin",
                                "employee"
                            }
                        },
                        httpMethods = {
                            "GET",
                            "DELETE",
                            "POST"
                        }
                    }
                }
            },
            {
                path = "/comments",
                conditions = {
                    {
                        scope_expression = {
                            rule = {
                                ["and"] = {
                                    {
                                        var = 0
                                    },
                                    {
                                        var = 1
                                    }
                                }
                            },
                            data = {
                                "customer"
                            }
                        },
                        httpMethods = {
                            "GET",
                            "POST",
                            "DELETE"
                        }
                    }
                }
            }
        },
        deny_by_default = true,
    })

    print "create a consumer"
    local res, err = sh_ex([[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=]], register_site_response.client_id, [[']])

    local consumer_response = JSON:decode(res)

    print "test with path /posts"
    local res, err = sh_ex([[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/posts --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])
    assert(res:lower():find("x-consumer-id: " .. string.lower(consumer_response.id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x%-oauth%-expiration: %d+"))

    print "test with path /posts"
    local res, err = sh_ex([[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/posts --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])
    assert(res:lower():find("x-consumer-id: " .. string.lower(consumer_response.id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x%-oauth%-expiration: %d+"))

    print"check metrics, client auth and grant should be same"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_admin_port,
        [[/gluu-metrics]]
    )
    assert(res:lower():find(string.lower([[gluu_oauth_client_authenticated{consumer="]] .. register_site_response.client_id .. [[",service="]] .. create_service_response.name .. [["} 2]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_oauth_client_granted{consumer="]] .. register_site_response.client_id .. [[",service="]] .. create_service_response.name .. [["} 2]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_endpoint_method{endpoint="/posts",method="GET"]]), 1, true))

    print "test with path /comments"
    local res, err = sh_ex([[curl -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/comments --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])
    assert(res:find("403", 1, true))

    print"check metrics, client is authenticated but grant fail"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_admin_port,
        [[/gluu-metrics]]
    )
    assert(res:lower():find(string.lower([[gluu_oauth_client_authenticated{consumer="]] .. register_site_response.client_id .. [[",service="]] .. create_service_response.name .. [["} 3]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_oauth_client_granted{consumer="]] .. register_site_response.client_id .. [[",service="]] .. create_service_response.name .. [["} 2]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_endpoint_method{endpoint="/posts",method="GET"]]), 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("2 different service with different clients", function()

    setup("oxd-model9.lua")

    local create_service_response = configure_service_route()

    print"test it works"
    sh([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    local register_site_response, access_token = configure_auth_plugin(create_service_response,{})

    configure_pep_plugin(register_site_response, create_service_response, {
        oauth_scope_expression = {
            {
                path = "/posts",
                conditions = {
                    {
                        scope_expression = {
                            rule = {
                                ["and"] = {
                                    {
                                        var = 0
                                    },
                                    {
                                        var = 1
                                    }
                                }
                            },
                            data = {
                                "admin",
                                "employee"
                            }
                        },
                        httpMethods = {
                            "GET",
                            "DELETE",
                            "POST"
                        }
                    }
                }
            }
        },
        deny_by_default = true
    })

    print"create a consumer"
    local res, err = sh_ex([[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=]], register_site_response.client_id, [[']]
    )

    local consumer_response = JSON:decode(res)

    local create_service_response2 = configure_service_route("demo-service2", "backend", "backend2.com")

    print"test it works"
    sh_ex([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend2.com']])

    local register_site_response2, access_token2 = configure_auth_plugin(create_service_response2,{})

    configure_pep_plugin(register_site_response2, create_service_response2, {
        oauth_scope_expression = {
            {
                path = "/todos",
                conditions = {
                    {
                        scope_expression = {
                            rule = {
                                ["and"] = {
                                    {
                                        var = 0
                                    },
                                    {
                                        var = 1
                                    }
                                }
                            },
                            data = {
                                "admin",
                                "employee"
                            }
                        },
                        httpMethods = {
                            "GET",
                            "DELETE",
                            "POST"
                        }
                    }
                }
            }
        },
        deny_by_default = true
    })

    print"create a consumer 2"
    local res, err = sh_ex([[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=]], register_site_response2.client_id, [[']]
    )

    local consumer_response2 = JSON:decode(res)

    print"test it work with token"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/posts --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )

    print"test second service works with token"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/todos --header 'Host: backend2.com' --header 'Authorization: Bearer ]],
        access_token2, [[']]
    )


    ctx.print_logs = false -- comment it out if want to see logs
end)
