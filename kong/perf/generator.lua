local cjson = require"cjson"

local function path_split(s)
    local result = {};
    for match in (s):gmatch([[/([^/]*)]]) do
        result[#result + 1] = match
    end
    return result
end

local function generate_path_element()
    return "folder" .. tostring(math.random(10))
end

local function generate_uri_from_template(template, regexp_map)
    print(template)
    local path_as_array = path_split(template)
    local t = { "" } -- it should add starting slash
    for i = 1, #path_as_array do
        local item = path_as_array[i]
        print(item)
        if item == "?" then
            t[#t + 1] = generate_path_element()
        elseif item == "??" then
            local n = math.random(10) -- TODO magic number
            for k = 1, n do
                t[#t + 1] = generate_path_element()
            end
        else
            local regexp = item:match"^{(.+)}$"
            print(regexp)
            if regexp then
                t[#t + 1] = assert(regexp_map[regexp])
            else -- exact match
                t[#t + 1] = item
            end
        end
    end
    return table.concat(t, "/")
end

local function generate_request(oauth_scope_expression, regexp_map)
    local n = math.random(#oauth_scope_expression)
    local item = oauth_scope_expression[n]
    local c_ind = math.random(#item.conditions)
    local condition = item.conditions[c_ind]
    local httpMethods = condition.httpMethods
    local m_ind = math.random(#httpMethods)
    local method = httpMethods[m_ind]
    local path = generate_uri_from_template(item.path, regexp_map)
    return { method, path }
end

--[[
the config structure:
{
    oauth_scope_expression = {}, -- as used by gluu-oauth-pep
    regexp_map = {}, -- key regexp, value - string which match the regexp
    token_data = {}, -- array of objects, every must contains client_id and scope at least
}
 ]]

local _M = {}

_M.generate_wrk_config = function(config, nrequest)
    local result = {}
    local tokens = {}
    local token_data = config.token_data
    for i = 1, #token_data do
        tokens[i] =  ngx.encode_base64(cjson.encode(token_data[i]))
    end
    result.tokens = tokens

    for k,v in pairs(config.regexp_map) do
        print(k, ":", v)
    end

    local requests = {}
    for k = 1, nrequest do
        requests[k] = generate_request(config.oauth_scope_expression, config.regexp_map)
    end
    result.requests = requests

    return result
end

return _M


