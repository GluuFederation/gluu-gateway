package = "kong-uma-rs"
version = "1.0-0"
source = {
  url = "git://https://ox.gluu.org/luarocks/kong-uma-rs.1.0-0.zip"
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
    access = "access.lua",
    common = "common.lua",
    handler = "handler.lua",
    helper = "helper.lua",
    schema = "schema.lua"
  }
}
