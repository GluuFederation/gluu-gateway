#!/usr/bin/env bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HOST_GIT_ROOT="$DIR/.."
cd $HOST_GIT_ROOT

git submodule update --init --recursive

mkdir gluu-gateway-node-deps
cp -R kong gluu-gateway-node-deps/
cp -R third-party gluu-gateway-node-deps/
cp setup/gg-kong-node.conf gluu-gateway-node-deps/
cp setup/gg-kong-node-setup.py gluu-gateway-node-deps/

zip -r gluu-gateway-node-deps.zip gluu-gateway-node-deps

rm -rf gluu-gateway-node-deps

git add gluu-gateway-node-deps.zip
git commit -m "Archive lua libs and plugins and upload zip"
git push origin $(git symbolic-ref --short HEAD)
