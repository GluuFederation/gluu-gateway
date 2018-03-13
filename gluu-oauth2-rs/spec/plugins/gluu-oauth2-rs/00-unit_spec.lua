local helper = require("kong.plugins.gluu-oauth2-rs.helper")
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
            oxd.get_client_token = function() return { status = "ok", data = { access_token = "access_token123" } } end
            oxd.uma_rs_protect = function() return { status = "ok", data = { oxd_id = "oxd_id123" } } end

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

        it("should return false when get_client_token is failed", function()
            -- Return false when status = "error"
            oxd.setup_client = function() return { status = "ok", data = { oxd_id = "oxd_id123", client_id = "client_id", client_secret = "client_secret" } } end
            oxd.get_client_token = function() return { status = "error" } end
            local res = helper.register(conf)
            assert.equals(false, res)

            -- Return false when nothing(without status key) is return
            oxd.setup_client = function() return { status = "ok", data = { oxd_id = "oxd_id123", client_id = "client_id", client_secret = "client_secret" } } end
            oxd.get_client_token = function() return {} end
            res = helper.register(conf)
            assert.equals(false, res)
        end)

        it("should return false when uma_rs_protect is failed", function()
            -- Return false when status = "error"
            oxd.setup_client = function() return { status = "ok", data = { oxd_id = "oxd_id123", client_id = "client_id", client_secret = "client_secret" } } end
            oxd.get_client_token = function() return { status = "ok", data = { access_token = "access_token123" } } end
            oxd.uma_rs_protect = function() return { status = "error" } end
            local res = helper.register(conf)
            assert.equals(false, res)

            -- Return false when nothing(without status key) is return
            oxd.setup_client = function() return { status = "ok", data = { oxd_id = "oxd_id123", client_id = "client_id", client_secret = "client_secret" } } end
            oxd.get_client_token = function() return { status = "ok", data = { access_token = "access_token123" } } end
            oxd.uma_rs_protect = function() return {} end
            res = helper.register(conf)
            assert.equals(false, res)
        end)
    end)

    describe("check_access() function", function()
        it("should return access = granted when uma_rs_check_access is granted", function()
            oxd.get_client_token = function() return { status = "ok", data = { access_token = "access_token123" } } end
            oxd.uma_rs_check_access = function() return { status = "ok", data = { access = "granted" } } end
            local res = helper.check_access(conf)
            assert.equals("ok", res.status)
            assert.equals("granted", res.data.access)
        end)

        it("should return access = denied when uma_rs_check_access is denied", function()
            oxd.get_client_token = function() return { status = "ok", data = { access_token = "access_token123" } } end
            oxd.uma_rs_check_access = function() return { status = "ok", data = { access = "denied" } } end
            local res = helper.check_access(conf)
            assert.equals("ok", res.status)
            assert.equals("denied", res.data.access)
        end)

        it("should return access = denied when the status of uma_rs_check_access is error", function()
            -- Failed to get token
            oxd.get_client_token = function() return { status = "error", data = { access_token = "access_token123" } } end
            local res = helper.check_access(conf)
            assert.equals(false, res)

            -- uma_rs_check_access is failed
            oxd.get_client_token = function() return { status = "ok", data = { access_token = "access_token123" } } end
            oxd.uma_rs_check_access = function() return { status = "error" } end
            res = helper.check_access(conf)
            assert.equals("error", res.status)
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
            assert.equals(false, res)

            -- Active = false
            oxd.introspect_rpt = function() return { status = "ok", data = { active = false } } end
            local res = helper.introspect_rpt(conf, "rpt_123")
            assert.equals(false, res)
        end)
    end)
end)
