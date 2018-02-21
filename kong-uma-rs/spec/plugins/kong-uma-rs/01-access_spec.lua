local helpers = require "spec.helpers"
local oxd = require "oxdweb"

local function is_empty(s)
    return s == nil or s == ''
end

describe("kong-uma-rs plugin", function()
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
            name = "kong-uma-rs",
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

        it("401 Unauthorized with permission ticket when token is present but invalid or oauth2 AT", function()
            local res = assert(proxy_client:send {
                method = "GET",
                path = "/posts",
                headers = {
                    ["Host"] = "jsonplaceholder.typicode.com",
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
                    ["Host"] = "jsonplaceholder.typicode.com",
                    ["Authorization"] = "Bearer dfdff5654tryhgfht",
                }
            })
            local UMAWarning = res.headers["UMA-Warning"]
            assert.equals(true, UMAWarning ~= nil)
            assert.res_status(200, res)
        end)

        it("200 Authorized with successful response from upstream URL when token is valid", function()
            -- ------------------GET Client Token-------------------------------
            local tokenRequest = {
                oxd_host = plugin.config.oxd_host,
                client_id = plugin.config.client_id,
                client_secret = plugin.config.client_secret,
                scope = { "openid", "uma_protection" },
                op_host = plugin.config.uma_server_host
            };

            local token = oxd.get_client_token(tokenRequest)

            if is_empty(token.status) or token.status == "error" then
                print("kong-uma-rs: Failed to get client_token")
            end
            local req_access_token = token.data.access_token
            -- *---- uma-rs-check-access ----* Before
            ngx.log(ngx.DEBUG, "Request **before RPT token to uma-rs-check-access")
            local umaRsCheckAccessRequest = {
                oxd_host = plugin.config.oxd_host,
                oxd_id = plugin.config.oxd_id,
                rpt = "",
                http_method = 'GET',
                path = '/posts'
            }

            local umaRsCheckAccessResponse = oxd.uma_rs_check_access(umaRsCheckAccessRequest, req_access_token)

            if is_empty(umaRsCheckAccessResponse.status) or umaRsCheckAccessResponse.status == "error" then
                print("kong-uma-rs: Failed uma_rs_check_access")
            end

            -- *---- uma-rp-get-rpt ----*
            ngx.log(ngx.DEBUG, "Request to uma-rp-get-rpt")
            local umaRpGetRptRequest = {
                oxd_host = plugin.config.oxd_host,
                oxd_id = plugin.config.oxd_id,
                ticket = umaRsCheckAccessResponse.data.ticket
            }

            local umaRpGetRptRequest = oxd.uma_rp_get_rpt(umaRpGetRptRequest, req_access_token)

            if is_empty(umaRpGetRptRequest.status) or umaRpGetRptRequest.status == "error" then
                print("kong-uma-rs: Failed to get uma_rp_get_rpt")
            end

            local res = assert(proxy_client:send {
                method = "GET",
                path = "/todos", -- Unprotected path
                headers = {
                    ["Host"] = "jsonplaceholder.typicode.com",
                    ["Authorization"] = "Bearer " .. umaRpGetRptRequest.data.access_token,
                }
            })
            assert.res_status(200, res)
        end)
    end)
end)

