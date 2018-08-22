local oxd = require "oxdweb"

-- we don't store our token in lrucache - we don't want it be pushed out
local access_token
local access_token_expire = 0
local EXPIRE_DELTA = 10

local PLUGINNAME = "gluu-oauth2-client-auth"


local lrucache = require "resty.lrucache"
-- it can be shared by all the requests served by each nginx worker process:
local token_cache, err = lrucache.new(1000)  -- allow up to 1000 items in the cache
if not token_cache then
    return error("failed to create the cache: " .. (err or "unknown"))
end

return function(conf)
    kong.log("demo plugin access phase")

    local authorization = ngx.var.http_authorization
    local token
    if authorization and #authorization > 0 then
        local from, to, err = ngx.re.find(authorization, "\\s*[Bb]earer\\s+(.+)", "jo", nil, 1)
        if from then
            token = authorization:sub(from, to)
        end
    end

    if not token then
        kong.log("No token")
        return kong.response.exit(401)
    end

    local now = ngx.now()
    print(now)
    print(access_token_expire)
    if not access_token  or access_token_expire < now + EXPIRE_DELTA then
        access_token_expire = access_token_expire + EXPIRE_DELTA -- avoid multiple token requests
        local response = oxd.get_client_token(
            conf.oxd_http_url,
            {
                client_id = conf.client_id,
                client_secret = conf.client_secret,
                scope = "openid profile email",
                op_host = conf.op_server,
            }
        )

        local status = response.status
        local body = response.body

        if status >= 300 or not body.data or not body.data.access_token then
            access_token = nil
            access_token_expire = 0
            kong.log.err("Failed to get access token")
            return kong.response.exit(500)
        end

        local data = body.data
        access_token =data.access_token
        if data.expires_in then
            access_token_expire = ngx.now() + data.expires_in
        else
            -- use once
            access_token_expire = 0
        end
    end

    local data, stale_data = token_cache:get(token)
    if not data or stale_data then

        local response = oxd.introspect_access_token(
            conf.oxd_http_url,
            {
                oxd_id = conf.oxd_id,
                access_token = token,
            },
            access_token
        )

        local status = response.status

        if status >= 300 or not response.body.data then
            kong.log.err("TODO")
            -- TODO shall we cache negative response? - not in first version, need to create a issue.
            -- TODO should we distinguish between unexected error and not valid credentials?
            return kong.response.exit(403)
        end

        data = response.body.data

        if data.exp and data.iat then
            token_cache:set(token, data, data.iat + data.exp - EXPIRE_DELTA)
        else
            kong.log.err(PLUGINNAME .. ": missed exp or iat fields")
            -- TODO what we must do?
        end
    end

    -- TODO implement consumer detection

    -- TODO implement scope expressions, id any
end
