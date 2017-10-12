package = "kong-uma-rs"
version = "1.0-0"
source = {
  url = "https://ox.gluu.org/luarocks/kong-uma-rs.1.0-0.zip"
}
description = {
  summary = "kong uma rs",
  detailed = [[
    Kong plugin that allows you to protect your API (which is proxied by Kong) with the UMA OAuth-based access management protocol.
  ]],
  homepage = "https://github.com/GluuFederation/kong-plugins/tree/master/kong-uma-rs",
  license = "MIT"
}
dependencies = {
  "lua >= 5.1"
}
build = {
  type = "builtin",
  modules = {
    ["kong.plugins.kong-uma-rs.access"] = "access.lua",
    ["kong.plugins.kong-uma-rs.common"] = "common.lua",
    ["kong.plugins.kong-uma-rs.handler"] = "handler.lua",
    ["kong.plugins.kong-uma-rs.helper"] = "helper.lua",
    ["kong.plugins.kong-uma-rs.schema"] = "schema.lua"
  }
}
