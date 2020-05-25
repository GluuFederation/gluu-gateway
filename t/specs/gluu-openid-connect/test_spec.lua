local utils = require"test_utils"
local sh, stdout, stderr, sleep, sh_ex, sh_until_ok =
utils.sh, utils.stdout, utils.stderr, utils.sleep, utils.sh_ex, utils.sh_until_ok

local kong_utils = require"kong_utils"
local JSON = require"JSON"

local host_git_root = os.getenv"HOST_GIT_ROOT"
local git_root = os.getenv"GIT_ROOT"
local test_root = host_git_root .. "/t/specs/gluu-openid-connect"

local pl_path = require "pl.path"
local pl_tmpname = pl_path.tmpname
local pl_file = require "pl.file"

-- finally() available only in current module environment
-- this is a hack to pass it to a functions in kong_utils
local function setup_db_less(model)
    kong_utils.setup_db_less(finally, test_root .. "/" .. model, true) -- create_cookie_tmp_filename = true
end

test("basic", function()
    setup_db_less("oxd-model1.lua")

    local register_site_response = kong_utils.register_site()

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
                name = "gluu-openid-connect",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    authorization_redirect_path = "/callback",
                    requested_scopes = {"openid", "email", "profile"},
                    max_id_token_age = 4,
                    max_id_token_auth_age = 60*60*24,
                    logout_path = "/logout_path",
                    post_logout_redirect_path_or_url = "/post_logout_redirect_path_or_url"
                },
            },
        },
    }

    kong_utils.gg_db_less(kong_config)

    local cookie_tmp_filename = ctx.cookie_tmp_filename

    print"test it responds with 302"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("302", 1, true))
    assert(res:find("response_type=code", 1, true))
    assert(res:find("session=", 1, true)) -- session cookie is here

    print"call callback with state from oxd-model1, follow redirect"
    local res, err = sh_ex([[curl -i -v -sS -X GET -L --url 'http://localhost:]],
        ctx.kong_proxy_port, [[/callback?code=1234567890&state=473ot4nuqb4ubeokc139raur13' --header 'Host: backend.com']],
        [[ -c ]], cookie_tmp_filename, [[ -b ]], cookie_tmp_filename)
    -- test that we redirected to original url
    assert(res:find("200", 1, true))
    assert(res:find("page1", 1, true))


    print"request second time with cookie"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("200", 1, true))


    sh_ex("sleep 5");

    print"id_token is expired, require silent reauth"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("302", 1, true))
    assert(res:find("response_type=code", 1, true))
    assert(res:find("session=", 1, true)) -- session cookie is here

    print"call callback with state from oxd-model1, follow redirect"
    local res, err = sh_ex([[curl -i  -sS -X GET -L --url 'http://localhost:]],
        ctx.kong_proxy_port, [[/callback?code=1234567890123&state=473ot4nuqb4ubeokc139raur13123' --header 'Host: backend.com']],
        [[ -c ]], cookie_tmp_filename, [[ -b ]], cookie_tmp_filename)
    -- test that we redirected to original url
    assert(res:find("200", 1, true))
    assert(res:find("page1", 1, true))


    print"logout and check the cookie"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/logout_path --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("302", 1, true))
    assert(res:find("session=;", 1, true)) -- no cookie is available

    print"just check getting 200 when request comes to post_logout_redirect_path_or_url"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/post_logout_redirect_path_or_url --header 'Host: backend.com']])
    assert(res:find("200", 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("OpenID Connect with UMA, Metrics", function()
    setup_db_less("oxd-model2.lua")

    local register_site_response = kong_utils.register_site()

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
                name = "gluu-openid-connect",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    authorization_redirect_path = "/callback",
                    requested_scopes = {"openid", "email", "profile"},
                    max_id_token_age = 10,
                    max_id_token_auth_age = 60*60*24,
                    logout_path = "/logout_path",
                    post_logout_redirect_path_or_url = "/post_logout_redirect_path_or_url"
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
                    obtain_rpt = true,
                    uma_scope_expression = JSON:encode{
                        {
                            path = "/page1",
                            conditions = {
                                {
                                    httpMethods = {"GET"},
                                }
                            }
                        },
                        {
                            path = "/page2/{todos|photos}",
                            conditions = {
                                {
                                    httpMethods = {"GET"},
                                }
                            }
                        },
                        {
                            path = "/path/?/image.jpg",
                            conditions = {
                                {
                                    httpMethods = {"GET"},
                                }
                            }
                        }
                    }
                }
            },
            {
                name = "gluu-metrics",
            }
        },
    }

    kong_utils.gg_db_less(kong_config)

    local cookie_tmp_filename = ctx.cookie_tmp_filename

    print"test it responds with 302"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("302", 1, true))
    assert(res:find("response_type=code", 1, true))
    assert(res:find("session=", 1, true)) -- session cookie is here

    print"call callback with state from oxd-model1, follow redirect"

    local res, err = sh_ex([[curl -i -sS -X GET -L --url 'http://localhost:]],
        ctx.kong_proxy_port, [[/callback?code=1234567890&state=473ot4nuqb4ubeokc139raur13' --header 'Host: backend.com']],
        [[ -c ]], cookie_tmp_filename, [[ -b ]], cookie_tmp_filename)
    -- test that we redirected to original url
    assert(res:find("200", 1, true))
    assert(res:find("page1", 1, true))

    print"request second time with cookie"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("200", 1, true))

    print"check metrics, it should return openid_connect_users_authenticated = 2"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_admin_port,
        [[/gluu-metrics]]
    )
    assert(res:lower():find("gluu_openid_connect_users_authenticated", 1, true))
    assert(res:lower():find(string.lower([[gluu_endpoint_method{endpoint="/page1",method="GET",service="demo-service"} 3]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_openid_connect_users_authenticated{service="demo-service"} 2]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_uma_client_granted{consumer="openid_connect_authentication",service="demo-service"} 2]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_uma_ticket{service="demo-service"} 1]]), 1, true))

    print"request third time with cookie"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("200", 1, true))

    print"request to another path page2/photos"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page2/photos --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("200", 1, true))

    print"request to another path /path/one/two/image.jpg"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/path/123/image.jpg --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("200", 1, true))

    print"check metrics, it should return openid_connect_users_authenticated = 5"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_admin_port,
        [[/gluu-metrics]]
    )
    assert(res:lower():find("gluu_openid_connect_users_authenticated", 1, true))
    assert(res:lower():find(string.lower([[gluu_endpoint_method{endpoint="/page1",method="GET",service="demo-service"} 4]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_endpoint_method{endpoint="/page2/photos",method="GET",service="demo-service"} 1]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_endpoint_method{endpoint="/path/123/image.jpg",method="GET",service="demo-service"} 1]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_openid_connect_users_authenticated{service="demo-service"} 5]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_uma_client_granted{consumer="openid_connect_authentication",service="demo-service"} 5]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_uma_ticket{service="demo-service"} 3]]), 1, true))

    print "deny for tha path which is not registered in UMA resources"
    local res, err = sh_ex([[curl -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/todos --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("403", 1, true))

    ctx.print_logs = false
end)

test("OpenID Connect with UMA, PCT", function()
    setup_db_less("oxd-model3.lua")

    local register_site_response = kong_utils.register_site()

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
                name = "gluu-openid-connect",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    authorization_redirect_path = "/callback",
                    requested_scopes = {"openid", "email", "profile"},
                    max_id_token_age = 10,
                    max_id_token_auth_age = 60*60*24,
                    logout_path = "/logout_path",
                    post_logout_redirect_path_or_url = "/post_logout_redirect_path_or_url"
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
                    obtain_rpt = true,
                    require_id_token = true,
                    pushed_claims_lua_exp = "id_token",
                    uma_scope_expression = JSON:encode{
                        {
                            path = "/page1",
                            conditions = {
                                {
                                    httpMethods = {"GET"},
                                }
                            }
                        }
                    }
                }
            },
        },
    }

    kong_utils.gg_db_less(kong_config)

    local cookie_tmp_filename = ctx.cookie_tmp_filename

    print"test it responds with 302"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("302", 1, true))
    assert(res:find("response_type=code", 1, true))
    assert(res:find("session=", 1, true)) -- session cookie is here

    print"call callback with state from oxd-model1, follow redirect"
    local res, err = sh_ex([[curl -i  -sS -X GET -L --url 'http://localhost:]],
        ctx.kong_proxy_port, [[/callback?code=1234567890&state=473ot4nuqb4ubeokc139raur13' --header 'Host: backend.com']],
        [[ -c ]], cookie_tmp_filename, [[ -b ]], cookie_tmp_filename)
    -- test that we redirected to original url
    assert(res:find("200", 1, true))
    assert(res:find("page1", 1, true))

    print"request second time with cookie"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("200", 1, true))

    print"request third time with cookie"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("200", 1, true))

    print"just check getting 200 when request comes to post_logout_redirect_path_or_url"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/post_logout_redirect_path_or_url --header 'Host: backend.com']])
    assert(res:find("200", 1, true))

    ctx.print_logs = false
end)

test("OpenID Connect with UMA Claim gathering flow", function()
    setup_db_less("oxd-model4.lua")

    local register_site_response = kong_utils.register_site()

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
                name = "gluu-openid-connect",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    authorization_redirect_path = "/callback",
                    requested_scopes = {"openid", "email", "profile"},
                    max_id_token_age = 10,
                    max_id_token_auth_age = 60*60*24,
                    logout_path = "/logout_path",
                    post_logout_redirect_path_or_url = "/post_logout_redirect_path_or_url"
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
                    obtain_rpt = true,
                    redirect_claim_gathering_url = true,
                    claims_redirect_path = "/claim_gathering_path",
                    uma_scope_expression = JSON:encode{
                        {
                            path = "/page1",
                            conditions = {
                                {
                                    httpMethods = {"GET"},
                                }
                            }
                        }
                    }
                }
            },
        },
    }

    kong_utils.gg_db_less(kong_config)

    local cookie_tmp_filename = ctx.cookie_tmp_filename

    print"test it responds with 302"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("302", 1, true))
    assert(res:find("response_type=code", 1, true))
    assert(res:find("session=", 1, true)) -- session cookie is here

    print"call callback with state and save userinfo in session"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url 'http://localhost:]],
        ctx.kong_proxy_port, [[/callback?code=1234567890&state=473ot4nuqb4ubeokc139raur13' --header 'Host: backend.com']],
        [[ -c ]], cookie_tmp_filename, [[ -b ]], cookie_tmp_filename)
    -- test that we redirected to original url
    assert(res:find("302", 1, true))
    assert(res:find("page1", 1, true))
    assert(res:find("session=", 1, true))

    print"request to /page1 to redirect to claim gathering url"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("302", 1, true))
    assert(res:find("gather_claims", 1, true))
    assert(res:find("ticket=", 1, true))
    assert(res:find("session=", 1, true))

    print"call /claim_gathering_path get ticket, obtain RPT and Grant"
    local res, err = sh_ex([[curl -i --fail -sS -X GET -L --url 'http://localhost:]],
        ctx.kong_proxy_port, [[/claim_gathering_path?ticket=fba00191-59ab-4ed6-ac99-a786a88a9f40&state=d871gpie16np0f5kfv936sc33k' --header 'Host: backend.com']],
        [[ -c ]], cookie_tmp_filename, [[ -b ]], cookie_tmp_filename)
    assert(res:find("200", 1, true))
    assert(res:find("page1", 1, true))

        print"request second time with cookie"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("200", 1, true))

    print"request third time with cookie"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("200", 1, true))

    ctx.print_logs = false
end)

test("acr_values testing", function()
    setup_db_less("oxd-model5.lua")

    local register_site_response = kong_utils.register_site()

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
                name = "gluu-openid-connect",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    authorization_redirect_path = "/callback",
                    requested_scopes = {"openid", "email", "profile"},
                    max_id_token_age = 10,
                    max_id_token_auth_age = 60*60*24,
                    logout_path = "/logout_path",
                    post_logout_redirect_path_or_url = "/post_logout_redirect_path_or_url",
                    required_acrs_expression = JSON:encode{
                        {
                            path = "/??",
                            conditions = {
                                {
                                    required_acrs = { "auth_ldap_server" },
                                    httpMethods = { "?" }, -- any
                                }
                            }
                        },
                        {
                            path = "/superhero",
                            conditions = {
                                {
                                    required_acrs = { "superhero" },
                                    httpMethods = { "?" }, -- any
                                }
                            }
                        },
                        {
                            path = "/open/??",
                            conditions = {
                                {
                                    no_auth = true,
                                    httpMethods = { "?" }, -- any
                                }
                            }
                        },
                    },
                },
            },
        },
    }

    kong_utils.gg_db_less(kong_config)

    local cookie_tmp_filename = ctx.cookie_tmp_filename

    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/open/page,html --header 'Host: backend.com' ]])
    assert(res:find("200", 1, true))

    print"acr=auth_ldap_server"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("302", 1, true))
    assert(res:find("response_type=code", 1, true))
    assert(res:find("session=", 1, true)) -- session cookie is here

    print"follow redirect 1"
    local res, err = sh_ex([[curl -i  -sS -X GET -L --url 'http://localhost:]],
        ctx.kong_proxy_port, [[/callback?code=1234567890&state=473ot4nuqb4ubeokc139raur13' --header 'Host: backend.com']],
        [[ -c ]], cookie_tmp_filename, [[ -b ]], cookie_tmp_filename)
    -- test that we redirected to original url
    assert(res:find("200", 1, true))
    assert(res:find("page1", 1, true))

    kong_config.plugins[1].config.required_acrs_expression = JSON:encode{
        {
            path = "/??",
            conditions = {
                {
                    required_acrs = { "otp" },
                    httpMethods = { "?" }, -- any
                }
            }
        },
        {
            path = "/superhero",
            conditions = {
                {
                    required_acrs = { "superhero" },
                    httpMethods = { "?" }, -- any
                }
            }
        },
    }
    kong_utils.db_less_reconfigure(kong_config)


    print"acr=OTP, acr updated so plugin should redirect for re-auth"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("302", 1, true))
    assert(res:find("response_type=code", 1, true))
    assert(res:find("session=", 1, true)) -- session cookie is here

    print"simulate redirect from GS 2"
    local res, err = sh_ex([[curl -i  -sS -X GET -L --url 'http://localhost:]],
        ctx.kong_proxy_port, [[/callback?code=1234567890&state=473ot4nuqb4ubeokc139raur13' --header 'Host: backend.com']],
        [[ -c ]], cookie_tmp_filename, [[ -b ]], cookie_tmp_filename)
    -- test that we redirected to original url
    assert(res:find("200", 1, true))
    assert(res:find("page1", 1, true))

    kong_config.plugins[1].config.required_acrs_expression = JSON:encode{
        {
            path = "/??",
            conditions = {
                {
                    required_acrs = { "auth_ldap_server" },
                    httpMethods = { "?" }, -- any
                }
            }
        },
        {
            path = "/superhero",
            conditions = {
                {
                    required_acrs = { "superhero" },
                    httpMethods = { "?" }, -- any
                }
            }
        },
        {
            path = "/any_acr",
            conditions = {
                {
                    httpMethods = { "?" }, -- any
                }
            }
        },
    }
    kong_utils.db_less_reconfigure(kong_config)

    print"acr=auth_ldap_server, plugin should allow because already authenticated with auth_ldap_server"
    local res, err = sh_ex([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("200", 1, true))
    assert(res:find("page1", 1, true))

    print"test url based required acrs, unescaped space in URI, protected with superhero acr"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url 'http://localhost:]],
        ctx.kong_proxy_port, [[/superhero bla' --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("302", 1, true))
    assert(res:find("response_type=code", 1, true))
    assert(res:find("session=", 1, true)) -- session cookie is here

    print"simulate redirect from GS 3"
    local res, err = sh_ex([[curl -i  -sS -X GET -L --url 'http://localhost:]],
        ctx.kong_proxy_port, [[/callback?code=1234567890qwerty&state=473ot4nuqb4ubeokc139raur13qwerty' --header 'Host: backend.com']],
        [[ -c ]], cookie_tmp_filename, [[ -b ]], cookie_tmp_filename)
    -- test that we redirected to original url
    assert(res:find("200", 1, true))
    assert(res:find("superhero", 1, true))

    print"should allow, this path accept any acr"
    local res, err = sh_ex([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/any_acr --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("200", 1, true))
    assert(res:find("any_acr", 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("not enough acr", function()
    setup_db_less("oxd-model6.lua")

    local register_site_response = kong_utils.register_site()

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
                name = "gluu-openid-connect",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    authorization_redirect_path = "/callback",
                    requested_scopes = {"openid", "email", "profile"},
                    max_id_token_age = 10,
                    max_id_token_auth_age = 60*60*24,
                    logout_path = "/logout_path",
                    post_logout_redirect_path_or_url = "/post_logout_redirect_path_or_url",
                    required_acrs_expression = JSON:encode{
                        {
                            path = "/??",
                            conditions = {
                                {
                                    required_acrs = { "auth_ldap_server" },
                                    httpMethods = { "?" }, -- any
                                }
                            }
                        },
                    },
                },
            },
        },
    }

    kong_utils.gg_db_less(kong_config)

    local cookie_tmp_filename = ctx.cookie_tmp_filename

    print"acr=auth_ldap_server"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("302", 1, true))
    assert(res:find("response_type=code", 1, true))
    assert(res:find("session=", 1, true)) -- session cookie is here

    print"simulate redirect from OP, model returns only basic acr, should be redjected"
    local res, err = sh_ex([[curl -i  -sS -X GET -L --url 'http://localhost:]],
        ctx.kong_proxy_port, [[/callback?code=1234567890&state=473ot4nuqb4ubeokc139raur13' --header 'Host: backend.com']],
        [[ -c ]], cookie_tmp_filename, [[ -b ]], cookie_tmp_filename)
    assert(res:find("403", 1, true))
    assert(res:find("The resource requires one of the", 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)

-- https://github.com/GluuFederation/gluu-gateway/issues/355
test("required_acrs in user session", function()
    setup_db_less("oxd-model7.lua")

    local register_site_response = kong_utils.register_site()

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
                name = "gluu-openid-connect",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    authorization_redirect_path = "/callback",
                    requested_scopes = {"openid", "email", "profile"},
                    max_id_token_age = 10,
                    max_id_token_auth_age = 60*60*24,
                    logout_path = "/logout_path",
                    post_logout_redirect_path_or_url = "/post_logout_redirect_path_or_url",
                    required_acrs_expression = JSON:encode{
                        {
                            path = "/??",
                            conditions = {
                                {
                                    httpMethods = { "?" }, -- any
                                }
                            }
                        },
                        {
                            path = "/users/??",
                            conditions = {
                                {
                                    required_acrs = { "auth_ldap_server" },
                                    httpMethods = { "?" }, -- any
                                }
                            }
                        },
                    },
                    custom_headers = {
                        {header_name = "KONG_USER_INFO_JWT", value_lua_exp = "userinfo", format = "jwt"},
                        {header_name = "kong_id_token_jwt", value_lua_exp = "id_token", format = "jwt"},
                    },
                },
            },
        },
    }

    kong_utils.gg_db_less(kong_config)

    local cookie_tmp_filename = ctx.cookie_tmp_filename

    print"acr=any"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("302", 1, true))
    assert(res:find("response_type=code", 1, true))
    assert(res:find("session=", 1, true)) -- session cookie is here

    print"follow redirect 1"
    local res, err = sh_ex([[curl -i  -sS -X GET -L --url 'http://localhost:]],
        ctx.kong_proxy_port, [[/callback?code=1234567890&state=473ot4nuqb4ubeokc139raur13' --header 'Host: backend.com']],
        [[ -c ]], cookie_tmp_filename, [[ -b ]], cookie_tmp_filename)
    -- test that we redirected to original url
    assert(res:find("200", 1, true))
    assert(res:find("page1", 1, true))
    assert(res:find("kong-id-token-jwt", 1, true))
    assert(res:find("kong-user-info-jwt", 1, true))

    print"acr=auth_ldap_server"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/users/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("302", 1, true))
    assert(res:find("response_type=code", 1, true))
    assert(res:find("session=", 1, true)) -- session cookie is here

    print"follow redirect 1"
    local res, err = sh_ex([[curl -i  -sS -X GET -L --url 'http://localhost:]],
        ctx.kong_proxy_port, [[/callback?code=1234567890&state=473ot4nuqb4ubeokc139raur13' --header 'Host: backend.com']],
        [[ -c ]], cookie_tmp_filename, [[ -b ]], cookie_tmp_filename)
    -- test that we redirected to original url
    assert(res:find("200", 1, true))
    assert(res:find("page1", 1, true))
    assert(res:find("kong-id-token-jwt", 1, true))
    assert(res:find("kong-user-info-jwt", 1, true))


    kong_config.plugins[1].config.required_acrs_expression = JSON:encode{
        {
            path = "/??",
            conditions = {
                {
                    httpMethods = { "?" }, -- any
                }
            }
        },
        {
            path = "/users/??",
            conditions = {
                {
                    required_acrs = { "otp" },
                    httpMethods = { "?" }, -- any
                }
            }
        }
    }
    kong_utils.db_less_reconfigure(kong_config)

    print"acr=otp"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/users/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("302", 1, true))
    assert(res:find("response_type=code", 1, true))
    assert(res:find("session=", 1, true)) -- session cookie is here

    print"follow redirect 1"
    local res, err = sh_ex([[curl -i  -sS -X GET -L --url 'http://localhost:]],
        ctx.kong_proxy_port, [[/callback?code=1234567890qwerty&state=473ot4nuqb4ubeokc139raur13qwerty' --header 'Host: backend.com']],
        [[ -c ]], cookie_tmp_filename, [[ -b ]], cookie_tmp_filename)
    -- test that we redirected to original url
    assert(res:find("200", 1, true))
    assert(res:find("page1", 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("unset required_acrs_expression", function()

    setup_db_less("oxd-model7.lua")

    local register_site_response = kong_utils.register_site()

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
                name = "gluu-openid-connect",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    authorization_redirect_path = "/callback",
                    requested_scopes = {"openid", "email", "profile"},
                    max_id_token_age = 10,
                    max_id_token_auth_age = 60*60*24,
                    logout_path = "/logout_path",
                    post_logout_redirect_path_or_url = "/post_logout_redirect_path_or_url",
                    required_acrs_expression = JSON:encode{
                        {
                            path = "/??",
                            conditions = {
                                {
                                    httpMethods = { "?" }, -- any
                                }
                            }
                        },
                        {
                            path = "/users/??",
                            conditions = {
                                {
                                    required_acrs = { "auth_ldap_server" },
                                    httpMethods = { "?" }, -- any
                                }
                            }
                        },
                    },
                },
            },
        },
    }

    kong_utils.gg_db_less(kong_config)

    local cookie_tmp_filename = ctx.cookie_tmp_filename

    print "acr=any"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("302", 1, true))
    assert(res:find("response_type=code", 1, true))
    assert(res:find("session=", 1, true)) -- session cookie is here

    print "follow redirect 1"
    local res, err = sh_ex([[curl -i  -sS -X GET -L --url 'http://localhost:]],
        ctx.kong_proxy_port, [[/callback?code=1234567890&state=473ot4nuqb4ubeokc139raur13' --header 'Host: backend.com']],
        [[ -c ]], cookie_tmp_filename, [[ -b ]], cookie_tmp_filename)
    -- test that we redirected to original url
    assert(res:find("200", 1, true))
    assert(res:find("page1", 1, true))

    kong_config.plugins[1].config.required_acrs_expression = nil
    kong_utils.db_less_reconfigure(kong_config)

    print"it should allow, because we already have any acr id_token"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/users/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("HTTP/1.1 200", 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("Check custom header", function()
    setup_db_less("oxd-model8.lua")

    local register_site_response = kong_utils.register_site()

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
                name = "gluu-openid-connect",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    authorization_redirect_path = "/callback",
                    requested_scopes = {"openid", "email", "profile"},
                    max_id_token_age = 14,
                    max_id_token_auth_age = 60*60*24,
                    logout_path = "/logout_path",
                    post_logout_redirect_path_or_url = "/post_logout_redirect_path_or_url",
                    custom_headers = {
                        { header_name = "http_sm_name", value_lua_exp = "userinfo.name", format = "string" },
                        { header_name = "KONG_USER_INFO_JWT", value_lua_exp = "userinfo", format = "jwt" },
                        { header_name = "kong_id_token_jwt", value_lua_exp = "id_token", format = "jwt" },
                        { header_name = "KONG_OPENIDC_USERINFO_{*}", value_lua_exp = "userinfo", format = "string", iterate = true },
                        { header_name = "KONG_OPENIDC_idtoken_{*}", value_lua_exp = "id_token", format = "base64", iterate = true },
                        { header_name = "http_dept_id", value_lua_exp = "123", format = "base64" },
                        { header_name = "http_kong_api_version", value_lua_exp = [["version 1.0"]], format = "urlencoded" },
                        { header_name = "GG-ACCESS-TOKEN", value_lua_exp = "access_token", format = "urlencoded" },
                    }
                },
            },
        },
    }

    kong_utils.gg_db_less(kong_config)

    local cookie_tmp_filename = ctx.cookie_tmp_filename

    print"test it responds with 302"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("302", 1, true))
    assert(res:find("response_type=code", 1, true))
    assert(res:find("session=", 1, true)) -- session cookie is here

    print"call callback with state from oxd-model1, follow redirect"
    local res, err = sh_ex([[curl -i -v -sS -X GET -L --url 'http://localhost:]],
        ctx.kong_proxy_port, [[/callback?code=1234567890&state=473ot4nuqb4ubeokc139raur13' --header 'Host: backend.com']],
        [[ -c ]], cookie_tmp_filename, [[ -b ]], cookie_tmp_filename)
    -- test that we redirected to original url
    assert(res:find("200", 1, true))
    assert(res:find("page1", 1, true))
    local headers = {
        "kong-openidc-idtoken-auth-time",
        "kong-openidc-idtoken-aud",
        "kong-openidc-userinfo-sub",
        "kong-openidc-idtoken-at-hash",
        "kong-openidc-userinfo-email",
        "kong-openidc-idtoken-iat",
        "kong-openidc-userinfo-given-name",
        "kong-openidc-userinfo-family-name",
        "kong-openidc-idtoken-nonce",
        "kong-openidc-idtoken-iss",
        "kong-openidc-userinfo-picture",
        "http-sm-name",
        "kong-id-token-jwt",
        "http-dept-id",
        "http-kong-api-version",
        "kong-openidc-idtoken-sub",
        "kong-user-info-jwt",
        "kong-openidc-userinfo-preferred-username",
        "kong-openidc-idtoken-exp",
        "kong-openidc-userinfo-name",
        "gg-access-token"}
    for i = 1, #headers do
        assert(res:find(headers[i], 1, true), "Missed header: " .. headers[i])
    end
    assert(not res:find("cookie: ", 1, true))

    print"request second time with cookie"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("200", 1, true))
    for i = 1, #headers do
        assert(res:find(headers[i], 1, true), "Missed header: " .. headers[i])
    end

    print"request third time with cookie"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("200", 1, true))
    for i = 1, #headers do
        assert(res:find(headers[i], 1, true), "Missed header: " .. headers[i])
    end

    print"request fourth time with cookie"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("200", 1, true))
    for i = 1, #headers do
        assert(res:find(headers[i], 1, true), "Missed header: " .. headers[i])
    end

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("custom headers for non protected page", function()
    setup_db_less("oxd-model5.lua")

    local register_site_response = kong_utils.register_site()

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
                name = "gluu-openid-connect",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    authorization_redirect_path = "/callback",
                    requested_scopes = {"openid", "email", "profile"},
                    max_id_token_age = 10,
                    max_id_token_auth_age = 60*60*24,
                    logout_path = "/logout_path",
                    post_logout_redirect_path_or_url = "/post_logout_redirect_path_or_url",
                    required_acrs_expression = JSON:encode{
                        {
                            path = "/??",
                            conditions = {
                                {
                                    required_acrs = { "auth_ldap_server" },
                                    httpMethods = { "?" }, -- any
                                }
                            }
                        },
                        {
                            path = "/superhero",
                            conditions = {
                                {
                                    required_acrs = { "superhero" },
                                    httpMethods = { "?" }, -- any
                                }
                            }
                        },
                        {
                            path = "/open/??",
                            conditions = {
                                {
                                    no_auth = true,
                                    httpMethods = { "?" }, -- any
                                }
                            }
                        },
                    },
                    custom_headers = {
                        { header_name = "http_sm_name", value_lua_exp = "userinfo.sub", format = "string" },
                    },
                },
            },
        },
    }

    kong_utils.gg_db_less(kong_config)

    local cookie_tmp_filename = ctx.cookie_tmp_filename

    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/open/page.html --header 'Host: backend.com' ]])
    assert(res:find("200", 1, true))
    assert(not res:find("http_sm_name", 1, true))

    print"acr=auth_ldap_server"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("302", 1, true))
    assert(res:find("response_type=code", 1, true))
    assert(res:find("session=", 1, true)) -- session cookie is here

    print"follow redirect 1"
    local res, err = sh_ex([[curl -i  -sS -X GET -L --url 'http://localhost:]],
        ctx.kong_proxy_port, [[/callback?code=1234567890&state=473ot4nuqb4ubeokc139raur13' --header 'Host: backend.com']],
        [[ -c ]], cookie_tmp_filename, [[ -b ]], cookie_tmp_filename)
    -- test that we redirected to original url
    assert(res:find("200", 1, true))
    assert(res:find("page1", 1, true))

    local res, err = sh_ex([[curl -i -v -sS --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/open/page.html --header 'Host: backend.com' -c ]], cookie_tmp_filename, [[ -b ]], cookie_tmp_filename)
    assert(res:find("200", 1, true))
    assert(res:find("http-sm-name", 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("2 kongs, session decryption", function()
    setup_db_less("oxd-model5.lua")

    local register_site_response = kong_utils.register_site()

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
                name = "gluu-openid-connect",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    authorization_redirect_path = "/callback",
                    requested_scopes = {"openid", "email", "profile"},
                    max_id_token_age = 10,
                    max_id_token_auth_age = 60*60*24,
                    logout_path = "/logout_path",
                    post_logout_redirect_path_or_url = "/post_logout_redirect_path_or_url",
                },
            },
        },
    }

    local injected_kong_proxy = "set $session_secret 1234567890;"
    kong_utils.gg_db_less(kong_config, nil, nil, injected_kong_proxy)
    kong_utils.gg_db_less(kong_config, nil, nil, injected_kong_proxy, true)

    assert(ctx.kong_id2)

    local cookie_tmp_filename = ctx.cookie_tmp_filename

    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("302", 1, true))
    assert(res:find("response_type=code", 1, true))
    assert(res:find("session=", 1, true)) -- session cookie is here

    print"follow redirect 1"
    local res, err = sh_ex([[curl -i  -sS -X GET -L --url 'http://localhost:]],
        ctx.kong_proxy_port, [[/callback?code=1234567890&state=473ot4nuqb4ubeokc139raur13' --header 'Host: backend.com']],
        [[ -c ]], cookie_tmp_filename, [[ -b ]], cookie_tmp_filename)
    -- test that we redirected to original url
    assert(res:find("200", 1, true))
    assert(res:find("page1", 1, true))

    print"request to another GG node with session cookie"
    local res, err = sh_ex([[curl -i -v -sS --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port2, [[/page2 --header 'Host: backend.com' -c ]], cookie_tmp_filename, [[ -b ]], cookie_tmp_filename)
    assert(res:find("200", 1, true))
    assert(res:find("page2", 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)

-- based on real life issue https://github.com/GluuFederation/gluu-gateway/issues/432
test("unexpected error, max_id_token_age - 1 hour and max_id_token_auth_age - 1 min", function()
    setup_db_less("oxd-model9.lua")

    local register_site_response = kong_utils.register_site()

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
                name = "gluu-openid-connect",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    authorization_redirect_path = "/callback",
                    requested_scopes = {"openid", "email", "profile"},
                    max_id_token_age = 60*60, -- one hour
                    max_id_token_auth_age = 60, -- one min
                    required_acrs_expression = "[{\"path\":\"/payments/??\",\"conditions\":[{\"httpMethods\":[\"?\"],\"required_acrs\":[\"otp\"],\"no_auth\":false}]}]",
                    logout_path = "/logout_path",
                    post_logout_redirect_path_or_url = "/post_logout_redirect_path_or_url"
                },
            },
        },
    }

    kong_utils.gg_db_less(kong_config)

    local cookie_tmp_filename = ctx.cookie_tmp_filename

    print"test it responds with 302"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("302", 1, true))
    assert(res:find("response_type=code", 1, true))
    assert(res:find("session=", 1, true)) -- session cookie is here

    print"call callback with state from oxd-model9, follow redirect"
    local res, err = sh_ex([[curl -i -L -v -sS -X GET  --url 'http://localhost:]],
        ctx.kong_proxy_port, [[/callback?code=1234567890&state=473ot4nuqb4ubeokc139raur13' --header 'Host: backend.com']],
        [[ -c ]], cookie_tmp_filename, [[ -b ]], cookie_tmp_filename)
    -- test that we redirected to original url
    assert(res:find("500", 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("restore POST after authentication", function()
    setup_db_less("oxd-model1.lua")

    local register_site_response = kong_utils.register_site()

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
                name = "gluu-openid-connect",
                service = "demo-service",
                config = {
                    op_url = "http://stub",
                    oxd_url = "http://oxd-mock",
                    client_id = register_site_response.client_id,
                    client_secret = register_site_response.client_secret,
                    oxd_id = register_site_response.oxd_id,
                    authorization_redirect_path = "/callback",
                    requested_scopes = {"openid", "email", "profile"},
                    max_id_token_age = 14,
                    max_id_token_auth_age = 60*60*24,
                    logout_path = "/logout_path",
                    post_logout_redirect_path_or_url = "/post_logout_redirect_path_or_url",
                    restore_original_auth_params = true,
                    custom_headers = {
                        { header_name = "kong_id_token_jwt", value_lua_exp = "id_token", format = "jwt" },
                    }
                },
            },
        },
    }

    kong_utils.gg_db_less(kong_config)

    local cookie_tmp_filename = ctx.cookie_tmp_filename

    print"test it responds with 302"
    local res, err = sh_ex([[curl -i --fail -sS -X POST --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Content-Type: text' --data 'qwerty1234567' --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("302", 1, true))
    assert(res:find("response_type=code", 1, true))
    assert(res:find("session=", 1, true)) -- session cookie is here

    print"call callback with state from oxd-model1, follow redirect"
    local res, err = sh_ex([[curl -i -v -sS -X GET -L --url 'http://localhost:]],
        ctx.kong_proxy_port, [[/callback?code=1234567890&state=473ot4nuqb4ubeokc139raur13' --header 'Host: backend.com']],
        [[ -c ]], cookie_tmp_filename, [[ -b ]], cookie_tmp_filename)
    -- test that we redirected to original url
    assert(res:find("200", 1, true))
    assert(res:find("page1", 1, true))
    assert(res:find("kong-id-token-jwt", 1, true))
    assert(res:find("content-type: text", 1, true))
    assert(res:find("Method: POST", 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)
