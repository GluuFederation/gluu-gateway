# Gluu OAuth 2.0 UMA RS plugin

User-Managed Access Resource Server plugin.

It allows to protect your API (which is proxied by Kong) with [UMA](https://docs.kantarainitiative.org/uma/rec-uma-core.html)

> Note: You must need to configure first [gluu-oauth2-client-auth](https://github.com/GluuFederation/gluu-gateway/tree/master/gluu-oauth2-client-auth) plugin.

Table of Contents
=================

 * [Installation](#installation)
 * [Configuration](#configuration)
   * [Protection document](#protection-document)
 * [Protect your API with UMA](#protect-your-api-with-uma)
   * [Add your API server to kong /apis](#add-your-api-server-to-kong-apis) 
   * [Enable gluu-oauth2-rs protection](#enable-gluu-oauth2-rs-protection)
   * [Verify that your API is protected by gluu-oauth2-rs](#verify-that-your-api-is-protected-by-gluu-oauth2-rs)
   * [Verify that your API can be accessed with valid RPT](#verify-that-your-api-can-be-accessed-with-valid-rpt)
 * [Upstream Headers](#upstream-headers)
 * [References](#references)
  
 
## Installation

1. [Install Kong](https://getkong.org/install/)
2. [Install oxd server v3.1.3](https://oxd.gluu.org/docs/)
3. Install gluu-oauth2-rs
    1. Stop kong : `kong stop`
    2. 
        Using luarocks `luarocks install gluu-oauth2-rs`
        
        or
        
        Copy `gluu-oauth2-rs/kong/plugins/gluu-oauth2-rs` Lua sources to kong plugins folder `kong/plugins/gluu-oauth2-rs`        
            
    3. Enable plugin in your `kong.conf` (typically located at `/etc/kong/kong.conf`) and start kong `kong start`.

        ```
            custom_plugins = gluu-oauth2-rs
        ```

## Configuration

 - oxd_host - OPTIONAL, host of the oxd server (default: localhost. It is recommended to have oxd server on localhost.)
 - protection_document - REQUIRED, json document that describes UMA protection
 - uma_server_host - REQUIRED, UMA Server that implements UMA 2.0 specification.
                     (For example [Gluu Server](https://www.gluu.org/gluu-server/overview/)). 
                     Check that UMA implementation is up and running by visiting `.well-known/uma2-configuration` endpoint.
               
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
[
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
```

You can also pass scope-expression formate.

```
[
  {
    "path": "/photo",
    "conditions": [
      {
        "httpMethods": [
          "GET"
        ],
        "scope_expression": {
          "rule": {
            "or": [
              {
                "var": 0
              }
            ]
          },
          "data": [
            "http://photoz.example.com/dev/actions/view"
          ]
        }
      },
      {
        "httpMethods": [
          "PUT",
          "POST"
        ],
        "scope_expression": {
          "rule": {
            "or": [
              {
                "var": 0
              },
              {
                "var": 1
              }
            ]
          },
          "data": [
            "http://photoz.example.com/dev/actions/all",
            "http://photoz.example.com/dev/actions/add"
          ]
        },
        "ticketScopes": [
          "http://photoz.example.com/dev/actions/add"
        ]
      }
    ]
  },
  {
    "path": "/document",
    "conditions": [
      {
        "httpMethods": [
          "GET"
        ],
        "scope_expression": {
          "rule": {
            "or": [
              {
                "var": 0
              }
            ]
          },
          "data": [
            "http://photoz.example.com/dev/actions/view"
          ]
        }
      }
    ]
  }
]
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

### Enable gluu-oauth2-rs protection

Important : each protection_document double quotes must be escaped by '\\' sign. This limitation comes from Kong configuration parameter type limitation which are limited to : "id", "number", "boolean", "string", "table", "array", "url", "timestamp".
   
During gluu-oauth2-rs addition to /plugins keep in mind that oxd must be up and running otherwise registration will fail. It's because during POST to kong's /plugin endpoint, plugin performs self registration on oxd server at oxd_host provided in configuration. For this reason if plugin is added and you remove oxd (install new version of oxd) without configuration persistence then gluu-oauth2-rs must be re-registered (to force registration with newly installed oxd).
    

```
$ curl -i -X POST \
  --url http://localhost:8001/apis/2eec1cb2-7093-411a-c14e-42e67142d2c4/plugins/ \
  --data "name=gluu-oauth2-rs" \
  --data "config.oxd_host=localhost" \
  --data "config.uma_server_host=https://uma.server.com" \
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

### Verify that your API is protected by gluu-oauth2-rs

```
$ curl -i -X GET \
  --url http://localhost:8000/your/api \
  --header 'Host: your.api.server.com'
```

Since you did not specify the required authorized RPT in "Authorization" header (e.g. "Authorization: Bearer vF9dft4qmT"), the response should be 403 Forbidden:

```
HTTP/1.1 403 Forbidden
WWW-Authenticate: UMA realm="rs",
  as_uri="https://uma.server.com",
  error="insufficient_scope",
  ticket="016f84e8-f9b9-11e0-bd6f-0021cc6004de"

{"message":"Unauthorized"}
```

```
HTTP/1.1 403 Forbidden
Warning: 199 - "UMA Authorization Server Unreachable"
```

### Verify that your API can be accessed with valid RPT
 
(This sample assumes that "481aa800-5282-4d6c-8001-7dcdf37031eb" is valid and authorized by UMA Authorization Server RPT).

```
$ curl -i -X GET \
  --url http://localhost:8000/your/api \
  --header 'Host: your.api.server.com'
  --header 'Authorization: Bearer 481aa800-5282-4d6c-8001-7dcdf37031eb'
```

## Upstream Headers
When a client has been authenticated, the plugin will append some headers to the request before proxying it to the upstream service, so that you can identify the consumer and the end-user in your code:
1. **X-Consumer-ID**, the ID of the Consumer on Kong
2. **X-Consumer-Custom-ID**, the custom_id of the Consumer (if set)
3. **X-Consumer-Username**, the username of the Consumer (if set)
4. **X-Authenticated-Scope**, the comma-separated list of scopes that the end user has authenticated, if available (only if the consumer is not the 'anonymous' consumer)
5. **X-OAuth-Client-ID**, the authenticated client id, if oauth_mode is enabled(only if the consumer is not the 'anonymous' consumer)
6. **X-OAuth-Expiration**, the token expiration time, Integer timestamp, measured in the number of seconds since January 1 1970 UTC, indicating when this token will expire, as defined in JWT RFC7519. It only returns in oauth_mode(only if the consumer is not the 'anonymous' consumer)
7. **X-Anonymous-Consumer**, will be set to true when authentication failed, and the 'anonymous' consumer was set instead.

You can use this information on your side to implement additional logic. You can use the X-Consumer-ID value to query the Kong Admin API and retrieve more information about the Consumer.

## References
 - [Kong](https://getkong.org)
 - [oxd server](https://oxd.gluu.org)
 - [Gluu Server](https://www.gluu.org/gluu-server/overview/)
 - [UMA specification](https://docs.kantarainitiative.org/uma/rec-uma-core.html)
 - [uma-rs library](https://github.com/GluuFederation/uma-rs)
