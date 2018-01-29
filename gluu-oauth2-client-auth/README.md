# Gluu OAuth 2.0 Back channel authentication

## Terminology
* `api`: your upstream service placed behind Kong, for which Kong proxies requests to.
* `plugin`: a plugin executing actions inside Kong before or after a request has been proxied to the upstream API.
* `consumer`: a developer or service using the api. When using Kong, a Consumer only communicates with Kong which proxies every call to the said, upstream api.
* `credential`: in the gluu-aouth2-client-auth plugin context, a openId client is registered with consumer and client id is used to identify the credential.

## Installation

1. [Install Kong](https://getkong.org/install/)
2. Install gluu-oauth2-client-auth
    1. Stop kong : `kong stop`
    2. Copy `gluu-oauth2-client-auth/kong/plugins/gluu-oauth2-client-auth` Lua sources to kong plugins folder `/usr/local/share/lua/<version>/kong/plugins/gluu-oauth2-client-auth`
         or
       `luarocks install gluu-oauth2-client-auth`
    3. Enable plugin in your `kong.conf` (typically located at `/etc/kong/kong.conf`) and start kong `kong start`.

    ```
        custom_plugins = gluu-oauth2-client-auth
    ```

## Configuration

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

### Enable gluu-oauth2-client-auth protection

```
curl -X POST http://kong:8001/apis/{api}/plugins \
    --data "name=gluu-oauth2-client-auth" \
    --data "config.hide_credentials=true"
```

*api*: The `id` or `name` of the API that this plugin configuration will target

Once applied, any user with a valid credential can access the service/API.

| FORM PARAMETER | DEFAULT | DESCRIPTION |
|----------------|---------|-------------|
| name | | The name of the plugin to use, in this case: gluu-oauth2-client-auth. |
| config.hide_credentials(optional) | false | An optional boolean value telling the plugin to hide the credential to the upstream API server. It will be removed by Kong before proxying the request. |

## Usage

In order to use the plugin, you first need to create a Consumer to associate one or more credentials to. The Consumer represents a developer using the final service/API.

### Create a Consumer

You need to associate a credential to an existing [Consumer](https://getkong.org/docs/latest/admin-api/#consumer-object) object, that represents a user consuming the API. To create a Consumer you can execute the following request:

```
$ curl -X POST http://localhost:8001/consumers/ \
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

| PARAMETER | DEFAULT | DESCRIPTION |
|----------------|---------|-------------|
| username(semi-optional) | | The username of the Consumer. Either this field or ``custom_id` must be specified. |
| custom_id(semi-optional) | | A custom identifier used to map the Consumer to another database. Either this field or `username` must be specified. |

### Register OpenId client

This process registers OpenId client with oxd. You can provision new credentials by making the following HTTP request:

```
curl -X POST \
  http://localhost:8001/consumers/{consumer}/gluu-oauth2-client-auth/ \
  -d name=<name>
  -d op_host=<op_host>
  -d oxd_http_url=<oxd_http_url>

RESPONSE :
{
  "created_at": 1517216795000,
  "id": "e1b1e30d-94fa-4764-835d-4fae0f8ff668",
  "name": <name>,
  "client_secret": <client_secret>,
  "client_jwks_uri": "",
  "client_token_endpoint_auth_method": "",
  "oxd_id": <oxd_id>,
  "op_host": <op_host>,
  "client_token_endpoint_auth_signing_alg": "",
  "client_id": <client_id>,
  "oxd_http_url": <oxd_http_url>,
  "consumer_id": "81ae39fa-d08e-4978-a6af-be0127b9fb99"
}
```

| FORM PARAMETER | DEFAULT | DESCRIPTION |
|----------------|---------|-------------|
| name | | The name to associate to the credential. In OAuth 2.0 this would be the application name. |
| op_host | | Open Id connect provider. Example: https://gluu.example.org |
| oxd_http_url | | OXD https extenstion url. |
| client_name(optional) | kong_oauth2_bc_client | An optional string value for client name. |
| client_jwks_uri(optional) | | An optional string value for client jwks uri. |
| client_token_endpoint_auth_method(optional) | | An optional string value for client token endpoint auth method. |
| client_token_endpoint_auth_signing_alg(optional) | | An optional string value for client token endpoint auth signing alg. |

### Verify that your API is protected by gluu-oauth2-client-auth

You need to pass bearer token. which is Base64 encoded combination of client_id and access_token. client_id is used to identify the consumer credential and access_token is used to authenticate the request.

Below is node js sample to make base64 encoded token.

```Node JS
new Buffer('client_id' + ':' + 'access_token').toString('base64');
```

```
$ curl -X GET \
    http://localhost:8000/your_api_endpoint \
    -H 'authorization: Bearer QCFBQUU2LjZCMzAuMTU5Ny5CMzJDITAwMDEhMEY2Ny5DMzQ4ITAwMDghQTkwNi5DRDgwLjg1QTkuNzZEQzpiYTEzZTZjMy00M2M3LTRmODQtYmI5NC0zYzdmNzQwNGJjNWY=' \
    -H 'host: your.api.server.com'
```

If your toke is not valid or time expired then you failer message.

```
{"message":"Invalid authentication credentials - Token is not active"}
```

### Verify that your API can be accessed with valid basic token
(This sample assumes that below bearer token is valid and grant by OP server).

```
$ curl -X GET \
    http://localhost:8000/your_api_endpoint \
    -H 'authorization: Bearer QCFBQUU2LjZCMzAuMTU5Ny5CMzJDITAwMDEhMEY2Ny5DMzQ4ITAwMDghQTkwNi5DRDgwLjg1QTkuNzZEQzpiYTEzZTZjMy00M2M3LTRmODQtYmI5NC0zYzdmNzQwNGJjNWY=' \
    -H 'host: your.api.server.com'
```

## References
 - [Kong](https://getkong.org)
 - [Gluu Server](https://www.gluu.org/gluu-server/overview/)