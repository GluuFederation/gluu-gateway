local _M = {}

function _M.execute(conf)
  ngx.log(ngx.DEBUG, "KONG-UMA: access, conf: " .. conf.oxd_host)
  ngx.log(ngx.DEBUG, "KONG-UMA: access, conf: " .. conf.oxd_port)
  ngx.log(ngx.DEBUG, "KONG-UMA: access, conf: " .. conf.uma_server_host)
  ngx.log(ngx.DEBUG, "KONG-UMA: access, conf: " .. conf.protection_document)


end

return _M

