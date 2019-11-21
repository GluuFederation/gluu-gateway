local utils = require"test_utils"
local sh, stdout, stderr, sleep, sh_ex, sh_until_ok =
utils.sh, utils.stdout, utils.stderr, utils.sleep, utils.sh_ex, utils.sh_until_ok

local kong_utils = require"kong_utils"
local JSON = require"JSON"

local host_git_root = os.getenv"HOST_GIT_ROOT"
local git_root = os.getenv"GIT_ROOT"
local test_root = host_git_root .. "/t/specs/gluu-oauth-auth"

-- finally() available only in current module environment
-- this is a hack to pass it to a functions in kong_utils
local function setup_db_less(model)
    kong_utils.setup_db_less(finally, test_root .. "/" .. model)
end

local function setup_postgress(model)
    kong_utils.setup_postgress(finally, test_root .. "/" .. model)
end

test("with, without token and metrics", function()

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
                name = "gluu-oauth-auth",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    custom_headers = {
                        { header_name = "x-consumer-id", value_lua_exp = "consumer.id", format = "string" },
                        { header_name = "x-oauth-client-id", value_lua_exp = "access_token.client_id", format = "string" },
                        { header_name = "x-consumer-custom-id", value_lua_exp = "access_token.client_id", format = "string" },
                        { header_name = "x-oauth-expiration", value_lua_exp = "access_token.exp", format = "string" },
                    },
                },
            },
            {
                name = "gluu-metrics",
            }
        },
        consumers = {
            {
                id = "a28a0f83-b619-4b58-94b3-e4ecaf8b6a2d",
                custom_id = register_site_response.client_id,
            }
        }
    }

    kong_utils.gg_db_less(kong_config)

    print"test it fail with 401 without token"
    local res, err = sh_ex([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])
    assert(res:find("401", 1, true))

    print"test it work with token, consumer is registered"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )

    -- backend returns all headrs within body
    print"check that GG set all required upstream headers"
    local consumer_id = assert(kong_config.consumers[1].id)
    assert(res:lower():find("x-consumer-id: " .. string.lower(consumer_id), 1, true))
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
    assert(res:lower():find(string.lower([[gluu_oauth_client_authenticated{consumer="]] .. register_site_response.client_id .. [[",service="demo-service"} 2]]), 1, true))
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
    assert(res:lower():find(string.lower([[gluu_oauth_client_authenticated{consumer="]] .. register_site_response.client_id .. [[",service="demo-service"} 2]]), 1, true))

    print"test it works with the same token again, oxd-model id completed, token taken from cache"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("Anonymous test and metrics", function()

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
                name = "gluu-oauth-auth",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    anonymous = "a28a0f83-b619-4b58-94b3-e4ecaf8b6a2d", -- must match consumer id below
                    custom_headers = { { header_name = "x-consumer-id", value_lua_exp = "consumer.id", format = "string" } },
                },
            },
            {
                name = "gluu-metrics",
            }
        },
        consumers = {
            {
                id = "a28a0f83-b619-4b58-94b3-e4ecaf8b6a2d",
                custom_id = "anonymous_123",
            }
        }
    }

    kong_utils.gg_db_less(kong_config)

    local res, err = sh_ex([[curl --fail -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer bla-bla']])
    assert(res:lower():find("x-consumer-id: " ..
            string.lower(kong_config.consumers[1].id), 1, true))

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

    setup_db_less("oxd-model1.lua")  -- yes, model1 should work

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
                name = "gluu-oauth-auth",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    pass_credentials = "hide",
                    custom_headers = {
                        { header_name = "x-consumer-id", value_lua_exp = "consumer.id", format = "string" },
                        { header_name = "x-oauth-client-id", value_lua_exp = "access_token.client_id", format = "string" },
                        { header_name = "x-consumer-custom-id", value_lua_exp = "access_token.client_id", format = "string" },
                        { header_name = "x-oauth-expiration", value_lua_exp = "access_token.exp", format = "string" },
                    },
                },
            },
            {
                name = "gluu-metrics",
            }
        },
        consumers = {
            {
                id = "a28a0f83-b619-4b58-94b3-e4ecaf8b6a2d",
                custom_id = register_site_response.client_id,
            }
        }
    }

    kong_utils.gg_db_less(kong_config)

    print"test with unprotected path"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/todos --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )
    assert(res:lower():find("x-consumer-id: " .. string.lower(kong_config.consumers[1].id), 1, true))
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
    assert(res:lower():find("x-consumer-id: " .. string.lower(kong_config.consumers[1].id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x%-oauth%-expiration: %d+"))
    assert.equal(nil, res:lower():find("authorization: "))

    print"check metrics"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_admin_port,
        [[/gluu-metrics]]
    )
    assert(res:lower():find(string.lower([[gluu_oauth_client_authenticated{consumer="]]
            .. register_site_response.client_id .. [[",service="demo-service"} 2]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_endpoint_method{endpoint="/todos",method="GET"]]), 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("rate limiter", function()
    -- we shall use a database for this test

    setup_postgress("oxd-model1.lua")

    local create_service_response = kong_utils.configure_service_route()

    print "Create a anonymous consumer"
    local ANONYMOUS_CONSUMER_CUSTOM_ID = "anonymous_123"
    local res, err = sh_ex(
        [[curl --fail -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/consumers/ --data 'custom_id=]], ANONYMOUS_CONSUMER_CUSTOM_ID, [[']])
    local anonymous_consumer_response = JSON:decode(res)

    print("anonymous_consumer_response.id: ", anonymous_consumer_response.id)

    local register_site_response, access_token = kong_utils.configure_oauth_auth_plugin(create_service_response,
        {
            anonymous = anonymous_consumer_response.id,
            custom_headers = {
                { header_name = "x-consumer-id", value_lua_exp = "consumer.id", format = "string" },
                { header_name = "x-oauth-client-id", value_lua_exp = "access_token.client_id", format = "string" },
                { header_name = "x-consumer-custom-id", value_lua_exp = "access_token.client_id", format = "string" },
                { header_name = "x-oauth-expiration", value_lua_exp = "access_token.exp", format = "string" },
                { header_name = "x-authenticated-scope", value_lua_exp = "access_token.scope", format = "list" },
            },
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
    local res, err = sh_ex([[curl -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/plugins --data "name=rate-limiting" --data "config.second=1" --data "config.limit_by=credential" ]],
        -- [[--data "consumer_id=]], consumer_response.id,
        [[ --data "config.policy=cluster" ]]
    )
    assert(err:find("HTTP/1.1 201", 1, true))
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
    local res, err = sh_ex([[curl -v -sS -X POST --url http://localhost:]],
        ctx.kong_admin_port, [[/plugins --data "name=rate-limiting" ]],
        [[ --data "config.second=1"  --data "config.policy=local" --data "config.limit_by=consumer" ]],
        [[ --data "consumer.id=]], consumer_response.id, [["]]
    )
    assert(err:find("HTTP/1.1 201", 1, true))
    local rate_limiting_consumer = JSON:decode(res)

    sleep(2)

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

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("consumer_mapping = false, allow anonymous access", function()

    setup_db_less("oxd-model1.lua")  -- yes, model1 should work

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
                name = "gluu-oauth-auth",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    consumer_mapping = false,
                    anonymous = "allow",
                    custom_headers = {
                        { header_name = "x-consumer-id", value_lua_exp = "consumer.id", format = "string" },
                        { header_name = "x-oauth-client-id", value_lua_exp = "access_token.client_id", format = "string" },
                        { header_name = "x-consumer-custom-id", value_lua_exp = "access_token.client_id", format = "string" },
                        { header_name = "x-oauth-expiration", value_lua_exp = "access_token.exp", format = "string" },
                        { header_name = "x-authenticated-scope", value_lua_exp = "access_token.scope", format = "list" },
                    },
                },
            },
        },
        consumers = {
            {
                custom_id = register_site_response.client_id,
            }
        }
    }

    kong_utils.gg_db_less(kong_config)

    print"test it work with token"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )

    -- backend returns all headrs within body
    print"check that GG set all required upstream headers"
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x%-oauth%-expiration: %d+"))
    assert(res:lower():find("x-authenticated-scope:", 1, true))
    -- TODO test comma separated list of scopes

    print"test it work without token"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' ]]
    )
    assert(not res:lower():find("x-oauth-client-id: " .. string.lower(register_site_response.client_id), 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("JWT RS256", function()

    setup_db_less("oxd-model4.lua")

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
                name = "gluu-oauth-auth",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    custom_headers = {
                        { header_name = "x-consumer-id", value_lua_exp = "consumer.id", format = "string" },
                        { header_name = "x-oauth-client-id", value_lua_exp = "access_token.client_id", format = "string" },
                        { header_name = "x-consumer-custom-id", value_lua_exp = "access_token.client_id", format = "string" },
                        { header_name = "x-oauth-expiration", value_lua_exp = "access_token.exp", format = "string" },
                        { header_name = "x-authenticated-scope", value_lua_exp = "access_token.scope", format = "list" },
                    },
                },
            },
        },
        consumers = {
            {
                id = "a28a0f83-b619-4b58-94b3-e4ecaf8b6a2d",
                custom_id = register_site_response.client_id,
            }
        }
    }

    kong_utils.gg_db_less(kong_config)

    print"test it fail with 401 without token"
    local res, err = sh_ex([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])
    assert(res:find("401", 1, true))

    print"test it work with token, consumer is registered"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )

    -- backend returns all headrs within body
    print"check that GG set all required upstream headers"
    assert(res:lower():find("x-consumer-id: " .. string.lower(kong_config.consumers[1].id), 1, true))
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

    setup_db_less("oxd-model5.lua")

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
                name = "gluu-oauth-auth",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    consumer_mapping = false,
                },
            },
        },
    }

    kong_utils.gg_db_less(kong_config)

    print"test it fail with 401 without token"
    local res, err = sh_ex([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])
    assert(res:find("401", 1, true))

    print"test it fail with 401"
    local res, err = sh_ex(
        [[curl -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )
    assert(res:find("401", 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("JWT alg mismatch", function()

    setup_db_less("oxd-model6.lua")

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
                name = "gluu-oauth-auth",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    consumer_mapping = false,
                },
            },
        },
    }

    kong_utils.gg_db_less(kong_config)


    print"test it fail with 401 without token"
    local res, err = sh_ex([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])
    assert(res:find("401", 1, true))

    print"test it fail with 401 with token"
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

if true then return end

test("JWT RS384", function()

    setup_db_less("oxd-model8.lua")

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
                name = "gluu-oauth-auth",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    custom_headers = {
                        { header_name = "x-consumer-id", value_lua_exp = "consumer.id", format = "string" },
                        { header_name = "x-oauth-client-id", value_lua_exp = "access_token.client_id", format = "string" },
                        { header_name = "x-consumer-custom-id", value_lua_exp = "access_token.client_id", format = "string" },
                        { header_name = "x-oauth-expiration", value_lua_exp = "access_token.exp", format = "string" },
                        { header_name = "x-authenticated-scope", value_lua_exp = "access_token.scope", format = "list" },
                    },
                },
            },
        },
        consumers = {
            {
                id = "a28a0f83-b619-4b58-94b3-e4ecaf8b6a2d",
                custom_id = register_site_response.client_id,
            }
        }
    }
    kong_utils.gg_db_less(kong_config)

    print "test it fail with 401 without token"
    local res, err = sh_ex([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])
    assert(res:find("401", 1, true))

    print "test it work with token, consumer is registered"
    local res, err = sh_ex([[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])

    -- backend returns all headrs within body
    print "check that GG set all required upstream headers"
    assert(res:lower():find("x-consumer-id: " .. string.lower(kong_config.consumers[1].id), 1, true))
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

    setup_db_less("oxd-model9.lua")

    local register_site_response, access_token = kong_utils.register_site_get_client_token()
    local register_site_response2, access_token2 = kong_utils.register_site_get_client_token()

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
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                },
            },
            {
                name = "gluu-oauth-auth",
                service = "demo-service2",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response2.client_id,
                    client_secret = register_site_response2.client_secret,
                    oxd_id = register_site_response2.oxd_id,
                },
            },
        },
        consumers = {
            {
                custom_id = register_site_response.client_id,
            },
            {
                custom_id = register_site_response2.client_id,
            }
        }
    }

    kong_utils.gg_db_less(kong_config)

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
                name = "gluu-oauth-auth",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    pass_credentials = "phantom_token",
                    custom_headers = {
                        { header_name = "x-consumer-id", value_lua_exp = "consumer.id", format = "string" },
                        { header_name = "x-oauth-client-id", value_lua_exp = "access_token.client_id", format = "string" },
                        { header_name = "x-consumer-custom-id", value_lua_exp = "access_token.client_id", format = "string" },
                        { header_name = "x-oauth-expiration", value_lua_exp = "access_token.exp", format = "string" },
                        { header_name = "x-authenticated-scope", value_lua_exp = "access_token.scope", format = "list" },
                    },
                },
            },
        },
        consumers = {
            {
                id = "a28a0f83-b619-4b58-94b3-e4ecaf8b6a2d",
                custom_id = register_site_response.client_id,
            }
        }
    }

    kong_utils.gg_db_less(kong_config)

    print"test it work with token, consumer is registered"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )

    print"check headers, auth header should not have requsted bearer token"
    assert.equal(nil, res:lower():find("authorization: Bearer " .. access_token))
    assert(res:lower():find("x-consumer-id: " .. string.lower(kong_config.consumers[1].id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(kong_config.consumers[1].custom_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(kong_config.consumers[1].custom_id), 1, true))

    print"second time call"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )
    assert.equal(nil, res:lower():find("authorization: Bearer " .. access_token))
    assert(res:lower():find("x-consumer-id: " .. string.lower(kong_config.consumers[1].id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(kong_config.consumers[1].custom_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(kong_config.consumers[1].custom_id), 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("Test Headers", function()

    setup("oxd-model1.lua")

    local create_service_response = configure_service_route()

    print"test it works"
    sh([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    local register_site_response, access_token = configure_plugin(create_service_response,{
        custom_headers = {
            {header_name = "KONG_access_token_jwt", value_lua_exp = "access_token", format = "jwt"},
            {header_name = "KONG_access_token_{*}", value_lua_exp = "access_token", format = "string", iterate = true},
            {header_name = "KONG_access_token_scope_v", value_lua_exp = "access_token.scope", format = "list"},
            {header_name = "KONG_consumer_jwt", value_lua_exp = "consumer", format = "jwt"},
            {header_name = "KONG_consumer_{*}", value_lua_exp = "consumer", format = "string", iterate = true},
            {header_name = "http_kong_api_version", value_lua_exp = "\"version 1.0\"", format = "urlencoded"},
        },
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
    assert(res:find("200", 1, true))
    local headers = {"kong-access-token-jwt", "kong-consumer-jwt", "kong-consumer-created-at", "kong-access-token-username", "kong-access-token-exp", "kong-consumer-id", "kong-access-token-consumer", "kong-access-token-aud", "kong-access-token-client-id", "kong-access-token-scope-v", "kong-access-token-active", "kong-consumer-custom-id", "kong-access-token-scope", "http-kong-api-version", "kong-access-token-iss", "kong-access-token-token-type", "kong-access-token-iat"}
    for i = 1, #headers do
        assert(res:find(headers[i], 1, true))
    end

    print"second time call"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )
    assert.equal(nil, res:lower():find("authorization: Bearer " .. access_token))
    assert(res:find("200", 1, true))
    for i = 1, #headers do
        assert(res:find(headers[i], 1, true))
    end

    ctx.print_logs = false -- comment it out if want to see logs
end)
