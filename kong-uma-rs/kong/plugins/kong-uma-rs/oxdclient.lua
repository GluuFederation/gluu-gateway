local socket = require("socket")


local function commandWithLengthPrefix(json)
  local lengthPrefix = "" .. json:len();

  while lengthPrefix:len() ~= 4 do
    lengthPrefix = "0" .. lengthPrefix
  end

  return lengthPrefix .. json
end

local _M = {}

function _M.execute(conf)
  ngx.log(ngx.DEBUG, "oxd_host: " .. conf.oxd_host .. ", oxd_port: " .. conf.oxd_port)
  ngx.log(ngx.DEBUG, "uma_server_host: " .. conf.uma_server_host .. ", protection_document: " .. conf.protection_document)

  local host = socket.dns.toip(conf.oxd_host)
  ngx.log(ngx.DEBUG, "host: " .. host)

  local client = socket.connect(host, conf.oxd_port);

--  local commandAsJson = ""command":"register_site","params":{"scope":["openid","uma_protection","uma_authorization"],"contacts":null,"op_host":"https://ce-dev2.gluu.org","authorization_redirect_uri":"https://client.example.com/cb","post_logout_redirect_uri":"https://client.example.com/logout","redirect_uris":null,"response_types":null,"client_id":null,"client_secret":null,"client_name":null,"client_jwks_uri":null,"client_token_endpoint_auth_method":null,"client_request_uris":null,"client_logout_uris":["https://client.example.com/cb/logout"],"client_sector_identifier_uri":null,"ui_locales":null,"claims_locales":null,"acr_values":null,"grant_types":null}}";
  local commandAsJson = "{\"command\":\"register_site_from_kong\"}"
  ngx.log(ngx.DEBUG, "oxd - commandAsJson: " .. commandAsJson)

  local commandWithLengthPrefix = commandWithLengthPrefix(commandAsJson);

  client:settimeout(1)
  assert(client:send(commandWithLengthPrefix))
  local responseLength = client:receive("4")

  ngx.log(ngx.DEBUG, "responseLength: " .. responseLength)

  local response = client:receive(tonumber(responseLength))
  ngx.log(ngx.DEBUG, "response: " .. response)

  client:close();
  ngx.log(ngx.DEBUG, "finished.")


end

return _M
