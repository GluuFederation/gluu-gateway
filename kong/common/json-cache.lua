local lrucache = require "resty.lrucache.pureffi"
local cjson = require "cjson.safe"

local EXPIRE_IN = 60 * 60

-- it is shared by all the requests served by each nginx worker process:
local worker_cache, err = lrucache.new(1000) -- allow up to 1000 items in the cache
if not worker_cache then
    return error("failed to create the cache: " .. (err or "unknown"))
end

return function(key, value, do_decode_value)
    local data, stale_data = worker_cache:get(key)
    if data and not stale_data then
        return data
    end

    local data, err
    if do_decode_value then
        data, err = cjson.decode(value)
        if err then
            return nil, "Cannot parse JSON: ".. err
        end
    else
        data = value
    end

    worker_cache:set(key, data, EXPIRE_IN)

    return data
end
