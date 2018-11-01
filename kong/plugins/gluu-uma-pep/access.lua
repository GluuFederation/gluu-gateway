local constants = require "kong.constants"
local oxd = require "oxdweb"
local helper = require "kong.plugins.gluu-uma-pep.helper"

-- we don't store our token in lrucache - we don't want it be pushed out
local access_token
local access_token_expire = 0
local EXPIRE_DELTA = 10

local PLUGINNAME = "gluu-uma-pep"

local lrucache = require "resty.lrucache"
-- it can be shared by all the requests served by each nginx worker process:
local worker_cache, err = lrucache.new(1000) -- allow up to 1000 items in the cache
if not worker_cache then
    return error("failed to create the cache: " .. (err or "unknown"))
end

local function unexpected_error(...)
    kong.log.err(...)
    kong.response.exit(500, { message = "An unexpected error ocurred" })
end

local function get_protection_token(conf)
    local now = ngx.now()
    kong.log.debug("Current datetime: ", now, " access_token_expire: ", access_token_expire)
    if not access_token or access_token_expire < now + EXPIRE_DELTA then
        -- TODO possible race condition when access_token == nil
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
            return unexpected_error("Failed to get access token.")
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

local function get_token(authorization)
    if authorization and #authorization > 0 then
        local from, to, err = ngx.re.find(authorization, "\\s*[Bb]earer\\s+(.+)", "jo", nil, 1)
        if from then
            return authorization:sub(from, to) -- Return token
        end
        if err then
            return unexpected_error(err)
        end
    end

    return nil
end

local function build_cache_key(token, path)
    path = path or ""
    local t = {
        token,
        ":",
        path,
        ":",
        ngx.req.get_method()
    }
    return table.concat(t)
end

-- call /uma-rs-check-access oxd API, handle errors
local function try_check_access(conf, path, method, token)
    token = token or ""
    local response = oxd.uma_rs_check_access(conf.oxd_url,
        {
            oxd_id = conf.oxd_id,
            rpt = token,
            path = path,
            http_method = method,
        },
        access_token)
    local status = response.status
    if status == 200 then
        -- TODO check status and ticket
        local body = response.body
        if not body.access then
            unexpected_error("uma_rs_check_access() missed access")
        end
        if body.access == "granted" then
            return body
        elseif body.access == "denied" then
            if not body["www-authenticate_header"] then
                unexpected_error("uma_rs_check_access() access == denied, but missing www-authenticate_header")
            end
            return body
        end
        unexpected_error("uma_rs_check_access() unexpected access value: ", body.access)
    end
    if status == 400 then
        unexpected_error("uma_rs_check_access() responds with status 400 - Invalid parameters are provided to endpoint")
    elseif status == 500 then
        unexpected_error("uma_rs_check_access() responds with status 500 - Internal error occured. Please check oxd-server.log file for details")
    elseif status == 403 then
        unexpected_error("uma_rs_check_access() responds with status 403 - Invalid access token provided in Authorization header")
    end
    unexpected_error("uma_rs_check_access() responds with unexpected status: ", status)
end

local function try_introspect_rpt(conf, token)
    local response = oxd.introspect_rpt(conf.oxd_url,
        {
            oxd_id = conf.oxd_id,
            rpt = token,
        },
        access_token)
    local status = response.status
    if status == 200 then
        -- TODO check required fields
        return response.body
    end
    if status == 400 then
        unexpected_error("introspect_rpt() responds with status 400 - Invalid parameters are provided to endpoint")
    elseif status == 500 then
        unexpected_error("introspect_rpt() responds with status 500 - Internal error occured. Please check oxd-server.log file for details")
    elseif status == 403 then
        unexpected_error("introspect_rpt() responds with status 403 - Invalid access token provided in Authorization header")
    end
    unexpected_error("introspect_rpt() responds with unexpected status: ", status)
end

local function hide_credentials(conf)
    if not conf.hide_credentials then
        return
    end
    kong.log.debug("Hide authorization header")
    kong.service.request.clear_header("authorization")
end

local function set_consumer(client_id, consumer, exp)
    local const = constants.HEADERS
    local new_headers = {
        [const.CONSUMER_ID] = consumer.id,
        [const.CONSUMER_CUSTOM_ID] = tostring(consumer.custom_id),
        [const.CONSUMER_USERNAME] = tostring(consumer.username),
    }
    -- https://github.com/Kong/kong/blob/2cdd07e34a362e86d95d5e88615e217fa4f6f0d2/kong/plugins/key-auth/handler.lua#L52
    kong.ctx.shared.authenticated_consumer = consumer -- forward compatibility
    ngx.ctx.authenticated_consumer = consumer -- backward compatibility

    if client_id then
        new_headers["X-OAuth-Client-ID"] = tostring(client_id)
        new_headers["X-OAuth-Expiration"] = tostring(exp)
        -- TODO what about kong.ctx.shared.authenticated_credential?
        kong.service.request.clear_header(const.ANONYMOUS) -- in case of auth plugins concatenation
    else
        new_headers[const.ANONYMOUS] = true
    end
    kong.service.request.set_headers(new_headers)
end

local function set_anonymous(conf)
    print(conf.anonymous)
    local consumer_cache_key = kong.db.consumers:cache_key(conf.anonymous)
    local consumer, err = kong.cache:get(consumer_cache_key, nil, load_consumer_by_id, conf.anonymous)

    if err then
        return unexpected_error("Anonymous customer: ", err)
    end

    set_consumer(nil, consumer)
end

return function (conf)
    local authorization = ngx.var.http_authorization
    local token = get_token(authorization)
    local method = ngx.req.get_method()
    local path = ngx.var.uri

    path = helper.get_path_by_request_path_method(conf.uma_scope_expression, path, method)
    kong.log.debug("registered resource path: ", path)

    if path and not token then
        get_protection_token(conf) -- this may exit with 500

        local check_access_no_rpt_response = try_check_access(conf, path, method, nil)

        if check_access_no_rpt_response.access == "denied" then
            kong.log.debug("Set WWW-Authenticate header with ticket")
            return kong.response.exit(401, "Unauthorized", {
                ["WWW-Authenticate"] = check_access_no_rpt_response["www-authenticate_header"]
            })
        end
        unexpected_error("check_access without RPT token, responds with access == \"granted\"")
    end

    if not path and not token then
        if not conf.deny_by_default then
            if conf.anonymous ~= "" then
                set_anonymous(conf)
            end
            return -- access granted
        end
        return kong.response.exit(403, "Unprotected path are not allowed") -- TODO ?!
    end

    local cache_key = build_cache_key(token, path)
    local data, stale_data = worker_cache:get(cache_key)
    if data and not stale_data then
        -- we're already authenticated
        kong.log.debug("Token cache found. we're already authenticated")
        set_consumer(data.client_id, data.consumer, data.exp)
        hide_credentials(conf)
        return -- access granted
    end

    get_protection_token(conf)

    local introspect_rpt_response_data = try_introspect_rpt(conf, token)
    if not introspect_rpt_response_data.active then
        return kong.response.exit(401, "Invalid access token provided in Authorization header")
    end

    local client_id = assert(introspect_rpt_response_data.client_id)
    local exp = assert(introspect_rpt_response_data.exp)

    local consumer, err = kong.db.consumers:select_by_custom_id(client_id)
    if not consumer and not err then
        kong.log.err('consumer with custom_id "' .. client_id .. '" not found')
        return kong.response.exit(401, "Unknown consumer")
    end
    if err then
        return unexpected_error("select_by_custom_id error: ", err)
    end
    introspect_rpt_response_data.consumer = consumer

    if not path then
        if not conf.deny_by_default then
            worker_cache:set(cache_key, introspect_rpt_response_data,
                introspect_rpt_response_data.exp - introspect_rpt_response_data.iat --TODO decrement some delta?
            )
            set_consumer(client_id, consumer, exp)
            hide_credentials(conf)
            return -- access granted
        end
        return kong.response.exit(403, "Unauthorized")
    end

    local check_access_response = try_check_access(conf, path, method, token)

    if check_access_response.access == "granted" then
        worker_cache:set(cache_key, introspect_rpt_response_data,
             introspect_rpt_response_data.exp - introspect_rpt_response_data.iat --TODO decrement some delta?
        )
        set_consumer(client_id, consumer, exp)
        hide_credentials(conf)
        return -- access granted
    end

    -- access == "denied"
    return kong.response.exit(403)
end
