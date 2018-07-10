local helpers = require "spec.helpers"
local oxd = require "oxdweb"
local cjson = require "cjson"
local auth_helper = require "kong.plugins.gluu-oauth2-client-auth.helper"

describe("gluu-oauth2-client-auth plugin", function()
    local proxy_client
    local admin_client
    local oauth2_consumer_oauth_mode
    local oauth2_consumer_oauth_mode_scope_expression
    local oauth2_consumer_with_uma_mode
    local oauth2_consumer_with_mix_mode
    local oauth2_consumer_with_uma_mode_allow_unprotected_path
    local oauth2_consumer_with_mix_mode_allow_unprotected_path
    local oauth2_consumer_with_mix_mode_hide_consumer_custom_id
    local oauth2_consumer_with_restricted_api
    local invalidToken
    local api, api2, api3, api4, api5
    local plugin, plugin_anonymous, plugin4, plugin5
    local timeout = 6000
    local op_server = "https://gluu.local.org"
    local oxd_http = "http://localhost:8553"
    local OAUTH_CLIENT_ID = "x-oauth-client-id"
    local OAUTH_EXPIRATION = "x-oauth-expiration"
    local OAUTH_SCOPES = "x-authenticated-scope"
    local consumer, anonymous_consumer

    setup(function()
        helpers.run_migrations()
        api = assert(helpers.dao.apis:insert {
            name = "json",
            upstream_url = "http://localhost:4040/api", --local API for check Upstream Headers -- You can use live example like "https://jsonplaceholder.typicode.com",
            hosts = { "jsonplaceholder.typicode.com" }
        })

        api2 = assert(helpers.dao.apis:insert {
            name = "api2",
            upstream_url = "http://localhost:4040/api",
            hosts = { "api2.typicode.com" }
        })

        api3 = assert(helpers.dao.apis:insert {
            name = "api3",
            upstream_url = "http://localhost:4040/api",
            hosts = { "api3.typicode.com" }
        })

        api4 = assert(helpers.dao.apis:insert {
            name = "api4",
            upstream_url = "http://localhost:4040/api",
            hosts = { "api4.typicode.com" }
        })

        api5 = assert(helpers.dao.apis:insert {
            name = "api5",
            upstream_url = "https://jsonplaceholder.typicode.com",
            hosts = { "api5.typicode.com" }
        })

        print("----------- Api created ----------- ")
        for k, v in pairs(api) do
            print(k, ": ", v)
        end

        print("\n----------- Add consumer ----------- ")
        consumer = assert(helpers.dao.consumers:insert {
            username = "foo",
            custom_id = "cust_foo"
        })
        anonymous_consumer = assert(helpers.dao.consumers:insert {
            username = "no-body",
            custom_id = "cust_no_body"
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

        print("\n----------- Plugin configuration with anonymous consumer ----------- ")
        local res = assert(admin_client:send {
            method = "POST",
            path = "/apis/api2/plugins",
            body = {
                name = "gluu-oauth2-client-auth",
                config = {
                    op_server = op_server,
                    oxd_http_url = oxd_http,
                    anonymous = anonymous_consumer.id
                },
            },
            headers = {
                ["Content-Type"] = "application/json"
            }
        })
        assert.response(res).has.status(201)
        plugin_anonymous = assert.response(res).has.jsonbody()
        for k, v in pairs(plugin_anonymous) do
            print(k, ": ", v)
            if k == 'config' then
                for sk, sv in pairs(v) do
                    print(sk, ": ", sv)
                end
            end
        end

        print("\n----------- Plugin configuration API3 ----------- ")
        local res = assert(admin_client:send {
            method = "POST",
            path = "/apis/api3/plugins",
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

        print("\n----------- Plugin configuration API4 ----------- ")
        local res = assert(admin_client:send {
            method = "POST",
            path = "/apis/api4/plugins",
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
        plugin4 = assert.response(res).has.jsonbody()
        for k, v in pairs(plugin4) do
            print(k, ": ", v)
            if k == 'config' then
                for sk, sv in pairs(v) do
                    print(sk, ": ", sv)
                end
            end
        end

        print("\n----------- Plugin configuration API5 ----------- ")
        local res = assert(admin_client:send {
            method = "POST",
            path = "/apis/api5/plugins",
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
        plugin5 = assert.response(res).has.jsonbody()
        for k, v in pairs(plugin5) do
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
                op_host = op_server,
                oxd_http_url = oxd_http,
                allow_oauth_scope_expression = false
            },
            headers = {
                ["Content-Type"] = "application/json"
            }
        })
        oauth2_consumer_oauth_mode = cjson.decode(assert.res_status(201, res))
        auth_helper.print_table(oauth2_consumer_oauth_mode)

        print("\n----------- OAuth2 consumer oauth mode and scope expression ----------- ")
        local res = assert(admin_client:send {
            method = "POST",
            path = "/consumers/foo/gluu-oauth2-client-auth",
            body = {
                name = "oauth2_credential_oauth_mode",
                op_host = op_server,
                oxd_http_url = oxd_http,
                oauth_mode = true,
                allow_oauth_scope_expression = true
            },
            headers = {
                ["Content-Type"] = "application/json"
            }
        })
        oauth2_consumer_oauth_mode_scope_expression = cjson.decode(assert.res_status(201, res))
        auth_helper.print_table(oauth2_consumer_oauth_mode_scope_expression)

        print("\n----------- OAuth2 consumer credential with mix_mode = true ----------- ")
        local res = assert(admin_client:send {
            method = "POST",
            path = "/consumers/foo/gluu-oauth2-client-auth",
            body = {
                name = "oauth2_credential_mix_mode",
                op_host = op_server,
                oxd_http_url = oxd_http,
                mix_mode = true
            },
            headers = {
                ["Content-Type"] = "application/json"
            }
        })
        oauth2_consumer_with_mix_mode = cjson.decode(assert.res_status(201, res))
        auth_helper.print_table(oauth2_consumer_with_mix_mode)

        print("\n----------- OAuth2 consumer credential with uma_mode = true ----------- ")
        local res = assert(admin_client:send {
            method = "POST",
            path = "/consumers/foo/gluu-oauth2-client-auth",
            body = {
                name = "oauth2_credential_uma_mode",
                op_host = op_server,
                oxd_http_url = oxd_http,
                uma_mode = true
            },
            headers = {
                ["Content-Type"] = "application/json"
            }
        })
        oauth2_consumer_with_uma_mode = cjson.decode(assert.res_status(201, res))
        auth_helper.print_table(oauth2_consumer_with_uma_mode)

        print("\n----------- OAuth2 consumer credential with uma_mode = true, allow_unprotected_path = true ----------- ")
        local res = assert(admin_client:send {
            method = "POST",
            path = "/consumers/foo/gluu-oauth2-client-auth",
            body = {
                name = "oauth2_credential_uma_mode",
                op_host = op_server,
                oxd_http_url = oxd_http,
                uma_mode = true,
                allow_unprotected_path = true
            },
            headers = {
                ["Content-Type"] = "application/json"
            }
        })
        oauth2_consumer_with_uma_mode_allow_unprotected_path = cjson.decode(assert.res_status(201, res))
        auth_helper.print_table(oauth2_consumer_with_uma_mode_allow_unprotected_path)

        print("\n----------- OAuth2 consumer credential with mix_mode = true, allow_unprotected_path = true ----------- ")
        local res = assert(admin_client:send {
            method = "POST",
            path = "/consumers/foo/gluu-oauth2-client-auth",
            body = {
                name = "oauth2_credential_uma_mode",
                op_host = op_server,
                oxd_http_url = oxd_http,
                mix_mode = true,
                allow_unprotected_path = true
            },
            headers = {
                ["Content-Type"] = "application/json"
            }
        })
        oauth2_consumer_with_mix_mode_allow_unprotected_path = cjson.decode(assert.res_status(201, res))
        auth_helper.print_table(oauth2_consumer_with_mix_mode_allow_unprotected_path)

        print("\n----------- OAuth2 consumer credential with mix_mode = true, show_consumer_custom_id = false ----------- ")
        local res = assert(admin_client:send {
            method = "POST",
            path = "/consumers/foo/gluu-oauth2-client-auth",
            body = {
                name = "oauth2_credential_uma_mode",
                op_host = op_server,
                oxd_http_url = oxd_http,
                mix_mode = true,
                show_consumer_custom_id = false
            },
            headers = {
                ["Content-Type"] = "application/json"
            }
        })
        oauth2_consumer_with_mix_mode_hide_consumer_custom_id = cjson.decode(assert.res_status(201, res))
        auth_helper.print_table(oauth2_consumer_with_mix_mode_hide_consumer_custom_id)

        print("\n----------- OAuth2 consumer credential with restricted API ----------- ")
        local res = assert(admin_client:send {
            method = "POST",
            path = "/consumers/foo/gluu-oauth2-client-auth",
            body = {
                name = "oauth2_credential_uma_mode",
                op_host = op_server,
                oxd_http_url = oxd_http,
                mix_mode = true,
                restrict_api = true,
                restrict_api_list = table.concat({ api.id, api2.id }, ",")
            },
            headers = {
                ["Content-Type"] = "application/json"
            }
        })
        oauth2_consumer_with_restricted_api = cjson.decode(assert.res_status(201, res))
        auth_helper.print_table(oauth2_consumer_with_restricted_api)

        -- ------------------Extra client for invalid token ----------------
        local setupClientRequest = {
            oxd_host = oxd_http,
            scope = { "openid", "uma_protection" },
            op_host = op_server,
            authorization_redirect_uri = "https://localhost",
            grant_types = { "client_credentials" },
            client_name = "extra_client_for_invalid_token"
        };

        local setupClientResponse = oxd.setup_client(setupClientRequest)

        -- ------------------GET Client Token-------------------------------
        local tokenRequest = {
            oxd_host = oxd_http,
            client_id = setupClientResponse.data.client_id,
            client_secret = setupClientResponse.data.client_secret,
            scope = { "openid", "uma_protection" },
            op_host = op_server
        };

        local tokenRespose = oxd.get_client_token(tokenRequest)
        invalidToken = tokenRespose.data.access_token
        -- -----------------------------------------------------------------
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

    describe("oauth2-consumer flow without gluu_oauth2_rs plugin", function()
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
                        ["Authorization"] = "Bearer " .. invalidToken
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
                        ["Authorization"] = "Bearer sdsfsdf-dsfdf-sdfsf4535-4545"
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

                -- 1st request, Cache is not exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- 2nd time request
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- 3rs time request
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
                        ["Authorization"] = "Bearer " .. invalidToken
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

                -- 1st time request, Cache is not exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- 2nd time request, when cache exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- 3rs time request, when cache exist
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
                        ["Authorization"] = "Bearer " .. invalidToken
                    }
                })
                assert.res_status(401, res)
            end)

            it("Get 200 status when token is active = true but token is oauth2 access token", function()
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
                -- 1st time request, Cache is not exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- 2nd time request, when cache exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- 3rd time request, when cache exist
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

    describe("oauth2-consumer flow with anonymous consumer", function()
        describe("When oauth2-consumer is in oauth_mode = true", function()
            it("200 Unauthorized when token is not present in header", function()
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "api2.typicode.com",
                        ["Authorization"] = "Bearer fddfsdfsd-sdfsdf-sdfsdf-fdsdfsd",
                    }
                })
                assert.res_status(200, res)
            end)
        end)
    end)

    describe("oauth2-consumer flow with gluu_oauth2_rs plugin", function()
        local gluu_oauth2_rs_plugin
        setup(function()
            local res = assert(admin_client:send {
                method = "POST",
                path = "/apis/json/plugins",
                body = {
                    name = "gluu-oauth2-rs",
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
            gluu_oauth2_rs_plugin = assert.response(res).has.jsonbody()
        end)

        -- oauth_mode
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
                assert.is_truthy(string.find(res.headers["WWW-Authenticate"], "ticket"))
            end)

            it("401 Unauthorized when token is invalid", function()
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. invalidToken
                    }
                })
                assert.res_status(401, res)
            end)

            it("401 status when UMA RPT token active = true but oauth_mode is active", function()
                -- ------------------GET Client Token-------------------------------
                local tokenRequest = {
                    oxd_host = gluu_oauth2_rs_plugin.config.oxd_host,
                    client_id = gluu_oauth2_rs_plugin.config.client_id,
                    client_secret = gluu_oauth2_rs_plugin.config.client_secret,
                    scope = { "openid", "uma_protection" },
                    op_host = gluu_oauth2_rs_plugin.config.uma_server_host
                };

                local token = oxd.get_client_token(tokenRequest)
                -- -----------------------------------------------------------------

                -- ------------------GET check_access-------------------------------
                local umaAccessRequest = {
                    oxd_host = gluu_oauth2_rs_plugin.config.oxd_host,
                    oxd_id = gluu_oauth2_rs_plugin.config.oxd_id,
                    rpt = "",
                    path = "/posts",
                    http_method = "GET"
                }
                local umaAccessResponse = oxd.uma_rs_check_access(umaAccessRequest, token.data.access_token)

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

                -- ------------------GET rpt-------------------------------
                local umaGetRPTRequest = {
                    oxd_host = oauth2_consumer_oauth_mode.oxd_http_url,
                    oxd_id = oauth2_consumer_oauth_mode.oxd_id,
                    ticket = umaAccessResponse.data.ticket
                }
                local umaGetRPTResponse = oxd.uma_rp_get_rpt(umaGetRPTRequest, req_access_token)

                -- -----------------------------------------------------------------
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. umaGetRPTResponse.data.access_token,
                    }
                })
                local body = assert.res_status(401, res)
                local json = cjson.decode(body)
                assert.equal("Unauthorized", json.message)
            end)

            it("200 status when oauth token is active = true", function()
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

                -- 1st time request, Cache is not exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- 2nd time request, when cache exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- 3rs time request, when cache exist
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

        -- This is same case when token_type is OAuth
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
                assert.is_truthy(string.find(res.headers["WWW-Authenticate"], "ticket"))
            end)

            it("401 Unauthorized when token is invalid", function()
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. invalidToken
                    }
                })
                assert.res_status(401, res)
            end)

            it("200 status when token is active = true", function()
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

                -- 1st time request, Cache is not exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token
                    }
                })
                assert.res_status(200, res)

                -- 2nd time request, when cache exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- Request with other path
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/comments",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- 2nd time Request with other path
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/comments",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- 3rs time request with first path, when cache exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- Request with unregister path - 401/Unauthorized allow_unprotected_path = false
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/todos",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(401, res)
                assert.equal(true, not auth_helper.is_empty(res.headers["uma-warning"]))
            end)

            it("401 status when OAuth token is active = true but uma_mode is active", function()
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

                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                local body = assert.res_status(401, res)
                local json = cjson.decode(body)
                assert.equal("Unauthorized! UMA Token is required in UMA Mode", json.message)
            end)
        end)

        -- This is same case when token_type is UMA RPT token
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
                assert.is_truthy(string.find(res.headers["WWW-Authenticate"], "ticket"))
            end)

            it("401 Unauthorized when token is invalid", function()
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. invalidToken
                    }
                })
                assert.res_status(401, res)
            end)

            it("200 status when token is RPT token active = true", function()
                -- ------------------GET Client Token-------------------------------
                local tokenRequest = {
                    oxd_host = gluu_oauth2_rs_plugin.config.oxd_host,
                    client_id = gluu_oauth2_rs_plugin.config.client_id,
                    client_secret = gluu_oauth2_rs_plugin.config.client_secret,
                    scope = { "openid", "uma_protection" },
                    op_host = gluu_oauth2_rs_plugin.config.uma_server_host
                };

                local token = oxd.get_client_token(tokenRequest)
                -- -----------------------------------------------------------------

                -- ------------------GET check_access-------------------------------
                local umaAccessRequest = {
                    oxd_host = gluu_oauth2_rs_plugin.config.oxd_host,
                    oxd_id = gluu_oauth2_rs_plugin.config.oxd_id,
                    rpt = "",
                    path = "/posts",
                    http_method = "GET"
                }
                local umaAccessResponse = oxd.uma_rs_check_access(umaAccessRequest, token.data.access_token)

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

                -- ------------------GET rpt-------------------------------
                local umaGetRPTRequest = {
                    oxd_host = oauth2_consumer_with_uma_mode.oxd_http_url,
                    oxd_id = oauth2_consumer_with_uma_mode.oxd_id,
                    ticket = umaAccessResponse.data.ticket
                }
                local umaGetRPTResponse = oxd.uma_rp_get_rpt(umaGetRPTRequest, req_access_token)

                -- -----------------------------------------------------------------

                -- 1st time request, Cache is not exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. umaGetRPTResponse.data.access_token,
                    }
                })
                assert.res_status(200, res)

                -- 2nd time request, when cache exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. umaGetRPTResponse.data.access_token,
                    }
                })
                assert.res_status(200, res)

                -- 3rd time request, when cache exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. umaGetRPTResponse.data.access_token,
                    }
                })
                assert.res_status(200, res)

                -- Request to other register path, 403/Forbidden because RPT token is for path /posts not for /comments
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/comments",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. umaGetRPTResponse.data.access_token,
                    }
                })
                assert.res_status(401, res)
                assert.is_truthy(string.find(res.headers["WWW-Authenticate"], "ticket"))

                -- Request with unregister path - 401/Unauthorized - allow_unprotected_path = false
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/todos",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. umaGetRPTResponse.data.access_token,
                    }
                })
                assert.res_status(401, res)
                assert.equal(true, not auth_helper.is_empty(res.headers["uma-warning"]))
            end)

            it("401 status when UMA RPT token active = true but oauth_mode is active", function()
                -- ------------------GET Client Token-------------------------------
                local tokenRequest = {
                    oxd_host = gluu_oauth2_rs_plugin.config.oxd_host,
                    client_id = gluu_oauth2_rs_plugin.config.client_id,
                    client_secret = gluu_oauth2_rs_plugin.config.client_secret,
                    scope = { "openid", "uma_protection" },
                    op_host = gluu_oauth2_rs_plugin.config.uma_server_host
                };

                local token = oxd.get_client_token(tokenRequest)
                -- -----------------------------------------------------------------

                -- ------------------GET check_access-------------------------------
                local umaAccessRequest = {
                    oxd_host = gluu_oauth2_rs_plugin.config.oxd_host,
                    oxd_id = gluu_oauth2_rs_plugin.config.oxd_id,
                    rpt = "",
                    path = "/posts",
                    http_method = "GET"
                }
                local umaAccessResponse = oxd.uma_rs_check_access(umaAccessRequest, token.data.access_token)

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

                -- ------------------GET rpt-------------------------------
                local umaGetRPTRequest = {
                    oxd_host = oauth2_consumer_oauth_mode.oxd_http_url,
                    oxd_id = oauth2_consumer_oauth_mode.oxd_id,
                    ticket = umaAccessResponse.data.ticket
                }
                local umaGetRPTResponse = oxd.uma_rp_get_rpt(umaGetRPTRequest, req_access_token)

                -- -----------------------------------------------------------------
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. umaGetRPTResponse.data.access_token,
                    }
                })
                local body = assert.res_status(401, res)
                local json = cjson.decode(body)
                assert.equal("Unauthorized", json.message)
            end)
        end)

        -- This is same case when token_type is OAuth with allow_unprotected_path is allow
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
                assert.is_truthy(string.find(res.headers["WWW-Authenticate"], "ticket"))
            end)

            it("401 Unauthorized when token is invalid", function()
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. invalidToken
                    }
                })
                assert.res_status(401, res)
            end)

            it("200 status when token is active = true", function()
                -- ------------------GET Client Token-------------------------------
                local tokenRequest = {
                    oxd_host = oauth2_consumer_with_mix_mode_allow_unprotected_path.oxd_http_url,
                    client_id = oauth2_consumer_with_mix_mode_allow_unprotected_path.client_id,
                    client_secret = oauth2_consumer_with_mix_mode_allow_unprotected_path.client_secret,
                    scope = { "openid", "uma_protection" },
                    op_host = oauth2_consumer_with_mix_mode_allow_unprotected_path.op_host
                };

                local token = oxd.get_client_token(tokenRequest)
                local req_access_token = token.data.access_token

                -- 1st time request with register path, Cache is not exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token
                    }
                })
                assert.res_status(200, res)
                assert.equal(true, auth_helper.is_empty(res.headers["uma-warning"]))

                -- 2nd time request with register path, when cache exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)
                assert.equal(true, auth_helper.is_empty(res.headers["uma-warning"]))

                -- 3rs time request with register path, when cache exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)
                assert.equal(true, auth_helper.is_empty(res.headers["uma-warning"]))

                -- Request with register other path
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/comments",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)
                assert.equal(true, auth_helper.is_empty(res.headers["uma-warning"]))

                -- 2nd time Request with register other path
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/comments",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)
                assert.equal(true, auth_helper.is_empty(res.headers["uma-warning"]))

                -- Request with unregister path - 200 Status
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/todos",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)
                assert.equal(true, not auth_helper.is_empty(res.headers["uma-warning"]))

                -- 2nd request with unregister path - 200 Status
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/todos",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)
                assert.equal(true, not auth_helper.is_empty(res.headers["uma-warning"]))
            end)
        end)

        -- This is same case when token_type is UMA RPT token with allow_unprotected_path is allow
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
                assert.is_truthy(string.find(res.headers["WWW-Authenticate"], "ticket"))
            end)

            it("401 Unauthorized when token is invalid", function()
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. invalidToken
                    }
                })
                assert.res_status(401, res)
            end)

            it("200 status when token is RPT token active = true", function()
                -- ------------------GET Client Token-------------------------------
                local tokenRequest = {
                    oxd_host = gluu_oauth2_rs_plugin.config.oxd_host,
                    client_id = gluu_oauth2_rs_plugin.config.client_id,
                    client_secret = gluu_oauth2_rs_plugin.config.client_secret,
                    scope = { "openid", "uma_protection" },
                    op_host = gluu_oauth2_rs_plugin.config.uma_server_host
                };

                local token = oxd.get_client_token(tokenRequest)
                -- -----------------------------------------------------------------

                -- ------------------GET check_access-------------------------------
                local umaAccessRequest = {
                    oxd_host = gluu_oauth2_rs_plugin.config.oxd_host,
                    oxd_id = gluu_oauth2_rs_plugin.config.oxd_id,
                    rpt = "",
                    path = "/posts",
                    http_method = "GET"
                }
                local umaAccessResponse = oxd.uma_rs_check_access(umaAccessRequest, token.data.access_token)

                -- ------------------GET Client Token-------------------------------
                local tokenRequest = {
                    oxd_host = oauth2_consumer_with_uma_mode_allow_unprotected_path.oxd_http_url,
                    client_id = oauth2_consumer_with_uma_mode_allow_unprotected_path.client_id,
                    client_secret = oauth2_consumer_with_uma_mode_allow_unprotected_path.client_secret,
                    scope = { "openid", "uma_protection" },
                    op_host = oauth2_consumer_with_uma_mode_allow_unprotected_path.op_host
                };

                local token = oxd.get_client_token(tokenRequest)
                local req_access_token = token.data.access_token

                -- ------------------GET rpt-------------------------------
                local umaGetRPTRequest = {
                    oxd_host = oauth2_consumer_with_uma_mode_allow_unprotected_path.oxd_http_url,
                    oxd_id = oauth2_consumer_with_uma_mode_allow_unprotected_path.oxd_id,
                    ticket = umaAccessResponse.data.ticket
                }
                local umaGetRPTResponse = oxd.uma_rp_get_rpt(umaGetRPTRequest, req_access_token)

                -- -----------------------------------------------------------------

                -- 1st time request to register path, Cache is not exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. umaGetRPTResponse.data.access_token,
                    }
                })
                assert.res_status(200, res)
                assert.equal(true, auth_helper.is_empty(res.headers["uma-warning"]))

                -- 2nd time request to register path, when cache exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. umaGetRPTResponse.data.access_token,
                    }
                })
                assert.res_status(200, res)
                assert.equal(true, auth_helper.is_empty(res.headers["uma-warning"]))

                -- 3rd time request to register path, when cache exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. umaGetRPTResponse.data.access_token,
                    }
                })
                assert.res_status(200, res)
                assert.equal(true, auth_helper.is_empty(res.headers["uma-warning"]))

                -- Request to other register path, 403/Forbidden because RPT token is for path /posts not for /comments
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/comments",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. umaGetRPTResponse.data.access_token,
                    }
                })
                assert.res_status(401, res)
                assert.is_truthy(string.find(res.headers["WWW-Authenticate"], "ticket"))

                -- Request with unregister path - 401/Unauthorized - allow_unprotected_path = false
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/todos",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. umaGetRPTResponse.data.access_token,
                    }
                })
                assert.res_status(200, res)
                assert.equal(true, not auth_helper.is_empty(res.headers["uma-warning"]))

                -- Request again with unregister path - 401/Unauthorized - allow_unprotected_path = false
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/todos",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. umaGetRPTResponse.data.access_token,
                    }
                })
                assert.res_status(200, res)
                assert.equal(true, not auth_helper.is_empty(res.headers["uma-warning"]))
            end)
        end)

        -- After update resources
        describe("After update resources, When oauth2-consumer is in mix_mode = true", function()
            setup(function()
                local config = gluu_oauth2_rs_plugin.config
                config.protection_document = "[{\"path\":\"/todos\",\"conditions\":[{\"httpMethods\":[\"GET\",\"POST\"],\"scope_expression\":{\"rule\":{\"or\":[{\"var\":0}]},\"data\":[\"https://jsonplaceholder.typicode.com\"]}}]},{\"path\":\"/comments\",\"conditions\":[{\"httpMethods\":[\"GET\"],\"scope_expression\":{\"rule\":{\"and\":[{\"var\":0}]},\"data\":[\"https://jsonplaceholder.typicode.com\"]}}]}]"
                local res = assert(admin_client:send {
                    method = "PATCH",
                    path = "/plugins/" .. gluu_oauth2_rs_plugin.id,
                    body = {
                        name = "gluu-oauth2-rs",
                        config = config,
                    },
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                })
                assert.response(res).has.status(200)
                gluu_oauth2_rs_plugin = assert.response(res).has.jsonbody()
                assert.is_truthy(string.find(gluu_oauth2_rs_plugin.config.protection_document, "todos"))
            end)

            it("200 status when token is active = true", function()
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

                -- 1st time request, Cache is not exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/todos",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token
                    }
                })
                assert.res_status(200, res)

                -- 2nd time request, when cache exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/todos",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- Request with other path
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/comments",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- 2nd time Request with other path
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/comments",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- 3rs time request with first path, when cache exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/todos",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- Request with unregister path - 401/Unauthorized allow_unprotected_path = false
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(401, res)
                assert.equal(true, not auth_helper.is_empty(res.headers["uma-warning"]))
            end)
        end)

        -- Hide consumer custom id
        describe("When oauth2-consumer is show_consumer_custom_id = false", function()
            it("200 status when token is active = true", function()
                -- ------------------GET Client Token-------------------------------
                local tokenRequest = {
                    oxd_host = oauth2_consumer_with_mix_mode_hide_consumer_custom_id.oxd_http_url,
                    client_id = oauth2_consumer_with_mix_mode_hide_consumer_custom_id.client_id,
                    client_secret = oauth2_consumer_with_mix_mode_hide_consumer_custom_id.client_secret,
                    scope = { "openid", "uma_protection" },
                    op_host = oauth2_consumer_with_mix_mode_hide_consumer_custom_id.op_host
                };

                local token = oxd.get_client_token(tokenRequest)
                local req_access_token = token.data.access_token

                -- 1st time Request
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/comments",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)
            end)
        end)

        -- Request with UMA_PUSHED_CLAIMS
        describe("When oauth2-consumer is show_consumer_custom_id = false", function()
            it("200 status when token is active = true", function()
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

                -- 1st time Request, 200 HTTP Status
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/comments",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                        ["UMA_PUSHED_CLAIMS"] = "{\"claim_token\":\"eyJraWQiOiJiNGJiZWYyZS0xYjBiLTRmNjYtOTVjYy1lMDQ5ZGRhYmY2ZTciLCJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczovL2dsdXUubG9jYWwub3JnIiwiYXVkIjoiQCE1ODMzLjUzRUQuNkZFRC5EQTdFITAwMDEhQkY1OC5DQTA3ITAwMDghRkM3OC5CMjJELjk4QkUuNzkxQiIsImV4cCI6MTUyMjc0OTI4MSwiaWF0IjoxNTIyNzQ1NjgxLCJub25jZSI6InJtMTlrM2x2NGVhNmZvams5dnZuaWZwZGd1IiwiYXV0aF90aW1lIjoxNTIyNzQ1Njc5LCJhdF9oYXNoIjoidVJUUjk1bEo0LUNLN2x1bFFUamtDQSIsIm94T3BlbklEQ29ubmVjdFZlcnNpb24iOiJvcGVuaWRjb25uZWN0LTEuMCIsInN1YiI6InFaRUVUUnpxYWZ5Ujc4THZSeFI2Z184X0NvN3ZuXzhFeG9oaHN0ZDBGcGcifQ.Zm_qg547zB-XI4PYW53b1d2pnU00_G5DNG1qFMbZjpJIFvCzAh6A9xvptMKxC9LgvMeUAAW4OlaQAGpDzgVmM1rGnapPuhyZhUdZvFyXWv_5ZdYWu6ajiOj0Hs2XKB-5Bp33tNtM8PtwW_2ax8wGvuEjZeXQal6AMc1fwvctrInF5776HZ70LnopUMlkIagDcjft6ZF1FFpzDSGTSHI91d4fXsosSK4_dqgbr_QhZGD65xAgiJyvkrxGEQRRmQF7CM2EljPSzfhZf59ek-aVtsfmZNStmY94MWbAoyjpQAlksoQU-cK_deLHbPxxkYRIGGQn4wRqpRd1UOH9rtPAow\", \"claim_token_format\": \"http://openid.net/specs/openid-connect-core-1_0.html#IDToken\"}"
                    }
                })
                assert.res_status(200, res)

                -- 2nd time Request, 200 HTTP Status
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/comments",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                        ["UMA_PUSHED_CLAIMS"] = "{\"claim_token\":\"eyJraWQiOiJiNGJiZWYyZS0xYjBiLTRmNjYtOTVjYy1lMDQ5ZGRhYmY2ZTciLCJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczovL2dsdXUubG9jYWwub3JnIiwiYXVkIjoiQCE1ODMzLjUzRUQuNkZFRC5EQTdFITAwMDEhQkY1OC5DQTA3ITAwMDghRkM3OC5CMjJELjk4QkUuNzkxQiIsImV4cCI6MTUyMjc0OTI4MSwiaWF0IjoxNTIyNzQ1NjgxLCJub25jZSI6InJtMTlrM2x2NGVhNmZvams5dnZuaWZwZGd1IiwiYXV0aF90aW1lIjoxNTIyNzQ1Njc5LCJhdF9oYXNoIjoidVJUUjk1bEo0LUNLN2x1bFFUamtDQSIsIm94T3BlbklEQ29ubmVjdFZlcnNpb24iOiJvcGVuaWRjb25uZWN0LTEuMCIsInN1YiI6InFaRUVUUnpxYWZ5Ujc4THZSeFI2Z184X0NvN3ZuXzhFeG9oaHN0ZDBGcGcifQ.Zm_qg547zB-XI4PYW53b1d2pnU00_G5DNG1qFMbZjpJIFvCzAh6A9xvptMKxC9LgvMeUAAW4OlaQAGpDzgVmM1rGnapPuhyZhUdZvFyXWv_5ZdYWu6ajiOj0Hs2XKB-5Bp33tNtM8PtwW_2ax8wGvuEjZeXQal6AMc1fwvctrInF5776HZ70LnopUMlkIagDcjft6ZF1FFpzDSGTSHI91d4fXsosSK4_dqgbr_QhZGD65xAgiJyvkrxGEQRRmQF7CM2EljPSzfhZf59ek-aVtsfmZNStmY94MWbAoyjpQAlksoQU-cK_deLHbPxxkYRIGGQn4wRqpRd1UOH9rtPAow\", \"claim_token_format\": \"http://openid.net/specs/openid-connect-core-1_0.html#IDToken\"}"
                    }
                })
                assert.res_status(200, res)

                -- Without claim token, 401/Unauthorized
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/comments",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token
                    }
                })
                assert.res_status(401, res)

                -- Invalid claim token, 401/Unauthorized
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/comments",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                        ["UMA_PUSHED_CLAIMS"] = "{\"claim_token\":\"yJraWQiOiJiNGJiZWYyZS0xYjBiLTRmNjYtOTVjYy1lMDQ5ZGRhYmY2ZTciLCJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczovL2dsdXUubG9jYWwub3JnIiwiYXVkIjoiQCE1ODMzLjUzRUQuNkZFRC5EQTdFITAwMDEhQkY1OC5DQTA3ITAwMDghRkM3OC5CMjJELjk4QkUuNzkxQiIsImV4cCI6MTUyMjc0OTI4MSwiaWF0IjoxNTIyNzQ1NjgxLCJub25jZSI6InJtMTlrM2x2NGVhNmZvams5dnZuaWZwZGd1IiwiYXV0aF90aW1lIjoxNTIyNzQ1Njc5LCJhdF9oYXNoIjoidVJUUjk1bEo0LUNLN2x1bFFUamtDQSIsIm94T3BlbklEQ29ubmVjdFZlcnNpb24iOiJvcGVuaWRjb25uZWN0LTEuMCIsInN1YiI6InFaRUVUUnpxYWZ5Ujc4THZSeFI2Z184X0NvN3ZuXzhFeG9oaHN0ZDBGcGcifQ.Zm_qg547zB-XI4PYW53b1d2pnU00_G5DNG1qFMbZjpJIFvCzAh6A9xvptMKxC9LgvMeUAAW4OlaQAGpDzgVmM1rGnapPuhyZhUdZvFyXWv_5ZdYWu6ajiOj0Hs2XKB-5Bp33tNtM8PtwW_2ax8wGvuEjZeXQal6AMc1fwvctrInF5776HZ70LnopUMlkIagDcjft6ZF1FFpzDSGTSHI91d4fXsosSK4_dqgbr_QhZGD65xAgiJyvkrxGEQRRmQF7CM2EljPSzfhZf59ek-aVtsfmZNStmY94MWbAoyjpQAlksoQU-cK_deLHbPxxkYRIGGQn4wRqpRd1UOH9rtPAow\", \"claim_token_format\": \"http://openid.net/specs/openid-connect-core-1_0.html#IDToken\"}"
                    }
                })
                assert.res_status(401, res)

                -- 3rs time Request with valid claim token, 200 HTTP Status
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/comments",
                    headers = {
                        ["Host"] = "jsonplaceholder.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                        ["UMA_PUSHED_CLAIMS"] = "{\"claim_token\":\"eyJraWQiOiJiNGJiZWYyZS0xYjBiLTRmNjYtOTVjYy1lMDQ5ZGRhYmY2ZTciLCJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczovL2dsdXUubG9jYWwub3JnIiwiYXVkIjoiQCE1ODMzLjUzRUQuNkZFRC5EQTdFITAwMDEhQkY1OC5DQTA3ITAwMDghRkM3OC5CMjJELjk4QkUuNzkxQiIsImV4cCI6MTUyMjc0OTI4MSwiaWF0IjoxNTIyNzQ1NjgxLCJub25jZSI6InJtMTlrM2x2NGVhNmZvams5dnZuaWZwZGd1IiwiYXV0aF90aW1lIjoxNTIyNzQ1Njc5LCJhdF9oYXNoIjoidVJUUjk1bEo0LUNLN2x1bFFUamtDQSIsIm94T3BlbklEQ29ubmVjdFZlcnNpb24iOiJvcGVuaWRjb25uZWN0LTEuMCIsInN1YiI6InFaRUVUUnpxYWZ5Ujc4THZSeFI2Z184X0NvN3ZuXzhFeG9oaHN0ZDBGcGcifQ.Zm_qg547zB-XI4PYW53b1d2pnU00_G5DNG1qFMbZjpJIFvCzAh6A9xvptMKxC9LgvMeUAAW4OlaQAGpDzgVmM1rGnapPuhyZhUdZvFyXWv_5ZdYWu6ajiOj0Hs2XKB-5Bp33tNtM8PtwW_2ax8wGvuEjZeXQal6AMc1fwvctrInF5776HZ70LnopUMlkIagDcjft6ZF1FFpzDSGTSHI91d4fXsosSK4_dqgbr_QhZGD65xAgiJyvkrxGEQRRmQF7CM2EljPSzfhZf59ek-aVtsfmZNStmY94MWbAoyjpQAlksoQU-cK_deLHbPxxkYRIGGQn4wRqpRd1UOH9rtPAow\", \"claim_token_format\": \"http://openid.net/specs/openid-connect-core-1_0.html#IDToken\"}"
                    }
                })
                assert.res_status(200, res)
            end)
        end)
    end)

    describe("oauth2-consumer with restricted APIS", function()
        local req_access_token, token
        setup(function()
            -- ------------------GET Client Token-------------------------------
            local tokenRequest = {
                oxd_host = oauth2_consumer_with_restricted_api.oxd_http_url,
                client_id = oauth2_consumer_with_restricted_api.client_id,
                client_secret = oauth2_consumer_with_restricted_api.client_secret,
                scope = { "openid", "uma_protection" },
                op_host = oauth2_consumer_with_restricted_api.op_host
            };

            token = oxd.get_client_token(tokenRequest)
            req_access_token = token.data.access_token
        end)

        it("401 Unauthorized with un-specified API", function()
            local res = assert(proxy_client:send {
                method = "GET",
                path = "/comments",
                headers = {
                    ["Host"] = "api3.typicode.com",
                    ["Authorization"] = "Bearer " .. req_access_token
                }
            })
            assert.res_status(401, res)
        end)

        it("200 authorized with specified API", function()
            local res = assert(proxy_client:send {
                method = "GET",
                path = "/comments",
                headers = {
                    ["Host"] = "jsonplaceholder.typicode.com",
                    ["Authorization"] = "Bearer " .. req_access_token
                }
            })
            assert.res_status(200, res)
        end)

        it("200 authorized with specified API", function()
            local res = assert(proxy_client:send {
                method = "GET",
                path = "/comments",
                headers = {
                    ["Host"] = "jsonplaceholder.typicode.com",
                    ["Authorization"] = "Bearer " .. req_access_token
                }
            })
            assert.res_status(200, res)
        end)

        it("401 Unauthorized with un-specified API", function()
            local res = assert(proxy_client:send {
                method = "GET",
                path = "/comments",
                headers = {
                    ["Host"] = "api3.typicode.com",
                    ["Authorization"] = "Bearer " .. req_access_token
                }
            })
            assert.res_status(401, res)
        end)

        it("200 authorized with specified API", function()
            local res = assert(proxy_client:send {
                method = "GET",
                path = "/comments",
                headers = {
                    ["Host"] = "api2.typicode.com",
                    ["Authorization"] = "Bearer " .. req_access_token
                }
            })
            assert.res_status(200, res)
        end)

        it("200 authorized with specified API", function()
            local res = assert(proxy_client:send {
                method = "GET",
                path = "/comments",
                headers = {
                    ["Host"] = "api2.typicode.com",
                    ["Authorization"] = "Bearer " .. req_access_token
                }
            })
            assert.res_status(200, res)
        end)
    end)

    describe("oauth2-consumer flow with gluu_oauth2_rs and oauth scope expression", function()
        local gluu_oauth2_rs_plugin
        setup(function()
            local res = assert(admin_client:send {
                method = "POST",
                path = "/apis/api4/plugins",
                body = {
                    name = "gluu-oauth2-rs",
                    config = {
                        uma_server_host = op_server,
                        oxd_host = oxd_http,
                        oauth_scope_expression = "[{\"path\":\"/posts\",\"conditions\":[{\"httpMethods\":[\"GET\",\"DELETE\",\"POST\",\"PUT\"],\"scope_expression\":{\"and\":[\"openid\"]}}]},{\"path\":\"/todos\",\"conditions\":[{\"httpMethods\":[\"GET\",\"DELETE\",\"POST\",\"PUT\"],\"scope_expression\":{\"and\":[\"openid\"]}}]},{\"path\":\"/todos/users\",\"conditions\":[{\"httpMethods\":[\"GET\",\"POST\",\"PUT\",\"DELETE\"],\"scope_expression\":{\"and\":[\"openid\",\"uma_protection\"]}}]},{\"path\":\"/todos/users/posts\",\"conditions\":[{\"httpMethods\":[\"GET\",\"POST\",\"PUT\",\"DELETE\"],\"scope_expression\":{\"and\":[\"openid\",\"uma_protection\",\"calendar\"]}}]}]"
                    },
                },
                headers = {
                    ["Content-Type"] = "application/json"
                }
            })
            assert.response(res).has.status(201)
            gluu_oauth2_rs_plugin = assert.response(res).has.jsonbody()
        end)

        -- oauth_mode
        describe("When oauth2-consumer is in oauth_mode = true", function()
            it("401 Unauthorized with ticket when token is not present in header", function()
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "api4.typicode.com"
                    }
                })
                assert.res_status(401, res)
            end)

            it("401 Unauthorized when token is invalid", function()
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "api4.typicode.com",
                        ["Authorization"] = "Bearer " .. invalidToken
                    }
                })
                assert.res_status(401, res)
            end)

            it("Check diff path with diff scope", function()
                -- ------------------GET Client Token-------------------------------
                local tokenRequest = {
                    oxd_host = oauth2_consumer_oauth_mode_scope_expression.oxd_http_url,
                    client_id = oauth2_consumer_oauth_mode_scope_expression.client_id,
                    client_secret = oauth2_consumer_oauth_mode_scope_expression.client_secret,
                    scope = { "openid", "uma_protection", "calendar" },
                    op_host = oauth2_consumer_oauth_mode_scope_expression.op_host
                };

                local token = oxd.get_client_token(tokenRequest)
                local req_access_token = token.data.access_token

                -- 1st time request, Cache is not exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "api4.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- 2nd time request, when cache exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "api4.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- 3rs time request, when cache exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "api4.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- Post method
                local res = assert(proxy_client:send {
                    method = "POST",
                    path = "/posts",
                    headers = {
                        ["Host"] = "api4.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                        ["Content-Type"] = "application/json"
                    },
                    body = {
                        name = "Test",
                        description = "Test description",
                        image = "test.jpg"
                    }
                })
                local json = cjson.decode(assert.res_status(200, res))

                -- Delete method
                local res = assert(proxy_client:send {
                    method = "DELETE",
                    path = "/posts/" .. json._id,
                    headers = {
                        ["Host"] = "api4.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- ------------------Check with diff endpoints-------------------------------
                local tokenRequest = {
                    oxd_host = oauth2_consumer_oauth_mode_scope_expression.oxd_http_url,
                    client_id = oauth2_consumer_oauth_mode_scope_expression.client_id,
                    client_secret = oauth2_consumer_oauth_mode_scope_expression.client_secret,
                    scope = { "openid" },
                    op_host = oauth2_consumer_oauth_mode_scope_expression.op_host
                };

                local token = oxd.get_client_token(tokenRequest)
                local req_access_token = token.data.access_token

                -- 1st time request, Cache is not exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/todos",
                    headers = {
                        ["Host"] = "api4.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- 2nd time request, Cache is exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/todos",
                    headers = {
                        ["Host"] = "api4.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- 403/forbidden request path with incomplete scope
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/todos/users",
                    headers = {
                        ["Host"] = "api4.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                local json = cjson.decode(assert.res_status(403, res))
                assert.equal("Failed to validate introspect scope with oauth scope expression", json.message)

                -- 403/forbidden request path with incomplete scope
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/todos/users/posts",
                    headers = {
                        ["Host"] = "api4.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                local json = cjson.decode(assert.res_status(403, res))
                assert.equal("Failed to validate introspect scope with oauth scope expression", json.message)

                -- ------------------Check with diff endpoints-------------------------------
                local tokenRequest = {
                    oxd_host = oauth2_consumer_oauth_mode_scope_expression.oxd_http_url,
                    client_id = oauth2_consumer_oauth_mode_scope_expression.client_id,
                    client_secret = oauth2_consumer_oauth_mode_scope_expression.client_secret,
                    scope = { "openid", "uma_protection" },
                    op_host = oauth2_consumer_oauth_mode_scope_expression.op_host
                };

                local token = oxd.get_client_token(tokenRequest)
                local req_access_token = token.data.access_token

                -- 1st time request, Cache is not exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/todos/users",
                    headers = {
                        ["Host"] = "api4.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- 2nd time request, Cache is exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/todos/users",
                    headers = {
                        ["Host"] = "api4.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- Post method
                local res = assert(proxy_client:send {
                    method = "POST",
                    path = "/todos/users",
                    headers = {
                        ["Host"] = "api4.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                        ["Content-Type"] = "application/json"
                    },
                    body = {
                        name = "TodoTestCase",
                        description = "Test description",
                        image = "test.jpg"
                    }
                })
                local json = cjson.decode(assert.res_status(200, res))

                -- Delete method
                local res = assert(proxy_client:send {
                    method = "DELETE",
                    path = "/todos/users/" .. json._id,
                    headers = {
                        ["Host"] = "api4.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- 403/forbidden request path with incomplete scope
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/todos/users/posts",
                    headers = {
                        ["Host"] = "api4.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                local json = cjson.decode(assert.res_status(403, res))
                assert.equal("Failed to validate introspect scope with oauth scope expression", json.message)
            end)
        end)
    end)

    describe("When multiple API and plugins are configured", function()
        describe("When oauth2-consumer is in oauth_mode = true", function()
            it("401 Unauthorized when token is not present in header", function()
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "api5.typicode.com"
                    }
                })
                assert.res_status(401, res)
            end)

            it("401 Unauthorized when token is invalid", function()
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "api5.typicode.com",
                        ["Authorization"] = "Bearer " .. invalidToken
                    }
                })
                assert.res_status(401, res)
            end)

            it("401 Unauthorized when token is invalid", function()
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "api5.typicode.com",
                        ["Authorization"] = "Bearer sdsfsdf-dsfdf-sdfsf4535-4545"
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

                -- 1st request, Cache is not exist
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "api5.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- 2nd time request
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "api5.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)

                -- 3rs time request
                local res = assert(proxy_client:send {
                    method = "GET",
                    path = "/posts",
                    headers = {
                        ["Host"] = "api5.typicode.com",
                        ["Authorization"] = "Bearer " .. req_access_token,
                    }
                })
                assert.res_status(200, res)
            end)
        end)
    end)
end)