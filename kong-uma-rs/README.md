# UMA RS plugin

User-Managed Access Resource Server plugin.

It allows to protect your API (which is proxied by Kong) with [UMA](https://docs.kantarainitiative.org/uma/rec-uma-core.html)

Table of Contents
=================

 * [Installation](#installation)
 * [Protect your API with UMA](#definitions)

## Installation

## Protect your API with UMA

1. Add you API server to kong /apis

```curl
$ curl -i -X POST \
  --url http://localhost:8001/apis/ \
  --data 'name=yourapiserver' \
  --data 'upstream_url=http://yourapiserver.com/' \
  --data 'request_host=yourapiserver.com'
```

Response must confirm the API is added

```
HTTP/1.1 201 Created
Content-Type: application/json
Connection: keep-alive

{
  "request_host": "yourapiserver.com",
  "upstream_url": "http://yourapiserver.com/",
  "id": "2eec1cb2-7093-411a-c14e-42e67142d2c4",
  "created_at": 1428456369000,
  "name": "yourapiserver"
}
```

Validate your API is correctly proxied via Kong.

```
$ curl -i -X GET \
  --url http://localhost:8000/your/api \
  --header 'Host: yourapiserver.com'
```

2. Enable kong-uma-plugin protection

```
$ curl -i -X POST \
  --url http://localhost:8001/apis/2eec1cb2-7093-411a-c14e-42e67142d2c4/plugins/ \
  --data '<uma plugin json configuration>'
```

