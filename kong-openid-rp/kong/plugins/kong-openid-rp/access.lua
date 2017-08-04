local oxd = require "kong.plugins.kong-openid-rp.oxdclient"
local common = require "kong.plugins.kong-openid-rp.common"
local responses = require "kong.tools.responses"
local USER_INFO = "USER_INFO"
local ck = require "resty.cookie"
local json = require "JSON"

local _M = {}

local function getPath()
    local path = ngx.var.request_uri
    local indexOf = string.find(path, "?")
    if indexOf ~= nil then
        return string.sub(path, 1, (indexOf - 1))
    end
    return path
end

function _M.execute(conf)
    local httpMethod = ngx.req.get_method()
    local authorization_code = ngx.req.get_uri_args()["code"]
    local state = ngx.req.get_uri_args()["state"]
    local path = getPath()
    local cookie, err = ck:new()

    local cacheUserInfo = cookie:get(USER_INFO);
    if cacheUserInfo == nil then
        -- ------- validation ------
        local flag = true
        if common.isempty(authorization_code) then
            flag = false
        end
        if common.isempty(state) then
            flag = false
        end

        if flag then
            ngx.log(ngx.DEBUG, "kong-openid-rp : Access - http_method: " .. httpMethod .. ", code: " .. authorization_code .. ", path: " .. path .. ", state: " .. state)
            -- ------------------------
            local response = oxd.get_user_info(conf, authorization_code, state)
            if response["status"] == "ok" then
                cookie:set({
                    key = USER_INFO, value = json:encode(response),
                })
                cacheUserInfo = response
            end
        end
    end

    if cacheUserInfo then
        common.set_header(conf, cacheUserInfo)
        return true -- ACCESS GRANTED
    end

    local response = oxd.get_authorization_url(conf)
    if response["status"] == "error" then
        ngx.log(ngx.ERR, "get_authorization_url : oxd_id: " .. conf.oxd_id)
        return responses.send_HTTP_INTERNAL_SERVER_ERROR(response)
    end

    return ngx.redirect(response.data.authorization_url)
end

return _M