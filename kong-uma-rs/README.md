# UMA RS plugin

User-Managed Access Resource Server plugin.

It allows to protect your API (which is proxied by Kong) with [UMA](https://docs.kantarainitiative.org/uma/rec-uma-core.html)

Table of Contents
=================

 * [Installation](#installation)
 * [Configuration](#configuration)
   * [Protection document](#protection-document)
 * [Protect your API with UMA](#protect-your-api-with-uma)
   * [Add your API server to kong /apis](#add-your-api-server-to-kong-apis) 
   * [Enable kong-uma-rs protection](#enable-kong-uma-rs-protection)
   * [Verify that your API is protected by kong-uma-rs](#verify-that-your-api-is-protected-by-kong-uma-rs)
   * [Verify that your API can be accessed with valid RPT](#verify-that-your-api-can-be-accessed-with-valid-rpt)
 * [References](#references)
  
 
## Installation

1. [Install Kong](https://getkong.org/install/)
2. [Install oxd server](https://oxd.gluu.org/docs/) 
3. Install kong-uma-rs
  1. Stop kong : `kong stop`
  2. Copy `kong-uma-rs/kong/plugins/kong-uma-rs` Lua sources to kong plugins folder `kong/plugins/kong-uma-rs`
  3. Enable plugin in your `kong.yml` (typically located at `/etc/kong/kong.yml`) and start kong `kong start`.
```
 custom_plugins:
   - kong-uma-rs
```

## Configuration

 - oxd_host - OPTIONAL, host of the oxd server (default: localhost. It is recommended to have oxd server on localhost.)
 - oxd_port - REQUIRED, port of the oxd server (oxd server default port is 8099)
 - protection_document - REQUIRED, json document that describes UMA protection
 - uma_server_host - REQUIRED, UMA Server that implements UMA 1.0.1 specification. E.g. https://ce-dev.gluu.org
                     (For example [Gluu Server](https://www.gluu.org/gluu-server/overview/)). 
                     Check that UMA implementation is up and running by visiting `.well-known/uma-configuration` endpoint. E.g. https://ce-dev.gluu.org/.well-known/uma-configuration
               
### Protection document   

Protection document - json document which describes UMA protection in declarative way and is based on [uma-rs](https://github.com/GluuFederation/uma-rs) project.

 - path - relative path to protect (exact match)
 - httpMethods - GET, HEAD, POST, PUT, DELETE
 - scope - scope required to access given path
 - ticketScopes - optional parameter which may be used to keep ticket scope as narrow as possible. If not specified plugin will register ticket with scopes specified by "scope" which often may be unwanted. (For example scope may have "http://photoz.example.com/dev/actions/all" and the authorized ticket may grant access also to other resources).
    
Lets say we have APIs which we would like to protect:
 - GET https://your.api.server.com/photo  (UMA scope: http://photoz.example.com/dev/actions/view)
 - PUT https://your.api.server.com/photo  (UMA scope: http://photoz.example.com/dev/actions/all or http://photoz.example.com/dev/actions/add)
 - POST https://your.api.server.com/photo  (UMA scope: http://photoz.example.com/dev/actions/all or http://photoz.example.com/dev/actions/add)
 - GET https://your.api.server.com/document  (UMA scope: http://photoz.example.com/dev/actions/view)

Protection document for this sample (upstream_url=http://your.api.server.com/, request_host=your.api.server.com for Kong add API):
                 
```
{"resources":[
    {
        "path":"/photo",
        "conditions":[
            {
                "httpMethods":["GET"],
                "scopes":[
                    "http://photoz.example.com/dev/actions/view"
                ]
            },
            {
                "httpMethods":["PUT", "POST"],
                "scopes":[
                    "http://photoz.example.com/dev/actions/all",
                    "http://photoz.example.com/dev/actions/add"
                ],
                "ticketScopes":[
                    "http://photoz.example.com/dev/actions/add"
                ]
            }
        ]
    },
    {
        "path":"/document",
        "conditions":[
            {
                "httpMethods":["GET"],
                "scopes":[
                    "http://photoz.example.com/dev/actions/view"
                ]
            }
        ]
    }
]
}
```

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

Important : each protection_document double quotes must be escaped by '\\' sign. This limitation comes from Kong configuration parameter type limitation which are limited to : "id", "number", "boolean", "string", "table", "array", "url", "timestamp".   

```
$ curl -i -X POST \
  --url http://localhost:8001/apis/2eec1cb2-7093-411a-c14e-42e67142d2c4/plugins/ \
  --data 'name=kong-uma-rs' \
  --data "config.oxd_host=localhost" \
  --data "config.oxd_port=8099" \
  --data "config.uma_server_host=https://ce-dev.gluu.org" \
  --data "config.protection_document={\"resources\":[
                                         {
                                             \"path\":\"/photo\",
                                             \"conditions\":[
                                                 {
                                                     \"httpMethods\":[\"GET\"],
                                                     \"scopes\":[
                                                         \"http://photoz.example.com/dev/actions/view\"
                                                     ]
                                                 },
                                                 {
                                                     \"httpMethods\":[\"PUT\", \"POST\"],
                                                     \"scopes\":[
                                                         \"http://photoz.example.com/dev/actions/all\",
                                                         \"http://photoz.example.com/dev/actions/add\"
                                                     ],
                                                     \"ticketScopes\":[
                                                         \"http://photoz.example.com/dev/actions/add\"
                                                     ]
                                                 }
                                             ]
                                         },
                                         {
                                             \"path\":\"/document\",
                                             \"conditions\":[
                                                 {
                                                     \"httpMethods\":[\"GET\"],
                                                     \"scopes\":[
                                                         \"http://photoz.example.com/dev/actions/view\"
                                                     ]
                                                 }
                                             ]
                                         }
                                     ]
                                     }\"
```

### Verify that your API is protected by kong-uma-rs

```
$ curl -i -X GET \
  --url http://localhost:8000/your/api \
  --header 'Host: your.api.server.com'
```

Since you did not specify the required authorized RPT in "Authorization" header (e.g. "Authorization: Bearer vF9dft4qmT"), the response should be 403 Forbidden:

```
HTTP/1.1 403 Forbiddenrealm
WWW-Authenticate: UMA realm="rs",
  as_uri="https://ce-dev.gluu.org",
  error="insufficient_scope",
  ticket="016f84e8-f9b9-11e0-bd6f-0021cc6004de"

{
"ticket": "016f84e8-f9b9-11e0-bd6f-0021cc6004de"
}
```

Or in case https://ce-dev.gluu.org is unreachange

```
HTTP/1.1 403 Forbidden
Warning: 199 - "UMA Authorization Server Unreachable"
```

### Verify that your API can be accessed with valid RPT
 
(This sample assumes that "vF9dft4qmT" is valid and authorized by UMA Authorization Server RPT).

```
$ curl -i -X GET \
  --url http://localhost:8000/your/api \
  --header 'Host: your.api.server.com'
  --header 'Authorization: Bearer vF9dft4qmT'
```



## References
 - [Kong](https://getkong.org)
 - [oxd server](https://oxd.gluu.org)
 - [Gluu Server](https://www.gluu.org/gluu-server/overview/)
 - [UMA specification](https://docs.kantarainitiative.org/uma/rec-uma-core.html)
 - [uma-rs library](https://github.com/GluuFederation/uma-rs)
