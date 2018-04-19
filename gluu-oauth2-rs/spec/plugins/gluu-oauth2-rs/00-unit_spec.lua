local helper = require("kong.plugins.gluu-oauth2-rs.helper")
local oxd = require("oxdweb")
local logic = require('rucciva.json_logic')
local json = require('JSON')

local array_mt = {}

local function ternary(cond, T, F)
    if cond then return T else return F end
end

local function is_array(tab)
    return getmetatable(tab) == array_mt
end

local function mark_as_array(tab)
    return setmetatable(tab, array_mt)
end

local function array(...)
    return mark_as_array({ ... })
end

local function logic_apply(lgc, data, options)
    if type(options) ~= 'table' or options == nil then
        options = {}
    end
    options.is_array = is_array
    options.mark_as_array = mark_as_array
    return logic.apply(lgc, data, options)
end

local function check_op_expression(rules)
    local result
    for i = #rules, 1, -1 do
        for op, _ in pairs(rules[i]) do
            local op_result = logic_apply(logic.new_logic(ternary(op == "not", "and", op), mark_as_array(rules[i][op])), {})
            if op == 'or' then
                result = ternary(result == nil, op_result, result or op_result)
            elseif op == 'and' then
                result = ternary(result == nil, op_result, result and op_result)
            else
                result = ternary(result == nil, op_result, result and op_result)
            end
        end
    end
    return result or false
end

local function make_op_expression(main_rule, scope_expression, data)
    data = mark_as_array(data)
    -- helper.print_table(scope_expression)
    for key, scope_array in pairs(scope_expression or {}) do
        local scope_result = {}
        local next_object

        if type(scope_array) == "table" then
            for _, value in pairs(scope_array) do
                if type(value) == "table" then
                    next_object = value
                    break;
                end

                local valueResult = logic_apply(logic.new_logic('in', array(value, data)), {})
                if key == "not" then
                    valueResult = not valueResult
                end

                if valueResult then
                    table.insert(scope_result, true)
                else
                    table.insert(scope_result, false)
                end
            end
        end

        table.insert(main_rule, logic.new_logic(key, mark_as_array(scope_result)))
        if next_object then
            make_op_expression(main_rule, next_object, data)
        else
            break
        end
    end

    return main_rule or {}
end

local function check_scope_expression(main_rule, scope_expression, data)
    local makeOPResult = make_op_expression(main_rule, scope_expression, data)
    print("---------------Scope expression-------------------")
    helper.print_table(makeOPResult)
    return check_op_expression(makeOPResult)
end

local function check_json_expression(json_expression, data)
    local scope_expression = json:decode(json_expression or "{}")
    local result = check_scope_expression({}, scope_expression, data or {})
    print(tostring(result))
    return result
end

describe("Helper module", function()
    describe("logic() function", function()
        it("should return true if variable is null", function()
            local data = { attr1 = 'val1', attr2 = 'val2', sub_attr = { attr = 'val1' } }
            local rule = { var = 'attr1' }
            assert.equals(data.attr1, logic_apply(rule, data))

            rule = logic.new_logic('in', mark_as_array(json:decode("[\"Spring\", [\"Spring\", \"Field\"]]"))) --  array("Spring", array("Spring", "Field"))
            assert.equals(true, logic_apply(rule, {}))

            -- OR operator
            rule = logic.new_logic('all', array({ var = "scope" }, logic.new_logic('in', array({ var = "" }, array("email", "profile")))))
            data = { scope = array("profile") }
            assert.equals(true, logic_apply(rule, data))

            -- With invalid value
            data = { scope = array("calendar") }
            assert.equals(false, logic_apply(rule, data))

            -- And operator
            rule = logic.new_logic('some', array({ var = "scope" }, logic.new_logic('in', array({ var = "" }, array("email", "profile")))))
            data = { scope = array("profile", "email") }
            assert.equals(true, logic_apply(rule, data))

            data = { scope = array("profile") }
            assert.equals(true, logic_apply(rule, data))

            -- And op
            rule = logic.new_logic('and', array(true, true, logic.new_logic('or', array(true, false))))
            assert.equals(true, logic_apply(rule, {}))

            -- Json
            local json_expression = "{\"and\": [\"email\", \"profile\", {\"or\": [\"calendar\",\"uma\"]}]}"
            assert.equals(false, check_json_expression(json_expression, { "email" }))
            assert.equals(false, check_json_expression(json_expression, { "email", "profile" }))
            assert.equals(true, check_json_expression(json_expression, { "email", "profile", "calendar" }))
            assert.equals(true, check_json_expression(json_expression, { "email", "profile", "calendar", "uma" }))

            json_expression = "{\"or\": [\"email\", \"profile\", {\"and\": [\"calendar\",\"uma\"]}]}"
            assert.equals(true, check_json_expression(json_expression, { "email" }))
            assert.equals(true, check_json_expression(json_expression, { "email", "profile" }))
            assert.equals(true, check_json_expression(json_expression, { "email", "profile", "calendar" }))
            assert.equals(true, check_json_expression(json_expression, { "email", "profile", "calendar", "uma" }))

            json_expression = "{\"and\": [\"email\", \"profile\"]}"
            assert.equals(false, check_json_expression(json_expression, { "email", }))
            assert.equals(true, check_json_expression(json_expression, { "email", "profile" }))
            assert.equals(true, check_json_expression(json_expression, { "email", "profile", "calendar" }))
            assert.equals(false, check_json_expression(json_expression, { "calendar" }))
            assert.equals(false, check_json_expression(json_expression))
            assert.equals(false, check_json_expression(json_expression, {}))
            assert.equals(false, check_json_expression(json_expression, nil))

            json_expression = "{\"or\": [\"email\", \"profile\"]}"
            assert.equals(true, check_json_expression(json_expression, { "email" }))
            assert.equals(true, check_json_expression(json_expression, { "email", "profile" }))
            assert.equals(true, check_json_expression(json_expression, { "email", "profile", "calendar" }))
            assert.equals(false, check_json_expression(json_expression, { "calendar" }))

            json_expression = "{}"
            assert.equals(false, check_json_expression(json_expression, { "email" }))
            assert.equals(false, check_json_expression(json_expression, { "email", "profile" }))
            assert.equals(false, check_json_expression(json_expression, { "email", "profile", "calendar" }))
            assert.equals(false, check_json_expression(json_expression, { "calendar" }))

            json_expression = nil
            assert.equals(false, check_json_expression(json_expression, { "email" }))
            assert.equals(false, check_json_expression(json_expression, { "email", "profile" }))
            assert.equals(false, check_json_expression(json_expression, { "email", "profile", "calendar" }))
            assert.equals(false, check_json_expression(json_expression, { "calendar" }))
            assert.equals(false, check_json_expression(json_expression, { "calendar" }))

            json_expression = "{\"and\": [\"email\"]}"
            assert.equals(true, check_json_expression(json_expression, { "email" }))
            assert.equals(false, check_json_expression(json_expression, { "profile" }))
            assert.equals(false, check_json_expression(json_expression, {}))

            json_expression = "{\"and\": [\"email\", {\"or\": [\"calendar\",\"uma\", {\"and\": [\"post\"]}]}]}"
            assert.equals(true, check_json_expression(json_expression, { "post", "email" }))
            assert.equals(false, check_json_expression(json_expression, { "email" }))
            assert.equals(true, check_json_expression(json_expression, { "email", "calendar" }))

            json_expression = "{\"not\": [\"email\"]}"
            assert.equals(true, check_json_expression(json_expression, { "post" }))
            assert.equals(false, check_json_expression(json_expression, { "email" }))
        end)
    end)

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
