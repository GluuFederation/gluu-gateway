local helper = require("kong.plugins.gluu-oauth2-client-auth.helper")
local oxd = require("oxdweb")

describe("Helper module", function()
    describe("is_empty() function", function()
        it("should return true if variable is null", function()
            assert.equals(true, helper.is_empty(''))
            assert.equals(true, helper.is_empty(nil))
        end)

        it("should return false if variable has value", function()
            assert.equals(false, helper.is_empty('foo'))
            assert.equals(false, helper.is_empty({ foo = "foo" }))
        end)
    end)

    describe("decode() function", function()
        it("Check all possibilities", function()
            assert.equals("three", helper.decode('{ "1": "one", "3": "three" }')["3"])
            assert.equals("one", helper.decode('[ "one", null, "three" ]')[1])
        end)
    end)

    describe("ternary() function", function()
        it("Check all possibilities", function()
            local foo = "foo"
            assert.equals(true, helper.ternary(foo == "foo", true, false))
            assert.equals(false, helper.ternary(foo ~= "foo", true, false))
        end)
    end)

    describe("split() function", function()
        it("Check all possibilities", function()
            assert.equals("foo1", helper.split("foo1,foo2", ",")[1])
        end)
    end)

    describe("isHttps() function", function()
        it("Check all possibilities", function()
            assert.equals(true, helper.isHttps("https://gluu.org"))
            assert.equals(false, helper.isHttps("http://gluu.org"))
            assert.equals(false, helper.isHttps("www.gluu.org"))
        end)
    end)

    -- Dumm data
    local conf = {
        oxd_host = "https://localhost:8444",
        scope = { "openid", "uma_protection" },
        op_host = "https://idp.gluu-local.org",
        authorization_redirect_uri = "https://client.example.com/cb",
        response_types = { "code" },
        client_name = "kong_uma_rs_test_cases",
        grant_types = { "authorization_code" },
        protection_document = "[{\"path\":\"/posts\",\"conditions\":[{\"httpMethods\":[\"GET\",\"POST\"],\"scope_expression\":{\"rule\":{\"or\":[{\"var\":0}]},\"data\":[\"https://jsonplaceholder.typicode.com\"]}}]},{\"path\":\"/comments\",\"conditions\":[{\"httpMethods\":[\"GET\"],\"scope_expression\":{\"rule\":{\"and\":[{\"var\":0}]},\"data\":[\"https://jsonplaceholder.typicode.com\"]}}]}]"
    }

    describe("register() function", function()
        it("should return false after setup_client and uma_rs_protect", function()
            oxd.setup_client = function() return { status = "ok", data = { oxd_id = "oxd_id123", client_id = "client_id", client_secret = "client_secret" } } end
            local res = helper.register(conf)
            assert.equals(true, res)
        end)

        it("should return false when setup_client is failed", function()
            -- Return false when status = "error"
            oxd.setup_client = function() return { status = "error" } end
            local res = helper.register(conf)
            assert.equals(false, res)

            -- Return false when nothing(without status key) is return from setup_client
            oxd.setup_client = function() return {} end
            res = helper.register(conf)
            assert.equals(false, res)
        end)
    end)

    describe("introspect_access_token() function", function()
        it("should return active = true when token is active", function()
            oxd.introspect_access_token = function() return { status = "ok", data = { active = true } } end
            local res = helper.introspect_access_token(conf, "rpt_123")
            assert.equals("ok", res.status)
            assert.equals(true, res.data.active)
        end)

        it("should return active = false when token is not active", function()
            oxd.introspect_access_token = function() return { status = "ok", data = { active = false } } end
            local res = helper.introspect_access_token(conf, "rpt_123")
            assert.equals(false, res.data.active)
        end)

        it("should return status = error when operation failed", function()
            oxd.introspect_access_token = function() return { status = "error" } end
            local res = helper.introspect_access_token(conf, "rpt_123")
            assert.equals(false, res.data.active)
        end)
    end)

    describe("introspect_rpt() function", function()
        it("should return with token active = true after instrospect_rpt", function()
            oxd.introspect_rpt = function() return { status = "ok", data = { active = true } } end
            local res = helper.introspect_rpt(conf, "rpt_123")
            assert.equals(true, res.data.active)
        end)

        it("should return access = denied when uma_rs_check_access is denied", function()
            -- Status = error
            oxd.introspect_rpt = function() return { status = "error" } end
            local res = helper.introspect_rpt(conf, "rpt_123")
            assert.equals(false, res.data.active)

            -- Active = false
            oxd.introspect_rpt = function() return { status = "ok", data = { active = false } } end
            local res = helper.introspect_rpt(conf, "rpt_123")
            assert.equals(false, res.data.active)
        end)
    end)

    describe("get_rpt() function", function()
        it("should return with UMA RPT access_token", function()
            local conf = {
                oxd_host = "http://localhost:8553",
                oxd_id = "123"
            }
            oxd.uma_rp_get_rpt = function() return { status = "ok", data = { access_token = "123" } } end
            local res = helper.get_rpt(conf, "access_token_123", "ticket_123")
            assert.equals("123", res)
        end)

        it("should return false when operation failed", function()
            local conf = {
                oxd_host = "http://localhost:8553",
                oxd_id = "123"
            }
            oxd.uma_rp_get_rpt = function() return { status = "error" } end
            local res = helper.get_rpt(conf, "access_token_123", "ticket_123")
            assert.equals(false, res)
        end)
    end)
end)
