local cjson = require "cjson"
local helpers = require "spec.helpers"
local auth_helper = require "kong.plugins.gluu-oauth2-client-auth.helper"
local oxd = require "oxdweb"

describe("Plugin: gluu-oauth2-client-auth (API)", function()
    local consumer, anonymous_user
    local admin_client
    local op_server = "https://gluu.local.org"
    local oxd_http_url = "http://localhost:8553"
    local api1, api2, api3

    setup(function()
        helpers.run_migrations()

        api1 = assert(helpers.dao.apis:insert {
            name = "api1",
            upstream_url = "https://jsonplaceholder.typicode.com",
            hosts = { "jsonplaceholder.typicode.com" },
        })
        api2 = assert(helpers.dao.apis:insert {
            name = "api2",
            upstream_url = "https://jsonplaceholder.typicode.com",
            hosts = { "jsonplaceholder.typicode.com" },
        })
        api3 = assert(helpers.dao.apis:insert {
            name = "api3",
            upstream_url = "https://jsonplaceholder.typicode.com",
            hosts = { "jsonplaceholder.typicode.com" },
        })

        consumer = assert(helpers.dao.consumers:insert {
            username = "foo"
        })
        anonymous_user = assert(helpers.dao.consumers:insert {
            username = "no-body"
        })
        assert(helpers.start_kong())
        admin_client = helpers.admin_client()
    end)

    teardown(function()
        if admin_client then admin_client:close() end
        helpers.stop_kong()
    end)

    describe("/apis/:api/plugins", function()
        it("Fails with invalid values", function()
            local res = assert(admin_client:send {
                method = "POST",
                path = "/apis/api1/plugins",
                body = {
                    name = "gluu-oauth2-client-auth",
                    config = {
                        op_server = "http://text.com"
                    },
                },
                headers = {
                    ["Content-Type"] = "application/json"
                }
            })
            assert.response(res).has.status(400)
            local body = assert.response(res).has.jsonbody()
            assert.equal("op_server must be 'https'", body["config.op_server"])
            assert.equal("oxd_http_url is required", body["config.oxd_http_url"])
        end)

        it("Succeeds with valid value", function()
            local oxd_id = "fb76fec7-bcc8-462a-8462-cc0f62236238"
            local res = assert(admin_client:send {
                method = "POST",
                path = "/apis/api1/plugins",
                body = {
                    name = "gluu-oauth2-client-auth",
                    config = {
                        op_server = op_server,
                        oxd_http_url = oxd_http_url,
                        oxd_id = oxd_id
                    },
                },
                headers = {
                    ["Content-Type"] = "application/json"
                }
            })
            assert.response(res).has.status(201)
            local body = assert.response(res).has.jsonbody()
            assert.equal(op_server, body.config.op_server)
            assert.equal(oxd_id, body.config.oxd_id)
            assert.equal("", body.config.anonymous)
        end)

        it("Succeeds with valid value and anonymous consumer", function()
            local oxd_id = "fb76fec7-bcc8-462a-8462-cc0f62236238"
            local res = assert(admin_client:send {
                method = "POST",
                path = "/apis/api2/plugins",
                body = {
                    name = "gluu-oauth2-client-auth",
                    config = {
                        op_server = op_server,
                        oxd_http_url = oxd_http_url,
                        oxd_id = oxd_id,
                        anonymous = anonymous_user.id
                    },
                },
                headers = {
                    ["Content-Type"] = "application/json"
                }
            })
            assert.response(res).has.status(201)
            local body = assert.response(res).has.jsonbody()
            assert.equal(op_server, body.config.op_server)
            assert.equal(oxd_id, body.config.oxd_id)
            assert.equal(anonymous_user.id, body.config.anonymous)
        end)

        it("Check global oxd client is created or not", function()
            local res = assert(admin_client:send {
                method = "POST",
                path = "/apis/api3/plugins",
                body = {
                    name = "gluu-oauth2-client-auth",
                    config = {
                        op_server = op_server,
                        oxd_http_url = oxd_http_url
                    },
                },
                headers = {
                    ["Content-Type"] = "application/json"
                }
            })
            assert.response(res).has.status(201)
            local body = assert.response(res).has.jsonbody()
            assert.equal(op_server, body.config.op_server)
            assert.equal(true, not auth_helper.is_empty(body.config.oxd_id))
        end)
    end)

    describe("/consumers/:consumer/gluu-oauth2-client-auth/", function()
        after_each(function()
            helpers.dao:truncate_table("gluu_oauth2_client_auth_credentials")
        end)

        describe("POST", function()
            it("creates a oauth2 consumer credential", function()
                local res = assert(admin_client:send {
                    method = "POST",
                    path = "/consumers/foo/gluu-oauth2-client-auth",
                    body = {
                        name = "New_oauth2_credential",
                        op_host = op_server,
                        oxd_http_url = oxd_http_url
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                })
                local body = cjson.decode(assert.res_status(201, res))
                assert.equal(consumer.id, body.consumer_id)
                assert.equal("New_oauth2_credential", body.name)
                assert.equal(true, not auth_helper.is_empty(body.oxd_id))
                assert.equal(true, not auth_helper.is_empty(body.client_id))
                assert.equal(true, not auth_helper.is_empty(body.client_secret))
                assert.equal(false, body.mix_mode)
                assert.equal(false, body.uma_mode)
                assert.equal(true, body.oauth_mode)
                assert.equal(false, body.allow_unprotected_path)
                assert.equal(true, body.show_consumer_custom_id)
                assert.equal(true, body.allow_oauth_scope_expression)
            end)
            it("creates a oauth2 consumer credential with oauth_mode = true", function()
                local res = assert(admin_client:send {
                    method = "POST",
                    path = "/consumers/foo/gluu-oauth2-client-auth",
                    body = {
                        name = "New_oauth2_credential",
                        op_host = op_server,
                        oxd_http_url = oxd_http_url,
                        oauth_mode = true
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                })
                local body = cjson.decode(assert.res_status(201, res))
                assert.equal(consumer.id, body.consumer_id)
                assert.equal("New_oauth2_credential", body.name)
                assert.equal(true, not auth_helper.is_empty(body.oxd_id))
                assert.equal(true, not auth_helper.is_empty(body.client_id))
                assert.equal(true, not auth_helper.is_empty(body.client_secret))
                assert.equal(false, body.uma_mode)
                assert.equal(false, body.mix_mode)
                assert.equal(true, body.oauth_mode)
                assert.equal(false, body.allow_unprotected_path)
                assert.equal(true, body.show_consumer_custom_id)
                assert.equal(true, body.allow_oauth_scope_expression)
            end)
            it("creates a oauth2 consumer credential with oauth_mode = true", function()
                local res = assert(admin_client:send {
                    method = "POST",
                    path = "/consumers/foo/gluu-oauth2-client-auth",
                    body = {
                        name = "New_oauth2_credential",
                        op_host = op_server,
                        oxd_http_url = oxd_http_url,
                        oauth_mode = true,
                        allow_oauth_scope_expression = true
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                })
                local body = cjson.decode(assert.res_status(201, res))
                assert.equal(consumer.id, body.consumer_id)
                assert.equal("New_oauth2_credential", body.name)
                assert.equal(true, not auth_helper.is_empty(body.oxd_id))
                assert.equal(true, not auth_helper.is_empty(body.client_id))
                assert.equal(true, not auth_helper.is_empty(body.client_secret))
                assert.equal(false, body.uma_mode)
                assert.equal(false, body.mix_mode)
                assert.equal(true, body.oauth_mode)
                assert.equal(false, body.allow_unprotected_path)
                assert.equal(true, body.show_consumer_custom_id)
                assert.equal(true, body.allow_oauth_scope_expression)
            end)
            it("creates a oauth2 consumer credential with uma_mode = true", function()
                local res = assert(admin_client:send {
                    method = "POST",
                    path = "/consumers/foo/gluu-oauth2-client-auth",
                    body = {
                        name = "New_oauth2_credential",
                        op_host = op_server,
                        oxd_http_url = oxd_http_url,
                        uma_mode = true
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                })
                local body = cjson.decode(assert.res_status(201, res))
                assert.equal(consumer.id, body.consumer_id)
                assert.equal("New_oauth2_credential", body.name)
                assert.equal(true, not auth_helper.is_empty(body.oxd_id))
                assert.equal(true, not auth_helper.is_empty(body.client_id))
                assert.equal(true, not auth_helper.is_empty(body.client_secret))
                assert.equal(true, body.uma_mode)
                assert.equal(false, body.mix_mode)
                assert.equal(false, body.oauth_mode)
                assert.equal(false, body.allow_unprotected_path)
                assert.equal(true, body.show_consumer_custom_id)
                assert.equal(false, body.allow_oauth_scope_expression)
            end)
            it("creates a oauth2 consumer credential with mix_mode = true", function()
                local res = assert(admin_client:send {
                    method = "POST",
                    path = "/consumers/foo/gluu-oauth2-client-auth",
                    body = {
                        name = "New_oauth2_credential",
                        op_host = op_server,
                        oxd_http_url = oxd_http_url,
                        mix_mode = true,
                        show_consumer_custom_id = false
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                })
                local body = cjson.decode(assert.res_status(201, res))
                assert.equal(consumer.id, body.consumer_id)
                assert.equal("New_oauth2_credential", body.name)
                assert.equal(true, not auth_helper.is_empty(body.oxd_id))
                assert.equal(true, not auth_helper.is_empty(body.client_id))
                assert.equal(true, not auth_helper.is_empty(body.client_secret))
                assert.equal(true, body.mix_mode)
                assert.equal(false, body.uma_mode)
                assert.equal(false, body.oauth_mode)
                assert.equal(false, body.allow_unprotected_path)
                assert.equal(false, body.show_consumer_custom_id)
                assert.equal(false, body.allow_oauth_scope_expression)
            end)
            it("creates a oauth2 consumer credential with allow_unprotected_path = true", function()
                local res = assert(admin_client:send {
                    method = "POST",
                    path = "/consumers/foo/gluu-oauth2-client-auth",
                    body = {
                        name = "New_oauth2_credential",
                        op_host = op_server,
                        oxd_http_url = oxd_http_url,
                        mix_mode = true,
                        allow_unprotected_path = true,
                        show_consumer_custom_id = true
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                })
                local body = cjson.decode(assert.res_status(201, res))
                assert.equal(consumer.id, body.consumer_id)
                assert.equal("New_oauth2_credential", body.name)
                assert.equal(true, not auth_helper.is_empty(body.oxd_id))
                assert.equal(true, not auth_helper.is_empty(body.client_id))
                assert.equal(true, not auth_helper.is_empty(body.client_secret))
                assert.equal(true, body.mix_mode)
                assert.equal(false, body.uma_mode)
                assert.equal(false, body.oauth_mode)
                assert.equal(true, body.allow_unprotected_path)
                assert.equal(true, body.show_consumer_custom_id)
            end)
            it("creates oauth2 credentials with the existing client", function()
                -- ------------------GET Client Token-------------------------------
                local setupClientRequest = {
                    oxd_host = oxd_http_url,
                    op_host = op_server,
                    authorization_redirect_uri = "https://localhost",
                    redirect_uris = { "https://localhost" },
                    scope = { "clientinfo", "uma_protection" },
                    grant_types = { "client_credentials" },
                    client_name = "Test_existing_client",
                };

                local setupClientResponse = oxd.setup_client(setupClientRequest)
                if setupClientResponse.status == "error" then
                    print("Failed to create client")
                end

                local res = assert(admin_client:send {
                    method = "POST",
                    path = "/consumers/foo/gluu-oauth2-client-auth",
                    body = {
                        name = "Existing_oauth2_credential",
                        op_host = op_server,
                        oxd_http_url = oxd_http_url,
                        oxd_id = setupClientResponse.data.oxd_id,
                        client_id = setupClientResponse.data.client_id,
                        client_secret = setupClientResponse.data.client_secret,
                        client_id_of_oxd_id = setupClientResponse.data.client_id_of_oxd_id
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                })
                local body = cjson.decode(assert.res_status(201, res))
                assert.equal(consumer.id, body.consumer_id)
                assert.equal("Existing_oauth2_credential", body.name)
                assert.equal(setupClientResponse.data.oxd_id, body.oxd_id)
                assert.equal(setupClientResponse.data.client_id, body.client_id)
                assert.equal(setupClientResponse.data.client_secret, body.client_secret)
                assert.equal(setupClientResponse.data.client_id_of_oxd_id, body.client_id_of_oxd_id)
                assert.equal(false, body.mix_mode)
                assert.equal(false, body.uma_mode)
                assert.equal(true, body.oauth_mode)
                assert.equal("clientinfo,uma_protection", body.scope)
            end)
            it("creates oauth2 credentials with the scope", function()
                -- ------------------GET Client Token-------------------------------
                local setupClientRequest = {
                    oxd_host = oxd_http_url,
                    op_host = op_server,
                    authorization_redirect_uri = "https://localhost",
                    redirect_uris = { "https://localhost" },
                    scope = { "clientinfo", "uma_protection" },
                    grant_types = { "client_credentials" },
                    client_name = "Test_existing_client"
                };

                local setupClientResponse = oxd.setup_client(setupClientRequest)
                if setupClientResponse.status == "error" then
                    print("Failed to create client")
                end

                local res = assert(admin_client:send {
                    method = "POST",
                    path = "/consumers/foo/gluu-oauth2-client-auth",
                    body = {
                        name = "Existing_oauth2_credential",
                        op_host = op_server,
                        oxd_http_url = oxd_http_url,
                        oxd_id = setupClientResponse.data.oxd_id,
                        client_id = setupClientResponse.data.client_id,
                        client_secret = setupClientResponse.data.client_secret,
                        client_id_of_oxd_id = setupClientResponse.data.client_id_of_oxd_id,
                        scope = "calendar"
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                })
                local body = cjson.decode(assert.res_status(201, res))
                assert.equal(consumer.id, body.consumer_id)
                assert.equal("Existing_oauth2_credential", body.name)
                assert.equal(setupClientResponse.data.oxd_id, body.oxd_id)
                assert.equal(setupClientResponse.data.client_id, body.client_id)
                assert.equal(setupClientResponse.data.client_secret, body.client_secret)
                assert.equal(setupClientResponse.data.client_id_of_oxd_id, body.client_id_of_oxd_id)
                assert.equal(false, body.mix_mode)
                assert.equal(false, body.uma_mode)
                assert.equal(true, body.oauth_mode)
                assert.equal("calendar,clientinfo,uma_protection", body.scope)
                assert.equal(false, body.restrict_api)
            end)
            it("creates oauth2 credentials with the restricted API", function()
                -- ------------------GET Client Token-------------------------------
                local setupClientRequest = {
                    oxd_host = oxd_http_url,
                    op_host = op_server,
                    authorization_redirect_uri = "https://localhost",
                    redirect_uris = { "https://localhost" },
                    scope = { "clientinfo", "uma_protection" },
                    grant_types = { "client_credentials" },
                    client_name = "Test_existing_client"
                };

                local setupClientResponse = oxd.setup_client(setupClientRequest)
                if setupClientResponse.status == "error" then
                    print("Failed to create client")
                end

                -- Failed 400
                local res = assert(admin_client:send {
                    method = "POST",
                    path = "/consumers/foo/gluu-oauth2-client-auth",
                    body = {
                        name = "Existing_oauth2_credential",
                        op_host = op_server,
                        oxd_http_url = oxd_http_url,
                        oxd_id = setupClientResponse.data.oxd_id,
                        client_id = setupClientResponse.data.client_id,
                        client_secret = setupClientResponse.data.client_secret,
                        client_id_of_oxd_id = setupClientResponse.data.client_id_of_oxd_id,
                        scope = "calendar",
                        restrict_api = true
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                })
                local body = assert.res_status(400, res)
                local json = cjson.decode(body)
                assert.equal("Require atleast one API in restrict APIs", json.message)

                -- Failed 400
                local invalid_api_id = "fdfdsf343545"
                local res = assert(admin_client:send {
                    method = "POST",
                    path = "/consumers/foo/gluu-oauth2-client-auth",
                    body = {
                        name = "Existing_oauth2_credential",
                        op_host = op_server,
                        oxd_http_url = oxd_http_url,
                        oxd_id = setupClientResponse.data.oxd_id,
                        client_id = setupClientResponse.data.client_id,
                        client_secret = setupClientResponse.data.client_secret,
                        client_id_of_oxd_id = setupClientResponse.data.client_id_of_oxd_id,
                        scope = "calendar",
                        restrict_api = true,
                        restrict_api_list = table.concat({api1.id, invalid_api_id, api2.id}, ",")
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                })
                local body = assert.res_status(400, res)
                local json = cjson.decode(body)
                assert.equal("Invalid API, id: " .. invalid_api_id, json.message)

                -- Success
                local res = assert(admin_client:send {
                    method = "POST",
                    path = "/consumers/foo/gluu-oauth2-client-auth",
                    body = {
                        name = "Existing_oauth2_credential",
                        op_host = op_server,
                        oxd_http_url = oxd_http_url,
                        oxd_id = setupClientResponse.data.oxd_id,
                        client_id = setupClientResponse.data.client_id,
                        client_secret = setupClientResponse.data.client_secret,
                        client_id_of_oxd_id = setupClientResponse.data.client_id_of_oxd_id,
                        scope = "calendar",
                        restrict_api = true,
                        restrict_api_list = table.concat({api1.id, api2.id}, ",")
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                })
                local body = cjson.decode(assert.res_status(201, res))
                assert.equal(consumer.id, body.consumer_id)
                assert.equal("Existing_oauth2_credential", body.name)
                assert.equal(setupClientResponse.data.oxd_id, body.oxd_id)
                assert.equal(setupClientResponse.data.client_id, body.client_id)
                assert.equal(setupClientResponse.data.client_secret, body.client_secret)
                assert.equal(setupClientResponse.data.client_id_of_oxd_id, body.client_id_of_oxd_id)
                assert.equal(false, body.mix_mode)
                assert.equal(false, body.uma_mode)
                assert.equal(true, body.oauth_mode)
                assert.equal("calendar,clientinfo,uma_protection", body.scope)
                assert.equal(true, body.restrict_api)
            end)
            describe("errors", function()
                it("returns bad request i:e without op_host", function()
                    local res = assert(admin_client:send {
                        method = "POST",
                        path = "/consumers/foo/gluu-oauth2-client-auth",
                        body = {},
                        headers = {
                            ["Content-Type"] = "application/json"
                        }
                    })
                    local body = assert.res_status(400, res)
                    local json = cjson.decode(body)
                    assert.equal("op_host is required", json.message)
                end)
                it("returns bad request i:e without op_host", function()
                    local res = assert(admin_client:send {
                        method = "POST",
                        path = "/consumers/foo/gluu-oauth2-client-auth",
                        body = {
                            op_host = op_server
                        },
                        headers = {
                            ["Content-Type"] = "application/json"
                        }
                    })
                    local body = assert.res_status(400, res)
                    local json = cjson.decode(body)
                    assert.equal("oxd_http_url is required", json.message)
                end)
                it("returns bad request i:e check only one mode is set", function()
                    -- Not allow when all flags is true.
                    local res = assert(admin_client:send {
                        method = "POST",
                        path = "/consumers/foo/gluu-oauth2-client-auth",
                        body = {
                            op_host = op_server,
                            oxd_http_url = oxd_http_url,
                            oauth_mode = true,
                            uma_mode = true,
                            mix_mode = true
                        },
                        headers = {
                            ["Content-Type"] = "application/json"
                        }
                    })
                    local body = assert.res_status(400, res)
                    local json = cjson.decode(body)
                    assert.equal("oauth mode, uma mode and mix mode, All flags cannot be YES at the same time", json.message)

                    -- Not allow when more than one is true. oauth_mode = true uma_mode = true
                    local res = assert(admin_client:send {
                        method = "POST",
                        path = "/consumers/foo/gluu-oauth2-client-auth",
                        body = {
                            op_host = op_server,
                            oxd_http_url = oxd_http_url,
                            oauth_mode = true,
                            uma_mode = true
                        },
                        headers = {
                            ["Content-Type"] = "application/json"
                        }
                    })
                    local body = assert.res_status(400, res)
                    local json = cjson.decode(body)
                    assert.equal("oauth mode and uma mode, Both flags cannot be YES at the same time", json.message)

                    -- Not allow when more than one is true. oauth_mode = true mix_mode = true
                    local res = assert(admin_client:send {
                        method = "POST",
                        path = "/consumers/foo/gluu-oauth2-client-auth",
                        body = {
                            op_host = op_server,
                            oxd_http_url = oxd_http_url,
                            oauth_mode = true,
                            mix_mode = true
                        },
                        headers = {
                            ["Content-Type"] = "application/json"
                        }
                    })
                    local body = assert.res_status(400, res)
                    local json = cjson.decode(body)
                    assert.equal("oauth mode and mix mode, Both flags cannot be YES at the same time", json.message)

                    -- Not allow when more than one is true. uma_mode = true mix_mode = true
                    local res = assert(admin_client:send {
                        method = "POST",
                        path = "/consumers/foo/gluu-oauth2-client-auth",
                        body = {
                            op_host = op_server,
                            oxd_http_url = oxd_http_url,
                            uma_mode = true,
                            mix_mode = true
                        },
                        headers = {
                            ["Content-Type"] = "application/json"
                        }
                    })
                    local body = assert.res_status(400, res)
                    local json = cjson.decode(body)
                    assert.equal("uma mode and mix mode, Both flags cannot be YES at the same time", json.message)
                end)
            end)
        end)

        describe("GET", function()
            setup(function()
                for i = 1, 3 do
                    assert(helpers.dao.gluu_oauth2_client_auth_credentials:insert {
                        name = "app" .. i,
                        oxd_id = "oxd_id_" .. i,
                        client_id = "client_id_" .. i,
                        client_secret = "client_secret_" .. i,
                        client_id_of_oxd_id = "client_id_of_oxd_id_" .. i,
                        oxd_http_url = oxd_http_url,
                        op_host = op_server,
                        consumer_id = consumer.id
                    })
                end
            end)
            teardown(function()
                helpers.dao:truncate_table("gluu_oauth2_client_auth_credentials")
            end)
            it("retrieves the first page", function()
                local res = assert(admin_client:send {
                    method = "GET",
                    path = "/consumers/foo/gluu-oauth2-client-auth"
                })
                local body = assert.res_status(200, res)
                local json = cjson.decode(body)
                assert.is_table(json.data)
                assert.equal(3, #json.data)
                assert.equal(3, json.total)
            end)
        end)
    end)
end)
