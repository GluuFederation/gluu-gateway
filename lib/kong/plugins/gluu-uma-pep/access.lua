local pl_tablex = require "pl.tablex"
local oxd = require "gluu.oxdweb"
local resty_session = require("resty.session")

local kong_auth_pep_common = require"gluu.kong-common"
local path_wildcard_tree = require"gluu.path-wildcard-tree"

local unexpected_error = kong_auth_pep_common.unexpected_error

-- call /uma-rs-check-access oxd API, handle errors
local function try_check_access(conf, path, method, token, access_token)
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
            return unexpected_error("uma_rs_check_access() missed access")
        end
        if body.access == "granted" then
            return body
        elseif body.access == "denied" then
            if token == "" and not body["www-authenticate_header"] then
                return unexpected_error("uma_rs_check_access() access == denied, but missing www-authenticate_header")
            end
            kong.ctx.shared.gluu_uma_ticket = body.ticket
            return body
        end
        return unexpected_error("uma_rs_check_access() unexpected access value: ", body.access)
    end
    if status == 400 then
        return unexpected_error("uma_rs_check_access() responds with status 400 - Invalid parameters are provided to endpoint")
    elseif status == 500 then
        return unexpected_error("uma_rs_check_access() responds with status 500 - Internal error occured. Please check oxd-server.log file for details")
    elseif status == 403 then
        return unexpected_error("uma_rs_check_access() responds with status 403 - Invalid access token provided in Authorization header")
    end
    return unexpected_error("uma_rs_check_access() responds with unexpected status: ", status)
end

local hooks = {}

local function redirect_to_claim_url(conf, ticket)
    local ptoken = kong_auth_pep_common.get_protection_token(conf)
    local claims_redirect_uri = kong_auth_pep_common.get_path_with_base_url(conf.claims_redirect_path)
    local response, err = oxd.uma_rp_get_claims_gathering_url(conf.oxd_url,
        {
            oxd_id = conf.oxd_id,
            ticket = ticket,
            claims_redirect_uri = claims_redirect_uri
        },
        ptoken)

    if err then
        kong.log.err(err)
        return unexpected_error()
    end

    local status, json = response.status, response.body

    if status ~= 200 then
        kong.log.err("uma_rp_get_claims_gathering_url() responds with status ", status)
        return unexpected_error()
    end

    if not json.url then
        kong.log.err("uma_rp_get_claims_gathering_url() missed url")
        return unexpected_error()
    end

    local session = resty_session.start()
    local session_data = session.data
    -- by uma_original_url session's field we distinguish enduser session previously redirected
    -- to OP for authorization
    session_data.uma_original_url = ngx.var.request_uri
    session:save()

    -- redirect to the /uma/gather_claims url endpoint
    ngx.header["Cache-Control"] = "no-cache, no-store, max-age=0"
    ngx.redirect(json.url)
end

-- call /uma_rp_get_rpt oxd API, handle errors
local function get_rpt_by_ticket(self, conf, ticket, state, id_token, userinfo)
    local ptoken = kong_auth_pep_common.get_protection_token(conf)

    local requestBody = {
        oxd_id = conf.oxd_id,
        ticket = ticket
    }

    if state then
        requestBody.state = state
    end

    local pushed_claims_lua_exp = conf.pushed_claims_lua_exp
    if conf.pushed_claims_lua_exp then
        -- TODO use a cache here to avoid Lua code parsing/compiling upon every request
        local chunk_text = "return " .. pushed_claims_lua_exp

        -- we rely here on schema validation, it should check for valid Lua syntax
        local chunk = assert(loadstring(chunk_text))

        local environment = {
            id_token = id_token,
            userinfo = userinfo,
            request = kong.request,
        }
        setfenv(chunk, environment)
        local ok, value = pcall(chunk)
        if not ok then
            kong.log.notice("Failed to populate value for custom UMA pushed claims, Lua error: ", value)
            value = nil
        end

        local jwt = kong_auth_pep_common.make_jwt_alg_none(value)

        requestBody.claim_token = jwt
        requestBody.claim_token_format = "http://openid.net/specs/openid-connect-core-1_0.html#IDToken"
    end

    local response = oxd.uma_rp_get_rpt(conf.oxd_url,
        requestBody,
        ptoken)
    local status = response.status
    local body = response.body

    if status ~= 200 then
        if conf.redirect_claim_gathering_url and status == 403 and body.error and body.error == "need_info" then
            kong.log.debug("Starting claim gathering flow")
            redirect_to_claim_url(conf, body.ticket)
        end

        return unexpected_error("Failed to get RPT token")
    end

    return body.access_token
end

function hooks.no_token_protected_path(self, conf, protected_path, method)
    if conf.require_id_token then
        return unexpected_error("Expect id_token")
    end

    local ptoken = kong_auth_pep_common.get_protection_token(conf)

    local check_access_no_rpt_response = try_check_access(conf, protected_path, method, nil, ptoken)

    if check_access_no_rpt_response.access == "denied" then
        kong.log.debug("Set WWW-Authenticate header with ticket")
        return kong.response.exit(401,
            { message = "Unauthorized" },
            { ["WWW-Authenticate"] = check_access_no_rpt_response["www-authenticate_header"]}
        )
    end
    return unexpected_error("check_access without RPT token, responds with access == \"granted\"")
end

local function get_ticket(self, conf, protected_path, method)
    local ptoken = kong_auth_pep_common.get_protection_token(conf)

    local check_access_no_rpt_response = try_check_access(conf, protected_path, method, nil, ptoken)

    if check_access_no_rpt_response.access == "denied" and check_access_no_rpt_response.ticket then
        return check_access_no_rpt_response.ticket
    end
    return unexpected_error("check_access without RPT token, responds without ticket")
end

function hooks.build_cache_key(method, path, token)
    path = path or ""
    local t = {
        method,
        ":",
        path,
        ":",
        token
    }
    return table.concat(t), true
end

function hooks.is_access_granted(self, conf, protected_path, method, _, _, rpt)
    if conf.obtain_rpt then
        local session = resty_session.start()

        local ticket, state
        if session.present then
            local session_data = session.data
            ticket, state = session_data.uma_ticket, session_data.uma_state
            if ticket and state then
                session_data.uma_state = nil
                session_data.uma_ticket = nil
                session:save()
            end
        end

        if not ticket then
            ticket = get_ticket(self, conf, protected_path, method)
        end

        local id_token = kong.ctx.shared.request_token_data
        local userinfo = kong.ctx.shared.userinfo
        rpt =  get_rpt_by_ticket(self, conf, ticket, state, id_token, userinfo)
    end
    local ptoken = kong_auth_pep_common.get_protection_token(conf)

    local check_access_response = try_check_access(conf, protected_path, method, rpt, ptoken)

    return check_access_response.access == "granted"
end

function hooks.get_scope_expression(config)
    return config.uma_scope_expression
end

return function(self, conf)
    local path = ngx.var.uri:match"^([^%s]+)"
    if conf.redirect_claim_gathering_url and path == conf.claims_redirect_path then
        kong.log.debug("Claim Redirect URI path (", path, ") is currently navigated -> Processing ticket response coming from OP")

        local session = resty_session.start()

        if not session.present then
            kong.log.warn("request to the claim redirect response path but there's no session state found")
            return kong.response.exit(400)
        end

        local session_data = session.data
        local uma_original_url = session_data.uma_original_url
        if not uma_original_url then
            kong.log.warn("request to the claim redirect response path but there's no uma_original_url found")
            return kong.response.exit(400)
        end

        local args = ngx.req.get_uri_args()
        local ticket, state = args.ticket, args.state
        if not ticket or not state then
            kong.log.warn("missed ticket or state argument(s)")
            return kong.response.exit(400, {message = "missed ticket or state argument(s)"})
        end
        session_data.uma_original_url = nil
        session_data.uma_ticket = ticket
        session_data.uma_state = state

        -- TODO should be there PCT?
        -- session_data.uma-pct = pct
        session:save()

        kong.log.debug("Got RPT and Claim flow completed -> Redirecting to original URL (", uma_original_url, ")")
        kong.ctx.shared[self.metric_client_granted] = true
        ngx.redirect(uma_original_url)
    end

    kong_auth_pep_common.access_pep_handler(self, conf, hooks)
end
