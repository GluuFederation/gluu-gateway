local resolver = require "resty.dns.resolver"
local cjson = require "cjson.safe"
local http = require "resty.http"

return function(self, conf)
    if ngx.worker.id() ~= 0 then
        return
    end

    if ngx.now() - self.last_check >= conf.check_ip_time then
        kong.log.debug("Last checking ", ngx.now() - self.last_check, " Current Time ", ngx.now())

        -- fetch ip
        local r, err = resolver:new {
            nameservers = { "8.8.8.8" },
            retrans = 5, -- 5 retransmissions on receive timeout
            timeout = 2000, -- 2 sec
        }

        if not r then
            kong.log.error("failed to instantiate the resolver: ", err)
            kong.response.exit(502, { message = "An unexpected error ocurred" })
        end

        local answers, err, tries = r:query(conf.gluu_prometheus_server_host, nil, {})

        if not answers then
            kong.log.err("failed to query the DNS server: ", err)
            kong.log.err("retry historie:\n  ", table.concat(tries, "\n  "))
            return
        end

        if answers.errcode then
            self.last_check = ngx.now()
            kong.log.err(self, "failed to query the DNS server: ", err, "retry historie:\n  ", table.concat(tries, "\n  "), self, "server returned error code: ", answers.errcode,
                ": ", answers.errstr)
            return -- Todo: return what? 502 or just allow because we don't need to stop customer kong when our license server is off
        end

        local found_answer = answers[1]
        if not (found_answer and (found_answer.address or found_answer.cname)) then
            self.last_check = ngx.now()
            kong.log.err("Failed to get ip address")
            return -- Todo: return what? 502 or just allow because we don't need to stop customer kong when our license server is off
        end

        local found_ip = found_answer.address or found_answer.cname
        if self.server_ip_address == found_ip then
            kong.log.debug("No change in IP ", found_ip, ", No need to update ip plugin")
            return
        end

        self.server_ip_address = found_ip
        kong.log.debug("IP Found ", self.server_ip_address)

        -- updating ip in ip restrict plugin
        local cjson2 = cjson.new()
        local body_json, err = cjson2.encode {
            config = {
                whitelist = { found_ip }
            }
        }

        kong.log.debug(body_json)

        local httpc = http.new()
        local plugin_endpoint = table.concat({
            conf.kong_admin_url,
            '/plugins/',
            conf.ip_restrict_plugin_id,
        })
        local res, err = httpc:request_uri(plugin_endpoint,
            {
                method = "PATCH",
                body = body_json,
                headers = {
                    ["Content-Type"] = "application/json",
                }
            })

        if not res then
            kong.log.err("resty-http error: ", err)
            kong.response.exit(502)
        end

        local status = res.status
        if status ~= 200 then
            kong.log.err("update plugin responds with status: ", status)
            kong.response.exit(502)
        end

        self.last_check = ngx.now()
    end
end
