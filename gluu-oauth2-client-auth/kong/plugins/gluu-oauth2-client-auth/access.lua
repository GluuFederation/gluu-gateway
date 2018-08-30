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

local function load_consumer_custom_id(custom_id)
    local result, err = kong.db.consumers:select_by_custom_id(custom_id)
    if err then
        err = 'anonymous consumer with custom_id "' .. custom_id .. '" not found'
        return nil, err
    end

    return result
end

local function load_consumer_by_id(consumer_id, anonymous)
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

local function get_token(authorization)
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

    return nil
end

local function get_protection_token(conf)
    local now = ngx.now()
    kong.log.debug("Current datetime: ", now, " access_token_expire: ", access_token_expire)
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

        kong.log.debug("Protection access token -- status: ", status)
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
end

local function do_authentication(conf)
    local authorization = ngx.var.http_authorization
    local token = get_token(authorization)

    -- Hide credentials
    kong.log.debug("hide_credentials: ", conf.hide_credentials)
    if conf.hide_credentials then
        kong.ctx.shared.authorization_token = token
        kong.log.debug("Hide authorization header")
        kong.service.request.clear_header("authorization")
    end

    if not token then
        kong.log.err("Token not found")
        return false, { status = 401, message = "Token not found" }
    end

    local body, stale_data = token_cache:get(token)
    if body and not stale_data then
        -- we're already authenticated
        kong.log.debug("Token cache found. we're already authenticated")
        set_consumer(body)
        return true, nil
    end

    -- Get protection access token for OXD API
    get_protection_token(conf)

    kong.log.debug("Token cache not found.")
    local response = oxd.introspect_access_token(conf.oxd_url,
        {
            oxd_id = conf.oxd_id,
            access_token = token,
        },
        access_token)
    local status = response.status

    if status >= 300 then
        -- TODO should we cache negative resposes? https://github.com/GluuFederation/gluu-gateway/issues/213

        -- TODO should we distinguish between unexected errors and not valid credentials?
        return false, { status = 401, message = "Failed to introspect token" }
    end

    body = response.body
    if not body.active then
        return false, { status = 401, message = "Token is not active" }
    end

    local consumer, err = kong.cache:get(body.client_id, nil, load_consumer_custom_id, body.client_id)

    if err then
        kong.log.err("Get consumer by custom_id error: ", err)
        return kong.response.exit(500, { message = "An unexpected error ocurred" })
    end

    if not consumer then
        return false, { status = 401, message = "Consumer not found" }
    end

    body.consumer = consumer

    if body.exp and body.iat then
        token_cache:set(token, body, body.exp - body.iat)
    else
        kong.log.err(PLUGINNAME .. ": missed exp or iat fields")
        return kong.response.exit(500, { message = "EXP and IAT fileds missing in introspection response" })
    end

    -- TODO implement scope expressions, id any

    -- set headers
    set_consumer(body)
    return true, nil
end

return function(conf)

    local result, err = do_authentication(conf);

    if not result then
        -- Check anonymous user and set header with anonymous consumer details
        if conf.anonymous ~= "" then
            -- get anonymous user
            local consumer_cache_key = kong.db.consumers:cache_key(conf.anonymous)
            local consumer, err = kong.cache:get(consumer_cache_key, nil, load_consumer_by_id, conf.anonymous, true)

            if err then
                kong.log.err(err)
                return kong.response.exit(500, { message = "An unexpected error occurred" })
            end
            set_consumer({ consumer = consumer })
            return
        else
            kong.response.exit(err.status, { message = err.message })
        end
    end
end
