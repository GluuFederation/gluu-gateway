local utils = require"test_utils"
local sh, stdout, stderr, sleep, sh_ex, sh_until_ok =
utils.sh, utils.stdout, utils.stderr, utils.sleep, utils.sh_ex, utils.sh_until_ok

local host_git_root = os.getenv "HOST_GIT_ROOT"
local git_root = os.getenv "GIT_ROOT"

local function docker_run()
    return stdout("docker run -d --rm -p 80",
        " -v ", host_git_root, "/t/specs/path-wildcard-tree/test.nginx:/usr/local/openresty/nginx/conf/nginx.conf:ro ",
        " -v ", host_git_root, "/lib/gluu/path-wildcard-tree.lua:/usr/local/openresty/lualib/gluu/path-wildcard-tree.lua:ro ",
        " -v ", host_git_root, "/t/specs/path-wildcard-tree/path-wildcard-tree-tester.lua:/usr/local/openresty/lualib/gluu/path-wildcard-tree-tester.lua:ro ",
        " openresty/openresty:alpine")
end

local nginx_port

local function addPath(path)
    return sh_ex([[curl -sS -v --fail -m 5 -L -X POST -H "Content-Type: text/plain" --data "]]
        ,path,[["  "127.0.0.1:]], nginx_port, "/add\"")
end

local function matchPath(path)
    return sh_ex([[curl -sS -v --fail -m 5 -L -X POST -H "Content-Type: text/plain" --data "]]
        ,path,[["  "127.0.0.1:]], nginx_port, "/match\"")
end

test("basic tests", function()

    local container_id = docker_run()

    local print_logs = true
    finally(function()
        -- useful for debug
        if print_logs then
            sh("docker logs ", container_id)
        end

        sh("docker stop ", container_id)
    end)

    nginx_port = stdout("docker inspect --format='{{(index (index .NetworkSettings.Ports \"80/tcp\") 0).HostPort}}' ", container_id)

    addPath("/folder/file.ext")

    local res, err = matchPath("/folder/file.ext")
    assert(res:find("/folder/file.ext", 1 , true))

    local res, err = matchPath("/folder/file")
    assert(res:find("Not match"))

    addPath("/folder/?/file")

    local res, err = matchPath("/folder/?/file")
    assert(res:find("/folder/?/file", 1 , true))

    local res, err = matchPath("/folder/xxx/file")
    assert(res:find("/folder/?/file", 1 , true))

    addPath("/path/??")

    local res, err = matchPath("/path/??")
    assert(res:find("/path/??", 1 , true))

    local res, err = matchPath("/path/xxx/file")
    assert(res:find("/path/??", 1 , true))

    local res, err = matchPath("/path/")
    assert(res:find("/path/??", 1 , true))

    -- slash is required before multiple wildcards placeholder
    local res, err = matchPath("/path")
    assert(res:find("Not match"))

    addPath("/path/??/image.jpg")

    local res, err = matchPath("/path/??/image.jpg")
    assert(res:find("/path/??/image.jpg", 1 , true))

    local res, err = matchPath("/path/one/two/image.jpg")
    assert(res:find("/path/??/image.jpg", 1 , true))

    local res, err = matchPath("/path/image.jpg")
    assert(res:find("/path/??/image.jpg", 1 , true))

    addPath("/path/?/image.jpg")

    local res, err = matchPath("/path/?/image.jpg")
    assert(res:find("/path/?/image.jpg", 1 , true))

    -- ensure wildcard has a prioroty on multiple wildcard
    local res, err = matchPath("/path/xxx/image.jpg")
    assert(res:find("/path/?/image.jpg", 1 , true))

    addPath("/path/{abc|xyz}/image.jpg")

    local res, err = matchPath("/path/abc/image.jpg")
    assert(res:find("/path/{abc|xyz}/image.jpg", 1 , true))

    local res, err = matchPath("/path/xyz/image.jpg")
    assert(res:find("/path/{abc|xyz}/image.jpg", 1 , true))

    -- regexp doesn't match, wildcard does
    local res, err = matchPath("/path/123/image.jpg")
    assert(res:find("/path/?/image.jpg", 1 , true))

    addPath("/users/?/{todos|photos}")

    local res, err = matchPath("/users/123/todos")
    assert(res:find("/users/?/{todos|photos}", 1 , true))

    addPath("/users/?/{todos|photos}/?")
    addPath("/users/?/{todos|photos}/123")

    local res, err = matchPath("/users/123/todos/")
    assert(res:find("/users/?/{todos|photos}/?", 1 , true))

    local res, err = matchPath("/users/123/todos/321")
    assert(res:find("/users/?/{todos|photos}/?", 1 , true))

    local res, err = matchPath("/users/123/todos/123")
    assert(res:find("/users/?/{todos|photos}/123", 1 , true))

    print_logs = false
end)
