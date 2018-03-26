local oxd = require "oxdweb"
local json = require "JSON"
local PLUGINNAME = "gluu-oauth2-rs"
local _M = {}

--- Check value of the variable is empty or not
-- @param s: any value
-- @return boolean
function _M.is_empty(s)
    return s == nil or s == ''
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

    return true
    -- -----------------------------------------------------------------
end

--- Register OP client using oxd setup_client
-- @param conf: plugin global values
-- @return response: response of setup_client
function _M.update_uma_rs(conf)
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

return _M