local oxd = require "gluu.oxdweb"
local resty_session = require("resty.session")
local kong_auth_pep_common = require "gluu.kong-common"
local path_wildcard_tree = require "gluu.path-wildcard-tree"
local method_path_tree_cache = require "gluu.method-path-tree-cache"

local function unexpected_error()
    kong.response.exit(502, { message = "An unexpected error ocurred" })
end

local function process_logout(conf, session)
    local session_token
    -- get any first id_token to use as id_token_hint
    for k, _ in pairs(session.data.id_tokens) do
        session_token = k
    end
    session:destroy()

    local ptoken = kong_auth_pep_common.get_protection_token(conf)

    local post_logout_redirect_uri
    if conf.post_logout_redirect_path_or_url:sub(1, 1) == "/" then
        post_logout_redirect_uri = kong_auth_pep_common.get_path_with_base_url(conf.post_logout_redirect_path_or_url)
    else
        post_logout_redirect_uri = conf.post_logout_redirect_path_or_url
    end

    local response, err = oxd.get_logout_uri(conf.oxd_url,
        {
            oxd_id = conf.oxd_id,
            id_token_hint = session_token,
            post_logout_redirect_uri = post_logout_redirect_uri,
        },
        ptoken)

    if err then
        kong.log.err(err)
        return unexpected_error()
    end

    local status, json = response.status, response.body

    if status ~= 200 then
        kong.log.err("get_logout_uri() responds with status ", status)
        return kong.response.exit(502)
    end

    ngx.header["Cache-Control"] = "no-cache, no-store, max-age=0"
    return ngx.redirect(json.uri)
end

-- handle a "code" authorization response from the OP
local function authorization_response(conf, session)
    local args = ngx.req.get_uri_args()

    local code, state = args.code, args.state
    if not code or not state then
        kong.log.warn("missed code or state argument(s)")
        return kong.response.exit(400, {message = "missed code or state argument(s)"})
    end

    kong.log.debug("Authentication with OP done -> Calling OP Token Endpoint to obtain tokens")

    local ptoken = kong_auth_pep_common.get_protection_token(conf)

    local response, err = oxd.get_tokens_by_code(conf.oxd_url,
        {
            oxd_id = conf.oxd_id,
            code = code,
            state = state,
        },
        ptoken)

    if err then
        kong.log.err(err)
        return unexpected_error()
    end

    local status, json = response.status, response.body

    if status ~= 200 then
        kong.log.err("get_tokens_by_code() responds with status ", status)
        return unexpected_error()
    end

    local id_token = json.id_token_claims

    local session_data = session.data
    local original_url = session_data.original_url
    session_data.original_url = nil

    local id_tokens = session_data.id_tokens
    local access_tokens = session_data.access_tokens

    if not id_tokens then
        id_tokens = {}
        session_data.id_tokens = id_tokens
        access_tokens = {}
        session_data.access_tokens = access_tokens
    end

    id_token.requested_acrs = session_data.requested_acrs
    session_data.requested_acrs = nil
    id_tokens[json.id_token] = id_token
    access_tokens[json.id_token] = json.access_token

    local ptoken = kong_auth_pep_common.get_protection_token(conf)

    local response, err = oxd.get_user_info(conf.oxd_url,
        {
            oxd_id = conf.oxd_id,
            access_token = json.access_token,
        },
        ptoken)

    if err then
        kong.log.err(err)
        return unexpected_error()
    end

    local status, json = response.status, response.body

    if status ~= 200 then
        kong.log.err("get_user_info() responds with status ", status)
        return unexpected_error()
    end

    session.data.userinfo = json
    session:save()

    -- redirect to the URL that was accessed originally
    kong.log.debug("OIDC Authorization Code Flow completed -> Redirecting to original URL (", original_url, ")")
    ngx.redirect(original_url)
end

local function is_acr_enough(required_acrs, acr)
    if not required_acrs then
        return true
    end
    local acr_array = kong_auth_pep_common.split(acr, " ")
    for i = 1, #required_acrs do
        for k = 1, #acr_array do
            if required_acrs[i] == acr_array[k] then
                return true
            end
        end
    end
    return false
end

local function acr_already_requested(id_tokens, required_acrs)
    assert(required_acrs and #required_acrs > 0)
    for _, id_token in pairs(id_tokens) do
        local requested_acrs = id_token.requested_acrs

        if requested_acrs then
            local match = true
            for i = 1, #required_acrs do
                if not requested_acrs[required_acrs[i]] then
                    match = false
                    break
                end
            end
            if match then
                return true
            end
        end
    end
    return false
end

local function set_requested_acrs(session_data, required_acrs)
    if not required_acrs or #required_acrs == 0 then
        session_data.requested_acrs = nil
        return
    end
    session_data.requested_acrs = {}
    local requested_acrs = session_data.requested_acrs
    for i = 1, #required_acrs do
        requested_acrs[required_acrs[i]] = true
    end
end

local function get_acrs(id_tokens)
    local t = {}
    for k, v in pairs(id_tokens) do
        t[#t + 1] = v.acr
    end
    return t
end

-- send the browser of to the OP's authorization endpoint
local function authorize(conf, session, prompt, required_acrs)
    local ptoken = kong_auth_pep_common.get_protection_token(conf)

    local response, err = oxd.get_authorization_url(conf.oxd_url,
        {
            oxd_id = conf.oxd_id,
            prompt = prompt,
            scope = conf.requested_scopes,
            acr_values = required_acrs,
            params = {
                max_age = conf.max_id_token_age,
            },
        },
        ptoken)

    if err then
        kong.log.err(err)
        return unexpected_error()
    end

    local status, json = response.status, response.body

    if status ~= 200 then
        kong.log.err("get_authorization_url() responds with status ", status)
        return unexpected_error()
    end

    local authorization_url = json.authorization_url
    if not authorization_url then
        kong.log.err("get_authorization_url() missed authorization_url")
        return unexpected_error()
    end

    local session_data = session.data
    -- by original_url session's field we distinguish enduser session previously redirected
    -- to OP for authentication
    session_data.original_url = ngx.var.request_uri
    set_requested_acrs(session_data, required_acrs)
    session:save()

    -- redirect to the /authorization endpoint
    ngx.header["Cache-Control"] = "no-cache, no-store, max-age=0"
    ngx.redirect(authorization_url)
end

local function purge_id_tokens(session_data, conf)
    local id_tokens = session_data.id_tokens
    if not  id_tokens then
        return
    end
    local active_id_tokens = 0
    for token, token_data in pairs(id_tokens) do
        if token_data.auth_time and (token_data.auth_time + conf.max_id_token_auth_age) < ngx.time() then
            kong.log.debug("Token ", token, " auth. is expired, remove from user session")
            id_tokens[token] = nil
        else
            active_id_tokens = active_id_tokens + 1
        end
    end
    if active_id_tokens == 0 then
        session_data.id_tokens = nil
    end
end

return function(self, conf)
    local session = resty_session.start()
    local session_data = session.data

    local path = ngx.var.uri:match"^([^%s]+)"

    -- see if this is a request to the redirect_uri i.e. an authorization response
    if path == conf.authorization_redirect_path then
        kong.log.debug("Redirect URI path (", path, ") is currently navigated -> Processing authorization response coming from OP")

        if not session.present then
            kong.log.err("request to the authorization response path but there's no session state found")
            return kong.response.exit(400)
        end

        return authorization_response(conf, session)
    end

    -- see is this a request to logout
    if path == conf.logout_path then
        kong.log.debug("Logout path (", path, ") is currently navigated -> Processing local session removal before redirecting to next step of logout process")

        if not session.present then
            kong.log.warn("request to the logout path but there's no session state found")
            return kong.response.exit(400)
        end

        return process_logout(conf, session)
    end

    -- if post logout uri is comming then allow
    -- Request is comming in kong proxy so checking only path
    if path == conf.post_logout_redirect_path_or_url then
        kong.log.debug("Post logout Redirect path (", path, ") found, allow request")
        return
    end

    purge_id_tokens(session_data, conf)
    local id_tokens = session_data.id_tokens
    kong.log.debug(
        "session.present=", session.present,
        ", session.data.id_tokens=", id_tokens ~= nil)

    local required_acrs_expression = conf.required_acrs_expression
    local required_acrs, no_auth

    if required_acrs_expression then
        local method_path_tree = method_path_tree_cache(required_acrs_expression)
        local rule = path_wildcard_tree.matchPath(method_path_tree, ngx.req.get_method(), path)
        required_acrs = rule and rule.required_acrs
        no_auth = rule and rule.no_auth
    end

    if no_auth then
        return
    end

    if not session.present or not id_tokens then
        kong.log.debug("Authentication is required - Redirecting to OP Authorization endpoint")
        return authorize(conf, session, nil, required_acrs)
    end

    local enc_id_token, id_token

    if not required_acrs then
        -- means any acr match
        for token, token_data in pairs(id_tokens) do
            if (token_data.iat + conf.max_id_token_age) > ngx.time() and token_data.exp > ngx.time() then
                enc_id_token, id_token = token, token_data
                break
            end
        end
       if not id_token then
           -- all tokens are expired, renew first
           for token, token_data in pairs(id_tokens) do
               id_tokens[token] = nil
               kong.log.debug("Authentication is required, no active tokens - Redirecting to OP Authorization endpoint")
               return authorize(conf, session, "none", { token_data.acr }) -- request the same acr
           end
       end
    end


    for token, token_data in pairs(id_tokens) do
        local acr = token_data.acr

        if acr and  is_acr_enough(required_acrs, acr) then
            enc_id_token, id_token = token, token_data
            break
        end
    end

    if not id_token then
        if acr_already_requested(id_tokens, required_acrs) then
            kong.log.debug("We already requested all required acrs, avoid a loop")

            local message = {
                "The resource requires one of the [",
                table.concat(required_acrs, ";"),
                "] acr(s), you have [",
                table.concat(get_acrs(id_tokens)),
                "]"
            }
            return kong.response.exit(403, { message = table.concat(message)})
        end

        kong.log.debug("Authentication is required, not enough acr - Redirecting to OP Authorization endpoint")
        return authorize(conf, session, "login", required_acrs)
    end

    if (id_token.iat + conf.max_id_token_age) < ngx.time() or
            id_token.exp < ngx.time() then
        -- clear expired id_token
        id_tokens[enc_id_token] = nil

        kong.log.debug("Silent authentication is required - Redirecting to OP Authorization endpoint")
        return authorize(conf, session, "none", required_acrs)
    end

    -- request_token_data need in uma-pep in both case i.e. uma-auth and openid-connect
    kong.ctx.shared.request_token = enc_id_token
    kong.ctx.shared.request_token_data = id_token
    kong.ctx.shared.userinfo = session_data.userinfo

    local environment = {
        id_token = id_token,
        userinfo = session_data.userinfo
    }

    local access_token = session_data.access_tokens[enc_id_token]
    if access_token then
        environment.access_token = access_token
    end

    local new_headers = kong_auth_pep_common.make_headers(conf.custom_headers, environment, enc_id_token)
    kong.service.request.set_headers(new_headers)
    kong.ctx.shared.gluu_openid_connect_users_authenticated = true
end


