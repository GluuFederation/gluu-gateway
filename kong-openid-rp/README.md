# Kong OpenID Connect RP plugin

The Kong OpenID Connect RP or OAuth 2.0 plugin allows you to protect your API (which is proxied by Kong) with [OpenID Connect](https://gluu.org/docs/ce/admin-guide/openid-connect/).

Table of Contents
=================

 * [Installation](#installation)
 * [Configuration](#configuration)
 * [Protect your API with OpenID Connect RP](#protect-your-api-with-Openid-connect-rp)
   * [Add your API server to kong /apis](#add-your-api-server-to-kong-apis) 
   * [Enable kong-openid-rp protection](#enable-kong-openid-rp-protection)
   * [Create a Consumer](#create-a-consumer)
   * [Config plugin and get OXD ID](#config-plugin-and-get-oxd-id)
   * [Getting authorization url](#getting-authorization-url)
   * [Verify that your API is protected by kong-openid-rp](#verify-that-your-api-is-protected-by-kong-openid-rp)
   * [Upstream Headers](#upstream-headers)
 * [References](#references)
  
## Installation

1. [Install Kong](https://getkong.org/install/)
2. [Install oxd server](https://oxd.gluu.org/docs/) 
3. Install kong-openid-rp
  1. Stop kong : `kong stop`
  2. Copy `kong-openid-rp/kong/plugins/kong-openid-rp` Lua sources to kong plugins folder `kong/plugins/kong-openid-rp`
  3. Enable plugin in your `kong.config` (typically located at `/etc/kong/kong.config`) and start kong `kong start`.
```
 custom_plugins:
   - kong-openid-rp
```

## Configuration
 - op_host - REQUIRED, Openid Connect Server that provides openid connect oauth facility. Op must be https.
                                            (For example [Gluu Server](https://www.gluu.org/gluu-server/overview/)). 
                                            Check that UMA implementation is up and running by visiting `.well-known/openid-configuration` endpoint.
 - client_id - REQUIRED, client_id of OAuth client
 - client_secret - REQUIRED, client_secret of OAuth client
 - authorization_redirect_uri - REQUIRED, This is the URL on your website that the OpenID Connect Provider (OP) will redirect the person to after successful authorization.
 - oxd_host - REQUIRED, host of the oxd server (default: localhost. It is recommended to have oxd server on localhost.)
 - oxd_port - REQUIRED, port of the oxd server (oxd server default port is 8099)
 - scope - REQUIRED, It is the user claims which you want in user information.
 
## Protect your API with OpenID Connect RP

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
    "http_if_terminated": true,
    "id": "4857493c-2211-4c4f-b180-772806d655b7",
    "retries": 5,
    "preserve_host": false,
    "created_at": 1500468927641,
    "upstream_connect_timeout": 60000,
    "upstream_url": "https://your.api.server",
    "upstream_send_timeout": 60000,
    "https_only": false,
    "upstream_read_timeout": 60000,
    "strip_uri": true,
    "name": "your.api.server",
    "hosts": [
        "your.api.server"
    ]
}
```

Validate your API is correctly proxied via Kong.

```
$ curl -i -X GET \
  --url http://localhost:8000/your/api \
  --header 'Host: your.api.server.com'
```

### Enable kong-openid-rp protection  
`session_time_second` is required field. It accept time in second and automatically remove the login session after specified time. (e.g 86400 seconds = 24 hr)
```
$ curl -i -X POST \
  --url http://localhost:8001/apis/4857493c-2211-4c4f-b180-772806d655b7/plugins/ \
  --data 'name=kong-openid-rp' \
  --data 'config.session_time_second=86400'
```

### Create a Consumer

You need to associate a credential to an existing Consumer object, that represents a user consuming the API. To create a Consumer you can execute the following request:

```
curl -i -X POST http://kong:8001/consumers/ \
    --data "username=<USERNAME>" \
    --data "custom_id=<CUSTOM_ID>"
HTTP/1.1 201 Created

{
    "username":"<USERNAME>",
    "custom_id": "<CUSTOM_ID>",
    "created_at": 1472604384000,
    "id": "7f853474-7b70-439d-ad59-2481a0a9a904"
}
```

### Config plugin and get OXD ID

During configuration keep in mind that oxd must be up and running otherwise registration will fail. It's because during POST to kong's /consumers/<consumer_id>/kong-openid-rp endpoint, plugin performs self registration on oxd server at oxd_host:oxd_port provided in request parameter. For this reason if plugin is added and you remove oxd (install new version of oxd) without configuration persistence then kong-openid-rp must be re-registered (to force registration with newly installed oxd).

```
curl -i -X POST \
 --url http://localhost:8001/consumers/7f853474-7b70-439d-ad59-2481a0a9a904/kong-openid-rp/ \
 --data 'op_host=https://opendid-provider.org' \
 --data 'client_id=<some_client_id>' \
 --data 'client_secret=<some_client_secret>' \
 --data 'authorization_redirect_uri=<your_authorization_redirect_uri>' \
 --data 'oxd_port=8099' \
 --data 'oxd_host=localhost' \
 --data 'scope=["openid","profile"]' \
```

Response: 
```
 {
     "consumer_id": "7f853474-7b70-439d-ad59-2481a0a9a904",
     "id": "8be4d154-c5e6-4003-90fc-31573073e5db",
     "oxd_port": "8099",
     "created_at": 1500460678281,
     "scope": "[\"openid\",\"profile\"]",
     "oxd_host": "localhost",
     "authorization_redirect_uri": <your_authorization_redirect_uri>,
     "oxd_id": "16a09fa3-03f5-47ca-ab95-ae619d643c35",
     "op_host": "https://opendid-provider.org"
 }
```

### Getting authorization url
The admin API endpoint help you to get `authorization URL` which is generated using `OXD server`.
You need to passed consumer id in path parameter.

```
curl -i -X GET \
 --url http://localhost:8001/consumers/7f853474-7b70-439d-ad59-2481a0a9a904/authorization_url \
```

Response

```
{
    "status": "ok",
    "data": {
        "authorization_url": "https://opendid-provider.org/oxauth/authorize?response_type=code&client_id=<some_client_id>&redirect_uri=<your_authorization_redirect_uri>&scope=openid+profile&state=<some_state>&acr_values=basic"
    }
}
```
Use this above `authorization_url` to getting code and state. If you properly registered with your client on your open id provider server and also with oxd server then it will redirect you to your open id service provider(e.g `https://opendid-provider.org`) for authentication. If authentication done successful then it will redirect you to `authorization_redirect_uri` with code and state.

### Verify that your API is protected by kong-openid-rp
Below is request with some wrong header parameter value and it's return unauthorized in response.
```
$ curl -i -X GET \
  --url http://localhost:8000/your/api \
  --header 'Host: your.api.server.com'
  --header 'authorization_code: <some_wrong_code>'
  --header 'state: <some_wrong_state>'
  --header 'oxd_id: <oxd_id>'
```

Response
```
{
    "message": "Unauthorized"
}
```

Below is request with valid header parameter value.
```
$ curl -i -X GET \
  --url http://localhost:8000/your/api \
  --header 'Host: your.api.server.com'
  --header 'authorization_code: <some_valid_code>'
  --header 'state: <some_valid_state>'
  --header 'oxd_id: <some_valid_OXD_id>'
```

If your credential is correct then you will get successful response from you api server. (e.g `your.api.server.com/your/api`)  

### Upstream Headers
When a client has been authenticated, the plugin will append some headers to the request before proxying it to the upstream API/Microservice, so that you can identify the Consumer in your code:
 - `X-Consumer-ID`, the ID of the Consumer on Kong
 - `X-Consumer-Custom-ID`, the custom_id of the Consumer (if set)
 - `X-Consumer-Username`, the username of the Consumer (if set)
 - `X-OXD-ID`, the OXD ID which is registered in oxd server (if set)
 - `X-Anonymous-Consumer`, will be set to true when authentication failed, and the 'anonymous' consumer was set instead.

You can use this information on your side to implement additional logic. You can use the `X-Consumer-ID` or `X-OXD-ID` value to query the Kong Admin API and retrieve more information about the Consumer.

### Logout session 
Using the `/consumers/<consumer_id>/logout` admin API endpoint you can manually destroy the session. After successful destroy session, It will return status code 200 OK.

```
curl -i -X DELETE \
 --url http://localhost:8001/consumers/7f853474-7b70-439d-ad59-2481a0a9a904/logout \
```

## References
 - [Kong](https://getkong.org)
 - [oxd server](https://oxd.gluu.org)
 - [Gluu Server](https://www.gluu.org/gluu-server/overview/)
 - [OpenId Connect specification](https://gluu.org/docs/ce/admin-guide/openid-connect/)
