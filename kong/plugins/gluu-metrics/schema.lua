return {
  fields = {},
  self_check = function(schema, plugin_t, dao, is_update)
    if not ngx.shared.gluu_metrics then
      return false, "ngx shared dict 'gluu_metrics' not found"
    end
    return true
  end,
}
