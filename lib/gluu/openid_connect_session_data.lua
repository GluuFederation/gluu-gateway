-- this module encapsulates gluu-openid-connect user session data
-- it provides public interface to operate with complex internals

local kong_auth_pep_common = require "gluu.kong-common"

local function is_token_expired(id_token_data, conf)
    return (id_token_data.iat + conf.max_id_token_age) <= ngx.time() or id_token_data.exp <= ngx.time()
end

local function is_token_auth_expired(id_token_data, conf)
    if not id_token_data.auth_time then
        return false
    end

    return (id_token_data.auth_time + conf.max_id_token_auth_age) <= ngx.time()
end

local mt = {}
mt.__index = mt

mt.has_any_id_token = function(self)
    return self.id_tokens
end

-- @return id_token, expiration_type
mt.get_any_id_token = function(self, conf)
    local id_tokens = self.id_tokens
    if not id_tokens then
        return
    end

    local id_token_expired_with_active_auth
    local is_token_expired_auth

    -- find any active
    for id_token, id_token_data in pairs(id_tokens) do
        if not is_token_expired(id_token_data, conf) and not is_token_auth_expired(id_token_data, conf) then
            return id_token
        end
    end

    -- find expired, but with active auth
    for id_token, id_token_data in pairs(id_tokens) do
        if not id_token_expired_with_active_auth and is_token_expired(id_token_data, conf)
                and not is_token_auth_expired(id_token_data, conf) then
            id_token_expired_with_active_auth = id_token
        end
    end

    -- find any with expired auth
    for id_token, id_token_data in pairs(id_tokens) do
        if not is_token_expired_auth and is_token_auth_expired(id_token_data, conf) then
            is_token_expired_auth = id_token
        end
    end

    if id_token_expired_with_active_auth then
        return id_token_expired_with_active_auth, "token"
    end

    if is_token_expired_auth then
        return is_token_expired_auth, "auth"
    end

    -- we cannot be here
    assert(false)
end

mt.get_any_not_expired_id_token = function(self, conf)
    local id_tokens = self.id_tokens
    if not id_tokens then
        return
    end

    -- find any active
    for id_token, id_token_data in pairs(id_tokens) do
        if (id_token_data.iat + conf.max_id_token_age) > ngx.time() and id_token_data.exp > ngx.time() then
            return id_token
        end
    end
end

-- id_token should exist
mt.get_token_acrs = function(self, id_token)
    local t = {}
    local id_tokens = assert(self.id_tokens)
    local id_token_data = assert(id_tokens[id_token])

    return id_token_data.acrs
end

mt.remove_token = function(self, id_token)
    self.id_tokens[id_token] = nil

    for token, token_data in pairs(self.id_tokens) do
        -- at least one id_token exist
        return
    end

    -- no id_tokens
    self.id_tokens = nil
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

-- @return id_token, expiration_type
mt.find_id_token_with_enough_acrs = function(self, conf, required_acrs)
    local id_tokens = assert(self.id_tokens)

    local id_token_expired_with_active_auth
    local is_token_expired_auth
    -- find any active
    for id_token, id_token_data in pairs(id_tokens) do
        local acr = id_token_data.acr

        if acr and  is_acr_enough(required_acrs, acr) then
            if not is_token_expired(id_token_data, conf) and not is_token_auth_expired(id_token_data, conf) then
                return id_token
            end
        end

        -- find expired, but with active auth
        if not id_token_expired_with_active_auth and acr and  is_acr_enough(required_acrs, acr) then
            if is_token_expired(id_token_data, conf) and not is_token_auth_expired(id_token_data, conf) then
                id_token_expired_with_active_auth = id_token
            end
        end

        -- find any with expired auth
        if not is_token_expired_auth and acr and  is_acr_enough(required_acrs, acr) then
            if is_token_auth_expired(id_token_data, conf) then
                is_token_expired_auth = id_token
            end
        end

    end

    if id_token_expired_with_active_auth then
        return id_token_expired_with_active_auth, "token"
    end

    if is_token_expired_auth then
        return is_token_expired_auth, "auth"
    end
end

-- session should be started
mt.set_requested_acrs = function(self, required_acrs)
    if not required_acrs or #required_acrs == 0 then
        self.requested_acrs = nil
        return
    end

    self.requested_acrs = {}
    local requested_acrs = self.requested_acrs
    for i = 1, #required_acrs do
        requested_acrs[required_acrs[i]] = true
    end
end

mt.acr_already_requested = function(self, required_acrs)
    assert(required_acrs and #required_acrs > 0)
    local id_tokens = self.id_tokens
    if not id_tokens then
        return false
    end

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

mt.get_acrs = function(self)
    local id_tokens = self.id_tokens
    local t = {}
    for k, v in pairs(id_tokens) do
        t[#t + 1] = v.acr
    end
    return t
end

local _M = {}

_M.wrap = function(session)
    setmetatable(session.data, mt)
    return session
end

return _M
