local function protection_document_validator(given_value, given_config)
  ngx.log(ngx.DEBUG, "KONG-UMA: given_value:" .. given_value)
  -- todo
  return true
end

return {
  no_consumer = true,
  fields = {
    protection_document = { required = true, type = "string", func = protection_document_validator },
  },
  self_check = function(schema, plugin_t, dao, is_updating)
    return true
  end
}