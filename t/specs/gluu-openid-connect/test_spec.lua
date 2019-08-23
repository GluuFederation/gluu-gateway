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

local function setup(model)
    _G.ctx = {}
    local ctx = _G.ctx
    ctx.finalizeres = {}
    ctx.host_git_root = host_git_root
    ctx.cookie_tmp_filename = pl_tmpname()

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

        pl_file.delete(ctx.cookie_tmp_filename)
    end)


    kong_utils.docker_unique_network()
    kong_utils.kong_postgress_custom_plugins{
        plugins = {
            ["gluu-openid-connect"] = host_git_root .. "/kong/plugins/gluu-openid-connect",
            ["gluu-uma-pep"] = host_git_root .. "/kong/plugins/gluu-uma-pep",
            ["gluu-metrics"] = host_git_root .. "/kong/plugins/gluu-metrics",
        },
        modules = {
            ["gluu/oxdweb.lua"] = host_git_root .. "/third-party/oxd-web-lua/oxdweb.lua",
            ["gluu/kong-common.lua"] = host_git_root .. "/kong/common/kong-common.lua",
            ["gluu/path-wildcard-tree.lua"] = host_git_root .. "/kong/common/path-wildcard-tree.lua",
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
            ["prometheus.lua"] = host_git_root .. "/third-party/nginx-lua-prometheus/prometheus.lua",
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

    plugin_config.op_url = "http://stub"
    plugin_config.oxd_url = "http://oxd-mock"
    plugin_config.client_id = register_site_response.client_id
    plugin_config.client_secret = register_site_response.client_secret
    plugin_config.oxd_id = register_site_response.oxd_id

    local payload = {
        name = "gluu-openid-connect",
        config = plugin_config,
        service_id = create_service_response.id,
    }
    local payload_json = JSON:encode(payload)

    print"enable plugin for the Service"
    local res, err = sh_ex([[
        curl -v -sS -X POST  --url http://localhost:]], ctx.kong_admin_port,
        [[/plugins/ ]],
        [[ --header 'content-type: application/json;charset=UTF-8' --data ']], payload_json, [[']]
    )
    local plugin_response = JSON:decode(res)

    return register_site_response, plugin_response
end

local function configure_pep_plugin(register_site_response, create_service_response, plugin_config)
    plugin_config.op_url = "http://stub"
    plugin_config.oxd_url = "http://oxd-mock"
    plugin_config.client_id = register_site_response.client_id
    plugin_config.client_secret = register_site_response.client_secret
    plugin_config.oxd_id = register_site_response.oxd_id

    local payload = {
        name = "gluu-uma-pep",
        config = plugin_config,
        service_id = create_service_response.id,
    }

    local payload_json = JSON:encode(payload)

    print"enable plugin for the Service"
    local res, err = sh_ex([[
        curl --fail -v -i -sS -X POST  --url http://localhost:]], ctx.kong_admin_port,
        [[/plugins/ ]],
        [[ --header 'content-type: application/json;charset=UTF-8' --data ']], payload_json, [[']]
    )
end

test("basic", function()
    setup("oxd-model1.lua")
    local cookie_tmp_filename = ctx.cookie_tmp_filename

    local create_service_response = configure_service_route()

    print"test it works"
    sh([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    configure_plugin(create_service_response,{
        authorization_redirect_path = "/callback",
        requested_scopes = {"openid", "email", "profile"},
        max_id_token_age = 14,
        max_id_token_auth_age = 60*60*24,
        logout_path = "/logout_path",
        post_logout_redirect_path_or_url = "/post_logout_redirect_path_or_url"
    })

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
    assert(res:find("x-openid-connect-idtoken", 1, true))
    assert(res:find("x-openid-connect-userinfo", 1, true))

    print"request second time with cookie"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("200", 1, true))
    assert(res:find("x-openid-connect-idtoken", 1, true))
    assert(res:find("x-openid-connect-userinfo", 1, true))

    sh_ex("sleep 15");

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
    assert(res:find("x-openid-connect-idtoken", 1, true))
    assert(res:find("x-openid-connect-userinfo", 1, true))

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
    setup("oxd-model2.lua")
    local cookie_tmp_filename = ctx.cookie_tmp_filename

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

    local register_site_response = configure_plugin(create_service_response,{
        authorization_redirect_path = "/callback",
        requested_scopes = {"openid", "email", "profile"},
        max_id_token_age = 10,
        max_id_token_auth_age = 60*60*24,
        logout_path = "/logout_path",
        post_logout_redirect_path_or_url = "/post_logout_redirect_path_or_url"
    })

    print"Adding uma-pep"
    configure_pep_plugin(register_site_response, create_service_response,
        {
            uma_scope_expression = {
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
            },
            deny_by_default = true,
            obtain_rpt = true
        }
    )

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
    assert(res:find("x-openid-connect-idtoken", 1, true))
    assert(res:find("x-openid-connect-userinfo", 1, true))

    print"request second time with cookie"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("200", 1, true))
    assert(res:find("x-openid-connect-idtoken", 1, true))
    assert(res:find("x-openid-connect-userinfo", 1, true))

    print"check metrics, it should return openid_connect_users_authenticated = 2"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_admin_port,
        [[/gluu-metrics]]
    )
    assert(res:lower():find("gluu_openid_connect_users_authenticated", 1, true))
    assert(res:lower():find(string.lower([[gluu_endpoint_method{endpoint="/page1",method="GET",service="]] .. create_service_response.name .. [["} 3]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_openid_connect_users_authenticated{service="]] .. create_service_response.name .. [["} 2]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_uma_client_granted{consumer="openid_connect_authentication",service="]] .. create_service_response.name .. [["} 2]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_uma_ticket{service="]] .. create_service_response.name .. [["} 1]]), 1, true))

    print"request third time with cookie"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("200", 1, true))
    assert(res:find("x-openid-connect-idtoken", 1, true))
    assert(res:find("x-openid-connect-userinfo", 1, true))

    print"request to another path page2/photos"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page2/photos --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("200", 1, true))
    assert(res:find("x-openid-connect-idtoken", 1, true))
    assert(res:find("x-openid-connect-userinfo", 1, true))

    print"request to another path /path/one/two/image.jpg"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/path/123/image.jpg --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("200", 1, true))
    assert(res:find("x-openid-connect-idtoken", 1, true))
    assert(res:find("x-openid-connect-userinfo", 1, true))

    print"check metrics, it should return openid_connect_users_authenticated = 5"
    local res, err = sh_ex(
        [[curl --fail -i -sS  -X GET --url http://localhost:]], ctx.kong_admin_port,
        [[/gluu-metrics]]
    )
    assert(res:lower():find("gluu_openid_connect_users_authenticated", 1, true))
    assert(res:lower():find(string.lower([[gluu_endpoint_method{endpoint="/page1",method="GET",service="]] .. create_service_response.name .. [["} 4]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_endpoint_method{endpoint="/page2/photos",method="GET",service="]] .. create_service_response.name .. [["} 1]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_endpoint_method{endpoint="/path/123/image.jpg",method="GET",service="]] .. create_service_response.name .. [["} 1]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_openid_connect_users_authenticated{service="]] .. create_service_response.name .. [["} 5]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_uma_client_granted{consumer="openid_connect_authentication",service="]] .. create_service_response.name .. [["} 5]]), 1, true))
    assert(res:lower():find(string.lower([[gluu_uma_ticket{service="]] .. create_service_response.name .. [["} 3]]), 1, true))

    print "deny for tha path which is not registered in UMA resources"
    local res, err = sh_ex([[curl -i -sS  -X GET --url http://localhost:]], ctx.kong_proxy_port,
        [[/todos --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("403", 1, true))

    ctx.print_logs = false
end)

test("OpenID Connect with UMA, PCT", function()
    setup("oxd-model3.lua")
    local cookie_tmp_filename = ctx.cookie_tmp_filename

    local create_service_response = configure_service_route()

    print"test it works"
    sh([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    local register_site_response = configure_plugin(create_service_response,{
        authorization_redirect_path = "/callback",
        requested_scopes = {"openid", "email", "profile"},
        max_id_token_age = 10,
        max_id_token_auth_age = 60*60*24,
        logout_path = "/logout_path",
        post_logout_redirect_path_or_url = "/post_logout_redirect_path_or_url"
    })

    print"Adding uma-pep"
    configure_pep_plugin(register_site_response, create_service_response,
        {
            uma_scope_expression = {
                {
                    path = "/page1",
                    conditions = {
                        {
                            httpMethods = {"GET"},
                        }
                    }
                }
            },
            deny_by_default = false,
            obtain_rpt = true,
            require_id_token = true,
        }
    )

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
    assert(res:find("x-openid-connect-idtoken", 1, true))
    assert(res:find("x-openid-connect-userinfo", 1, true))

    print"request second time with cookie"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("200", 1, true))
    assert(res:find("x-openid-connect-idtoken", 1, true))
    assert(res:find("x-openid-connect-userinfo", 1, true))

    print"request third time with cookie"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("200", 1, true))
    assert(res:find("x-openid-connect-idtoken", 1, true))
    assert(res:find("x-openid-connect-userinfo", 1, true))

    print"just check getting 200 when request comes to post_logout_redirect_path_or_url"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/post_logout_redirect_path_or_url --header 'Host: backend.com']])
    assert(res:find("200", 1, true))

    ctx.print_logs = false
end)

test("OpenID Connect with UMA Claim gathering flow", function()
    setup("oxd-model4.lua")
    local cookie_tmp_filename = ctx.cookie_tmp_filename

    local create_service_response = configure_service_route()

    print"test it works"
    sh([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    local register_site_response = configure_plugin(create_service_response,{
        authorization_redirect_path = "/callback",
        requested_scopes = {"openid", "email", "profile"},
        max_id_token_age = 10,
        max_id_token_auth_age = 60*60*24,
        logout_path = "/logout_path",
        post_logout_redirect_path_or_url = "/post_logout_redirect_path_or_url"
    })

    print"Adding uma-pep"
    configure_pep_plugin(register_site_response, create_service_response,
        {
            uma_scope_expression = {
                {
                    path = "/page1",
                    conditions = {
                        {
                            httpMethods = {"GET"},
                        }
                    }
                }
            },
            deny_by_default = true,
            obtain_rpt = true,
            redirect_claim_gathering_url = true,
            claims_redirect_path = "/claim_gathering_path"
        }
    )

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
    assert(res:find("x-openid-connect-idtoken", 1, true))
    assert(res:find("x-openid-connect-userinfo", 1, true))

        print"request second time with cookie"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("200", 1, true))
    assert(res:find("x-openid-connect-idtoken", 1, true))
    assert(res:find("x-openid-connect-userinfo", 1, true))

    print"request third time with cookie"
    local res, err = sh_ex([[curl -i --fail -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("200", 1, true))
    assert(res:find("x-openid-connect-idtoken", 1, true))
    assert(res:find("x-openid-connect-userinfo", 1, true))

    ctx.print_logs = false
end)

local function update_required_acrs_expression(plugin_id, required_acrs_expression)
    local payload = {
        config = {
            required_acrs_expression = required_acrs_expression
        },
    }
    local payload_json = JSON:encode(payload)

    print"update plugin"
    local res, err = sh_ex([[
        curl --fail -v -i -sS -X PATCH  --url http://localhost:]], ctx.kong_admin_port,
        [[/plugins/]], plugin_id,
        [[ --header 'content-type: application/json;charset=UTF-8' --data ']], payload_json, [[']]
    )
end

test("acr_values testing", function()
    setup("oxd-model5.lua")
    local cookie_tmp_filename = ctx.cookie_tmp_filename

    local create_service_response = configure_service_route()

    print"test it works"
    sh([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    local _, plugin = configure_plugin(create_service_response,{
        authorization_redirect_path = "/callback",
        requested_scopes = {"openid", "email", "profile"},
        max_id_token_age = 10,
        max_id_token_auth_age = 60*60*24,
        logout_path = "/logout_path",
        post_logout_redirect_path_or_url = "/post_logout_redirect_path_or_url",
        required_acrs_expression = {
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
    })

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
    assert(res:find("x-openid-connect-idtoken", 1, true))
    assert(res:find("x-openid-connect-userinfo", 1, true))

    update_required_acrs_expression(plugin.id,
        {
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
        })

    sh_ex("sleep 1")

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
    assert(res:find("x-openid-connect-idtoken", 1, true))
    assert(res:find("x-openid-connect-userinfo", 1, true))

    update_required_acrs_expression(plugin.id,
        {
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
        })


    sh_ex("sleep 1")

    print"acr=auth_ldap_server, plugin should allow because already authenticated with auth_ldap_server"
    local res, err = sh_ex([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/page1 --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("200", 1, true))
    assert(res:find("page1", 1, true))
    assert(res:find("x-openid-connect-idtoken", 1, true))
    assert(res:find("x-openid-connect-userinfo", 1, true))

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
    assert(res:find("x-openid-connect-idtoken", 1, true))
    assert(res:find("x-openid-connect-userinfo", 1, true))

    print"should allow, this path accept any acr"
    local res, err = sh_ex([[curl -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/any_acr --header 'Host: backend.com' -c ]], cookie_tmp_filename,
        [[ -b ]], cookie_tmp_filename)
    assert(res:find("200", 1, true))
    assert(res:find("any_acr", 1, true))
    assert(res:find("x-openid-connect-idtoken", 1, true))
    assert(res:find("x-openid-connect-userinfo", 1, true))

    ctx.print_logs = false -- comment it out if want to see logs
end)

test("not enough acr", function()
    setup("oxd-model6.lua")
    local cookie_tmp_filename = ctx.cookie_tmp_filename

    local create_service_response = configure_service_route()

    print"test it works"
    sh([[curl --fail -i -sS -X GET --url http://localhost:]],
        ctx.kong_proxy_port, [[/ --header 'Host: backend.com']])

    local _, plugin = configure_plugin(create_service_response,{
        authorization_redirect_path = "/callback",
        requested_scopes = {"openid", "email", "profile"},
        max_id_token_age = 10,
        max_id_token_auth_age = 60*60*24,
        logout_path = "/logout_path",
        post_logout_redirect_path_or_url = "/post_logout_redirect_path_or_url",
        required_acrs_expression = {
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
    })

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
