# Gluu OAuth 2.0 Back channel authentication

Table of Contents
=================

 * [Installation](#installation)
 * [Configuration](#configuration)
 * [Protect your API](#protect-your-api)
   * [Add your API server to kong /apis](#add-your-api-server-to-kong-apis) 
   * [Enable gluu-oauth2-bc protection](#enable-gluu-oauth2-bc-protection)
   * [Verify that your API is protected by gluu-oauth2-bc](#verify-that-your-api-is-protected-by-gluu-oauth2-bc)
   * [Verify that your API can be accessed with valid basic token](#verify-that-your-api-can-be-accessed-with-valid-basic-token)
 * [References](#references)

## Installation

1. [Install Kong](https://getkong.org/install/)
2. Install gluu-oauth2-bc
    1. Stop kong : `kong stop`
    2. Copy `gluu-oauth2-bc/kong/plugins/gluu-oauth2-bc` Lua sources to kong plugins folder `/usr/local/share/lua/<version>/kong/plugins/gluu-oauth2-bc`
            
    3. Enable plugin in your `kong.conf` (typically located at `/etc/kong/kong.conf`) and start kong `kong start`.
    
    ```
        custom_plugins = gluu-oauth2-bc
    ```

## Configuration

 - op_host - OPTIONAL, OAuth OpenId provider server. Example: https://idp.gluu.org

## Protect your API

### Add your API server to kong /apis

```curl
$ curl -X POST \
  http://localhost:8001/apis/ \
  -H 'content-type: application/x-www-form-urlencoded' \
  -d 'name=example&hosts=<your.api.server.com>&upstream_url=<your.upstream_url>'
```

Response must confirm the API is added

```
HTTP/1.1 201 Created
Content-Type: application/json
Connection: keep-alive

{
    "created_at": 1515841471000,
    "strip_uri": true,
    "id": "68a8153f-e15f-4b6e-8fe1-264f7474ba42",
    "hosts": [
        "<your.api.server.com>"
    ],
    "name": "example",
    "http_if_terminated": false,
    "preserve_host": false,
    "upstream_url": "<your.upstream_url>
    "upstream_connect_timeout": 60000,
    "upstream_send_timeout": 60000,
    "upstream_read_timeout": 60000,
    "retries": 5,
    "https_only": false
}
```

Validate your API is correctly proxied via Kong.

```
$ curl -i -X GET \
  --url http://localhost:8000/your/api \
  --header 'Host: your.api.server.com'
```

### Enable gluu-oauth2-bc protection

```
$ curl -X POST \
    http://localhost:8001/apis/68a8153f-e15f-4b6e-8fe1-264f7474ba42/plugins/ \
    -H 'content-type: application/x-www-form-urlencoded' \
    -d 'name=gluu-oauth2-bc&config.op_host=https://gluu.local.org'
```

### Verify that your API is protected by gluu-oauth2-bc
You need to pass basic token.

Basic token is base64 encoded token. Below is node js sample to make base64 encoded token.

```Node JS
new Buffer('client_id' + ':' + 'client_secret').toString('base64');
```

```
$ curl -X GET \
    http://localhost:8000/your_api_endpoint \
    -H 'authorization: Basic QCFBQUU2LjZCMzAuMTU5Ny5CMzJDITAwMDEhMEY2Ny5DMzQ4ITAwMDghQTkwNi5DRDgwLjg1QTkuNzZEQzpiYTEzZTZjMy00M2M3LTRmODQtYmI5NC0zYzdmNzQwNGJjNWY=' \
    -H 'host: jsonplaceholder.typicode.com'
```

If your toke is not valid then you failer message.

```
{"message":"Failed to allow grant"}
```

### Verify that your API can be accessed with valid basic token
(This sample assumes that below basic token is valid and grant by OP server).

```
$ curl -X GET \
    http://localhost:8000/your_api_endpoint \
    -H 'authorization: Basic QCFBQUU2LjZCMzAuMTU5Ny5CMzJDITAwMDEhMEY2Ny5DMzQ4ITAwMDghQTkwNi5DRDgwLjg1QTkuNzZEQzpiYTEzZTZjMy00M2M3LTRmODQtYmI5NC0zYzdmNzQwNGJjNWY=' \
    -H 'host: jsonplaceholder.typicode.com'
```

## References
 - [Kong](https://getkong.org)
 - [Gluu Server](https://www.gluu.org/gluu-server/overview/)