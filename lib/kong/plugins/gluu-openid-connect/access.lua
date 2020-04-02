local oxd = require "gluu.oxdweb"
local resty_session = require("resty.session")
local kong_auth_pep_common = require "gluu.kong-common"
local path_wildcard_tree = require "gluu.path-wildcard-tree"
local method_path_tree_cache = require "gluu.method-path-tree-cache"

local openid_connect_session_data = require "gluu.openid_connect_session_data"
local oidc_wrap = openid_connect_session_data.wrap

local function unexpected_error()
    kong.response.exit(502, { message = "An unexpected error ocurred" })
end

local function process_logout(conf, session, path)
    kong.log.debug("Logout path (", path, ") is currently navigated -> Processing local session removal before redirecting to next step of logout process")

    if not session.present then
        kong.log.debug("request to the logout path but there's no session state found")
        return kong.response.exit(400)
    end

    local session_token
    -- get any first id_token to use as id_token_hint
    for k, _ in pairs(session.data.id_tokens) do
        session_token = k
        break
    end

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

    session:start()
    session:destroy()

    ngx.header["Cache-Control"] = "no-cache, no-store, max-age=0"
    return ngx.redirect(json.uri)
end

-- handle a "code" authorization response from the OP
local function authorization_response(conf, session, path)
    kong.log.debug("Redirect URI path (", path, ") is currently navigated -> Processing authorization response coming from OP")

    if not session.present then
        kong.log.err("request to the authorization response path but there's no session state found")
        return kong.response.exit(400)
    end

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

    local id_token_data = json.id_token_claims

    if id_token_data.exp <  ngx.time() then
        kong.log.warn("get_tokens_by_code() returns expired token")
        return kong.response.exit(500, { message = "OP returns expired id_token"})
    end

    if (id_token_data.iat + conf.max_id_token_age) < ngx.time() then
        kong.log.warn("get_tokens_by_code() returns id_token with too old iat")
        return kong.response.exit(500, { message = "OP returns id_token with too old iat"})
    end

    if id_token_data.auth_time and (id_token_data.auth_time + conf.max_id_token_auth_age) < ngx.time() then
        kong.log.warn("get_tokens_by_code() returns id_token with expired auth")
        return kong.response.exit(500, { message = "OP returns id_token with too old auth_time"})
    end

    local session_data = session.data
    local original_url = session_data.original_url
    session_data.original_url = nil

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

    local status, json2 = response.status, response.body

    if status ~= 200 then
        kong.log.err("get_user_info() responds with status ", status)
        return unexpected_error()
    end

    session:start()

    -- TODO replace code with direct access to session_data internal with methods
    kong.log.debug"save id_token in user session"
    local id_tokens = session_data.id_tokens
    local access_tokens = session_data.access_tokens
    if not id_tokens then
        kong.log.debug"create id_tokens table"
        id_tokens = {}
        session_data.id_tokens = id_tokens
        access_tokens = {}
        session_data.access_tokens = access_tokens
    end

    id_token_data.requested_acrs = session_data.requested_acrs
    session_data.requested_acrs = nil
    id_tokens[json.id_token] = id_token_data
    access_tokens[json.id_token] = json.access_token

    session_data.userinfo = json2
    session:save()

    -- redirect to the URL that was accessed originally
    kong.log.debug("OIDC Authorization Code Flow completed -> Redirecting to original URL (", original_url, ")")
    ngx.redirect(original_url)
end

-- send the browser of to the OP's authorization endpoint
local function authorize(conf, session, prompt, required_acrs)
    kong.log.debug("prompt: ", prompt == nil and "nil" or prompt)
    if required_acrs then
        if session.data:acr_already_requested(required_acrs) then
            kong.log.debug("We already requested all required acrs, avoid a loop")

            local message = {
                "The resource requires one of the [",
                table.concat(required_acrs, ";"),
                "] acr(s), you have [",
                table.concat(session.data:get_acrs()),
                "]"
            }
            return kong.response.exit(403, { message = table.concat(message)})
        end
    end

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

    session:start()
    local session_data = session.data
    -- by original_url session's field we distinguish enduser session previously redirected
    -- to OP for authentication
    session_data.original_url = ngx.var.request_uri
    session.data:set_requested_acrs(required_acrs)
    session:save()

    -- redirect to the /authorization endpoint
    ngx.header["Cache-Control"] = "no-cache, no-store, max-age=0"
    ngx.redirect(authorization_url)
end

local function request_authenticated(conf, session, id_token)
    local session_data = session.data
    local id_token_data = session_data.id_tokens[id_token]

    kong.ctx.shared.request_token = id_token
    kong.ctx.shared.request_token_data = id_token_data
    kong.ctx.shared.userinfo = session_data.userinfo

    local environment = {
        id_token = id_token_data,
        userinfo = session_data.userinfo
    }

    local access_token = session_data.access_tokens[id_token]
    if access_token then
        environment.access_token = access_token
    end

    local new_headers = kong_auth_pep_common.make_headers(conf.custom_headers, environment, id_token)
    kong.service.request.set_headers(new_headers)
    kong.ctx.shared.gluu_openid_connect_users_authenticated = true

end

return function(self, conf)
    -- open() check cookie exist and validate if any, but it doesn't modify cookie
    -- you need to call session:start() to really start the session
    local session = oidc_wrap(resty_session.open())

    local path = ngx.var.uri:match"^([^%s]+)"

    if path == conf.authorization_redirect_path then
        return authorization_response(conf, session, path)
    end

    if path == conf.logout_path then
        return process_logout(conf, session, path)
    end

    if path == conf.post_logout_redirect_path_or_url then
        kong.log.debug("Post logout Redirect path (", path, ") found, allow request")
        return
    end

    local required_acrs, no_auth
    local required_acrs_expression = conf.required_acrs_expression

    if required_acrs_expression then
        local method_path_tree = method_path_tree_cache(required_acrs_expression)
        local rule = path_wildcard_tree.matchPath(method_path_tree, ngx.req.get_method(), path)
        required_acrs = rule and rule.required_acrs
        no_auth = rule and rule.no_auth
    end

    if no_auth then
        kong.log.debug("path [", path, "] doesn't require authentication")
        local id_token
        if session.present then
            id_token = session.data:get_any_not_expired_id_token(conf)
        end
        if id_token then
            return request_authenticated(conf, session, id_token)
        end

        return -- allow, but request isn't authenticated
    end

    if not session.present then
        kong.log.debug("no session present")
        return authorize(conf, session, nil, required_acrs)
    end

    local session_data = session.data
    if not session_data.id_tokens then
        kong.log.debug("there is no id_tokens")
        return authorize(conf, session, nil, required_acrs)
    end

    if not required_acrs then
        kong.log.debug("any acrs match")
        -- it should be any id_token, because id_tokens present
        local id_token, expiration_type = assert(session_data:get_any_id_token(conf))

        if not expiration_type then
            return request_authenticated(conf, session, id_token)
        end

        kong.log.debug("expiration_type: ", expiration_type)
        local acrs = session_data:get_token_acrs(id_token)
        session_data:remove_token(id_token)

        if expiration_type == "token" then
            kong.log.debug("Authentication is required, token expired - Redirecting to OP Authorization endpoint")
            return authorize(conf, session, "none", acrs) -- request the same acrs
        end

        assert(expiration_type == "auth")
        kong.log.debug("Auth. expired, force relogin - Redirecting to OP Authorization endpoint")
        return authorize(conf, session, "login", acrs) -- request the same acrs
    end

    local id_token, expiration_type = session_data:find_id_token_with_enough_acrs(conf, required_acrs)
    if not id_token then
        kong.log.debug("Authentication is required, not enough acr - Redirecting to OP Authorization endpoint")
        return authorize(conf, session, "login", required_acrs)
    end

    if not expiration_type then
        return request_authenticated(conf, session, id_token)
    end

    kong.log.debug("expiration_type: ", expiration_type)
    if expiration_type == "token" then
        kong.log.debug("Authentication is required, token expired - Redirecting to OP Authorization endpoint")
        return authorize(conf, session, "none", required_acrs) -- request the same acrs
    end

    assert(expiration_type == "auth")
    kong.log.debug("Auth. expired, force relogin - Redirecting to OP Authorization endpoint")
    return authorize(conf, session, "login", required_acrs) -- request the same acrs
end
