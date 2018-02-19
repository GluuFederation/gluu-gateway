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
end)

