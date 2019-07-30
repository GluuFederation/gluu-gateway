local JSON = require"JSON"

-- Initialize the pseudo random number generator
-- Resource: http://lua-users.org/wiki/MathLibraryTutorial
math.randomseed(os.time())
math.random(); math.random(); math.random()

-- Shuffle array
-- Returns a randomly shuffled array
function shuffle(paths)
    local j, k
    local n = #paths

    for i = 1, n do
        j, k = math.random(n), math.random(n)
        paths[j], paths[k] = paths[k], paths[j]
    end

    return paths
end

-- Load URL paths from the JSON file
-- must be an array of elements describing the next request,
-- in the order: method, path [,body]
--[[
{
    "requests" : [
        ["GET", "/", ],
        ["POST", "/"],
    ]
    "tokens" : [
        "xxxxxxxxx", -- base64 encoded json with token data (scope and client_id must be present)
        "xxxxxxxxx",
        "xxxxxxxxxxxx",
    ]
}
]]
local function load_data_from_json_file(file)
    local f = io.open(file, "r")
    if f == nil then
        return
    end

    local content = f:read("*all")
    io.close(f)

    return JSON:decode(content)
end

local counter = 1
local authorization_prefix = "Bearer "
local headers = {  Host = "backend.com" }

local git_root = os.getenv"GIT_ROOT"
local config = assert(load_data_from_json_file(git_root .. "/kong/perf/config.json"))

-- TODO do we need to shufle? maybe the reproducable test is the best?!
local requests = shuffle(config.requests)

local tokens = config.tokens

local EXPIRES_IN = 60
local EXPIRE_OUT = 1 -- secods while wrk will send expired tokens
local exp = os.time() + EXPIRES_IN


request = function()
    if counter > #requests then
        counter = 1
    end

    local timestamp = os.time()
    if timestamp > exp + EXPIRE_OUT then
        exp = os.time() + EXPIRES_IN
        print"update timestamp"
    end

    local req = requests[counter]
    local token_ind = math.random(#tokens)

    headers.Authorization = table.concat{
        authorization_prefix,
        tokens[token_ind],
        "-",
        tostring(timestamp + EXPIRES_IN),
    }

    counter = counter + 1
    return wrk.format(req[1], req[2], headers, req[3] )
end

delay = function()
    return 100
end




