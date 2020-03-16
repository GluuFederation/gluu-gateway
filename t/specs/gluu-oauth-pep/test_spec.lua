local utils = require"test_utils"
local sh, stdout, stderr, sleep, sh_ex, sh_until_ok =
utils.sh, utils.stdout, utils.stderr, utils.sleep, utils.sh_ex, utils.sh_until_ok

local kong_utils = require"kong_utils"
local JSON = require"JSON"

local host_git_root = os.getenv"HOST_GIT_ROOT"
local git_root = os.getenv"GIT_ROOT"
local test_root = host_git_root .. "/t/specs/gluu-oauth-pep"

-- finally() available only in current module environment
-- this is a hack to pass it to a functions in kong_utils
local function setup_db_less(model)
    kong_utils.setup_db_less(finally, model and (test_root .. "/" .. model) or nil)
end

local function setup_postgress(model)
    kong_utils.setup_postgress(finally, model and (test_root .. "/" .. model) or nil)
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
                        { header_name = "x-oauth-client-id", value_lua_exp = "introspect_data.client_id", format = "string" },
                        { header_name = "x-consumer-custom-id", value_lua_exp = "introspect_data.client_id", format = "string" },
                        { header_name = "x-oauth-expiration", value_lua_exp = "introspect_data.exp", format = "string" },
                        { header_name = "x-authenticated-scope", value_lua_exp = "introspect_data.scope", format = "list" },
                    },
                },
            },
            {
                name = "gluu-oauth-pep",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    deny_by_default = false,
                    oauth_scope_expression = JSON:encode{
                        {
                            path = "/todos",
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
    assert(res:lower():find(string.lower([[gluu_oauth_client_authenticated{consumer="]]
            .. register_site_response.client_id .. [[",service="demo-service"} 2]]), 1, true))
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
    assert(res:lower():find(string.lower([[gluu_oauth_client_authenticated{consumer="]]
            .. register_site_response.client_id .. [[",service="demo-service"} 2]]), 1, true))

    print"test it works with the same token again, oxd-model id completed, token taken from cache"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']]
    )

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("Anonymous test", function()

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
                    anonymous = "a28a0f83-b619-4b58-94b3-e4ecaf8b6a2d",
                },
            },
            {
                name = "gluu-oauth-pep",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    deny_by_default = false,
                    oauth_scope_expression = JSON:encode{
                        {
                            path = "/todos",
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
                id = "a28a0f83-b619-4b58-94b3-e4ecaf8b6a2d",
                custom_id = "anonymous_123",
            }
        }
    }

    kong_utils.gg_db_less(kong_config)

    print"Allow access, deny_by_default = false"
    local res, err = sh_ex([[curl -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer bla-bla']])
    assert(res:find("200"))

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("deny_by_default = true and metrics", function()

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
                },
            },
            {
                name = "gluu-oauth-pep",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    deny_by_default = true,
                    oauth_scope_expression = JSON:encode{
                        {
                            path = "/todos",
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
                id = "a28a0f83-b619-4b58-94b3-e4ecaf8b6a2d",
                custom_id = register_site_response.client_id,
            }
        }
    }

    kong_utils.gg_db_less(kong_config)

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
                    pass_credentials = "hide",
                    custom_headers = {
                        { header_name = "x-consumer-id", value_lua_exp = "consumer.id", format = "string" },
                        { header_name = "x-oauth-client-id", value_lua_exp = "introspect_data.client_id", format = "string" },
                        { header_name = "x-consumer-custom-id", value_lua_exp = "introspect_data.client_id", format = "string" },
                        { header_name = "x-oauth-expiration", value_lua_exp = "introspect_data.exp", format = "string" },
                        { header_name = "x-authenticated-scope", value_lua_exp = "introspect_data.scope", format = "list" },
                    },
                },
            },
            {
                name = "gluu-oauth-pep",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    deny_by_default = false,
                    oauth_scope_expression = JSON:encode{
                        {
                            path = "/posts",
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

    print"check metrics, it should not return gluu_oauth_client_granted"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_admin_port,
        [[/gluu-metrics]]
    )
    assert(res:lower():find(string.lower([[gluu_oauth_client_authenticated{consumer="]]
            .. register_site_response.client_id .. [[",service="demo-service"} 2]]), 1, true))
    assert(res:lower():find("gluu_oauth_client_granted", 1, true) == nil)
    assert(res:lower():find(string.lower([[gluu_endpoint_method{endpoint="/todos",method="GET"]]), 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("check oauth_scope_expression and metrics", function()

    setup_db_less("oxd-model3.lua")

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
                        { header_name = "x-oauth-client-id", value_lua_exp = "introspect_data.client_id", format = "string" },
                        { header_name = "x-consumer-custom-id", value_lua_exp = "introspect_data.client_id", format = "string" },
                        { header_name = "x-oauth-expiration", value_lua_exp = "introspect_data.exp", format = "string" },
                        { header_name = "x-authenticated-scope", value_lua_exp = "introspect_data.scope", format = "list" },
                    },
                },
            },
            {
                name = "gluu-oauth-pep",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    deny_by_default = true,
                    oauth_scope_expression = JSON:encode{
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
                        },
                        {
                            path = "/test/??",
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
                                            "unpossible"
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

    print "test with path /posts"
    local res, err = sh_ex([[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/posts --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])
    assert(res:lower():find("x-consumer-id: " .. string.lower(kong_config.consumers[1].id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x%-oauth%-expiration: %d+"))

    print "test with path /comments"
    local res, err = sh_ex([[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/comments --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])
    assert(res:lower():find("x-consumer-id: " .. string.lower(kong_config.consumers[1].id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x%-oauth%-expiration: %d+"))

    print "test with path /todos"
    local res, err = sh_ex([[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/todos --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])
    assert(res:lower():find("x-consumer-id: " .. string.lower(kong_config.consumers[1].id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x%-oauth%-expiration: %d+"))

    print "test with path /todos, second time request, plugin shouldn't call oxd, must use cache"
    local res, err = sh_ex([[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/todos --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])
    assert(res:lower():find("x-consumer-id: " .. string.lower(kong_config.consumers[1].id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x%-oauth%-expiration: %d+"))

    print "test with path /"
    local res, err = sh_ex([[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])
    assert(res:lower():find("x-consumer-id: " .. string.lower(kong_config.consumers[1].id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x%-oauth%-expiration: %d+"))

    print "test with path /, second time request, plugin shouldn't call oxd, must use cache"
    local res, err = sh_ex([[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/ --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])
    assert(res:lower():find("x-consumer-id: " .. string.lower(kong_config.consumers[1].id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x%-oauth%-expiration: %d+"))

    print "test with path /photos, not register then apply rules under path /. plugin shouldn't call oxd, must use cache because / path is already authenticated. "
    local res, err = sh_ex([[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/photos --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])
    assert(res:lower():find("x-consumer-id: " .. string.lower(kong_config.consumers[1].id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x%-oauth%-expiration: %d+"))

    print "test with path /photos, second time request, plugin shouldn't call oxd, must use cache"
    local res, err = sh_ex([[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/photos --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])
    assert(res:lower():find("x-consumer-id: " .. string.lower(kong_config.consumers[1].id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x%-oauth%-expiration: %d+"))

    print"check metrics"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_admin_port,
        [[/gluu-metrics]]
    )
    assert(res:lower():find(string.lower([[gluu_oauth_client_authenticated{consumer="]]
            .. register_site_response.client_id .. [[",service="demo-service"} 8]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_oauth_client_granted{consumer="]]
            .. register_site_response.client_id .. [[",service="demo-service"} 8]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_endpoint_method{endpoint="/",method="GET"]]), 1, true))

    print "test with path /test, should be redjected"
    local res, err = sh_ex([[curl -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/test --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])
    assert(res:find("403", 1, true))
    assert(not res:find([[Unprotected path\/method are not allowed]], 1, true))

    print "test with path /test, should be redjected, no introspect call, use the cache"
    local res, err = sh_ex([[curl -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/test/whatever --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])
    assert(res:find("403", 1, true))
    assert(not res:find([[Unprotected path\/method are not allowed]], 1, true))

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
                    pass_credentials = "hide",
                    custom_headers = {
                        { header_name = "x-consumer-id", value_lua_exp = "consumer.id", format = "string" },
                        { header_name = "x-oauth-client-id", value_lua_exp = "introspect_data.client_id", format = "string" },
                        { header_name = "x-consumer-custom-id", value_lua_exp = "introspect_data.client_id", format = "string" },
                        { header_name = "x-oauth-expiration", value_lua_exp = "introspect_data.exp", format = "string" },
                        { header_name = "x-authenticated-scope", value_lua_exp = "introspect_data.scope", format = "list" },
                    },
                },
            },
            {
                name = "gluu-oauth-pep",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    deny_by_default = false,
                    oauth_scope_expression = JSON:encode{
                        {
                            path = "/todos",
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

test("check metrics client auth and grant", function()

    setup_db_less("oxd-model7.lua")

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
                        { header_name = "x-oauth-client-id", value_lua_exp = "introspect_data.client_id", format = "string" },
                        { header_name = "x-consumer-custom-id", value_lua_exp = "introspect_data.client_id", format = "string" },
                        { header_name = "x-oauth-expiration", value_lua_exp = "introspect_data.exp", format = "string" },
                        { header_name = "x-authenticated-scope", value_lua_exp = "introspect_data.scope", format = "list" },
                    },
                },
            },
            {
                name = "gluu-oauth-pep",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    deny_by_default = true,
                    oauth_scope_expression = JSON:encode{
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

    print "test with path /posts"
    local res, err = sh_ex([[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/posts --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])
    assert(res:lower():find("x-consumer-id: " .. string.lower(kong_config.consumers[1].id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x%-oauth%-expiration: %d+"))

    print "test with path /posts"
    local res, err = sh_ex([[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/posts --header 'Host: backend.com' --header 'Authorization: Bearer ]],
        access_token, [[']])
    assert(res:lower():find("x-consumer-id: " .. string.lower(kong_config.consumers[1].id), 1, true))
    assert(res:lower():find("x-oauth-client-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x-consumer-custom-id: " .. string.lower(register_site_response.client_id), 1, true))
    assert(res:lower():find("x%-oauth%-expiration: %d+"))

    print"check metrics, client auth and grant should be same"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_admin_port,
        [[/gluu-metrics]]
    )
    assert(res:lower():find(string.lower([[gluu_oauth_client_authenticated{consumer="]] .. register_site_response.client_id .. [[",service="demo-service"} 2]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_oauth_client_granted{consumer="]] .. register_site_response.client_id .. [[",service="demo-service"} 2]]), 1, true))
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
    assert(res:lower():find(string.lower([[gluu_oauth_client_authenticated{consumer="]] .. register_site_response.client_id .. [[",service="demo-service"} 3]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_oauth_client_granted{consumer="]] .. register_site_response.client_id .. [[",service="demo-service"} 2]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_endpoint_method{endpoint="/posts",method="GET"]]), 1, true))

    print "test with unescaped space in the path, path /posts"
    local res, err = sh_ex([[curl --fail -i -sS  -X GET --url 'http://localhost:]], ctx.kong_proxy_port,
        [[/posts bla' --header 'Host: backend.com' --header 'Authorization: Bearer ]],
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
                name = "gluu-oauth-pep",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    deny_by_default = true,
                    oauth_scope_expression = JSON:encode{
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
            {
                name = "gluu-oauth-pep",
                service = "demo-service2",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response2.client_id,
                    client_secret = register_site_response2.client_secret,
                    oxd_id = register_site_response2.oxd_id,
                    deny_by_default = true,
                    oauth_scope_expression = JSON:encode{
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
                },
            },
            {
                name = "gluu-metrics",
            }
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

local function build_config(oauth_scope_expression)
    return {
        _format_version = "1.1",
        services = {
            {
                name = "demo-service",
                url = "http://backend",
            },
        },
        routes = {
            {
                name = "demo-route",
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
                    client_id = "1234567890",
                    client_secret = "1234567890",
                    oxd_id = "1234567890",
                    pass_credentials = "hide",
                },
            },
            {
                name = "gluu-oauth-pep",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = "1234567890",
                    client_secret = "1234567890",
                    oxd_id = "1234567890",
                    deny_by_default = true,
                    oauth_scope_expression = JSON:encode(oauth_scope_expression),
                },
            },
            {
                name = "gluu-metrics",
            }
        },
        consumers = {
            {
                id = "a28a0f83-b619-4b58-94b3-e4ecaf8b6a2d",
                custom_id = "1234567890",
            }
        }
    }
end

test("Path is missing or empty in expression", function()
    setup_db_less()

    local kong_config = build_config{
        {
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
    }

    kong_utils.gg_db_less(kong_config, nil, true) -- wait for stop

    local res = stderr("docker logs ", ctx.kong_id)
    assert(res:find("Path is missing or empty in expression", 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("Empty expression not allowed", function()
    setup_db_less()

    local kong_config = build_config{}

    kong_utils.gg_db_less(kong_config, nil, true) -- wait for stop

    local res = stderr("docker logs ", ctx.kong_id)
    assert(res:find("Empty expression not allowed", 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("Path is missing or empty in expression", function()
    setup_db_less()

    local kong_config = build_config{
        {
            path = "",
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
        }
    }

    kong_utils.gg_db_less(kong_config, nil, true) -- wait for stop

    local res = stderr("docker logs ", ctx.kong_id)
    assert(res:find("Path is missing or empty in expression", 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("Duplicate path in expression", function()
    setup_db_less()

    local kong_config = build_config{
        {
            path = "/posts/??",
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
            path = "/posts/??",
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
    }

    kong_utils.gg_db_less(kong_config, nil, true) -- wait for stop

    local res = stderr("docker logs ", ctx.kong_id)
    assert(res:find("Duplicate path in expression", 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("Conditions are missing in expression", function()
    setup_db_less()

    local kong_config = build_config{
        {
            path = "/posts/??",
        },
    }

    kong_utils.gg_db_less(kong_config, nil, true) -- wait for stop

    local res = stderr("docker logs ", ctx.kong_id)
    assert(res:find("Conditions are missing in expression", 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("HTTP Methods are missing or empty from condition in expression", function()
    setup_db_less()

    local kong_config = build_config{
        {
            path = "/posts/??",
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
                }
            }
        }
    }

    kong_utils.gg_db_less(kong_config, nil, true) -- wait for stop

    local res = stderr("docker logs ", ctx.kong_id)
    assert(res:find("HTTP Methods are missing or empty from condition in expression", 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("HTTP Methods are missing or empty from condition in expression", function()
    setup_db_less()

    local kong_config = build_config{
        {
            path = "/posts/??",
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
                    httpMethods = {}
                }
            }
        }
    }

    kong_utils.gg_db_less(kong_config, nil, true) -- wait for stop

    local res = stderr("docker logs ", ctx.kong_id)
    assert(res:find("HTTP Methods are missing or empty from condition in expression", 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("Duplicate http method from conditions in expression", function()
    setup_db_less()

    local kong_config = build_config{
        {
            path = "/posts/??",
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
                    httpMethods = { "GET", "POST" }
                },
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
                    httpMethods = { "POST", "PUT" }
                }
            }
        }
    }

    kong_utils.gg_db_less(kong_config, nil, true) -- wait for stop

    local res = stderr("docker logs ", ctx.kong_id)
    assert(res:find("Duplicate http method from conditions in expression", 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)
