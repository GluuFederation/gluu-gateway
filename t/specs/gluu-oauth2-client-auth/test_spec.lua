local utils = require"test_utils"
local sh, stdout, stderr, sleep, sh_ex, sh_until_ok =
utils.sh, utils.stdout, utils.stderr, utils.sleep, utils.sh_ex, utils.sh_until_ok

local kong_utils = require"kong_utils"
local JSON = require"JSON"

local host_git_root = os.getenv"HOST_GIT_ROOT"
local git_root = os.getenv"GIT_ROOT"
local test_root = host_git_root .. "/t/specs/gluu-oauth2-client-auth"

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
            ["gluu-oauth2-client-auth"] = host_git_root .. "/gluu-oauth2-client-auth/kong/plugins/gluu-oauth2-client-auth",
        },
        modules = {
            ["oxdweb.lua"] = host_git_root .. "/third-party/oxd-web-lua/oxdweb.lua",
            ["resty/lrucache.lua"] = host_git_root .. "/third-party/lua-resty-lrucache/lib/resty/lrucache.lua",
            ["resty/lrucache/pureffi.lua"] = host_git_root .. "/third-party/lua-resty-lrucache/lib/resty/lrucache/pureffi.lua",
            ["rucciva/json_logic.lua"] = host_git_root .. "/third-party/json-logic-lua/logic.lua",
        }
    }
    kong_utils.backend()
    kong_utils.oxd_mock(test_root .. "/" .. model)
end

local function configure_service_route()
    print"create a Sevice"
    local res, err = sh_until_ok(10,
        [[curl --fail -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/services/ --header 'content-type: application/json' --data '{"name":"demo-service","url":"http://backend"}']]
    )

    local create_service_response = JSON:decode(res)

    print"create a Route"
    local res, err = sh_until_ok(10,
        [[curl --fail -i -sS -X POST  --url http://localhost:]],
        ctx.kong_admin_port, [[/services/demo-service/routes --data 'hosts[]=backend.com']]
    )

    return create_service_response
end

local function configure_plugin(create_service_response, plugin_config)
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
        name = "gluu-oauth2-client-auth",
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

test("with and without token", function()

    setup("oxd-model1.lua")

    local create_service_response = configure_service_route()

    print"test it works"
    sh([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    local register_site_response, access_token = configure_plugin(create_service_response,
        {
            oauth_scope_expression = {},
            allow_oauth_scope_expression = false,
        }
    )

    print"test it fail with 401 without token"
    local res, err = sh_ex([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])
    assert(res:find("401"), 1, true)

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

    print"test it fail with 403 with wrong Bearer token"
    local res, err = sh_ex(
        [[curl -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer bla-bla']]
    )
    assert(res:find("401"))

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

    configure_plugin(create_service_response,
        {
            anonymous = anonymous_consumer_response.id,
        }
    )

    sleep(1)

    local res, err = sh_ex([[curl --fail -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer bla-bla']])
    assert(res:lower():find("x-consumer-id: " .. string.lower(anonymous_consumer_response.id), 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)


test("allow_unprotected_path = false", function()

    setup("oxd-model1.lua") -- yes, model1 should work

    local create_service_response = configure_service_route()

    print"test it works"
    sh([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    local register_site_response, access_token = configure_plugin(create_service_response,
        {
            oauth_scope_expression = {},
            allow_oauth_scope_expression = true,
            allow_unprotected_path = false,
        }
    )

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
    assert(res:find("403"), 1, true)

    ctx.print_logs = false -- comment it out if want to see logs
end)


test("allow_unprotected_path = true", function()

    setup("oxd-model1.lua") -- yes, model1 should work

    local create_service_response = configure_service_route()

    print"test it works"
    sh([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    local register_site_response, access_token = configure_plugin(create_service_response,
        {
            oauth_scope_expression = {},
            allow_oauth_scope_expression = true,
            allow_unprotected_path = true,
        }
    )

    print"create a consumer"
    local res, err = sh_ex([[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=]], register_site_response.client_id, [[']]
    )

    local consumer_response = JSON:decode(res)

    print"test it work"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("check oauth_scope_expression", function()

    setup("oxd-model3.lua")

    local create_service_response = configure_service_route()

    print "test it works"
    sh([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    local register_site_response, access_token = configure_plugin(create_service_response,
        {
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
            allow_oauth_scope_expression = true,
            allow_unprotected_path = false,
        });

    print "create a consumer"
    local res, err = sh_ex([[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=]], register_site_response.client_id, [[']])

    local consumer_response = JSON:decode(res)

    print "test it work"
    print "test with path /posts"
    local res, err = sh_ex([[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/posts --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])

    print "test with path /comments"
    local res, err = sh_ex([[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/comments --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])

    print "test with path /todos"
    local res, err = sh_ex([[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/todos --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])

    -- ctx.print_logs = false -- comment it out if want to see logs
end)
