local helpers = require "spec.helpers"
local oxd = require "oxdweb"
local cjson = require "cjson"
local auth_helper = require "kong.plugins.gluu-oauth2-client-auth.helper"

describe("gluu-oauth2-client-auth plugin", function()
    local proxy_client
    local admin_client
    local oauth2_consumer_both_flag_false
    local oauth2_consumer_with_native_uma_client
    local oauth2_consumer_with_kong_acts_as_uma_client
    local api
    local plugin
    local timeout = 6000
    local op_server = "https://gluu.local.org"
    local oxd_http = "http://localhost:8553"

    setup(function()
        helpers.run_migrations()
        api = assert(helpers.dao.apis:insert {
            name = "json",
            upstream_url = "https://jsonplaceholder.typicode.com",
            hosts = { "jsonplaceholder.typicode.com" }
        })

        print("----------- Api created ----------- ")
        for k, v in pairs(api) do
            print(k, ": ", v)
        end

        print("\n----------- Add consumer ----------- ")
        local consumer = assert(helpers.dao.consumers:insert {
            username = "foo"
        })

        -- start Kong with your testing Kong configuration (defined in "spec.helpers")
        assert(helpers.start_kong())
        print("Kong started")

        admin_client = helpers.admin_client(timeout)

        print("\n----------- Plugin configuration ----------- ")
        local res = assert(admin_client:send {
            method = "POST",
            path = "/apis/json/plugins",
            body = {
                name = "gluu-oauth2-client-auth",
                config = {
                    op_server = op_server,
                    oxd_http_url = oxd_http
                },
            },
            headers = {
                ["Content-Type"] = "application/json"
            }
        })
        assert.response(res).has.status(201)
        plugin = assert.response(res).has.jsonbody()

        for k, v in pairs(plugin) do
            print(k, ": ", v)
            if k == 'config' then
                for sk, sv in pairs(v) do
                    print(sk, ": ", sv)
                end
            end
        end

        print("\n----------- OAuth2 consumer credential ----------- ")
        local res = assert(admin_client:send {
            method = "POST",
            path = "/consumers/foo/gluu-oauth2-client-auth",
            body = {
                name = "New_oauth2_credential",
                op_host = "https://gluu.local.org",
                oxd_http_url = "http://localhost:8553"
            },
            headers = {
                ["Content-Type"] = "application/json"
            }
        })
        oauth2_consumer_both_flag_false = cjson.decode(assert.res_status(201, res))
        for k, v in pairs(oauth2_consumer_both_flag_false) do
            print(k, ": ", v)
        end

        print("\n----------- OAuth2 consumer credential with kong_acts_as_uma_client = true ----------- ")
        local res = assert(admin_client:send {
            method = "POST",
            path = "/consumers/foo/gluu-oauth2-client-auth",
            body = {
                name = "New_oauth2_credential",
                op_host = "https://gluu.local.org",
                oxd_http_url = "http://localhost:8553",
                kong_acts_as_uma_client = true
            },
            headers = {
                ["Content-Type"] = "application/json"
            }
        })
        oauth2_consumer_with_kong_acts_as_uma_client = cjson.decode(assert.res_status(201, res))
        for k, v in pairs(oauth2_consumer_with_kong_acts_as_uma_client) do
            print(k, ": ", v)
        end

        print("\n----------- OAuth2 consumer credential with native_uma_client = true ----------- ")
        local res = assert(admin_client:send {
            method = "POST",
            path = "/consumers/foo/gluu-oauth2-client-auth",
            body = {
                name = "New_oauth2_credential",
                op_host = "https://gluu.local.org",
                oxd_http_url = "http://localhost:8553",
                native_uma_client = true
            },
            headers = {
                ["Content-Type"] = "application/json"
            }
        })
        oauth2_consumer_with_native_uma_client = cjson.decode(assert.res_status(201, res))
        for k, v in pairs(oauth2_consumer_with_native_uma_client) do
            print(k, ": ", v)
        end
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
        describe("When oauth2-consumer is act only as OAuth client i:e both flag is false, native_uma_client = false and kong_acts_as_uma_client = false", function()
            it("401 Unauthorized when token is not present in header", function()
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com"
                    }
                })
                assert.res_status(401, res)
            end)

            it("401 Unauthorized when token is invalid", function()
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

            it("200 Authorized when token active = true", function()
                -- ------------------GET Client Token-------------------------------
                local tokenRequest = {
                    oxd_host = oauth2_consumer_both_flag_false.oxd_http_url,
                    client_id = oauth2_consumer_both_flag_false.client_id,
                    client_secret = oauth2_consumer_both_flag_false.client_secret,
                    scope = { "openid", "uma_protection" },
                    op_host = oauth2_consumer_both_flag_false.op_host
                };

                local token = oxd.get_client_token(tokenRequest)
                local req_access_token = token.data.access_token

                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)
            end)
        end)

        describe("When oauth2-consumer is act as kong_acts_as_uma_client = true", function()
            local kong_uma_rs_plugin
            setup(function()
                local res = assert(admin_client:send {
                    method = "POST",
                    path = "/apis/json/plugins",
                    body = {
                        name = "kong-uma-rs",
                        config = {
                            uma_server_host = op_server,
                            oxd_host = oxd_http,
                            protection_document = "[{\"path\":\"/posts\",\"conditions\":[{\"httpMethods\":[\"GET\",\"POST\"],\"scope_expression\":{\"rule\":{\"or\":[{\"var\":0}]},\"data\":[\"https://jsonplaceholder.typicode.com\"]}}]},{\"path\":\"/comments\",\"conditions\":[{\"httpMethods\":[\"GET\"],\"scope_expression\":{\"rule\":{\"and\":[{\"var\":0}]},\"data\":[\"https://jsonplaceholder.typicode.com\"]}}]}]"
                        },
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                })
                assert.response(res).has.status(201)
                kong_uma_rs_plugin = assert.response(res).has.jsonbody()
            end)

            it("401 Unauthorized when token is not present in header", function()
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com"
                    }
                })
                assert.res_status(401, res)
            end)

            it("401 Unauthorized when token is invalid", function()
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

            it("Get 205 status first time when token is active = true", function()
                -- ------------------GET Client Token-------------------------------
                auth_helper.print_table(kong_uma_rs_plugin)
                local tokenRequest = {
                    oxd_host = oauth2_consumer_with_kong_acts_as_uma_client.oxd_http_url,
                    client_id = oauth2_consumer_with_kong_acts_as_uma_client.client_id,
                    client_secret = oauth2_consumer_with_kong_acts_as_uma_client.client_secret,
                    scope = { "openid", "uma_protection" },
                    op_host = oauth2_consumer_with_kong_acts_as_uma_client.op_host
                };

                local token = oxd.get_client_token(tokenRequest)
                local req_access_token = token.data.access_token

                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                print("req_access_token " .. req_access_token)
                local body = assert.res_status(205, res)
            end)

            it("200 Authorized after handling 401, get status 205 and obtaining RPT", function()
                -- ------------------GET Client Token-------------------------------
                local tokenRequest = {
                    oxd_host = oauth2_consumer_with_kong_acts_as_uma_client.oxd_http_url,
                    client_id = oauth2_consumer_with_kong_acts_as_uma_client.client_id,
                    client_secret = oauth2_consumer_with_kong_acts_as_uma_client.client_secret,
                    scope = { "openid", "uma_protection" },
                    op_host = oauth2_consumer_with_kong_acts_as_uma_client.op_host
                };

                local token = oxd.get_client_token(tokenRequest)
                local req_access_token = token.data.access_token

                -- First time get 205
                print("First time get 205")
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(205, res)
                print("In second request got 200")

                -- In second request got 200
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)
            end)
        end)
    end)
end)