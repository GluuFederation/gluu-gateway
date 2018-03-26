local cjson = require "cjson"
local helpers = require "spec.helpers"
local auth_helper = require "kong.plugins.gluu-oauth2-rs.helper"
local oxd = require "oxdweb"

describe("Plugin: gluu-oauth2-rs (API)", function()
    local consumer, api
    local admin_client
    local op_server = "https://gluu.local.org"
    local oxd_http_url = "http://localhost:8553"

    setup(function()
        helpers.run_migrations()

        api = assert(helpers.dao.apis:insert {
            name = "json",
            upstream_url = "https://jsonplaceholder.typicode.com",
            hosts = { "jsonplaceholder.typicode.com" },
        })
        consumer = assert(helpers.dao.consumers:insert {
            username = "foo"
        })
        assert(helpers.start_kong())
        admin_client = helpers.admin_client()
    end)

    teardown(function()
        if admin_client then admin_client:close() end
        helpers.stop_kong()
    end)

    describe("/apis/:api/plugins", function()
        it("Succeeds with valid value", function()
            local res = assert(admin_client:send {
                method = "POST",
                path = "/plugins",
                body = {
                    name = "gluu-oauth2-rs",
                    api_id = api.id,
                    config = {
                        uma_server_host = op_server,
                        oxd_host = oxd_http_url,
                        protection_document = "[{\"path\":\"/posts\",\"conditions\":[{\"httpMethods\":[\"GET\",\"POST\"],\"scope_expression\":{\"rule\":{\"or\":[{\"var\":0}]},\"data\":[\"https://jsonplaceholder.typicode.com\"]}}]},{\"path\":\"/comments\",\"conditions\":[{\"httpMethods\":[\"GET\"],\"scope_expression\":{\"rule\":{\"and\":[{\"var\":0}]},\"data\":[\"https://jsonplaceholder.typicode.com\"]}}]}]"
                    },
                },
                headers = {
                    ["Content-Type"] = "application/json"
                }
            })
            assert.response(res).has.status(201)
            local body = assert.response(res).has.jsonbody()
            assert.equal(op_server, body.config.uma_server_host)
            assert.is_truthy(string.find(body.config.protection_document, "posts"))

            local config = body.config
            config.protection_document = "[{\"path\":\"/photo\",\"conditions\":[{\"httpMethods\":[\"GET\",\"POST\"],\"scope_expression\":{\"rule\":{\"or\":[{\"var\":0}]},\"data\":[\"https://jsonplaceholder.typicode.com\"]}}]},{\"path\":\"/comments\",\"conditions\":[{\"httpMethods\":[\"GET\"],\"scope_expression\":{\"rule\":{\"and\":[{\"var\":0}]},\"data\":[\"https://jsonplaceholder.typicode.com\"]}}]}]"
            local res = assert(admin_client:send {
                method = "PATCH",
                path = "/plugins/" .. body.id,
                body = {
                    name = "gluu-oauth2-rs",
                    config = config,
                },
                headers = {
                    ["Content-Type"] = "application/json"
                }
            })
            assert.response(res).has.status(200)
            local body = assert.response(res).has.jsonbody()
            assert.is_truthy(string.find(body.config.protection_document, "photo"))
        end)
    end)
end)
