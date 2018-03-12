local helpers = require "spec.helpers"
local oxd = require "oxdweb"
local cjson = require "cjson"
local auth_helper = require "kong.plugins.gluu-oauth2-client-auth.helper"

describe("gluu-oauth2-client-auth plugin", function()
    local proxy_client
    local admin_client
    local oauth2_consumer_oauth_mode
    local oauth2_consumer_with_uma_mode
    local oauth2_consumer_with_mix_mode
    local api
    local plugin
    local timeout = 6000
    local op_server = "https://gluu.local.org"
    local oxd_http = "http://localhost:8553"
    local OAUTH_CLIENT_ID = "OAUTH-CLIENT-ID"
    local OAUTH_EXPIRATION = "OAUTH-EXPIRATION"
    local OAUTH_SCOPES = "OAUTH_SCOPES"

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

        print("\n----------- OAuth2 consumer oauth mode credential ----------- ")
        local res = assert(admin_client:send {
            method = "POST",
            path = "/consumers/foo/gluu-oauth2-client-auth",
            body = {
                name = "oauth2_credential_oauth_mode",
                op_host = "https://gluu.local.org",
                oxd_http_url = "http://localhost:8553"
            },
            headers = {
                ["Content-Type"] = "application/json"
            }
        })
        oauth2_consumer_oauth_mode = cjson.decode(assert.res_status(201, res))
        for k, v in pairs(oauth2_consumer_oauth_mode) do
            print(k, ": ", v)
        end

        print("\n----------- OAuth2 consumer credential with mix_mode = true ----------- ")
        local res = assert(admin_client:send {
            method = "POST",
            path = "/consumers/foo/gluu-oauth2-client-auth",
            body = {
                name = "oauth2_credential_mix_mode",
                op_host = "https://gluu.local.org",
                oxd_http_url = "http://localhost:8553",
                mix_mode = true
            },
            headers = {
                ["Content-Type"] = "application/json"
            }
        })
        oauth2_consumer_with_mix_mode = cjson.decode(assert.res_status(201, res))
        for k, v in pairs(oauth2_consumer_with_mix_mode) do
            print(k, ": ", v)
        end

        print("\n----------- OAuth2 consumer credential with uma_mode = true ----------- ")
        local res = assert(admin_client:send {
            method = "POST",
            path = "/consumers/foo/gluu-oauth2-client-auth",
            body = {
                name = "oauth2_credential_uma_mode",
                op_host = "https://gluu.local.org",
                oxd_http_url = "http://localhost:8553",
                uma_mode = true
            },
            headers = {
                ["Content-Type"] = "application/json"
            }
        })
        oauth2_consumer_with_uma_mode = cjson.decode(assert.res_status(201, res))
        for k, v in pairs(oauth2_consumer_with_uma_mode) do
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

    describe("oauth2-consumer flow without uma-rs plugin", function()
        describe("When oauth2-consumer is in oauth_mode = true", function()
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
                    oxd_host = oauth2_consumer_oauth_mode.oxd_http_url,
                    client_id = oauth2_consumer_oauth_mode.client_id,
                    client_secret = oauth2_consumer_oauth_mode.client_secret,
                    scope = { "openid", "uma_protection" },
                    op_host = oauth2_consumer_oauth_mode.op_host
                };

                local token = oxd.get_client_token(tokenRequest)
                local req_access_token = token.data.access_token

                -- Cache is not exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)
                assert.equal(true, not auth_helper.is_empty(res.headers[OAUTH_CLIENT_ID]))
                print("OAUTH_CLIENT_ID : " .. res.headers[OAUTH_CLIENT_ID])

                assert.equal(true, not auth_helper.is_empty(res.headers[OAUTH_EXPIRATION]))
                print("OAUTH_EXPIRATION : " .. res.headers[OAUTH_EXPIRATION])

                assert.equal(true, not auth_helper.is_empty(res.headers[OAUTH_SCOPES]))
                print("OAUTH_SCOPES : " .. res.headers[OAUTH_SCOPES])

                -- Next request, when cache exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })

                assert.res_status(200, res)
                assert.equal(true, not auth_helper.is_empty(res.headers[OAUTH_CLIENT_ID]))
                print("OAUTH_CLIENT_ID : " .. res.headers[OAUTH_CLIENT_ID])

                assert.equal(true, not auth_helper.is_empty(res.headers[OAUTH_EXPIRATION]))
                print("OAUTH_EXPIRATION : " .. res.headers[OAUTH_EXPIRATION])

                assert.equal(true, not auth_helper.is_empty(res.headers[OAUTH_SCOPES]))
                print("OAUTH_SCOPES : " .. res.headers[OAUTH_SCOPES])
            end)
        end)

        describe("When oauth2-consumer is in mix_mode = true", function()
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

            it("Get 200 status when token is active = true", function()
                -- ------------------GET Client Token-------------------------------
                local tokenRequest = {
                    oxd_host = oauth2_consumer_with_mix_mode.oxd_http_url,
                    client_id = oauth2_consumer_with_mix_mode.client_id,
                    client_secret = oauth2_consumer_with_mix_mode.client_secret,
                    scope = { "openid", "uma_protection" },
                    op_host = oauth2_consumer_with_mix_mode.op_host
                };

                local token = oxd.get_client_token(tokenRequest)
                local req_access_token = token.data.access_token

                -- Cache is not exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- Next request, when cache exist
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

        describe("When oauth2-consumer is in uma_mode = true", function()
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

            it("Get 401 status when token is active = true but token is oauth2 access tokn ", function()
                -- ------------------GET Client Token-------------------------------
                local tokenRequest = {
                    oxd_host = oauth2_consumer_with_uma_mode.oxd_http_url,
                    client_id = oauth2_consumer_with_uma_mode.client_id,
                    client_secret = oauth2_consumer_with_uma_mode.client_secret,
                    scope = { "openid", "uma_protection" },
                    op_host = oauth2_consumer_with_uma_mode.op_host
                };

                local token = oxd.get_client_token(tokenRequest)
                local req_access_token = token.data.access_token

                -- Cache is not exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- Next request, when cache exist
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
    describe("oauth2-consumer flow with uma-rs plugin", function()
    end)
end)