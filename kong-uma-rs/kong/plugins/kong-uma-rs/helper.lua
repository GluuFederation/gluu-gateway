local oxd = require "oxdweb"
local json = require "JSON"

local _M = {}


function _M.is_empty(s)
    return s == nil or s == ''
end

function _M.register(conf)
    ngx.log(ngx.DEBUG, "Registering on oxd ... ")

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

    if response.status == "error" then
        return false
    end

    local data = response.data
    if _M.is_empty(data) then
        return false
    end

    ngx.log(ngx.DEBUG, "Registered successfully.")

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

    if token.status == "error" then
        ngx.log(ngx.ERR, "Error in get_client_token")
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

    if response.status == "ok" then
        ngx.log(ngx.ERR, "Registered resources : " .. data.oxd_id)
        conf.oxd_id = data.oxd_id
        conf.client_id = data.client_id
        conf.client_secret = data.client_secret

        return true
    else
        return false
    end
    -- -----------------------------------------------------------------
end

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
        ngx.log(ngx.DEBUG, "Failed to get client_token")
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

    return umaAccessResponse;
end

function _M.introspect_rpt(conf, rpt)
    local introspectRequest = {
        oxd_host = conf.oxd_host,
        oxd_id = conf.oxd_id,
        rpt = rpt
    };

    local introspectResponse = oxd.introspect_rpt(introspectRequest)

    if _M.is_empty(introspectResponse.status) or introspectResponse.status == "error" then
        ngx.log(ngx.ERR, "kong-uma-rs : Failed introspect_rpt")
        return false
    end

    -- If tokne is not active the return false
    if not introspectResponse.data.active then
        ngx.log(ngx.DEBUG, "kong-uma-rs : Introspect active false")
        return false
    end

    return introspectResponse;
end

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