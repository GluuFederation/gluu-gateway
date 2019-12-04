#!/usr/bin/env bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HOST_GIT_ROOT="$DIR/.."
cd $HOST_GIT_ROOT

git submodule update --init --recursive

TMP_DIR=$(mktemp -d -t luadeps-$(date +%Y-%m-%d-%H-%M-%S)-XXXXXXXXXX)

# gluu modules and plugins
cp -R kong/common ${TMP_DIR}/gluu/
mkdir -p ${TMP_DIR}/kong/plugins/
cp -R kong/plugins ${TMP_DIR}/kong/
cp third-party/oxd-web-lua/oxdweb.lua ${TMP_DIR}/gluu/

#third-party deps
mkdir -p ${TMP_DIR}/rucciva
cp third-party/json-logic-lua/logic.lua ${TMP_DIR}/rucciva/json_logic.lua
cp -R third-party/lua-resty-lrucache/lib/resty/ ${TMP_DIR}/
cp -R third-party/lua-resty-session/lib/resty/ ${TMP_DIR}/
cp -R third-party/lua-resty-jwt/lib/resty/ ${TMP_DIR}/
cp -R third-party/lua-resty-hmac/lib/resty/ ${TMP_DIR}/
cp -R third-party/nginx-lua-prometheus/prometheus.lua ${TMP_DIR}/

cd ${TMP_DIR}

tar -czvf $HOST_GIT_ROOT/gluu-gateway-lua-deps.tag.gz *

cd $HOST_GIT_ROOT
rm -rf ${TMP_DIR}

#git add gluu-gateway-lua-deps.tag.gz
#git commit -m "Archive lua libs and plugins"
#git push origin $(git symbolic-ref --short HEAD)
