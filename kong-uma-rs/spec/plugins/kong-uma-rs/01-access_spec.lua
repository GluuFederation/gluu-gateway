local helpers = require "spec.helpers"

describe("kong-uma-rs plugin", function()
    local proxy_client
    local admin_client
    local timeout = 6000

    setup(function()
        local api1 = assert(helpers.dao.apis:insert {
            name = "mock",
            upstream_url = "http://mockbin.com",
            hosts = { "mock.org" }
        })
        print("Api created:")
        for k, v in pairs(api1) do
            print(k, ": ", v)
        end
        assert(helpers.dao.plugins:insert {
            name = "kong-uma-rs",
            api_id = api1.id,
            config = {
                oxd_host = "http://localhost:8553",
                uma_server_host = "https://gluu.local.org",
                protection_document = "[{\"path\":\"/posts\",\"conditions\":[{\"httpMethods\":[\"GET\",\"POST\"],\"scope_expression\":{\"rule\":{\"or\":[{\"var\":0}]},\"data\":[\"https://jsonplaceholder.typicode.com\"]}}]},{\"path\":\"/comments\",\"conditions\":[{\"httpMethods\":[\"GET\"],\"scope_expression\":{\"rule\":{\"and\":[{\"var\":0}]},\"data\":[\"https://jsonplaceholder.typicode.com\"]}}]}]"
            }
        })

        -- start Kong with your testing Kong configuration (defined in "spec.helpers")
        assert(helpers.start_kong())
        print("Kong started")

        admin_client = helpers.admin_client(timeout)
    end)

    teardown(function()
        if admin_client then
            admin_client:close()
        end

        helpers.stop_kong()
        print("Kong stopped")
    end)

    before_each(function()
        proxy_client = helpers.proxy_client(timeout)
    end)

    after_each(function()
        if proxy_client then
            proxy_client:close()
        end
    end)

    describe("Unauthorized", function()
        it("401 Unauthorized with permission ticket when token is not present", function()
            local res = assert(proxy_client:send {
                method = "GET",
                path = "/posts",
                headers = {
                    ["Host"] = "mock.org"
                }
            })
            local wwwAuthenticate = res.headers["WWW-Authenticate"]
            assert.is_truthy(string.find(wwwAuthenticate, "ticket"))
            assert.res_status(401, res)
        end)

        it("401 Unauthorized with permission ticket when token is present but invalid or oauth2 AT", function()
            local res = assert(proxy_client:send {
                method = "GET",
                path = "/posts",
                headers = {
                    ["Host"] = "mock.org",
                    ["Authorization"] = "Bearer dfdff5654tryhgfht",
                }
            })
            local wwwAuthenticate = res.headers["WWW-Authenticate"]
            assert.is_truthy(string.find(wwwAuthenticate, "ticket"))
            assert.res_status(401, res)
        end)

        it("200 Authorized with UMA-Warning header from upstream URL when path is not protected by UMA-RS", function()
            local res = assert(proxy_client:send {
                method = "GET",
                path = "/todos", -- Unprotected path
                headers = {
                    ["Host"] = "mock.org",
                    ["Authorization"] = "Bearer dfdff5654tryhgfht",
                }
            })
            local UMAWarning = res.headers["UMA-Warning"]
            print(UMAWarning)
            assert.equals(true, UMAWarning ~= nil)
            assert.res_status(200, res)
        end)
    end)
end)

