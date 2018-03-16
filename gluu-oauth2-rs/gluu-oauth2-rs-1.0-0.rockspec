package = "gluu-oauth2-rs"
version = "1.0-0"
source = {
  url = "https://ox.gluu.org/luarocks/gluu-oauth2-rs.1.0-0.zip"
}
description = {
  summary = "Gluu OAuth2 RS",
  detailed = [[
    Kong plugin that allows you to protect your API (which is proxied by Kong) with the UMA OAuth-based access management protocol.
  ]],
  homepage = "https://github.com/GluuFederation/kong-plugins/tree/master/gluu-oauth2-rs",
  license = "MIT"
}
dependencies = {
  "lua >= 5.1"
}
build = {
  type = "builtin",
  modules = {
    ["kong.plugins.gluu-oauth2-rs.access"] = "access.lua",
    ["kong.plugins.gluu-oauth2-rs.handler"] = "handler.lua",
    ["kong.plugins.gluu-oauth2-rs.helper"] = "helper.lua",
    ["kong.plugins.gluu-oauth2-rs.schema"] = "schema.lua"
  }
}
