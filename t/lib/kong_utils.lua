local utils = require"test_utils"
local sh, stdout, stderr, sleep, sh_ex, sh_until_ok =
    utils.sh, utils.stdout, utils.stderr, utils.sleep, utils.sh_ex, utils.sh_until_ok


local _M = {}

local kong_image = "kong:0.14.1-alpine"
local postgress_image = "postgres:9.5"
local openresty_image = "openresty/openresty:alpine"
--local oxd_image = "gluu/oxd:4.0-beta-1"

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

    -- https://stackoverflow.com/questions/24544288/how-to-detect-if-docker-run-succeeded-programmatically
    check_container_is_running(ctx.postgress_id, "postgress")

    -- TODO use Postgress client and try to connect
    sleep(30)

    local plugins = opts.plugins or {}
    local modules = opts.modules or {}

    -- run in foreground to get a chance to finish
    sh("docker run --rm ",
        " --network=", ctx.network_name,
        " -e KONG_DATABASE=postgres ",
        " -e KONG_PG_HOST=kong-database ",
        " -e KONG_LOG_LEVEL=debug ",
        " -e KONG_NGINX_HTTP_LUA_SHARED_DICT=\"gluu_metrics 1M\" ",
        " -e KONG_PROXY_ACCESS_LOG=/dev/stdout ",
        " -e KONG_ADMIN_ACCESS_LOG=/dev/stdout ",
        " -e KONG_PROXY_ERROR_LOG=/dev/stderr ",
        " -e KONG_ADMIN_ERROR_LOG=/dev/stderr ",
        " -e KONG_PLUGINS=\"bundled\",", build_plugins_list(plugins), " ",
        build_plugins_volumes(plugins),
        build_modules_volumes(modules),
        opts.kong_image or kong_image,
        " kong migrations up"
    )

    -- TODO something better?
    sleep(2)

    ctx.kong_id = stdout("docker run -p 8000 -p 8001 -d ",
        " --network=", ctx.network_name,
        " -e KONG_NGINX_WORKER_PROCESSES=1 ", -- important! oxd-mock logic assume one worker
        " -e KONG_NGINX_HTTP_LUA_SHARED_DICT=\"gluu_metrics 1M\" ",
        " -e KONG_DATABASE=postgres ",
        " -e KONG_PG_HOST=kong-database ",
        " -e KONG_PG_DATABASE=kong ",
        " -e KONG_ADMIN_LISTEN=0.0.0.0:8001 ",
        " -e KONG_LOG_LEVEL=debug ",
        " -e KONG_PROXY_ACCESS_LOG=/dev/stdout ",
        " -e KONG_ADMIN_ACCESS_LOG=/dev/stdout ",
        " -e KONG_PROXY_ERROR_LOG=/dev/stderr ",
        " -e KONG_ADMIN_ERROR_LOG=/dev/stderr ",
        " -e KONG_PLUGINS=\"bundled\",", build_plugins_list(plugins), " ",
        build_plugins_volumes(plugins),
        build_modules_volumes(modules),
        opts.kong_image or kong_image
    )

    check_container_is_running(ctx.kong_id, "kong")

    ctx.kong_admin_port =
        stdout("docker inspect --format='{{(index (index .NetworkSettings.Ports \"8001/tcp\") 0).HostPort}}' ", ctx.kong_id)
    ctx.kong_proxy_port =
        stdout("docker inspect --format='{{(index (index .NetworkSettings.Ports \"8000/tcp\") 0).HostPort}}' ", ctx.kong_id)

    local res, err = sh_ex("/opt/wait-for-it/wait-for-it.sh ", "127.0.0.1:", ctx.kong_admin_port)
    local res, err = sh_ex("/opt/wait-for-it/wait-for-it.sh ", "127.0.0.1:", ctx.kong_proxy_port)

end

_M.backend = function(image)
    local ctx = _G.ctx
    ctx.backend_id = stdout("docker run -p 80 -d ",
        " --network=", ctx.network_name,
        " -v ", ctx.host_git_root, "/t/lib/backend.nginx:/usr/local/openresty/nginx/conf/nginx.conf:ro ",
        " --name backend ", -- TODO avoid hardcoded name
        image or openresty_image
    )

    check_container_is_running(ctx.backend_id, "backend")

    ctx.backend_port =
        stdout("docker inspect --format='{{(index (index .NetworkSettings.Ports \"80/tcp\") 0).HostPort}}' ", ctx.backend_id)

    local res, err = sh_ex("/opt/wait-for-it/wait-for-it.sh ", "127.0.0.1:", ctx.backend_port)
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
        " --name oxd-mock ", -- TODO avoid hardcoded name
        image or openresty_image
    )

    check_container_is_running(ctx.oxd_id, "oxd")

    ctx.oxd_port =
        stdout("docker inspect --format='{{(index (index .NetworkSettings.Ports \"80/tcp\") 0).HostPort}}' ", ctx.oxd_id)

    local res, err = sh_ex("/opt/wait-for-it/wait-for-it.sh ", "127.0.0.1:", ctx.oxd_port)
end

_M.opa = function()
    local image = "openpolicyagent/opa:0.10.5"
    local ctx = _G.ctx
    ctx.opa_id = stdout("docker run -p 8181 -d ",
        " --network=", ctx.network_name,
        " --name opa ", -- TODO avoid hardcoded name
        image,
        " run --server "
    )

    check_container_is_running(ctx.opa_id, "opa")

    ctx.opa_port =
        stdout("docker inspect --format='{{(index (index .NetworkSettings.Ports \"8181/tcp\") 0).HostPort}}' ", ctx.opa_id)

    local res, err = sh_ex("/opt/wait-for-it/wait-for-it.sh ", "127.0.0.1:", ctx.opa_port)
end


return _M
