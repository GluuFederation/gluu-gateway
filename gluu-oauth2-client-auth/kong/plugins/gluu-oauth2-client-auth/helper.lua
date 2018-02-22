local oxd = require "oxdweb"
local cjson = require "cjson"
local json = require "JSON"
local _M = {}

function _M.decode(string_data)
    local response = cjson.decode(string_data)
    return response
end

function _M.is_empty(s)
    return s == nil or s == ''
end

function _M.ternary(cond, T, F)
    if cond then return T else return F end
end

function _M.split(str, sep)
    local output = {}
    for match in str:gmatch("([^" .. sep .. "%s]+)") do
        table.insert(output, match)
    end
    return output
end

function _M.isHttps(url)
    if _M.isempty(url) then
        ngx.log(ngx.ERR, url .. ". It is blank.")
        return false
    end

    if not (string.sub(url, 0, 8) == "https://") then
        ngx.log(ngx.ERR, "Invalid " .. url .. ". It does not start from 'https://', value: " .. url)
        return false
    end

    return true
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

function _M.set_header(oxd, user_info)
    ngx.req.set_header("X-OXD", json:encode(oxd))
    if type(user_info) == "string" then
        ngx.req.set_header("X-USER-INFO", user_info)
    else
        ngx.req.set_header("X-USER-INFO", cjson.encode(user_info))
    end
end

--- Register OP client using oxd setup_client
-- @param conf: plugin global values
-- @return response: response of setup_client
function _M.register(conf)
    ngx.log(ngx.DEBUG, "gluu-oauth2-client-auth: Registering on oxd ... ")

    -- ------------------Register Site----------------------------------
    local setupClientRequest = {
        oxd_host = conf.oxd_http_url,
        scope = { "openid", "uma_protection" },
        op_host = conf.op_server,
        authorization_redirect_uri = "https://client.example.com/cb",
        client_name = "gluu-oauth2-introspect-client",
        grant_types = { "client_credentials" }
    }

    local setupClientResponse = oxd.setup_client(setupClientRequest)

    if _M.is_empty(setupClientResponse.status) or setupClientResponse.status == "error" then
        return false
    end

    conf.oxd_id = setupClientResponse.data.oxd_id
    return true
end

--- Used to introspect OAuth2 access token
-- @param conf: plugin global values
-- @param token: requested oAuth2 access token token for introspect
-- @return response: response of introspect_access_token
function _M.introspect_access_token(conf, token)
    local tokenBody = {
        oxd_host = conf.oxd_http_url,
        oxd_id = conf.oxd_id,
        access_token = token
    }

    local tokenResponse = oxd.introspect_access_token(tokenBody)

    if _M.is_empty(tokenResponse.status) or tokenResponse.status == "error" or not tokenResponse.data.active then
        ngx.log(ngx.DEBUG, "introspect_access_token active: false")
        return { data = { active = false } }
    end

    return tokenResponse
end

--- Used to introspect RPT token
-- @param conf: plugin global values
-- @param token: requested RPT token for introspect
-- @return response: response of introspect_rpt
function _M.introspect_rpt(conf, token)
    local tokenBody = {
        oxd_host = conf.oxd_http_url,
        oxd_id = conf.oxd_id,
        rpt = token
    }

    local tokenResponse = oxd.introspect_rpt(tokenBody)

    if _M.is_empty(tokenResponse.status) or tokenResponse.status == "error" or not tokenResponse.data.active then
        ngx.log(ngx.DEBUG, "introspect_rpt active: false")
        return { data = { active = false } }
    end

    return tokenResponse
end

return _M