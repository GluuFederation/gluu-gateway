local oxd = require "oxdweb"
local json = require "JSON"
local logic = require('rucciva.json_logic')
local PLUGINNAME = "gluu-oauth2-rs"
local _M = {}

--- Check value of the variable is empty or not
-- @param s: any value
-- @return boolean
function _M.is_empty(s)
    return s == nil or s == ''
end

--- Check value exist in array. If exist then return index value otherwise 0
-- @param tbl: Array of values
-- @param value: Value want to search
function _M.find(tbl, value)
    for k, v in ipairs(tbl) do
        if v == value then
            return k;
        end
    end
    return 0
end

--- Function work as ternary operator
-- @param cond: Condition which return true and false
-- @param T: Value return when condition is true
-- @param F: Value return when condition is false
function _M.ternary(cond, T, F)
    if cond then return T else return F end
end

--- Register OP client using oxd setup_client
-- @param conf: plugin global values
-- @return response: response of setup_client
function _M.register(conf)
    ngx.log(ngx.DEBUG, PLUGINNAME .. ": Registering on oxd ... ")

    -- ------------------Register Site----------------------------------
    local siteRequest = {
        oxd_host = conf.oxd_host,
        scope = { "openid", "uma_protection" },
        op_host = conf.uma_server_host,
        authorization_redirect_uri = "https://client.example.com/cb",
        response_types = { "code" },
        client_name = "kong_uma_rs",
        grant_types = { "authorization_code" }
    }

    local response = oxd.setup_client(siteRequest)

    if _M.is_empty(response.status) or response.status == "error" then
        ngx.log(ngx.DEBUG, PLUGINNAME .. ": Error in setup_client")
        return false
    end

    local data = response.data
    if _M.is_empty(data) then
        return false
    end

    -- -----------------------------------------------------------------

    -- ------------------GET Client Token-------------------------------

    local tokenRequest = {
        oxd_host = conf.oxd_host,
        client_id = data.client_id,
        client_secret = data.client_secret,
        scope = { "openid", "uma_protection" },
        op_host = conf.uma_server_host,
        authorization_redirect_uri = "https://client.example.com/cb",
        grant_types = { "authorization_code" }
    };
    local token = oxd.get_client_token(tokenRequest)

    if _M.is_empty(token.status) or token.status == "error" then
        ngx.log(ngx.DEBUG, PLUGINNAME .. ": Error in get_client_token")
        return false
    end
    -- -----------------------------------------------------------------

    -- --------------- UMA-RS Protect ----------------------------------
    local umaRSRequest = {
        oxd_host = conf.oxd_host,
        oxd_id = data.oxd_id,
        resources = json:decode(conf.protection_document)
    }

    response = oxd.uma_rs_protect(umaRSRequest, token.data.access_token)

    if _M.is_empty(response.status) or response.status == "error" then
        ngx.log(ngx.DEBUG, PLUGINNAME .. ": Error in uma_rs_protect")
        return false
    end

    conf.oxd_id = data.oxd_id
    conf.client_id = data.client_id
    conf.client_secret = data.client_secret
    conf.client_id_of_oxd_id = data.client_id_of_oxd_id
    conf.setup_client_oxd_id = data.setup_client_oxd_id

    return true
    -- -----------------------------------------------------------------
end

--- Register OP client using oxd setup_client
-- @param conf: plugin global values
-- @return response: response of setup_client
function _M.update_uma_rs(conf)
    if _M.is_empty(conf.oxd_id) then
        ngx.log(ngx.DEBUG, PLUGINNAME .. ": OXD id is not found, Call register() ... ")
        return _M.register(conf)
    end

    ngx.log(ngx.DEBUG, PLUGINNAME .. ": Updating UMA RS ... ")

    -- ------------------GET Client Token-------------------------------
    local tokenRequest = {
        oxd_host = conf.oxd_host,
        client_id = conf.client_id,
        client_secret = conf.client_secret,
        scope = { "openid", "uma_protection" },
        op_host = conf.uma_server_host,
        authorization_redirect_uri = "https://client.example.com/cb",
        grant_types = { "authorization_code" }
    };
    local token = oxd.get_client_token(tokenRequest)

    if _M.is_empty(token.status) or token.status == "error" then
        ngx.log(ngx.DEBUG, PLUGINNAME .. ": Error in get_client_token")
        return false
    end
    -- -----------------------------------------------------------------

    -- --------------- UMA-RS Protect ----------------------------------
    local umaRSRequest = {
        oxd_host = conf.oxd_host,
        oxd_id = conf.oxd_id,
        resources = json:decode(conf.protection_document),
        overwrite = true
    }

    local response = oxd.uma_rs_protect(umaRSRequest, token.data.access_token)
    if _M.is_empty(response.status) or response.status == "error" then
        ngx.log(ngx.DEBUG, PLUGINNAME .. ": Error in uma_rs_protect")
        return false
    end

    return true
    -- -----------------------------------------------------------------
end

--- Check rpt token - /uma-rs-check-access
-- @param conf: plugin global values
-- @return response: response of /uma-rs-check-access
function _M.get_rpt_with_check_access(conf, path, httpMethod, uma_data, rpt)
    -- ------------------GET Client Token-------------------------------
    local tokenRequest = {
        oxd_host = conf.oxd_host,
        client_id = conf.client_id,
        client_secret = conf.client_secret,
        scope = { "openid", "uma_protection" },
        op_host = conf.uma_server_host
    };

    local token = oxd.get_client_token(tokenRequest)

    if _M.is_empty(token.status) or token.status == "error" then
        ngx.log(ngx.DEBUG, PLUGINNAME .. ": Failed to get client_token")
        return false
    end
    -- -----------------------------------------------------------------

    -- ------------------GET check_access-------------------------------
    local umaAccessRequest = {
        oxd_host = conf.oxd_host,
        oxd_id = conf.oxd_id,
        rpt = "",
        path = path,
        http_method = httpMethod
    }
    local umaAccessResponse = oxd.uma_rs_check_access(umaAccessRequest, token.data.access_token)

    if _M.is_empty(umaAccessResponse.status) or umaAccessResponse.status == "error" then
        if _M.is_empty(umaAccessResponse.data) or umaAccessResponse.data.error == "invalid_request" then
            ngx.log(ngx.DEBUG, PLUGINNAME .. ": Path is not protected")
            return umaAccessResponse
        end
        ngx.log(ngx.DEBUG, PLUGINNAME .. ": Failed to get uma_rs_check_access")
        return false
    end
    -- -----------------------------------------------------------------

    -- ------------------GET rpt-------------------------------
    local umaGetRPTRequest = {
        oxd_host = conf.oxd_host,
        oxd_id = conf.oxd_id,
        ticket = umaAccessResponse.data.ticket
    }

    if not _M.is_empty(rpt) then
        umaGetRPTRequest.rpt = rpt
    end

    -- check uma_data is comming then passed it to get_rpt
    if not _M.is_empty(uma_data) then
        umaGetRPTRequest.claim_token = uma_data.claim_token
        umaGetRPTRequest.claim_token_format = uma_data.claim_token_format
    end

    local umaGetRPTResponse = oxd.uma_rp_get_rpt(umaGetRPTRequest, token.data.access_token)

    if _M.is_empty(umaGetRPTResponse.status) or umaGetRPTResponse.status == "error" then
        ngx.log(ngx.DEBUG, PLUGINNAME .. ": Failed to get uma_rp_get_rpt")
        return false
    end
    -- -----------------------------------------------------------------

    -- ------------------GET access-------------------------------
    local umaAccessRequest = {
        oxd_host = conf.oxd_host,
        oxd_id = conf.oxd_id,
        rpt = umaGetRPTResponse.data.access_token,
        path = path,
        http_method = httpMethod
    };
    local umaAccessResponse = oxd.uma_rs_check_access(umaAccessRequest, token.data.access_token)
    umaAccessResponse.rpt = umaGetRPTResponse.data.access_token
    return umaAccessResponse;
end

--- Check rpt token - /uma-rs-check-access
-- @param conf: plugin global values
-- @return response: response of /uma-rs-check-access
function _M.check_access(conf, rpt, path, httpMethod)
    -- ------------------GET Client Token-------------------------------
    local tokenRequest = {
        oxd_host = conf.oxd_host,
        client_id = conf.client_id,
        client_secret = conf.client_secret,
        scope = { "openid", "uma_protection" },
        op_host = conf.uma_server_host
    };

    local token = oxd.get_client_token(tokenRequest)

    if _M.is_empty(token.status) or token.status == "error" then
        ngx.log(ngx.DEBUG, PLUGINNAME .. ": Failed to get client_token")
        return false
    end
    -- -----------------------------------------------------------------

    -- ------------------GET access-------------------------------
    local umaAccessRequest = {
        oxd_host = conf.oxd_host,
        oxd_id = conf.oxd_id,
        rpt = rpt,
        path = path,
        http_method = httpMethod
    };
    local umaAccessResponse = oxd.uma_rs_check_access(umaAccessRequest, token.data.access_token)
    umaAccessResponse.rpt = rpt;
    return umaAccessResponse;
end

--- Introspect to rpt token /introspect_rpt
-- @param conf: plugin global values
-- @return response: response of /introspect_rpt
function _M.introspect_rpt(conf, rpt)
    local introspectRequest = {
        oxd_host = conf.oxd_host,
        oxd_id = conf.oxd_id,
        rpt = rpt
    };

    local introspectResponse = oxd.introspect_rpt(introspectRequest)

    if _M.is_empty(introspectResponse.status) or introspectResponse.status == "error" then
        ngx.log(ngx.DEBUG, PLUGINNAME .. "Failed introspect_rpt")
        return false
    end

    -- If tokne is not active the return false
    if not introspectResponse.data.active then
        ngx.log(ngx.DEBUG, PLUGINNAME .. ": Introspect active false")
        return false
    end

    return introspectResponse;
end

--- Used to print table values in log
-- @param node: table type values
function _M.print_table(node)
    -- to make output beautiful
    local function tab(amt)
        local str = ""
        for i = 1, amt do
            str = str .. "\t"
        end
        return str
    end

    local cache, stack, output = {}, {}, {}
    local depth = 1
    local output_str = "{\n"

    while true do
        local size = 0
        for k, v in pairs(node) do
            size = size + 1
        end

        local cur_index = 1
        for k, v in pairs(node) do
            if (cache[node] == nil) or (cur_index >= cache[node]) then

                if (string.find(output_str, "}", output_str:len())) then
                    output_str = output_str .. ",\n"
                elseif not (string.find(output_str, "\n", output_str:len())) then
                    output_str = output_str .. "\n"
                end

                -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
                table.insert(output, output_str)
                output_str = ""

                local key
                if (type(k) == "number" or type(k) == "boolean") then
                    key = "[" .. tostring(k) .. "]"
                else
                    key = "['" .. tostring(k) .. "']"
                end

                if (type(v) == "number" or type(v) == "boolean") then
                    output_str = output_str .. tab(depth) .. key .. " = " .. tostring(v)
                elseif (type(v) == "table") then
                    output_str = output_str .. tab(depth) .. key .. " = {\n"
                    table.insert(stack, node)
                    table.insert(stack, v)
                    cache[node] = cur_index + 1
                    break
                else
                    output_str = output_str .. tab(depth) .. key .. " = '" .. tostring(v) .. "'"
                end

                if (cur_index == size) then
                    output_str = output_str .. "\n" .. tab(depth - 1) .. "}"
                else
                    output_str = output_str .. ","
                end
            else
                -- close the table
                if (cur_index == size) then
                    output_str = output_str .. "\n" .. tab(depth - 1) .. "}"
                end
            end

            cur_index = cur_index + 1
        end

        if (size == 0) then
            output_str = output_str .. "\n" .. tab(depth - 1) .. "}"
        end

        if (#stack > 0) then
            node = stack[#stack]
            stack[#stack] = nil
            depth = cache[node] == nil and depth + 1 or depth - 1
        else
            break
        end
    end

    -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
    table.insert(output, output_str)
    output_str = table.concat(output)

    print(output_str)
end

--- Check OAuth scope expression
-- Use check_json_expression function
-- Others are utility functions for json logic library

local array_mt = {}

--- Check value is array or not
-- @param tab: Any type of data
local function is_array(tab)
    return getmetatable(tab) == array_mt
end

--- Set metadata to array value
-- @param tab: Array values
local function mark_as_array(tab)
    return setmetatable(tab, array_mt)
end

--- Convert array with array metadata
-- @param ... Command separated values
local function array(...)
    return mark_as_array({ ... })
end

--- Apply json logic
-- @param lgc: Json rules
-- @param data: Data which you want to validate with lgc
-- @param option: Extra options example: is_array
local function logic_apply(lgc, data, options)
    if type(options) ~= 'table' or options == nil then
        options = {}
    end
    options.is_array = is_array
    options.mark_as_array = mark_as_array
    return logic.apply(lgc, data, options)
end

--- Check OP expression
-- @param rules: Requested OP expressions
local function check_op_expression(rules)
    local result
    for i = #rules, 1, -1 do
        for op, _ in pairs(rules[i]) do
            local op_result = logic_apply(logic.new_logic(_M.ternary(op == "not", "and", op), mark_as_array(rules[i][op])), {})
            if op == 'or' then
                result = _M.ternary(result == nil, op_result, result or op_result)
            elseif op == 'and' then
                result = _M.ternary(result == nil, op_result, result and op_result)
            else
                result = _M.ternary(result == nil, op_result, result and op_result)
            end
        end
    end
    return result or false
end

--- Recursion function to Make json expression into OP expression
-- @param main_rule: object to store all the rules
-- @param scope_Expression: OAuth scope expression
-- @param data: Data which you want to validate with lgc
local function make_op_expression(main_rule, scope_expression, data)
    data = mark_as_array(data)
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

--- Check JSON expression
-- @param json_expression: String json expression example: "{\"and\": [\"email\", \"profile\", {\"or\": [\"calendar\",\"uma\"]}]}"
-- @param data: Array of scopes example: { "email", "profile" }
-- @return true or false
function _M.check_json_expression(scope_expression, data)
    scope_expression = scope_expression or {}
    local makeOPResult = make_op_expression({}, scope_expression, (data or {}))
    local result = check_op_expression(makeOPResult)
    return result
end

--- Fetch expression based on path and http methods
function _M.fetch_Expression(json_exp, path, method)
    if _M.is_empty(json_exp) then
        return nil
    end

    local json_expression = json:decode(json_exp or "{}")
    local found_path_condition
    for k, v in pairs(json_expression) do
        if v['path'] == path then
            found_path_condition = v['conditions']
            break
        end
    end

    if not found_path_condition then
        return nil
    end

    for k, v in pairs(found_path_condition) do
        if _M.find(v['httpMethods'], method) > 0 then
            return v['scope_expression']
        end
    end

    return nil
end

--- Get path
function _M.get_path(request_path, register_path)
    if request_path == nil then
        return false
    end

    if register_path == nil then
        return false
    end

    local start, last = string.find(request_path, register_path, 1)
    if start == nil or last == nil or start ~= 1 then
        return false
    end

    return request_path == register_path or string.sub(request_path, start, last + 1) == register_path .. "/" or string.sub(request_path, start, last + 1) == register_path .. "?"
end

--- Filter request path with parent path
function _M.filter_expression_path(json_exp, request_path)
    if _M.is_empty(json_exp) then
        return request_path
    end

    local json_expression = json:decode(json_exp or "{}")
    local register_paths = {}
    for k, v in pairs(json_expression) do
        table.insert(register_paths, v['path'])
    end

    table.sort(register_paths, function(first, second)
        return string.len(first) > string.len(second)
    end)

    for k, v in pairs(register_paths) do
        if _M.get_path(request_path, v) then
            return v
        end
    end
    return request_path
end

return _M