local helpers = require "spec.helpers"
local oxd = require "oxdweb"

local function is_empty(s)
    return s == nil or s == ''
end

describe("gluu-oauth2-client-auth plugin", function()
    local proxy_client
    local admin_client
    local oauth2_consumer
    local plugin
    local timeout = 6000

    setup(function()
        local api = assert(helpers.dao.apis:insert {
            name = "json",
            upstream_url = "https://jsonplaceholder.typicode.com",
            hosts = { "jsonplaceholder.typicode.com" }
        })

        print("----------- Api created ----------- ")
        for k, v in pairs(api) do
            print(k, ": ", v)
        end
        plugin = assert(helpers.dao.plugins:insert {
            name = "gluu-oauth2-client-auth",
            api_id = api.id,
            config = {
                oxd_id = "c44d4823-ec30-4136-9caf-0bd87c828715",
                op_server = "https://gluu.local.org",
                oxd_http_url = "http://localhost:8553"
            }
        })
        print("\n----------- Plugin configured ----------- ")
        for k, v in pairs(plugin) do
            print(k, ": ", v)
            if k == 'config' then
                for sk, sv in pairs(v) do
                    print(sk, ": ", sv)
                end
            end
        end

        print("\n----------- Add consumer ----------- ")
        local consumer = assert(helpers.dao.consumers:insert {
            username = "foo"
        })

        print("\n----------- Add oauth2 consumer ----------- ")
        oauth2_consumer = assert(helpers.dao.gluu_oauth2_client_auth_credentials:insert {
            key = "kong",
            consumer_id = consumer.id,
            name = "gluu=oauth2",
            kong_acts_as_uma_client = false
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
        it("401 Unauthorized when token is not present", function()
            local res = assert(proxy_client:send {
                method = "GET",
                path = "/posts",
                headers = {
                    ["Host"] = "jsonplaceholder.typicode.com"
                }
            })
            assert.res_status(401, res)
        end)

        it("200 Authorized with successful response from upstream URL when token is valid", function()
            -- ------------------GET Client Token-------------------------------
            local tokenRequest = {
                oxd_host = oauth2_consumer.oxd_http_url,
                client_id = oauth2_consumer.client_id,
                client_secret = oauth2_consumer.client_secret,
                scope = { "openid", "uma_protection" },
                op_host = oauth2_consumer.op_host
            };

            local token = oxd.get_client_token(tokenRequest)

            if is_empty(token.status) or token.status == "error" then
                print("kong-uma-rs: Failed to get client_token")
            end
            local req_access_token = token.data.access_token

            local res = assert(proxy_client:send {
                method = "GET",
                path = "/posts", -- Unprotected path
                headers = {
                    ["Host"] = "jsonplaceholder.typicode.com",
                    ["Authorization"] = "Bearer " .. req_access_token,
                }
            })
            assert.res_status(200, res)
        end)
    end)
end)

