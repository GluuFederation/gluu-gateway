local helper = require "kong.plugins.kong-uma-rs.helper"
local responses = require "kong.tools.responses"
local singletons = require "kong.singletons"
local ngx_re_gmatch = ngx.re.gmatch
local PLUGINNAME = "kong-uma-rs"
local ngx_set_header = ngx.req.set_header

--- Retrieve a RPT token in the `Authorization` header.
-- @param request ngx request object
-- @param conf Plugin configuration
-- @return RPT token or nil
-- @return err
local function retrieve_token(request)
    local authorization_header = request.get_headers()["authorization"]
    if authorization_header then
        local iterator, iter_err = ngx_re_gmatch(authorization_header, "\\s*[Bb]earer\\s+(.+)")
        if not iterator then
            return nil, iter_err
        end

        local m, err = iterator()
        if err then
            return nil, err
        end

        if m and #m > 0 then
            return m[1]
        end
    end
end

--- Fetch given requested path. Example: /posts
-- @return path
local function getPath()
    local path = ngx.var.request_uri
    ngx.log(ngx.DEBUG, "request_uri " .. path)
    local indexOf = string.find(path, "?")
    if indexOf ~= nil then
        return string.sub(path, 1, (indexOf - 1))
    end
    return path
end

--- Return cache data in table formate
-- @return if exp_sec is set then return valid data otherwise nil
local function load_token_into_memory(rpt, method, path, isPathProtected, exp_sec)
    local result
    if not helper.is_empty(exp_sec) then
        result = { rpt = rpt, method = method, path = path, isPathProtected = isPathProtected }
    end
    return result
end

--- Get or set token cache token from cache
-- If token not in cache then call load_token_into_memory function and set values in cache return by load_token_into_memory.
-- @param rpt: RPT token
-- @param method: Requested http method
-- @param path: Requested path
-- @param exp_sec: Expiration time for cache in seccond
-- @return { rpt, method, path }
local function get_set_token_cache(rpt, method, path, isPathProtected, exp_sec)
    local token, err
    if rpt then
        local token_cache_key = PLUGINNAME .. rpt .. method .. path
        ngx.log(ngx.DEBUG, "Cache search: " .. token_cache_key)
        token, err = singletons.cache:get(token_cache_key, { ttl = exp_sec },
            load_token_into_memory, rpt, method, path, isPathProtected, exp_sec)
        if err then
            return responses.send_HTTP_INTERNAL_SERVER_ERROR(err)
        end
    end
    return token or nil
end

--- Check response of /uma-rs-check-access
-- @param umaRSResponse: Full response of uma-rs-check-access command
-- @param rpt: rpt token
-- @param httpMethod: HTTP method
-- @param path: Requested path Example: /posts
--
local function check_uma_rs_response(umaRSResponse, rpt, httpMethod, path)
    if helper.is_empty(umaRSResponse.status) then
        return responses.send_HTTP_FORBIDDEN("UMA Authorization Server Unreachable")
    end

    if umaRSResponse.status == "error" and helper.is_empty(umaRSResponse.data) then
        return responses.send_HTTP_UNAUTHORIZED("Unauthorized")
    elseif umaRSResponse.data.error == "invalid_request" then
        ngx.log(ngx.DEBUG, "kong-uma-rs : Path is not protected! - http_method: " .. httpMethod .. ", rpt: " .. (rpt or "nil") .. ", path: " .. path)
        ngx.header["UMA-Warning"] = "Path is not protected by UMA. Please check protection_document."
        return { access = true, isPathProtected = false }
    end

    if umaRSResponse.status == "ok" then
        if umaRSResponse.data.access == "granted" then
            return { access = true, isPathProtected = true }
        end

        if umaRSResponse.data.access == "denied" then
            local ticket = umaRSResponse.data.ticket
            if not helper.is_empty(ticket) and not helper.is_empty(umaRSResponse.data["www-authenticate_header"]) then
                ngx_set_header("WWW-Authenticate", umaRSResponse.data["www-authenticate_header"])
                return responses.send_HTTP_UNAUTHORIZED("Unauthorized")
            end

            return responses.send_HTTP_FORBIDDEN("UMA Authorization Server Unreachable")
        end
    end
end

local _M = {}

--- Start execution. Call by handler.lua
-- @param conf: Global configuration oxd_id, client_id and client_secret
-- @return ACCESS GRANTED and Unauthorized
function _M.execute(conf)
    local httpMethod = ngx.req.get_method()
    local rpt = retrieve_token(ngx.req)
    local path = getPath()
    local ip = ngx.var.remote_addr

    ngx.log(ngx.DEBUG, "kong-uma-rs : Access - http_method: " .. httpMethod .. ", rpt: " .. (rpt or "nil") .. " ip: " .. ip .. ", path: " .. path)

    -- Check token in cache
    local cacheToken = get_set_token_cache(rpt or ip, httpMethod, path, false, nil)

    if not helper.is_empty(cacheToken) then
        ngx.log(ngx.DEBUG, "Token found in cache")

        -- If path is not protected then send header with UMA-Wanrning
        if not cacheToken.isPathProtected then
            ngx.log(ngx.DEBUG, "kong-uma-rs : Path is not protected! - http_method: " .. httpMethod .. ", rpt: " .. (rpt or "nil") .. " ip: " .. ip .. ", path: " .. path)
            ngx.header["UMA-Warning"] = "Path is not protected by UMA. Please check protection_document."
        end

        return -- ACCESS GRANTED
    end

    ngx.log(ngx.DEBUG, "Token not found in cache")

    -- Check UMA-RS access -> oxd
    local umaRSResponse = helper.check_access(conf, rpt, path, httpMethod)

    -- Check uma_rs_acceess response
    local checkUMARsResponse = check_uma_rs_response(umaRSResponse, rpt, path, httpMethod)

    if checkUMARsResponse.access == true then
        -- Invalidate(clear) the cache if exist
        singletons.cache:invalidate(PLUGINNAME .. (rpt or ip) .. httpMethod .. path)

        -- If path is protected the cache rpt with token expiration time otherwise cache using ip address
        if checkUMARsResponse.isPathProtected then
            -- Introspect to rpt token and get expire time
            local introspectResponse = helper.introspect_rpt(conf, rpt)

            if not introspectResponse then
                return responses.send_HTTP_UNAUTHORIZED("Failed to introspect token.")
            end

            -- Count expire time in second
            local exp_sec = (introspectResponse.data.exp - introspectResponse.data.iat)
            ngx.log(ngx.DEBUG, "Expire time: " .. exp_sec)

            get_set_token_cache(rpt, httpMethod, path, checkUMARsResponse.isPathProtected, exp_sec)
            return -- ACCESS GRANTED
        else
            get_set_token_cache(rpt or ip, httpMethod, path, checkUMARsResponse.isPathProtected, conf.unprotected_path_cache_time_sec)
            return -- ACCESS GRANTED with UMA-Warning header
        end
    end

    return responses.send_HTTP_FORBIDDEN("Unknown (unsupported) status code from oxd server for uma_rs_check_access operation.")
end

return _M