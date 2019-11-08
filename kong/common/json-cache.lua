local lrucache = require "resty.lrucache.pureffi"
local cjson = require "cjson.safe"

local EXPIRE_IN = 60 * 60

-- it is shared by all the requests served by each nginx worker process:
local worker_cache, err = lrucache.new(1000) -- allow up to 1000 items in the cache
if not worker_cache then
    return error("failed to create the cache: " .. (err or "unknown"))
end

return function(json_text)
    local data, stale_data = worker_cache:get(json_text)
    if data and not stale_data then
        return data
    end

    local data, err = cjson.decode(json_text)
    if err then
        return nil, "Cannot parse JSON: ".. err
    end

    worker_cache:set(json_text, data, EXPIRE_IN)

    return data
end
