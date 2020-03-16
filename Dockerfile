FROM kong:2.0.0-alpine

ARG LUA_DIST=/usr/local/share/lua/5.1
ARG DISABLED_PLUGINS="ldap-auth key-auth basic-auth hmac-auth jwt oauth2"

# ============
# Gluu Gateway
# ============


# otherwise we cannot replace/remove existing files
USER root

COPY lib/ ${LUA_DIST}/

RUN for plugin in ${DISABLED_PLUGINS}; do \
  cp ${LUA_DIST}/gluu/disable-plugin-handler.lua ${LUA_DIST}/kong/plugins/${plugin}/handler.lua; \
  rm -f ${LUA_DIST}/kong/plugins/${plugin}/migrations/*; \
  rm -f ${LUA_DIST}/kong/plugins/${plugin}/daos.lua; \
  done && \
  rm ${LUA_DIST}/gluu/disable-plugin-handler.lua

#copy Lua deps

COPY third-party/lua-resty-hmac/lib/ ${LUA_DIST}/
COPY third-party/lua-resty-jwt/lib/ ${LUA_DIST}/
COPY third-party/lua-resty-lrucache/lib/ ${LUA_DIST}/
COPY third-party/lua-resty-session/lib/ ${LUA_DIST}/
COPY third-party/json-logic-lua/logic.lua ${LUA_DIST}/rucciva/json_logic.lua
COPY third-party/oxd-web-lua/oxdweb.lua ${LUA_DIST}/gluu/
COPY third-party/nginx-lua-prometheus/prometheus.lua ${LUA_DIST}/


# restore
USER kong

# ===
# ENV
# ===

# by default enable all bundled and gluu plugins
ENV KONG_PLUGINS bundled,gluu-oauth-auth,gluu-uma-auth,gluu-uma-pep,gluu-oauth-pep,gluu-metrics,gluu-openid-connect,gluu-opa-pep
# required in kong.conf
ENV KONG_NGINX_HTTP_LUA_SHARED_DICT "gluu_metrics 1m"
#redirect all logs to Docker
ENV KONG_PROXY_ACCESS_LOG /dev/stdout
ENV KONG_ADMIN_ACCESS_LOG /dev/stdout
ENV KONG_PROXY_ERROR_LOG /dev/stderr
ENV KONG_ADMIN_ERROR_LOG /dev/stderr
ENV KONG_NGINX_HTTP_LARGE_CLIENT_HEADER_BUFFERS "8 16k"
