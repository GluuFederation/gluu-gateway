return {
  fields = {
    ip_restrict_plugin_id = { required = true, type = "string" },
    kong_admin_url = { required = true, type = "url", default = "http://localhost:8001" },
    check_ip_time = { required = true, type = "timestamp", default = 86400 }, -- seconds, default 24 hr
  },
  self_check = function(schema, plugin_t, dao, is_update)
    if not ngx.shared.gluu_metrics then
      return false, "ngx shared dict 'gluu_metrics' not found"
    end
    return true
  end,
}
