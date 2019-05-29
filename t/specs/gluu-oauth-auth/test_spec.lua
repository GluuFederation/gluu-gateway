local utils = require"test_utils"
local sh, stdout, stderr, sleep, sh_ex, sh_until_ok =
utils.sh, utils.stdout, utils.stderr, utils.sleep, utils.sh_ex, utils.sh_until_ok

local kong_utils = require"kong_utils"
local JSON = require"JSON"

local host_git_root = os.getenv"HOST_GIT_ROOT"
local git_root = os.getenv"GIT_ROOT"
local test_root = host_git_root .. "/t/specs/gluu-oauth-auth"

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
            ["gluu-metrics"] = host_git_root .. "/kong/plugins/gluu-metrics",
        },
        modules = {
            ["prometheus.lua"] = host_git_root .. "/third-party/nginx-lua-prometheus/prometheus.lua",
            ["gluu/oxdweb.lua"] = host_git_root .. "/third-party/oxd-web-lua/oxdweb.lua",
            ["gluu/kong-common.lua"] = host_git_root .. "/kong/common/kong-common.lua",
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
    sh([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    print "configure gluu-metrics plugin for the Service"
    local _, _ = sh_ex([[
        curl --fail -i -sS -X POST  --url http://localhost:]], ctx.kong_admin_port,
        [[/plugins/ --data 'name=gluu-metrics' --data 'service_id=]], create_service_response.id, [[']]
    )

    local register_site_response, access_token = configure_plugin(create_service_response,{})

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

    print"test it fail with 401 with wrong Bearer token"
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

test("Anonymous test and metrics", function()

    setup("oxd-model2.lua")

    local create_service_response = configure_service_route()

    print "configure gluu-metrics plugin for the Service"
    local _, _ = sh_ex([[
        curl --fail -i -sS -X POST  --url http://localhost:]], ctx.kong_admin_port,
        [[/plugins/ --data 'name=gluu-metrics' --data 'service_id=]], create_service_response.id, [[']]
    )

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

    print"check metrics, it should not return gluu_oauth_client_authenticated"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_admin_port,
        [[/gluu-metrics]]
    )
    assert(res:lower():find("gluu_oauth_client_authenticated", 1, true) == nil)
    assert(res:lower():find(string.lower([[gluu_endpoint_method{endpoint="/",method="GET"]]), 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("pass_credentials = hide and metrics", function()

    setup("oxd-model1.lua") -- yes, model1 should work

    local create_service_response = configure_service_route()

    print "configure gluu-metrics plugin for the Service"
    local _, _ = sh_ex([[
        curl --fail -i -sS -X POST  --url http://localhost:]], ctx.kong_admin_port,
        [[/plugins/ --data 'name=gluu-metrics' --data 'service_id=]], create_service_response.id, [[']]
    )

    print"test it works"
    sh([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    local register_site_response, access_token = configure_plugin(create_service_response,
        {
            pass_credentials = "hide"
        }
    )

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

    print"check metrics"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_admin_port,
        [[/gluu-metrics]]
    )
    assert(res:lower():find(string.lower([[gluu_oauth_client_authenticated{consumer="]] .. register_site_response.client_id .. [[",service="]] .. create_service_response.name .. [["} 2]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_endpoint_method{endpoint="/",method="GET"]]), 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("rate limiter", function()

    setup("oxd-model1.lua")

    local create_service_response = configure_service_route()

    print "Create a anonymous consumer"
    local ANONYMOUS_CONSUMER_CUSTOM_ID = "anonymous_123"
    local res, err = sh_ex(
        [[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=]], ANONYMOUS_CONSUMER_CUSTOM_ID, [[']])
    local anonymous_consumer_response = JSON:decode(res)

    print("anonymous_consumer_response.id: ", anonymous_consumer_response.id)

    local register_site_response, access_token = configure_plugin(create_service_response,
        {
            anonymous = anonymous_consumer_response.id,
        }
    )

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
    assert(res:lower():find("x-authenticated-scope:", 1, true))
    -- TODO test comma separated list of scopes

    print"configure rate-limiting global plugin"
    local res, err = sh_ex([[curl -v --fail -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/plugins --data "name=rate-limiting" --data "config.second=1" --data "config.limit_by=consumer" ]],
        -- [[--data "consumer_id=]], consumer_response.id,
        [[ --data "config.policy=local" ]]
    )
    local rate_limiting_global = JSON:decode(res)

    print"test it work with token first time"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )
    print"it may be blocked by rate limiter"
    local res1, err = sh_ex(
        [[curl -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )

    print"it may be blocked by rate limiter"
    local res2, err = sh_ex(
        [[curl -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )
    -- at least one requests of two requests above must be blocker by rate limiter
    assert(res1:find("API rate limit exceeded", 1, true) or res2:find("API rate limit exceeded", 1, true))
    -- if we are here global plugin works

    print"remove rate-limiting global plugin"
    local res, err = sh_ex([[curl -v --fail -sS -X DELETE --url http://localhost:]],
        ctx.kong_admin_port, [[/plugins/]], rate_limiting_global.id
    )

    print"configure rate limiting plugin for a consumer"
    local res, err = sh_ex([[curl -v --fail -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/plugins --data "name=rate-limiting" ]],
        [[ --data "config.second=1"  --data "config.policy=local" --data "config.limit_by=consumer" ]],
        [[ --data "consumer_id=]], consumer_response.id, [["]]
    )
    local rate_limiting_consumer = JSON:decode(res)

    sleep(2) -- TODO is it required?!

    print"test it work with token first time"
    local res, err = sh_ex(
        [[curl -i --fail -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )
    print"it may be blocked by rate limiter"
    local res1, err = sh_ex(
        [[curl -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )

    print"anonymous, should work without limitation"
    for i = 1, 3 do
        local res, err = sh_ex(
            [[curl -i --fail -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
            [[/ --header 'Host: backend.com' ]]
        )
    end

    print"it may be blocked by rate limiter"
    local res2, err = sh_ex(
        [[curl -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )
    -- at least one requests of two requests above must be blocker by rate limiter
    assert(res1:find("API rate limit exceeded", 1, true) or res2:find("API rate limit exceeded", 1, true))
    -- if we are here global plugin works

    --ctx.print_logs = false -- comment it out if want to see logs
end)

test("JWT RS256", function()

    setup("oxd-model4.lua")

    local create_service_response = configure_service_route()

    print"test it works"
    sh([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    local register_site_response, access_token = configure_plugin(create_service_response,{})

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

test("JWT none alg fail", function()

    setup("oxd-model5.lua")

    local create_service_response = configure_service_route()

    print"test it works"
    sh([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    local register_site_response, access_token = configure_plugin(create_service_response,{})

    print"test it fail with 401 without token"
    local res, err = sh_ex([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])
    assert(res:find("401", 1, true))

    print"create a consumer"
    local res, err = sh_ex([[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=]], register_site_response.client_id, [[']]
    )

    local consumer_response = JSON:decode(res)

    print"test it fail with 401"
    local res, err = sh_ex(
        [[curl -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )
    assert(res:find("401", 1, true))

    --ctx.print_logs = false -- comment it out if want to see logs
end)

test("JWT alg mismatch", function()

    setup("oxd-model6.lua")

    local create_service_response = configure_service_route()

    print"test it works"
    sh([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    local register_site_response, access_token = configure_plugin(create_service_response,{})

    print"test it fail with 401 without token"
    local res, err = sh_ex([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])
    assert(res:find("401", 1, true))

    print"create a consumer"
    local res, err = sh_ex([[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=]], register_site_response.client_id, [[']]
    )

    local consumer_response = JSON:decode(res)

    print"test it fail with 401 without token"
    local res, err = sh_ex(
        [[curl -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )
    assert(res:find("401", 1, true))

    local res = stderr("docker logs ", ctx.kong_id)
    assert(res:find("mismatch", 1, true))
    assert(not res:find("[error]",1, true))


    ctx.print_logs = false -- comment it out if want to see logs
end)

test("JWT RS384", function()

    setup("oxd-model8.lua")

    local create_service_response = configure_service_route()

    print "test it works"
    sh([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    local register_site_response, access_token = configure_plugin(create_service_response,{})

    print "test it fail with 401 without token"
    local res, err = sh_ex([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])
    assert(res:find("401", 1, true))

    print "create a consumer"
    local res, err = sh_ex([[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=]], register_site_response.client_id, [[']])

    local consumer_response = JSON:decode(res)

    print "test it work with token, consumer is registered"
    local res, err = sh_ex([[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])

    -- backend returns all headrs within body
    print "check that GG set all required upstream headers"
    assert(res:lower():find("x-consumer-id: " .. string.lower(consumer_response.id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x%-oauth%-expiration: %d+"))

    print "test it works with the same token again, oxd-model id completed, token taken from cache"
    local res, err = sh_ex([[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("2 different service with different clients", function()

    setup("oxd-model9.lua")

    local create_service_response = configure_service_route()

    print"test it works"
    sh([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    local register_site_response, access_token = configure_plugin(create_service_response,{})

    print"create a consumer"
    local res, err = sh_ex([[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=]], register_site_response.client_id, [[']]
    )

    local consumer_response = JSON:decode(res)

    local create_service_response2 = configure_service_route("demo-service2", "backend", "backend2.com")

    print"test it works"
    sh_ex([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend2.com']])

    local register_site_response2, access_token2 = configure_plugin(create_service_response2,{})

    print"create a consumer 2"
    local res, err = sh_ex([[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=]], register_site_response2.client_id, [[']]
    )

    local consumer_response2 = JSON:decode(res)

    print"test it work with token"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )

    print"test second service works with token"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend2.com' --header 'Authorization: Bearer ]],
        access_token2, [[']]
    )

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("Test phantom token", function()

    setup("oxd-model1.lua")

    local create_service_response = configure_service_route()

    print"test it works"
    sh([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    local register_site_response, access_token = configure_plugin(create_service_response,{
        pass_credentials = "phantom_token",
    })

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

    print"check headers, auth header should not have requsted bearer token"
    assert.equal(nil, res:lower():find("authorization: Bearer " .. access_token))
    assert(res:lower():find("x-consumer-id: " .. string.lower(consumer_response.id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(consumer_response.custom_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(consumer_response.custom_id), 1, true))

    print"second time call"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )
    assert.equal(nil, res:lower():find("authorization: Bearer " .. access_token))
    assert(res:lower():find("x-consumer-id: " .. string.lower(consumer_response.id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(consumer_response.custom_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(consumer_response.custom_id), 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)
