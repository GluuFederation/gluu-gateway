-- gluu-oauth2-rs plugin test cases
-- Test cases with combination of gluu-oauth2-client-auth and gluu-oauth2-rs are in gluu-oauth2-client-auth plugin.
local helpers = require "spec.helpers"
local oxd = require "oxdweb"

local function is_empty(s)
    return s == nil or s == ''
end

describe("gluu-oauth2-rs plugin", function()
    local proxy_client
    local admin_client
    local plugin
    local timeout = 6000

    setup(function()
        local api = assert(helpers.dao.apis:insert {
            name = "json",
            upstream_url = "https://jsonplaceholder.typicode.com",
            hosts = { "jsonplaceholder.typicode.com" }
        })
        print("Api created:")
        for k, v in pairs(api) do
            print(k, ": ", v)
        end
        plugin = assert(helpers.dao.plugins:insert {
            name = "gluu-oauth2-rs",
            api_id = api.id,
            config = {
                oxd_host = "http://localhost:8553",
                uma_server_host = "https://gluu.local.org",
                protection_document = "[{\"path\":\"/posts\",\"conditions\":[{\"httpMethods\":[\"GET\",\"POST\"],\"scope_expression\":{\"rule\":{\"or\":[{\"var\":0}]},\"data\":[\"https://jsonplaceholder.typicode.com\"]}}]},{\"path\":\"/comments\",\"conditions\":[{\"httpMethods\":[\"GET\"],\"scope_expression\":{\"rule\":{\"and\":[{\"var\":0}]},\"data\":[\"https://jsonplaceholder.typicode.com\"]}}]}]"
            }
        })
        print("\nPlugin configured")
        for k, v in pairs(plugin) do
            print(k, ": ", v)
            if k == 'config' then
                for sk, sv in pairs(v) do
                    print(sk, ": ", sv)
                end
            end
        end
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
                    ["Host"] = "jsonplaceholder.typicode.com"
                }
            })
            local wwwAuthenticate = res.headers["WWW-Authenticate"]
            assert.is_truthy(string.find(wwwAuthenticate, "ticket"))
            assert.res_status(401, res)
        end)

        it("401 Unauthorized with permission ticket when token is invalid", function()
            local res = assert(proxy_client:send {
                method = "GET",
                path = "/posts",
                headers = {
                    ["Host"] = "jsonplaceholder.typicode.com",
                    ["Authorization"] = "Bearer 39cd86e5-ca17-4936-a9b7-deac998431fb"
                }
            })
            assert.res_status(401, res)
        end)
    end)
end)

