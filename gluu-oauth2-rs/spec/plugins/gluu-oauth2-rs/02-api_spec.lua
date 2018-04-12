local cjson = require "cjson"
local helpers = require "spec.helpers"
local auth_helper = require "kong.plugins.gluu-oauth2-rs.helper"
local oxd = require "oxdweb"

describe("Plugin: gluu-oauth2-rs (API)", function()
    local consumer, api1, api2, api3
    local admin_client
    local op_server = "https://gluu.local.org"
    local oxd_http_url = "http://localhost:8553"

    setup(function()
        helpers.run_migrations()

        api1 = assert(helpers.dao.apis:insert {
            name = "api1",
            upstream_url = "https://localhost",
            hosts = { "localhost.com" },
        })

        api2 = assert(helpers.dao.apis:insert {
            name = "api2",
            upstream_url = "https://localhost",
            hosts = { "localhost.com" },
        })

        api3 = assert(helpers.dao.apis:insert {
            name = "api3",
            upstream_url = "https://localhost",
            hosts = { "localhost.com" },
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
        it("Succeeds with valid value with oauth scope expression", function()
            local res = assert(admin_client:send {
                method = "POST",
                path = "/plugins",
                body = {
                    name = "gluu-oauth2-rs",
                    api_id = api1.id,
                    config = {
                        uma_server_host = op_server,
                        oxd_host = oxd_http_url,
                        oauth_scope_expression = "[{\"path\":\"/posts\",\"conditions\":[{\"httpMethods\":[\"GET\",\"POST\"],\"scope_expression\":{\"rule\":{\"or\":[{\"var\":0}]},\"data\":[\"email\"]}}]},{\"path\":\"/comments\",\"conditions\":[{\"httpMethods\":[\"GET\"],\"scope_expression\":{\"rule\":{\"and\":[{\"var\":0}]},\"data\":[\"email\",\"profile\"]}}]}]"
                    },
                },
                headers = {
                    ["Content-Type"] = "application/json"
                }
            })
            assert.response(res).has.status(201)
            local body = assert.response(res).has.jsonbody()
            assert.equal(op_server, body.config.uma_server_host)
            assert.is_truthy(string.find(body.config.oauth_scope_expression, "posts"))
            assert.equal(nil, body.config.oxd_id)

            -- Update oauth_scope_expression
            local config = body.config
            config.oauth_scope_expression = "[{\"path\":\"/photo\",\"conditions\":[{\"httpMethods\":[\"GET\",\"POST\"],\"scope_expression\":{\"rule\":{\"or\":[{\"var\":0}]},\"data\":[\"email\"]}}]},{\"path\":\"/comments\",\"conditions\":[{\"httpMethods\":[\"GET\"],\"scope_expression\":{\"rule\":{\"and\":[{\"var\":0}]},\"data\":[\"email\",\"profile\"]}}]}]"
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
            assert.equal(op_server, body.config.uma_server_host)
            assert.is_truthy(string.find(body.config.oauth_scope_expression, "photo"))
            assert.equal(nil, body.config.oxd_id)

            -- Update with protection_document
            local config = body.config
            config.protection_document = "[{\"path\":\"/posts\",\"conditions\":[{\"httpMethods\":[\"GET\",\"POST\"],\"scope_expression\":{\"rule\":{\"or\":[{\"var\":0}]},\"data\":[\"https://jsonplaceholder.typicode.com\"]}}]},{\"path\":\"/comments\",\"conditions\":[{\"httpMethods\":[\"GET\"],\"scope_expression\":{\"rule\":{\"and\":[{\"var\":0}]},\"data\":[\"https://jsonplaceholder.typicode.com\"]}}]}]"
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
            assert.equal(op_server, body.config.uma_server_host)
            assert.is_truthy(string.find(body.config.protection_document, "posts"))
            assert.equal(false, auth_helper.is_empty(body.config.oxd_id))
        end)

        it("Succeeds with valid value with UMA rs scope expression", function()
            local res = assert(admin_client:send {
                method = "POST",
                path = "/plugins",
                body = {
                    name = "gluu-oauth2-rs",
                    api_id = api2.id,
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
            assert.equal(false, auth_helper.is_empty(body.config.oxd_id))

            -- Update
            local config = body.config
            config.protection_document = "[{\"path\":\"/photo\",\"conditions\":[{\"httpMethods\":[\"GET\",\"POST\"],\"scope_expression\":{\"rule\":{\"or\":[{\"var\":0}]},\"data\":[\"https://jsonplaceholder.typicode.com\"]}}]},{\"path\":\"/comments\",\"conditions\":[{\"httpMethods\":[\"GET\"],\"scope_expression\":{\"rule\":{\"and\":[{\"var\":0}]},\"data\":[\"https://jsonplaceholder.typicode.com\"]}}]}]"
            local oxd_id = body.config.oxd_id
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
            assert.equal(oxd_id, body.config.oxd_id)

            -- Update with oauth_scope_expression
            local config = body.config
            config.oauth_scope_expression = "[{\"path\":\"/photo\",\"conditions\":[{\"httpMethods\":[\"GET\",\"POST\"],\"scope_expression\":{\"rule\":{\"or\":[{\"var\":0}]},\"data\":[\"email\"]}}]},{\"path\":\"/comments\",\"conditions\":[{\"httpMethods\":[\"GET\"],\"scope_expression\":{\"rule\":{\"and\":[{\"var\":0}]},\"data\":[\"email\",\"profile\"]}}]}]"
            local oxd_id = body.config.oxd_id
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
            assert.equal(op_server, body.config.uma_server_host)
            assert.is_truthy(string.find(body.config.oauth_scope_expression, "photo"))
            assert.equal(oxd_id, body.config.oxd_id)
        end)

        it("Succeeds with valid value with both", function()
            local res = assert(admin_client:send {
                method = "POST",
                path = "/plugins",
                body = {
                    name = "gluu-oauth2-rs",
                    api_id = api3.id,
                    config = {
                        uma_server_host = op_server,
                        oxd_host = oxd_http_url,
                        protection_document = "[{\"path\":\"/posts\",\"conditions\":[{\"httpMethods\":[\"GET\",\"POST\"],\"scope_expression\":{\"rule\":{\"or\":[{\"var\":0}]},\"data\":[\"https://jsonplaceholder.typicode.com\"]}}]},{\"path\":\"/comments\",\"conditions\":[{\"httpMethods\":[\"GET\"],\"scope_expression\":{\"rule\":{\"and\":[{\"var\":0}]},\"data\":[\"https://jsonplaceholder.typicode.com\"]}}]}]",
                        oauth_scope_expression = "[{\"path\":\"/posts\",\"conditions\":[{\"httpMethods\":[\"GET\",\"POST\"],\"scope_expression\":{\"rule\":{\"or\":[{\"var\":0}]},\"data\":[\"email\"]}}]},{\"path\":\"/comments\",\"conditions\":[{\"httpMethods\":[\"GET\"],\"scope_expression\":{\"rule\":{\"and\":[{\"var\":0}]},\"data\":[\"email\",\"profile\"]}}]}]"
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
            assert.is_truthy(string.find(body.config.oauth_scope_expression, "posts"))
            assert.equal(false, auth_helper.is_empty(body.config.oxd_id))

            -- Update
            local config = body.config
            local oxd_id = body.config.oxd_id
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
            assert.equal(oxd_id, body.config.oxd_id)

            -- Update with oauth_scope_expression
            local config = body.config
            config.oauth_scope_expression = "[{\"path\":\"/photo\",\"conditions\":[{\"httpMethods\":[\"GET\",\"POST\"],\"scope_expression\":{\"rule\":{\"or\":[{\"var\":0}]},\"data\":[\"email\"]}}]},{\"path\":\"/comments\",\"conditions\":[{\"httpMethods\":[\"GET\"],\"scope_expression\":{\"rule\":{\"and\":[{\"var\":0}]},\"data\":[\"email\",\"profile\"]}}]}]"
            local oxd_id = body.config.oxd_id
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
            assert.equal(op_server, body.config.uma_server_host)
            assert.is_truthy(string.find(body.config.oauth_scope_expression, "photo"))
            assert.equal(oxd_id, body.config.oxd_id)
        end)
    end)
end)
