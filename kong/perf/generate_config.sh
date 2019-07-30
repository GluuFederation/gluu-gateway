#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

GENERATOR_ID="$(docker run -d --rm -p 80 \
     -v $DIR/generator.nginx:/usr/local/openresty/nginx/conf/nginx.conf:ro \
     -v $DIR/generator.lua:/usr/local/openresty/lualib/gluu/generator.lua:ro \
openresty/openresty:alpine)"

GENERATOR_PORT="$(docker inspect --format='{{(index (index .NetworkSettings.Ports "80/tcp") 0).HostPort}}' $GENERATOR_ID))"

WRK_CONFIG=$(curl -s --data "@$1" "http://127.0.0.1:$GENERATOR_PORT/")

#docker logs $GENERATOR_ID
docker stop $GENERATOR_ID > null

echo $WRK_CONFIG
