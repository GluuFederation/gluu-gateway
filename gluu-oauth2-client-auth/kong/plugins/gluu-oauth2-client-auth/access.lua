local constants = require "kong.constants"
local oxd = require "oxdweb"
-- we don't store our token in lrucache - we don't want it be pushed out
local access_token
local access_token_expire = 0
local EXPIRE_DELTA = 10

local PLUGINNAME = "gluu-oauth2-client-auth"

local lrucache = require "resty.lrucache"
-- it can be shared by all the requests served by each nginx worker process:
local token_cache, err = lrucache.new(1000) -- allow up to 1000 items in the cache
if not token_cache then
    return error("failed to create the cache: " .. (err or "unknown"))
end

local function load_consumer(consumer_id, anonymous)
    local result, err = kong.db.consumers:select({ id = consumer_id })
    if not result then
        if anonymous and not err then
            err = 'anonymous consumer "' .. consumer_id .. '" not found'
        end

        return nil, err
    end

    return result
end

local function set_consumer(body)
    local const = constants.HEADERS
    local new_headers = {
        [const.CONSUMER_ID] = body.consumer.id,
        [const.CONSUMER_CUSTOM_ID] = tostring(body.consumer.custom_id),
        [const.CONSUMER_USERNAME] = tostring(body.consumer.username),
        ["X-OAuth-Client-ID"] = tostring(body.client_id),
        ["X-OAuth-Expiration"] = tostring(body.exp)
    }
    kong.service.request.set_headers(new_headers)
end

local function get_token(conf)
    local authorization = ngx.var.http_authorization
    if authorization and #authorization > 0 then
        local from, to, err = ngx.re.find(authorization, "\\s*[Bb]earer\\s+(.+)", "jo", nil, 1)
        if from then
            return authorization:sub(from, to) -- Return token
        end
        if err then
            kong.log.err(err)
            return kong.response.exit(500, { message = "Failed to get token from header" })
        end
    end

    -- Hide credentials
    kong.log.debug("hide_credentials: ", conf.hide_credentials)
    if conf.hide_credentials then
        kong.log.debug("Hide authorization header")
        kong.service.request.clear_header(authorization)
    end

    return nil
end

return function(conf)
    local token = get_token(conf)
    if not token then
        kong.log.err("Token not found")
        return kong.response.exit(401, { message = "Token not found" })
    end

    local now = ngx.now()
    kong.log.debug("Current datetime: ", now)
    kong.log.debug("access_token_expire: ", access_token_expire)
    if not access_token or access_token_expire < now + EXPIRE_DELTA then
        access_token_expire = access_token_expire + EXPIRE_DELTA -- avoid multiple token requests
        local response = oxd.get_client_token(conf.oxd_url,
            {
                client_id = conf.client_id,
                client_secret = conf.client_secret,
                scope = "openid profile email",
                op_host = conf.op_url,
            })

        local status = response.status
        local body = response.body

        kong.log.err("Protection access token -- status: ", status)
        if status >= 300 or not body.access_token then
            access_token = nil
            access_token_expire = 0
            kong.log.err("Failed to get access token.")
            return kong.response.exit(status, { message = "Failed to get access token" })
        end

        access_token = body.access_token
        if body.expires_in then
            access_token_expire = ngx.now() + body.expires_in
        else
            -- use once
            access_token_expire = 0
        end
    end

    local body, stale_data = token_cache:get(token)

    if body and not stale_data then
        -- we're already authenticated
        kong.log.debug("Token cache found. we're already authenticated")
        set_consumer(body)
        return
    end

    kong.log.debug("Token cache not found.")
    local response = oxd.introspect_access_token(conf.oxd_url,
        {
            oxd_id = conf.oxd_id,
            access_token = token,
        },
        access_token)
    local status = response.status

    if status >= 300 then
        kong.log.err("TODO")
        -- should we cache negative resposes? https://github.com/GluuFederation/gluu-gateway/issues/213

        -- Check for conf.ananimouse here
        if conf.anonymous ~= "" then
            -- get anonymous user
            local consumer_cache_key = kong.db.consumers:cache_key(conf.anonymous)
            local consumer, err = kong.cache:get(consumer_cache_key, nil, load_consumer, conf.anonymous, true)

            if err then
                kong.log.err(err)
                return kong.response.exit(500, { message = "An unexpected error ocurred" })
            end
            set_consumer({ consumer })
            return
        end

        -- TODO should we distinguish between unexected errors and not valid credentials?
        return kong.response.exit(401, { message = "Token expired" })
    end

    body = response.body

    kong.log.debug("calling select_by_custom_id: ", body.client_id)

    -- TODO implement consumer detection
    local consumer, err = kong.db.consumers:select_by_custom_id(body.client_id)
    kong.log.debug("after select_by_custom_id")

    if err then
        kong.log.err("select_by_custom_id error: ", err)
        return kong.response.exit(500, { message = "An unexpected error ocurred" })
    end

    if not consumer then
        kong.log.debug("consumer not found")
        return kong.response.exit(401, { message = "Consumer not found" })
    end

    -- cache consumer id also, avoid DB call on every request
    body.consumer = consumer

    if body.exp and body.iat then
        token_cache:set(token, body, body.exp - body.iat)
    else
        kong.log.err(PLUGINNAME .. ": missed exp or iat fields")
        return kong.response.exit(500, { message = "EXP and IAT fileds missing in introspection response" })
    end

    kong.log.debug("Consumer: ", body.consumer.id)

    -- TODO implement scope expressions, id any

    -- TODO set headers
    set_consumer(body)
end
