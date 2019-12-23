local lrucache = require "resty.lrucache.pureffi"

local EXPIRE_IN = 60 * 60

-- it is shared by all the requests served by each nginx worker process:
local worker_cache, err = lrucache.new(1000) -- Todo: is it ok to set limit 1000?
if not worker_cache then
    return error("failed to create the cache: " .. (err or "unknown"))
end

return function(key ,value)
    local data, stale_data = worker_cache:get(key)
    if data and not stale_data then
        return data
    end

    worker_cache:set(key, value, EXPIRE_IN)
    return value
end
