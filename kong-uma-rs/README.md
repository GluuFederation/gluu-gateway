# UMA RS plugin

User-Managed Access Resource Server plugin.

It allows to protect your API (which is proxied by Kong) with [UMA](https://docs.kantarainitiative.org/uma/rec-uma-core.html)

Table of Contents
=================

 * [Installation](#installation)
 * [Protect your API with UMA](#protect-your-api-with-uma)
   * [Add your API server to kong /apis](#add-your-api-server-to-kong-apis) 
   * [Enable kong-uma-rs protection](#enable-kong-uma-rs-protection 
 * [References](#references)
  
 
## Installation

1. [Install Kong](https://getkong.org/install/)
2. [Install & Configure oxd server](https://oxd.gluu.org/docs/)
3. Install kong-uma-rs
  1. Stop kong : `kong stop`
  2. Copy `kong-uma-rs/kong/plugins/kong-uma-rs` Lua sources to kong plugins folder `kong/plugins/kong-uma-rs`
  3. Enable plugin in your `kong.yml` (typically located at `/etc/kong/kong.yml`).
    ```
    custom_plugins:
      - kong-uma-rs
    ```
  4. Start kong : `kong start`


## Protect your API with UMA

### Add your API server to kong /apis

```curl
$ curl -i -X POST \
  --url http://localhost:8001/apis/ \
  --data 'name=your.api.server' \
  --data 'upstream_url=http://your.api.server.com/' \
  --data 'request_host=your.api.server.com'
```

Response must confirm the API is added

```
HTTP/1.1 201 Created
Content-Type: application/json
Connection: keep-alive

{
  "request_host": "your.api.server.com",
  "upstream_url": "http://your.api.server.com/",
  "id": "2eec1cb2-7093-411a-c14e-42e67142d2c4",
  "created_at": 1428456369000,
  "name": "your.api.server"
}
```

Validate your API is correctly proxied via Kong.

```
$ curl -i -X GET \
  --url http://localhost:8000/your/api \
  --header 'Host: your.api.server.com'
```

### Enable kong-uma-rs protection

```
$ curl -i -X POST \
  --url http://localhost:8001/apis/2eec1cb2-7093-411a-c14e-42e67142d2c4/plugins/ \
  --data 'name=kong-uma-rs' \
  --data "config.oxd_port=8099" \
  --data "config.protection_document={protection document}"
```

## References
 - [Kong](https://getkong.org)
