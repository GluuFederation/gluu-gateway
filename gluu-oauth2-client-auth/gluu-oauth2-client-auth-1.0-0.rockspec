package = "gluu-oauth2-client-auth"
version = "1.0-0"
source = {
  url = "https://ox.gluu.org/luarocks/gluu-oauth2-client-auth.1.0-0.zip"
}
description = {
  summary = "Gluu OAuth 2.0 client authentication",
  detailed = [[
    Kong plugin that allows you to protect your API (which is proxied by Kong) with the Gluu OAuth 2.0 back channel client authentication.
  ]],
  homepage = "https://github.com/GluuFederation/gluu-gateway/tree/master/gluu-oauth2-client-auth",
  license = "MIT"
}
dependencies = {
  "lua >= 5.1"
}
build = {
  type = "builtin",
  modules = {
    ["kong.plugins.gluu-oauth2-client-auth.access"] = "access.lua",
    ["kong.plugins.gluu-oauth2-client-auth.api"] = "api.lua",
    ["kong.plugins.gluu-oauth2-client-auth.daos"] = "daos.lua",
    ["kong.plugins.gluu-oauth2-client-auth.handler"] = "handler.lua",
    ["kong.plugins.gluu-oauth2-client-auth.helper"] = "helper.lua",
    ["kong.plugins.gluu-oauth2-client-auth.schema"] = "schema.lua",
    ["kong.plugins.gluu-oauth2-client-auth.migrations.cassandra"] = "migrations/cassandra.lua",
    ["kong.plugins.gluu-oauth2-client-auth.migrations.postgres"] = "migrations/postgres.lua"
  }
}
