local helper = require "kong.plugins.gluu-oauth2-rs.helper"
local responses = require "kong.tools.responses"
local singletons = require "kong.singletons"
local json = require "JSON"
local ngx_re_gmatch = ngx.re.gmatch
local PLUGINNAME = "gluu-oauth2-rs"
local CLIENT_PLUGIN_NAME = "gluu-oauth2-client-auth"

--- Retrieve a RPT token in the `Authorization` header.
-- @param request ngx request object
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

--- Retrieve a claim information from UMA_PUSHED_CLAIMS header.
-- @param request ngx request object
-- @return {"claim_token": "", "claim_token_format": "" }
local function retrieve_uma_data(request)
    -- Get UMA_PUSHED_CLAIMS {"claim_token": "", "claim_token_format": "" }
    local claim_header = request.get_headers()["uma_pushed_claims"]
    if not helper.is_empty(claim_header) then
        ngx.log(ngx.DEBUG, "claim_header " .. claim_header)
        if pcall(function() json:decode(claim_header) end) then
            local uma_data = json:decode(claim_header)
            ngx.log(ngx.DEBUG, "uma_data.claim_token " .. uma_data.claim_token)
            if not helper.is_empty(uma_data.claim_token) and not helper.is_empty(uma_data.claim_token) then
                return uma_data
            end
        else
            ngx.log(ngx.DEBUG, "Failed to parse UMA_PUSHED_CLAIMS")
        end
    end
    return nil
end

--- Fetch given requested path. Example: /posts
-- @return path
local function getPath()
    local path = ngx.var.request_uri
    ngx.log(ngx.DEBUG, PLUGINNAME .. ": request_uri " .. path)
    local indexOf = string.find(path, "?")
    if indexOf ~= nil then
        return string.sub(path, 1, (indexOf - 1))
    end
    return path
end

--- Check response of /uma-rs-check-access
-- @param umaRSResponse: Full response of uma-rs-check-access command
-- @param rpt: rpt token
-- @param httpMethod: HTTP method
-- @param path: Requested path Example: /posts
local function check_uma_rs_response(umaRSResponse, rpt, httpMethod, path)
    if helper.is_empty(umaRSResponse.status) then
        return responses.send_HTTP_FORBIDDEN("UMA Authorization Server Unreachable")
    end

    if umaRSResponse.status == "error" and helper.is_empty(umaRSResponse.data) then
        return responses.send_HTTP_UNAUTHORIZED("Unauthorized")
    elseif umaRSResponse.data.error == "invalid_request" then
        ngx.log(ngx.DEBUG, PLUGINNAME .. ": Path is not protected! - http_method: " .. httpMethod .. ", rpt: " .. (rpt or "nil") .. ", path: " .. path)
        ngx.header["UMA-Warning"] = "Path is not protected by UMA"
        return { access = true, path_protected = false }
    elseif umaRSResponse.data.error == "internal_error" then
        ngx.log(ngx.DEBUG, PLUGINNAME .. ": Unknown internal server error occurs. Check oxd-server log")
        ngx.status = 500
        ngx.header.content_type = "application/json; charset=utf-8"
        ngx.say([[{ "message": "Unknown internal server error occurs. Check oxd-server log" }]])
        return ngx.exit(500)
    end

    if umaRSResponse.status == "ok" then
        if umaRSResponse.data.access == "granted" then
            return { access = true, path_protected = true }
        end

        if umaRSResponse.data.access == "denied" then
            local ticket = umaRSResponse.data.ticket
            if not helper.is_empty(ticket) and not helper.is_empty(umaRSResponse.data["www-authenticate_header"]) then
                ngx.log(ngx.DEBUG, "Set WWW-Authenticate header with ticket")
                ngx.header["WWW-Authenticate"] = umaRSResponse.data["www-authenticate_header"]
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
    ngx.log(ngx.DEBUG, "Enter in gluu-oauth2-rs plugin")
    local httpMethod = ngx.req.get_method()
    local reqToken = retrieve_token(ngx.req)
    local path = getPath()

    ngx.log(ngx.DEBUG, PLUGINNAME .. ": Access - http_method: " .. httpMethod .. ", reqToken: " .. (reqToken or "nil") .. ", path: " .. path)

    if helper.is_empty(reqToken) then
        ngx.log(ngx.DEBUG, PLUGINNAME .. " : Unauthorized! Token not found in header")
        -- Check access and return permission ticket in header
        local umaRSResponse = helper.check_access(conf, "", path, httpMethod)

        if helper.is_empty(umaRSResponse) or umaRSResponse == false then
            return responses.send_HTTP_UNAUTHORIZED("Unauthorized!")
        end

        check_uma_rs_response(umaRSResponse, reqToken, httpMethod, path)

        -- Unauthorized! Token not found in header
        return responses.send_HTTP_UNAUTHORIZED("Unauthorized! Token not found in header")
    end

    -- Check RPT token is in gluu-oauth2-rs cache
    local clientPluginCacheToken = singletons.cache:get(reqToken, nil, function() end)

    if helper.is_empty(clientPluginCacheToken) then
        ngx.log(ngx.DEBUG, PLUGINNAME .. " : Unauthorized! gluu-oauth2-client-auth cache is not found")
        return responses.send_HTTP_UNAUTHORIZED("Unauthorized! gluu-oauth2-client-auth cache is not found")
    else
        -- Path filter
        path = helper.filter_expression_path(conf.protection_document, path)

        -- Check Token is already exist with same path and method
        if not helper.is_empty(clientPluginCacheToken.permissions) then
            local permissionFlag = false
            -- Check requested path in cached paths
            for count = 1, #clientPluginCacheToken.permissions do
                if clientPluginCacheToken.permissions[count].path == path and clientPluginCacheToken.permissions[count].method == httpMethod then
                    ngx.log(ngx.DEBUG, PLUGINNAME .. ": Token already exist with same path and method")
                    -- If path is not protected then send header with UMA-Wanrning
                    if not clientPluginCacheToken.permissions[count].path_protected then
                        ngx.log(ngx.DEBUG, PLUGINNAME .. ": Path is not protected by UMA-RS! - http_method: " .. httpMethod .. ", path: " .. path)
                        ngx.header["UMA-Warning"] = "Path is not protected by UMA-RS"
                    end
                    permissionFlag = true
                end
            end

            -- If requested path is found in cache then check claim token in cache
            if permissionFlag and not helper.is_empty(clientPluginCacheToken.claim_tokens) and #clientPluginCacheToken.claim_tokens > 0 then
                -- Check claim token in header
                local uma_data = retrieve_uma_data(ngx.req)

                -- check claim token is exist then check it with claim_tokens in cache JSON
                if helper.is_empty(uma_data) or helper.is_empty(uma_data.claim_token) then
                    ngx.log(ngx.DEBUG, "Unauthorized! You need to pass claim token")
                    return responses.send_HTTP_UNAUTHORIZED("Unauthorized! You need to pass claim token")
                end

                for count = 1, #clientPluginCacheToken.claim_tokens do
                    if uma_data.claim_token == clientPluginCacheToken.claim_tokens[count] then
                        ngx.log(ngx.DEBUG, "Token already exist with same path, method, and claim token found in cache, Allow access")
                        return -- Access Granted
                    end
                end

                ngx.log(ngx.DEBUG, "Token already exist with same path, method, but claim token is invalid, deny access")
                return responses.send_HTTP_UNAUTHORIZED("Unauthorized! You are passing wrong claim token")
            else
                -- If claim token is not in cache and path is found then allow access
                if permissionFlag then
                    ngx.log(ngx.DEBUG, "Token already exist with same path and method found in cache, Allow access")
                    return -- Access Granted
                end
            end
        end
    end

    ngx.log(ngx.DEBUG, PLUGINNAME .. ": Token not exist with requested path and method")

    -- Get oauth2-consumer credential for getting all modes(oauth_mode, uma_mode, mix_mode) in here.
    local oauth2Credential = singletons.cache:get(singletons.dao.gluu_oauth2_client_auth_credentials:cache_key(clientPluginCacheToken.client_id), nil, function() end)
    ngx.log(ngx.DEBUG, PLUGINNAME .. ": Token type : " .. clientPluginCacheToken.token_type)
    ngx.log(ngx.DEBUG, PLUGINNAME .. ": oauth_mode : " .. tostring(oauth2Credential.oauth_mode) .. ", uma_mode : " .. tostring(oauth2Credential.uma_mode) .. ", mix_mode : " .. tostring(oauth2Credential.mix_mode))

    --- Flow when Token is UMA RPT token
    if clientPluginCacheToken.token_type == "UMA" then
        ngx.log(ngx.DEBUG, PLUGINNAME .. ": Enter in process when token is UMA")
        if oauth2Credential.oauth_mode then
            ngx.log(ngx.DEBUG, PLUGINNAME .. " : 401 Unauthorized. OAuth(not UMA) is required in oauth_mode")
            return responses.send_HTTP_UNAUTHORIZED("Unauthorized! OAuth(not UMA) token required in oauth_mode")
        end

        -- Path filter
        path = helper.filter_expression_path(conf.protection_document, path)

        -- Check UMA-RS access -> oxd
        local umaRSResponse = helper.check_access(conf, reqToken, path, httpMethod)

        if not umaRSResponse then
            ngx.log(ngx.DEBUG, PLUGINNAME .. " : Failed to access resources. umaRSResponse is false")
            return responses.send_HTTP_FORBIDDEN("Failed to access resources")
        end

        -- Check uma_rs_access response
        local checkUMARsResponse = check_uma_rs_response(umaRSResponse, reqToken, httpMethod, path)
        if checkUMARsResponse.access == true then
            -- Allow unprotected path is deny by oauth2-consumer then deny 401/Unauthorized
            if not checkUMARsResponse.path_protected and not oauth2Credential.allow_unprotected_path then
                ngx.log(ngx.DEBUG, PLUGINNAME .. " : Unauthorized! path is not protected and allow_unprotected_path flag is false")
                return responses.send_HTTP_UNAUTHORIZED("Unauthorized")
            end

            -- Update rpt in gluu-oauth2-client-auth plugin
            singletons.cache:invalidate(reqToken)
            clientPluginCacheToken.associated_rpt = umaRSResponse.rpt
            table.insert(clientPluginCacheToken.permissions, { path = path, method = httpMethod, path_protected = checkUMARsResponse.path_protected })

            ngx.log(ngx.DEBUG, "RPT token " .. umaRSResponse.rpt)
            singletons.cache:get(reqToken, { ttl = clientPluginCacheToken.exp_sec }, function() return clientPluginCacheToken end)

            -- Set bi-map cache with RPT token
            singletons.cache:invalidate(umaRSResponse.rpt)
            singletons.cache:get(umaRSResponse.rpt, { ttl = clientPluginCacheToken.exp_sec }, function() return clientPluginCacheToken end)
            return -- ACCESS GRANTED
        end

        ngx.log(ngx.DEBUG, PLUGINNAME .. " : Failed to access resources. access is false")
        return responses.send_HTTP_FORBIDDEN("Failed to access resources")
    end

    --- Flow when Token is OAuth
    if clientPluginCacheToken.token_type == "OAuth" then
        ngx.log(ngx.DEBUG, PLUGINNAME .. ": Enter in process when token is OAuth")
        if oauth2Credential.uma_mode then
            ngx.log(ngx.DEBUG, PLUGINNAME .. " : UMA Token is required in UMA Mode")
            return responses.send_HTTP_UNAUTHORIZED("Unauthorized! UMA Token is required in UMA Mode")
        end

        if oauth2Credential.oauth_mode then
            if helper.is_empty(oauth2Credential.allow_oauth_scope_expression) or oauth2Credential.allow_oauth_scope_expression == false then
                ngx.log(ngx.DEBUG, PLUGINNAME .. " : Authorized. Allow - OAuth mode. allow_oauth_scope_expression is off")
                return -- Access Granted
            end

            -- Path filter
            path = helper.filter_expression_path(conf.oauth_scope_expression, path)

            ngx.log(ngx.DEBUG, "Checking scope expression available for path and method or not")
            local scope_expression = helper.fetch_Expression(conf.oauth_scope_expression, path, httpMethod)

            if helper.is_empty(scope_expression) then
                ngx.log(ngx.DEBUG, "Path and method is not protected with oauth scope expression. Update your expression")
                return responses.send_HTTP_FORBIDDEN("Path and method is not protected with oauth scope expression")
            end

            ngx.log(ngx.DEBUG, "Checking allow_oauth_scope_expression...")
            if helper.check_json_expression(scope_expression, clientPluginCacheToken.scopes) then
                ngx.log(ngx.DEBUG, "OAuth scope expression result : true")
                return -- Access Granted
            else
                ngx.log(ngx.DEBUG, "OAuth scope expression result : true")
                return responses.send_HTTP_FORBIDDEN("Failed to validate introspect scope with oauth scope expression")
            end
        end

        if not oauth2Credential.mix_mode then
            return responses.send_HTTP_UNAUTHORIZED("Enable anyone mix mode")
        end

        -- Check UMA Data in header for claim token
        local uma_data = retrieve_uma_data(ngx.req)

        -- Path filter
        path = helper.filter_expression_path(conf.protection_document, path)

        -- Check UMA-RS access -> oxd
        local umaRSResponse = helper.get_rpt_with_check_access(conf, path, httpMethod, uma_data, clientPluginCacheToken.associated_rpt or nil)
        if not umaRSResponse then
            ngx.log(ngx.DEBUG, PLUGINNAME .. " : Failed to access resources. umaRSResponse is false")
            return responses.send_HTTP_FORBIDDEN("Failed to access resources")
        end

        -- Check uma_rs_access response
        local checkUMARsResponse = check_uma_rs_response(umaRSResponse, reqToken, httpMethod, path)
        if checkUMARsResponse.access == true then
            -- Allow unprotected path is deny by oauth2-consumer then deny 401/Unauthorized
            if not checkUMARsResponse.path_protected and not oauth2Credential.allow_unprotected_path then
                ngx.log(ngx.DEBUG, PLUGINNAME .. " : Unauthorized! path is not protected and allow_unprotected_path flag is false")
                return responses.send_HTTP_UNAUTHORIZED("Unauthorized")
            end

            -- check claim token is exist then add it into claim_tokens in cache JSON
            if not helper.is_empty(uma_data) and not helper.is_empty(uma_data.claim_token) then
                table.insert(clientPluginCacheToken.claim_tokens, uma_data.claim_token)
            end

            -- Set permissions ket in token JSON cache
            table.insert(clientPluginCacheToken.permissions, { path = path, method = httpMethod, path_protected = checkUMARsResponse.path_protected })

            -- Set associated_rpt only when path is protected by UMA-RS
            if checkUMARsResponse.path_protected then
                clientPluginCacheToken.associated_rpt = umaRSResponse.rpt
            end

            -- Update rpt in gluu-oauth2-client-auth plugin
            singletons.cache:invalidate(reqToken)
            singletons.cache:get(reqToken, { ttl = clientPluginCacheToken.exp_sec }, function() return clientPluginCacheToken end)

            -- Store rpt in cache only when path is protected by uma-rs
            if checkUMARsResponse.path_protected then
                -- Set bi-map cache with RPT token
                ngx.log(ngx.DEBUG, "RPT token " .. umaRSResponse.rpt)
                singletons.cache:invalidate(umaRSResponse.rpt)
                singletons.cache:get(umaRSResponse.rpt, { ttl = clientPluginCacheToken.exp_sec }, function() return clientPluginCacheToken end)
            end

            return -- ACCESS GRANTED
        end

        ngx.log(ngx.DEBUG, PLUGINNAME .. " : Failed to access resources. access is false")
        return responses.send_HTTP_FORBIDDEN("Failed to access resources")
    end

    return responses.send_HTTP_FORBIDDEN("Unknown (unsupported) status code from oxd server for uma_rs_check_access operation.")
end

return _M