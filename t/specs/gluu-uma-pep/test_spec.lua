local utils = require"test_utils"
local sh, stdout, stderr, sleep, sh_ex, sh_until_ok =
utils.sh, utils.stdout, utils.stderr, utils.sleep, utils.sh_ex, utils.sh_until_ok

local kong_utils = require"kong_utils"
local JSON = require"JSON"

local host_git_root = os.getenv"HOST_GIT_ROOT"
local git_root = os.getenv"GIT_ROOT"
local test_root = host_git_root .. "/t/specs/gluu-uma-pep"

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
            ["gluu-uma-pep"] = host_git_root .. "/kong/plugins/gluu-uma-pep",
            ["gluu-uma-auth"] = host_git_root .. "/kong/plugins/gluu-uma-auth",
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
            ["resty/jwt.lua"] = host_git_root .. "/third-party/lua-resty-jwt/lib/resty/jwt.lua",
            ["resty/evp.lua"] = host_git_root .. "/third-party/lua-resty-jwt/lib/resty/evp.lua",
            ["resty/jwt-validators.lua"] = host_git_root .. "/third-party/lua-resty-jwt/lib/resty/jwt-validators.lua",
            ["resty/hmac.lua"] = host_git_root .. "/third-party/lua-resty-hmac/lib/resty/hmac.lua",
            ["resty/session.lua"] = host_git_root .. "/third-party/lua-resty-session/lib/resty/session.lua",
            ["resty/session/ciphers/aes.lua"] = host_git_root .. "/third-party/lua-resty-session/lib/resty/session/ciphers/aes.lua",
            ["resty/session/encoders/base64.lua"] = host_git_root .. "/third-party/lua-resty-session/lib/resty/session/encoders/base64.lua",
            ["resty/session/hmac/sha1.lua"] = host_git_root .. "/third-party/lua-resty-session/lib/resty/session/hmac/sha1.lua",
            ["resty/session/identifiers/random.lua"] = host_git_root .. "/third-party/lua-resty-session/lib/resty/session/identifiers/random.lua",
            ["resty/session/serializers/json.lua"] = host_git_root .. "/third-party/lua-resty-session/lib/resty/session/serializers/json.lua",
            ["resty/session/storage/cookie.lua"] = host_git_root .. "/third-party/lua-resty-session/lib/resty/session/storage/cookie.lua",
            ["resty/session/strategies/default.lua"] = host_git_root .. "/third-party/lua-resty-session/lib/resty/session/strategies/default.lua",
        },
        host_git_root = host_git_root,
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

local function configure_pep_plugin(register_site_response, create_service_response, plugin_config, consumer_id)
    if plugin_config.uma_scope_expression then
        plugin_config.uma_scope_expression = JSON:encode(plugin_config.uma_scope_expression)
    end

    plugin_config.op_url = "http://stub"
    plugin_config.oxd_url = "http://oxd-mock"
    plugin_config.client_id = register_site_response.client_id
    plugin_config.client_secret = register_site_response.client_secret
    plugin_config.oxd_id = register_site_response.oxd_id

    local payload = {
        name = "gluu-uma-pep",
        config = plugin_config,
        service = { id = create_service_response.id},
    }

    if consumer_id then
        payload.consumer_id = consumer_id
    end

    local payload_json = JSON:encode(payload)

    print"enable plugin for the Service"
    local res, err = sh_ex([[
        curl --fail -v -i -sS -X POST  --url http://localhost:]], ctx.kong_admin_port,
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
        name = "gluu-uma-auth",
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

    return register_site_response, response.access_token
end

test("with and without token, metrics, uma-auth and check UMA scope", function()
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

    print "create an anonymous consumer for uma-auth"
    local anonymous_consumer = "qwertyuiop"
    local res, err = sh_ex([[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=]], anonymous_consumer, [[']])
    local consumer_response = JSON:decode(res)

    local register_site_response, access_token = configure_auth_plugin(create_service_response,{
        anonymous = consumer_response.id
    })

    configure_pep_plugin(register_site_response, create_service_response,
        {
            uma_scope_expression = {
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
            }
        }
    )

    print "create a consumer"
    local res, err = sh_ex([[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=]], register_site_response.client_id, [[']])

    local consumer_response = JSON:decode(res)

    local stdout, _ = sh_ex([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])
    assert(stdout:find("401", 1, true))
    assert(stdout:find("ticket", 1, true))

    local stdout, stderr = sh_ex([[curl -v --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com' --header 'Authorization: Bearer 1234567890']])
    assert(stdout:lower():find("x-consumer-id: " .. string.lower(consumer_response.id), 1, true))
    assert(stdout:lower():find("x-oauth-client-id: " .. string.lower(consumer_response.custom_id), 1, true))
    assert(stdout:lower():find("x-consumer-custom-id: " .. string.lower(consumer_response.custom_id), 1, true))
    assert(stdout:lower():find("x%-rpt%-expiration: %d+"))

    -- plugin shouldn't call oxd, must use cache
    local stdout, stderr = sh_ex([[curl -v --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com' --header 'Authorization: Bearer 1234567890']])
    assert(stdout:lower():find("x-consumer-id: " .. string.lower(consumer_response.id), 1, true))
    assert(stdout:lower():find("x-oauth-client-id: " .. string.lower(consumer_response.custom_id), 1, true))
    assert(stdout:lower():find("x-consumer-custom-id: " .. string.lower(consumer_response.custom_id), 1, true))
    assert(stdout:lower():find("x%-rpt%-expiration: %d+"))

    print"check metrics, it should return gluu_client_authenticated = 2"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_admin_port,
        [[/gluu-metrics]]
    )
    assert(res:lower():find("gluu_uma_client_granted", 1, true))
    assert(res:lower():find(string.lower([[gluu_uma_client_granted{consumer="]] .. register_site_response.client_id .. [[",service="]] .. create_service_response.name .. [["} 2]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_uma_client_authenticated{consumer="]] .. register_site_response.client_id .. [[",service="]] .. create_service_response.name .. [["} 2]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_endpoint_method{endpoint="/",method="GET"]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_uma_ticket{service="]] .. create_service_response.name .. [["} 1]]), 1, true))

    -- posts: request with wrong token
    local stdout, _ = sh_ex([[curl -i -sS -X POST --url http://localhost:]],
        ctx.kong_proxy_port, [[/posts --header 'Host: backend.com' --header 'Authorization: Bearer POSTS_INVALID_1234567890']])
    assert(stdout:find("401", 1, true))

    -- posts: request
    local stdout, _ = sh_ex([[curl -v --fail -sS -X POST --url http://localhost:]],
        ctx.kong_proxy_port, [[/posts --header 'Host: backend.com' --header 'Authorization: Bearer POSTS1234567890']])
    assert(stdout:lower():find("x-consumer-id: " .. string.lower(consumer_response.id), 1, true))
    assert(stdout:lower():find("x-oauth-client-id: " .. string.lower(consumer_response.custom_id), 1, true))
    assert(stdout:lower():find("x-consumer-custom-id: " .. string.lower(consumer_response.custom_id), 1, true))
    assert(stdout:lower():find("x%-rpt%-expiration: %d+"))

    -- posts: plugin shouldn't call oxd, must use cache
    local stdout, _ = sh_ex([[curl -v --fail -sS -X POST --url http://localhost:]],
        ctx.kong_proxy_port, [[/posts --header 'Host: backend.com' --header 'Authorization: Bearer POSTS1234567890']])
    assert(stdout:lower():find("x-consumer-id: " .. string.lower(consumer_response.id), 1, true))
    assert(stdout:lower():find("x-oauth-client-id: " .. string.lower(consumer_response.custom_id), 1, true))
    assert(stdout:lower():find("x-consumer-custom-id: " .. string.lower(consumer_response.custom_id), 1, true))
    assert(stdout:lower():find("x%-rpt%-expiration: %d+"))

    print"Check metrics for client authentication, it should return count 4 because client auth failed"
    local res, err = sh_ex(
        [[curl -i -sS  -X GET --url http://localhost:]], ctx.kong_admin_port,
        [[/gluu-metrics]]
    )
    assert(res:lower():find("gluu_uma_client_granted", 1, true))
    assert(res:lower():find(string.lower([[gluu_uma_client_granted{consumer="]] .. register_site_response.client_id .. [[",service="]] .. create_service_response.name .. [["} 4]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_uma_client_authenticated{consumer="]] .. register_site_response.client_id .. [[",service="]] .. create_service_response.name .. [["} 4]]), 1, true))

    -- todos: not register then apply rules under path / with same token `1234567890`
    local stdout, _ = sh_ex([[curl -v --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/todos --header 'Host: backend.com' --header 'Authorization: Bearer 1234567890']])
    assert(stdout:lower():find("x-consumer-id: " .. string.lower(consumer_response.id), 1, true))
    assert(stdout:lower():find("x-oauth-client-id: " .. string.lower(consumer_response.custom_id), 1, true))
    assert(stdout:lower():find("x-consumer-custom-id: " .. string.lower(consumer_response.custom_id), 1, true))
    assert(stdout:lower():find("x%-rpt%-expiration: %d+"))

    print"GET to the same path but with another already cached token"
    local stdout, _ = sh_ex([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/todos --header 'Host: backend.com' --header 'Authorization: Bearer POSTS1234567890']])
    assert(stdout:find("403", 1, true))

    ctx.print_logs = false
end)

test("deny_by_default = true, uma-auth", function()

    setup("oxd-model2.lua")
    local create_service_response = configure_service_route()

    print "test it works"
    sh([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    print "create an anonymous consumer for uma-auth"
    local anonymous_consumer = "qwertyuiop"
    local res, err = sh_ex([[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=]], anonymous_consumer, [[']])
    local consumer_response = JSON:decode(res)

    local register_site_response, access_token = configure_auth_plugin(create_service_response,{
        anonymous = consumer_response.id
    })

    configure_pep_plugin(register_site_response, create_service_response,
        {
            uma_scope_expression = {
                {
                    path = "/posts",
                    conditions = {
                        {
                            httpMethods = { "GET" },
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
    setup("oxd-model2.lua")

    local create_service_response = configure_service_route()

    print "create an anonymous consumer for uma-auth"
    local anonymous_consumer = "qwertyuiop"
    local res, err = sh_ex([[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=]], anonymous_consumer, [[']])
    local consumer_response = JSON:decode(res)

    local register_site_response, access_token = configure_auth_plugin(create_service_response,{
        anonymous = consumer_response.id,
        pass_credentials = "hide"
    })

    configure_pep_plugin(register_site_response, create_service_response,
        {
            uma_scope_expression = {
                {
                    path = "/posts",
                    conditions = {
                        {
                            httpMethods = {"GET"},
                        }
                    }
                }
            },
            deny_by_default = false,
        }
    )

    print "create a consumer"
    local res, err = sh_ex([[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=]], register_site_response.client_id, [[']])

    local consumer_response = JSON:decode(res)

    -- posts: request to protected path
    local stdout, _ = sh_ex([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/posts --header 'Host: backend.com']])
    assert(stdout:find("401", 1, true))
    assert(stdout:find("ticket", 1, true))

    -- posts: request and check hide_credential
    local stdout, _ = sh_ex([[curl -v --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/posts --header 'Host: backend.com' --header 'Authorization: Bearer 1234567890']])
    assert.equal(nil, stdout:lower():find("authorization: "))
    assert(stdout:lower():find("x-consumer-id: " .. string.lower(consumer_response.id), 1, true))
    assert(stdout:lower():find("x-oauth-client-id: " .. string.lower(consumer_response.custom_id), 1, true))
    assert(stdout:lower():find("x-consumer-custom-id: " .. string.lower(consumer_response.custom_id), 1, true))
    assert(stdout:lower():find("x%-rpt%-expiration: %d+"))

    -- ensure no authorization headers is sent to backend
    -- backend responds in lowecase, so we may distinguish from request's header in curl output
    assert(not stdout:lower():find("authorization: : Bearer"))

    -- plugin shouldn't call oxd, must use cache
    local stdout, _ = sh_ex([[curl -v --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/posts --header 'Host: backend.com' --header 'Authorization: Bearer 1234567890']])
    assert.equal(nil, stdout:lower():find("authorization: "))
    assert(stdout:lower():find("x-consumer-id: " .. string.lower(consumer_response.id), 1, true))
    assert(stdout:lower():find("x-oauth-client-id: " .. string.lower(consumer_response.custom_id), 1, true))
    assert(stdout:lower():find("x-consumer-custom-id: " .. string.lower(consumer_response.custom_id), 1, true))
    assert(stdout:lower():find("x%-rpt%-expiration: %d+"))

    -- /todos: request to not protected
    local res, err = sh_ex(
        [[curl -v --fail -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/todos --header 'Host: backend.com' --header 'Authorization: Bearer 1234567890']]
    )

    ctx.print_logs = false -- comment it out if want to see logs
end)
