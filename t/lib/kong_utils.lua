local utils = require"test_utils"
local JSON = require"JSON"
local sh, stdout, stderr, sleep, sh_ex, sh_until_ok =
    utils.sh, utils.stdout, utils.stderr, utils.sleep, utils.sh_ex, utils.sh_until_ok
local pl_file = require"pl.file"
local pl_path = require "pl.path"
local pl_tmpname = pl_path.tmpname


local _M = {}

local kong_image = "kong:2.0.0-alpine"
local postgress_image = "postgres:9.5"
local openresty_image = "openresty/openresty:alpine"

local host_git_root = os.getenv"HOST_GIT_ROOT"
local git_root = os.getenv"GIT_ROOT"
local gg_image_id = os.getenv"GG_IMAGE_ID"

_M.docker_unique_network = function()
    local ctx = _G.ctx
    local unique_network_name = stdout("uuidgen")
    sh("docker network create --driver bridge ", unique_network_name)
    ctx.finalizeres[#ctx.finalizeres + 1] = function()
        sh("docker network rm  ", unique_network_name)
    end
    _G.ctx.network_name = unique_network_name
end

local function build_plugins_list(plugins)
    assert(type(plugins) == "table")
    local plugin_list = {}
    plugin_list[1] = [[bundled]]
    for k,v in pairs(plugins) do
        plugin_list[#plugin_list + 1] = k
    end

    local result = table.concat(plugin_list, ",")
    print("plugin list: ", result)
    return result
end

local function build_plugins_volumes(plugins)
    assert(type(plugins) == "table")
    local items = {}
    for k,v in pairs(plugins) do
        items[#items + 1] =
            " -v " .. v .. ":" .. "/usr/local/openresty/lualib/kong/plugins/" .. k .. " "
    end

    local result = table.concat(items)
    print("plugin volumes: ", result)
    return result
end

local function build_modules_volumes(modules)
    assert(type(modules) == "table")
    local items = {}
    for k,v in pairs(modules) do
        items[#items + 1] =
        " -v " .. v .. ":" .. "/usr/local/openresty/lualib/" .. k .. " "
    end

    local result = table.concat(items)
    print("modules volumes: ", result)
    return result
end

local function build_volumes(volumes)
    assert(type(volumes) == "table")
    local items = {}
    for k,v in pairs(volumes) do
        items[#items + 1] =
        " -v " .. v .. ":" .. k .. " "
    end

    local result = table.concat(items)
    print("volumes: ", result)
    return result
end


local function check_container_is_running(id, name)
    -- https://stackoverflow.com/questions/24544288/how-to-detect-if-docker-run-succeeded-programmatically
    sleep(1)
    local ok = stdout("docker inspect -f {{.State.Running}} ", id)
    if ok == "false" then
        ctx.finalizeres[#ctx.finalizeres + 1] = function()
            sh("docker rm -v  ", id, " || true")
        end
        error(name .. " container failed to start")
    end

    ctx.finalizeres[#ctx.finalizeres + 1] = function()
        sh("docker stop  ", id, " || true")
        sh("docker rm -v  ", id, " || true")
    end
end

_M.kong_postgress_custom_plugins = function(opts)
    local ctx = _G.ctx
    assert(ctx.network_name)
    ctx.postgress_id = stdout("docker run -p 5432 -d ",
        " --network=", ctx.network_name,
        " -e POSTGRES_USER=kong ",
        " -e POSTGRES_DB=kong ",
        " --name kong-database ", -- TODO avoid hardcoded names
        opts.postgress_image or postgress_image
    )

    check_container_is_running(ctx.postgress_id, "postgress")

    -- TODO use Postgress client and try to connect
    sleep(30)

    local plugins = opts.plugins or {}
    local modules = opts.modules or {}
    local volumes = opts.volumes or {}

    -- run in foreground to get a chance to finish
    sh("docker run --rm ",
        " --network=", ctx.network_name,
        " -e KONG_DATABASE=postgres ",
        " -e KONG_PG_HOST=kong-database ",
        " -e KONG_LOG_LEVEL=debug ",
        " -e KONG_NGINX_HTTP_LUA_SHARED_DICT=\"gluu_metrics 1m\" ",
        " -e KONG_PROXY_ACCESS_LOG=/dev/stdout ",
        " -e KONG_ADMIN_ACCESS_LOG=/dev/stdout ",
        " -e KONG_PROXY_ERROR_LOG=/dev/stderr ",
        " -e KONG_ADMIN_ERROR_LOG=/dev/stderr ",
        " -e KONG_PLUGINS=", build_plugins_list(plugins), " ",
        build_plugins_volumes(plugins),
        build_modules_volumes(modules),
        build_volumes(volumes),
        opts.kong_image or kong_image,
        " kong migrations bootstrap"
    )

    -- TODO something better?
    sleep(2)

    ctx.kong_id = stdout("docker run -p 8000 -p 8001 -d ",
        " --network=", ctx.network_name,
        " -e KONG_NGINX_WORKER_PROCESSES=1 ", -- important! oxd-mock logic assume one worker
        " -e KONG_NGINX_HTTP_LUA_SHARED_DICT=\"gluu_metrics 1m\" ",
        " -e KONG_DATABASE=postgres ",
        " -e KONG_PG_HOST=kong-database ",
        " -e KONG_PG_DATABASE=kong ",
        " -e KONG_ADMIN_LISTEN=0.0.0.0:8001 ",
        " -e KONG_LOG_LEVEL=debug ",
        " -e KONG_PROXY_ACCESS_LOG=/dev/stdout ",
        " -e KONG_ADMIN_ACCESS_LOG=/dev/stdout ",
        " -e KONG_PROXY_ERROR_LOG=/dev/stderr ",
        " -e KONG_ADMIN_ERROR_LOG=/dev/stderr ",
        " -e KONG_PLUGINS=", build_plugins_list(plugins), " ",
        build_plugins_volumes(plugins),
        build_modules_volumes(modules),
        build_volumes(volumes),
        opts.kong_image or kong_image
    )

    check_container_is_running(ctx.kong_id, "kong")

    ctx.kong_admin_port =
        stdout("docker inspect --format='{{(index (index .NetworkSettings.Ports \"8001/tcp\") 0).HostPort}}' ", ctx.kong_id)
    ctx.kong_proxy_port =
        stdout("docker inspect --format='{{(index (index .NetworkSettings.Ports \"8000/tcp\") 0).HostPort}}' ", ctx.kong_id)

    local res, err = sh_ex("/opt/wait-for-http-ready.sh ", "127.0.0.1:", ctx.kong_admin_port)
    local res, err = sh_ex("/opt/wait-for-http-ready.sh ", "127.0.0.1:", ctx.kong_proxy_port)
end

_M.kong_postgress = function()
    local ctx = _G.ctx

    assert(ctx.network_name)
    ctx.postgress_id = stdout("docker run -p 5432 -d ",
        " --network=", ctx.network_name,
        " -e POSTGRES_USER=kong ",
        " -e POSTGRES_DB=kong ",
        " --name kong-database ", -- TODO avoid hardcoded names
        postgress_image
    )

    check_container_is_running(ctx.postgress_id, "postgress")

    -- TODO use Postgress client and try to connect
    sleep(30)

    -- run in foreground to get a chance to finish
    sh("docker run --rm ",
        " --network=", ctx.network_name,
        " -e KONG_DATABASE=postgres ",
        " -e KONG_PG_HOST=kong-database ",
        " -e KONG_LOG_LEVEL=debug ",
        gg_image_id,
        " kong migrations bootstrap"
    )

    -- TODO something better?
    sleep(2)

    ctx.kong_id = stdout("docker run -p 8000 -p 8001 -d ",
        " --network=", ctx.network_name,
        " -e KONG_NGINX_WORKER_PROCESSES=1 ", -- important! oxd-mock logic assume one worker
        " -e KONG_DATABASE=postgres ",
        " -e KONG_PG_HOST=kong-database ",
        " -e KONG_PG_DATABASE=kong ",
        " -e KONG_ADMIN_LISTEN=0.0.0.0:8001 ",
        " -e KONG_LOG_LEVEL=debug ",
        gg_image_id
    )

    check_container_is_running(ctx.kong_id, "kong")

    ctx.kong_admin_port =
    stdout("docker inspect --format='{{(index (index .NetworkSettings.Ports \"8001/tcp\") 0).HostPort}}' ", ctx.kong_id)
    ctx.kong_proxy_port =
    stdout("docker inspect --format='{{(index (index .NetworkSettings.Ports \"8000/tcp\") 0).HostPort}}' ", ctx.kong_id)

    local res, err = sh_ex("/opt/wait-for-http-ready.sh ", "127.0.0.1:", ctx.kong_admin_port)
    local res, err = sh_ex("/opt/wait-for-http-ready.sh ", "127.0.0.1:", ctx.kong_proxy_port)
end


_M.gg_db_less = function(config, plugins, wait_for_stop)

    local config_json_tmp_filename = utils.dump_table_to_tmp_json_file(config)
    ctx.finalizeres[#ctx.finalizeres + 1] = function()
        pl_file.delete(config_json_tmp_filename)
    end

    ctx.kong_id = stdout("docker run -p 8000 -p 8001 -d ",
        " --network=", ctx.network_name,
        " -e KONG_NGINX_WORKER_PROCESSES=1 ", -- important! oxd-mock logic assume one worker
        " -e KONG_DECLARATIVE_CONFIG=/config.yml ",
        " -v ", config_json_tmp_filename, ":/config.yml ",
        " -e KONG_DATABASE=off ",
        " -e KONG_ADMIN_LISTEN=0.0.0.0:8001 ",
        " -e KONG_PROXY_LISTEN=0.0.0.0:8000 ",
        " -e KONG_LOG_LEVEL=debug ",
        plugins and build_plugins_volumes(plugins) or "",
        gg_image_id
    )

    if wait_for_stop then
        sh_ex("docker wait ", ctx.kong_id)
        return
    end

    check_container_is_running(ctx.kong_id, "kong")

    ctx.kong_admin_port =
    stdout("docker inspect --format='{{(index (index .NetworkSettings.Ports \"8001/tcp\") 0).HostPort}}' ", ctx.kong_id)
    ctx.kong_proxy_port =
    stdout("docker inspect --format='{{(index (index .NetworkSettings.Ports \"8000/tcp\") 0).HostPort}}' ", ctx.kong_id)

    local res, err = sh_ex("/opt/wait-for-http-ready.sh ", "127.0.0.1:", ctx.kong_admin_port)
    local res, err = sh_ex("/opt/wait-for-http-ready.sh ", "127.0.0.1:", ctx.kong_proxy_port)
end

_M.backend = function(image)
    local ctx = _G.ctx
    ctx.backend_id = stdout("docker run -p 80 -d ",
        " --network=", ctx.network_name,
        " -v ", ctx.host_git_root, "/t/lib/backend.nginx:/usr/local/openresty/nginx/conf/nginx.conf:ro ",
        " --net-alias=backend ",
        image or openresty_image
    )

    check_container_is_running(ctx.backend_id, "backend")

    ctx.backend_port =
        stdout("docker inspect --format='{{(index (index .NetworkSettings.Ports \"80/tcp\") 0).HostPort}}' ", ctx.backend_id)

    local res, err = sh_ex("/opt/wait-for-http-ready.sh ", "127.0.0.1:", ctx.backend_port)
end

_M.oxd_mock = function(model, image)
    local ctx = _G.ctx
    ctx.oxd_id = stdout("docker run -p 80 -d ",
        " --network=", ctx.network_name,
        " -v ", ctx.host_git_root, "/t/lib/oxd-mock.lua:/usr/local/openresty/lualib/gluu/oxd-mock.lua:ro ",
        " -v ", ctx.host_git_root, "/t/lib/oxd-mock.nginx:/usr/local/openresty/nginx/conf/nginx.conf:ro ",
        " -v ", model, ":/usr/local/openresty/lualib/gluu/oxd-model.lua:ro ",
        " -v ", ctx.host_git_root, "/third-party/lua-resty-jwt/lib/resty/jwt.lua:/usr/local/openresty/lualib/resty/jwt.lua:ro ",
        " -v ", ctx.host_git_root, "/third-party/lua-resty-jwt/lib/resty/evp.lua:/usr/local/openresty/lualib/resty/evp.lua:ro ",
        " -v ", ctx.host_git_root, "/third-party/lua-resty-jwt/lib/resty/jwt-validators.lua:/usr/local/openresty/lualib/resty/jwt-validators.lua:ro ",
        " -v ", ctx.host_git_root, "/third-party/lua-resty-hmac/lib/resty/hmac.lua:/usr/local/openresty/lualib/resty/hmac.lua:ro ",
        " --net-alias=oxd-mock ",

        image or openresty_image
    )

    check_container_is_running(ctx.oxd_id, "oxd")

    ctx.oxd_port =
        stdout("docker inspect --format='{{(index (index .NetworkSettings.Ports \"80/tcp\") 0).HostPort}}' ", ctx.oxd_id)

    local res, err = sh_ex("/opt/wait-for-http-ready.sh ", "127.0.0.1:", ctx.oxd_port)
end

_M.opa = function()
    local image = "openpolicyagent/opa:0.10.5"
    local ctx = _G.ctx
    ctx.opa_id = stdout("docker run -p 8181 -d ",
        " --network=", ctx.network_name,
        " --net-alias=opa ",
        image,
        " run --server "
    )

    check_container_is_running(ctx.opa_id, "opa")

    ctx.opa_port =
        stdout("docker inspect --format='{{(index (index .NetworkSettings.Ports \"8181/tcp\") 0).HostPort}}' ", ctx.opa_id)

    local res, err = sh_ex("/opt/wait-for-http-ready.sh ", "127.0.0.1:", ctx.opa_port)
end

_M.configure_metrics_plugin = function(plugin_config)
    local payload = {
        name = "gluu-metrics",
        config = plugin_config,
    }
    local payload_json = JSON:encode(payload)

    print"enable metrics plugin globally"
    local res, err = sh_ex([[
        curl -v -i -sS -X POST  --url http://localhost:]], ctx.kong_admin_port,
        [[/plugins/ ]],
        [[ --header 'content-type: application/json;charset=UTF-8' --data ']], payload_json, [[']]
    )
end

_M.configure_ip_restrict_plugin = function(create_service_response, plugin_config)
    local payload = {
        name = "ip-restriction",
        config = plugin_config,
        service = { id = create_service_response.id},
    }
    local payload_json = JSON:encode(payload)

    print"enable ip restriction plugin for the Service"
    local res, err = sh_ex([[
        curl --fail -sS -X POST --url http://localhost:]], ctx.kong_admin_port,
        [[/plugins/ ]],
        [[ --header 'content-type: application/json;charset=UTF-8' --data ']], payload_json, [[']]
    )

    return JSON:decode(res)
end

_M.setup_postgress = function(finally, model)
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

    _M.docker_unique_network()
    _M.kong_postgress()
    _M.backend()
    if model then
        _M.oxd_mock(model)
    end
end

_M.configure_service_route = function(service_name, service, route)
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

_M.setup_db_less = function(finally, model, create_cookie_tmp_filename)
    _G.ctx = {}
    local ctx = _G.ctx
    ctx.finalizeres = {}
    ctx.host_git_root = host_git_root
    if create_cookie_tmp_filename then
        ctx.cookie_tmp_filename = pl_tmpname()
    end

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

        if create_cookie_tmp_filename then
            pl_file.delete(ctx.cookie_tmp_filename)
        end
    end)

    _M.docker_unique_network()
    if model then
        _M.oxd_mock(model)
    end
    _M.backend()
end

_M.register_site = function()
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

    return register_site_response
end

_M.register_site_get_client_token = function()
    local register_site_response = _M.register_site()

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

    return register_site_response, response.access_token
end

_M.configure_oauth_auth_plugin = function(create_service_response, plugin_config)
    local register_site = {
        scope = { "openid", "uma_protection" },
        op_host = "just_stub",
        authorization_redirect_uri = "https://client.example.com/cb",
        client_name = "demo plugin",
        grant_types = { "client_credentials" }
    }
    local register_site_json = JSON:encode(register_site)

    local res, err = sh_ex([[curl --fail -v -sS -X POST --url http://localhost:]], ctx.oxd_port,
        [[/register-site --header 'Content-Type: application/json' --data ']],
        register_site_json, [[']])
    local register_site_response = JSON:decode(res)

    local get_client_token = {
        op_host = "just_stub",
        client_id = register_site_response.client_id,
        client_secret = register_site_response.client_secret,
    }

    local get_client_token_json = JSON:encode(get_client_token)

    local res, err = sh_ex([[curl --fail -v -sS -X POST --url http://localhost:]], ctx.oxd_port,
        [[/get-client-token --header 'Content-Type: application/json' --data ']],
        get_client_token_json, [[']])
    local response = JSON:decode(res)


    plugin_config.op_url = "http://stub"
    plugin_config.oxd_url = "http://oxd-mock"
    plugin_config.client_id = register_site_response.client_id
    plugin_config.client_secret = register_site_response.client_secret
    plugin_config.oxd_id = register_site_response.oxd_id

    local payload = {
        name = "gluu-oauth-auth",
        config = plugin_config,
        service = { id = create_service_response.id },
    }
    local payload_json = JSON:encode(payload)

    print "enable plugin for the Service"
    local res, err = sh_ex([[
        curl -v -i -sS -X POST  --url http://localhost:]], ctx.kong_admin_port,
        [[/plugins/ ]],
        [[ --header 'content-type: application/json;charset=UTF-8' --data ']], payload_json, [[']])

    return register_site_response, response.access_token
end

_M.configure_oauth_pep_plugin = function(register_site_response, create_service_response, plugin_config, disableFail)
    if plugin_config.oauth_scope_expression then
        plugin_config.oauth_scope_expression = JSON:encode(plugin_config.oauth_scope_expression)
    end

    plugin_config.op_url = "http://stub"
    plugin_config.oxd_url = "http://oxd-mock"
    plugin_config.client_id = register_site_response.client_id
    plugin_config.client_secret = register_site_response.client_secret
    plugin_config.oxd_id = register_site_response.oxd_id

    local payload = {
        name = "gluu-oauth-pep",
        config = plugin_config,
        service = { id = create_service_response.id},
    }
    local payload_json = JSON:encode(payload)

    print"enable plugin for the Service"
    local res, err = sh_ex([[
        curl ]], (disableFail and "" or "--fail") ,[[ -v -i -sS -X POST  --url http://localhost:]], ctx.kong_admin_port,
        [[/plugins/ ]],
        [[ --header 'content-type: application/json;charset=UTF-8' --data ']], payload_json, [[']]
    )
    return res, err
end

_M.configure_uma_auth_plugin = function(create_service_response, plugin_config)
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

    -- configure gluu-uma-auth
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

_M.configure_uma_pep_plugin = function(register_site_response, create_service_response, plugin_config, consumer_id)
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

_M.configure_openid_connect_plugin = function(create_service_response, plugin_config)
    if plugin_config.required_acrs_expression then
        plugin_config.required_acrs_expression = JSON:encode(plugin_config.required_acrs_expression)
    end

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
        service = { id = create_service_response.id},
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

_M.update_openid_connect_required_acrs_expression = function(plugin_id, required_acrs_expression)
    local required_acrs_expression_json = JSON:encode(required_acrs_expression)
    local payload = {
        config = {
            required_acrs_expression = required_acrs_expression_json
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

_M.unset_openid_connect_required_acrs_expression = function(plugin_id)
    local payload = [[{
        "config": { "required_acrs_expression" : null }
    }]]

    print"unset_required_acrs_expression"
    local res, err = sh_ex([[
        curl --fail -v -i -sS -X PATCH  --url http://localhost:]], ctx.kong_admin_port,
        [[/plugins/]], plugin_id,
        [[ --header 'content-type: application/json;charset=UTF-8' --data ']], payload, [[']]
    )
end

_M.db_less_reconfigure = function(config)

    local payload = JSON:encode(config)

    local res, err = sh_ex([[
        curl --fail -v -i -sS -X POST --url http://localhost:]], ctx.kong_admin_port,
        [[/config --header 'content-type: application/json;charset=UTF-8' --data ']], payload, [[']]
    )

    sleep(2)
end

return _M
