local oxd = require "gluu.oxdweb"
local resty_session = require("resty.session")
local kong_auth_pep_common = require "gluu.kong-auth-pep-common"

local function access_token_expires_in(conf, exp)
    local max_id_token_age = conf.max_id_token_age
    return max_id_token_age < exp and max_id_token_age or exp
end

local function unexpected_error()
    kong.response.exit(502, { message = "An unexpected error ocurred" })
end

local function process_logout(conf, session)
    local session_token = session.data.enc_id_token
    session:destroy()

    -- TODO get rid of self parameter of get_protection_token(), make it as separate commit
    local ptoken = kong_auth_pep_common.get_protection_token(nil, conf)

    local response, err = oxd.get_logout_uri(conf.oxd_url,
        {
            oxd_id = conf.oxd_id,
            id_token_hint = session_token,
            post_logout_redirect_uri = conf.post_logout_redirect_uri,
        },
        ptoken)

    if err then
        kong.log.err(err)
        return unexpected_error()
    end

    local status, json = response.status, response.body

    if status ~= 200 then
        kong.log.err("get_tokens_by_code() responds with status ", status)
        return kong.response.exit(502)
    end

    ngx.header["Cache-Control"] = "no-cache, no-store, max-age=0"
    return ngx.redirect(json.uri)
end

-- handle a "code" authorization response from the OP
local function authorization_response(self, conf, session)
    local args = ngx.req.get_uri_args()

    local code, state = args.code, args.state
    if not code or not state then
        kong.log.warn("missed code or state argument(s)")
        return kong.response.exit(400, {message = "missed code or state argument(s)"})
    end

    kong.log.debug("Authentication with OP done -> Calling OP Token Endpoint to obtain tokens")

    local ptoken = kong_auth_pep_common.get_protection_token(nil, conf)

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

    session_data.enc_id_token = json.id_token
    session_data.id_token = id_token

    session_data.access_token = json.access_token
    session_data.access_token_expiration = ngx.time() + access_token_expires_in(conf, json.expires_in)
    session_data.refresh_token = json.refresh_token

    local ptoken = kong_auth_pep_common.get_protection_token(nil, conf)

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

    session.data.userinfo = json.claims
    session:save()

    -- redirect to the URL that was accessed originally
    kong.log.debug("OIDC Authorization Code Flow completed -> Redirecting to original URL (", original_url, ")")
    ngx.redirect(original_url)
end

local function refresh_access_token(conf, session)
    local current_time = ngx.time()
    local session_data = session.data
    if current_time < session_data.access_token_expiration then
        return true
    end

    if not session_data.refresh_token then
        kong.log.debug("token expired and no refresh token available")
        return
    end

    kong.log.debug("refreshing expired access_token: ", session_data.access_token, " with: ", session_data.refresh_token)

    local ptoken = kong_auth_pep_common.get_protection_token(nil, conf)

    local response, err = oxd.get_access_token_by_refresh_token(conf.oxd_url,
        {
            oxd_id = conf.oxd_id,
            refresh_token = session_data.refresh_token,
        },
        ptoken)

    if err then
        kong.log.err(err)
        return unexpected_error()
    end

    local status, json = response.status, response.body

    if status ~= 200 then
        kong.log.err("get_access_token_by_refresh_token() responds with status ", status)
        return unexpected_error()
    end

    kong.log.debug("access_token refreshed: ", json.access_token, " updated refresh_token: ", json.refresh_token)

    session_data.access_token = json.access_token
    session_data.access_token_expiration = current_time + access_token_expires_in(conf, json.expires_in)
    session_data.refresh_token = json.refresh_token

    -- save the session with the new access_token and optionally the new refresh_token and id_token
    session:save()

    return true
end

-- send the browser of to the OP's authorization endpoint
local function authorize(conf, session, prompt)

    local ptoken = kong_auth_pep_common.get_protection_token(nil, conf)

    local response, err = oxd.get_authorization_url(conf.oxd_url,
        {
            oxd_id = conf.oxd_id,
            prompt = prompt,
            scope = conf.requested_scopes,
            acr_values = conf.required_acrs,
            custom_parameters = {
                max_age = conf.max_id_token_auth_age,
            }
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

    if not json.authorization_url then
        kong.log.err("get_authorization_url() missed authorization_url")
        return unexpected_error()
    end

    local session_data = session.data
    -- by original_url session's field we distinguish enduser session previously redirected
    -- to OP for authentication
    session_data.original_url = ngx.var.request_uri
    session:save()

    -- redirect to the /authorization endpoint
    ngx.header["Cache-Control"] = "no-cache, no-store, max-age=0"
    ngx.redirect(json.authorization_url)
end


return function(self, conf)
    local err

    local session = resty_session.start()
    local session_data = session.data

    -- see if this is a request to the redirect_uri i.e. an authorization response
    local path = ngx.var.uri
    if path == conf.authorization_redirect_path then
        kong.log.debug("Redirect URI path (", path, ") is currently navigated -> Processing authorization response coming from OP")

        if not session.present then
            kong.log.err("request to the authorization response path but there's no session state found")
            return kong.response.exit(400)
        end

        return authorization_response(self, conf, session)
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

    local token_expired = false
    if session.present and session_data.id_token then
        -- refresh access_token if necessary
        if not refresh_access_token(conf, session) then
            token_expired = true
        end
    end

    local id_token = session_data.id_token
    kong.log.debug(
        "session.present=", session.present,
        ", session.data.id_token=", id_token ~= nil,
        ", token_expired=", token_expired)

    if not session.present
            or not id_token
            or token_expired
            or (id_token.auth_time and (id_token.auth_time + conf.max_id_token_auth_age) < ngx.time()) then
        kong.log.debug("Authentication is required - Redirecting to OP Authorization endpoint")
        return authorize(conf, session)
    end

    if (id_token.iat + conf.max_id_token_auth_age) < ngx.time() or
            id_token.exp < ngx.time() then
        kong.log.debug("Silent authentication is required - Redirecting to OP Authorization endpoint")
        return authorize(conf, session, "none")
    end

    kong.ctx.shared.id_token = id_token
    kong.ctx.shared.userinfo = session_data.userinfo

    -- TODO set headers
end


