local helper = require "kong.plugins.kong-uma-rs.helper"
local responses = require "kong.tools.responses"
local singletons = require "kong.singletons"
local ngx_re_gmatch = ngx.re.gmatch

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

--- Fetch given requested path. Example: /products
-- @return path
local function getPath()
    local path = ngx.var.request_uri
    ngx.log(ngx.DEBUG, "request_uri " .. path);
    local indexOf = string.find(path, "?")
    if indexOf ~= nil then
        return string.sub(path, 1, (indexOf - 1))
    end
    return path
end

--- Return cache data in table formate
-- @return if exp_sec is set then return valid data otherwise nil
local function load_token_into_memory(rpt, method, path, exp_sec)
    local result
    if not helper.is_empty(exp_sec) then
        result = { rpt = rpt, method = method, path = path }
    end
    return result
end

--- Retriev token from cache
-- @param rpt: RPT token
-- @param method: Requested http method
-- @param path: Requested path
-- @param exp_sec: Expiration time for cache in seccond
-- @return { rpt, method, path }
local function retrieve_token_cache(rpt, method, path, exp_sec)
    local token, err
    if rpt then
        local token_cache_key = rpt .. method .. path
        ngx.log(ngx.DEBUG, "Cache search: " .. token_cache_key)
        token, err = singletons.cache:get(token_cache_key, { ttl = exp_sec },
            load_token_into_memory, rpt, method, path, exp_sec)
        if err then
            return responses.send_HTTP_INTERNAL_SERVER_ERROR(err)
        end
    end
    return token or nil
end

local _M = {}

--- Start execution. Call by handler.lua
-- @param conf: Global configuration oxd_id, client_id and client_secret
-- @return ACCESS GRANTED and Unauthorized
function _M.execute(conf)
    local httpMethod = ngx.req.get_method()
    local rpt = retrieve_token(ngx.req)
    local path = getPath()

    ngx.log(ngx.DEBUG, "kong-uma-rs : Access - http_method: " .. httpMethod .. ", rpt: " .. rpt .. ", path: " .. path)

    -- Check token in cache
    local cacheToken = retrieve_token_cache(rpt, httpMethod, path, nil);
    if not helper.is_empty(cacheToken) then
        ngx.log(ngx.DEBUG, "Token found in cache")
        return -- ACCESS GRANTED
    end
    ngx.log(ngx.DEBUG, "Token not found in cache")

    -- Introspect to rpt token
    local introspectResponse = helper.introspect_rpt(conf, rpt)

    if not introspectResponse then
        return responses.send_HTTP_UNAUTHORIZED("Unauthorized")
    end

    -- Count expire time in second
    local exp_sec = (introspectResponse.data.exp - introspectResponse.data.iat)

    -- Check UMA-RS access
    local response = helper.check_access(conf, rpt, path, httpMethod)
    if response == nil then
        return responses.send_HTTP_FORBIDDEN("UMA Authorization Server Unreachable")
    end

    -- Invalidate(clear) the cache if exist
    singletons.cache:invalidate(rpt .. httpMethod .. path)

    if response.status == "error" or helper.is_empty(response.data) then
        return responses.send_HTTP_UNAUTHORIZED("Unauthorized")
    elseif response.data.error == "invalid_request" then
        ngx.log(ngx.DEBUG, "kong-uma-rs : Path is not protected! - http_method: " .. httpMethod .. ", rpt: " .. rpt .. ", path: " .. path)
        ngx.header["UMA-Warning"] = "Path is not protected by UMA. Please check protection_document."
        retrieve_token_cache(rpt, httpMethod, path, exp_sec)
        return -- ACCESS GRANTED with UMA-Warning header
    end

    if response.status == "ok" then
        if response.data.access == "granted" then
            retrieve_token_cache(rpt, httpMethod, path, exp_sec)
            return -- ACCESS GRANTED
        end

        if response.data.access == "denied" then
            local ticket = response.data.ticket
            if not helper.is_empty(ticket) and not helper.is_empty(response.data["www-authenticate_header"]) then
                ngx.header["WWW-Authenticate"] = response.data["www-authenticate_header"]
                return responses.send_HTTP_UNAUTHORIZED("Unauthorized")
            end

            return responses.send_HTTP_FORBIDDEN("UMA Authorization Server Unreachable")
        end
    end

    return responses.send_HTTP_FORBIDDEN("Unknown (unsupported) status code from oxd server for uma_rs_check_access operation.")
end

return _M