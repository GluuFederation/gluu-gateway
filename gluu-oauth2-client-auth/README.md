# Gluu OAuth 2.0 client credential authentication

It provides oauth 2.0 client credential authentication with [3 different modes](#create-oauth-credential).

Table of Contents
=================

 * [Terminology](#terminology)
 * [Installation](#installation)
 * [Configuration](#configuration)
   * [Add API](#add-api)
   * [Enable gluu-oauth2-client-auth protection](#enable-gluu-oauth2-client-auth-protection)
 * [Usage](#usage)
   * [Create a Consumer](#create-a-consumer)
   * [Create OAuth credential](#create-oauth-credential)
   * [Verify that your API is protected by gluu-oauth2-client-auth](#verify-that-your-api-is-protected-by-gluu-oauth2-client-auth)
   * [Verify that your API can be accessed with valid basic token](#verify-that-your-api-can-be-accessed-with-valid-token)
 * [Upstream Headers](#upstream-headers)
 * [References](#references)

## Terminology
* `api`: your upstream service placed behind Kong, for which Kong proxies requests to.
* `plugin`: a plugin executing actions inside Kong before or after a request has been proxied to the upstream API.
* `consumer`: a developer or service using the API. When using Kong, a Consumer only communicates with Kong which proxies every call to the said, upstream API.
* `credential`: in the gluu-aouth2-client-auth plugin context, an openId client is registered with consumer and client id is used to identify the credential.

## Installation
1. [Install Kong](https://getkong.org/install/)
2. [Install oxd server v3.1.3](https://oxd.gluu.org/docs/)
3. Install gluu-oauth2-client-auth
    1. Stop kong : `kong stop`
    2. Copy `gluu-oauth2-client-auth/kong/plugins/gluu-oauth2-client-auth` Lua sources to kong plugins folder `/usr/local/share/lua/<version>/kong/plugins/gluu-oauth2-client-auth`

         or

       `luarocks install gluu-oauth2-client-auth`
    3. Enable plugin in your `kong.conf` (typically located at `/etc/kong/kong.conf`) and start kong `kong start`.

    ```
        custom_plugins = gluu-oauth2-client-auth
    ```

## Configuration
### Add API
The first step is to add your API in the kong. Below is the request for adding API in the kong.
```
$ curl -X POST http://localhost:8001/apis \
      --data "name=example" \
      --data "hosts=your.api.server" \
      --data "upstream_url=http://your.api.server.com"
```

Validate your API is correctly proxied via Kong.

```
$ curl -i -X GET \
  --url http://localhost:8000/your/api \
  --header 'Host: your_api_server'
```

### Enable gluu-oauth2-client-auth protection
```
curl -X POST http://kong:8001/apis/{api}/plugins \
    --data "name=gluu-oauth2-client-auth" \
    --data "config.hide_credentials=true" \
    --data "config.op_server=<op_server.com>" \
    --data "config.oxd_http_url=<oxd_http_url>" \
    --data "config.oxd_id=<oxd_id>" \
    --data "config.anonymous=<consumer_id>"
```

**api**: The `id` or `name` of the API that this plugin configuration will target

| FORM PARAMETER | DEFAULT | DESCRIPTION |
|----------------|---------|-------------|
| name | | The name of the plugin to use, in this case: gluu-oauth2-client-auth. |
| config.hide_credentials(optional) | false | An optional boolean value telling the plugin to hide the credential to the upstream API server. It will be removed by Kong before proxying the request. |
| config.op_server | | OP server |
| config.oxd_http_url | | OXD HTTP extension URL |
| config.oxd_id(optional) | | Used to introspect the token. You can use any other oxd_id. If you not pass then plugin creates new client itself. |
| config.anonymous(optional) | | An optional string (consumer uuid) value to use as an "anonymous" consumer if authentication fails. If empty (default), the request will fail with an authentication failure 4xx. Please note that this value must refer to the Consumer id attribute which is internal to Kong, and not its custom_id. |

## Usage

In order to use the plugin, you first need to create a Consumer to associate one or more credentials to. The Consumer represents a developer using the final service/API.

### Create a Consumer

You need to associate a credential to an existing Consumer object, that represents a user consuming the API. To create a Consumer you can execute the following request:

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

### Create OAuth credential

This process registers OpenId client with oxd which help you to get tokens and authenticate the token. Plugin behaves as per selected mode. There are three modes.

| Mode | DESCRIPTION |
|----------------|-------------|
| oauth_mode | If yes then kong act as OAuth client only. |
| uma_mode | If yes then this indicates your client is a valid UMA client, and obtain and send an RPT as the access token. You must need to configure [gluu-oauth2-rs](https://github.com/GluuFederation/gluu-gateway/tree/master/gluu-oauth2-rs) plugin for uma_mode. |
| mix_mode | If yes then the gluu-oauth2 plugin will try to obtain an UMA RPT token if the RS returns a 401/Unauthorized. You must need to configure [gluu-oauth2-rs](https://github.com/GluuFederation/gluu-gateway/tree/master/gluu-oauth2-rs) plugin for uma_mode. |

You can provision new credentials by making the following HTTP request:

```
curl -X POST \
  http://localhost:8001/consumers/{consumer}/gluu-oauth2-client-auth/ \
  -d name=<name>
  -d op_host=<op_host>
  -d oxd_http_url=<oxd_http_url>
  -d oauth_mode=<true|false>
  -d uma_mode=<true|false>
  -d mix_mode=<true|false>
  -d oxd_id=<existing_oxd_id>
  -d client_name=<client_name>
  -d client_id=<existing_client_id>
  -d client_secret=<existing_client_secret>
  -d allow_unprotected_path=<true|false>
  -d client_jwks_uri=<client_jwks_uri>
  -d client_token_endpoint_auth_method=<client_token_endpoint_auth_method>
  -d client_token_endpoint_auth_signing_alg=<client_token_endpoint_auth_signing_alg>

RESPONSE :
{
  "id": "e1b1e30d-94fa-4764-835d-4fae0f8ff668",
  "created_at": 1517216795000,
  "consumer_id": "81ae39fa-d08e-4978-a6af-be0127b9fb99"
  "name": <name>,
  "op_host": <op_host>
  "oxd_http_url": <oxd_http_url>
  "oauth_mode": <true|false>
  "uma_mode": <true|false>
  "mix_mode": <true|false>
  "oxd_id": <oxd_id>
  "client_name": <client_name>
  "client_id": <client_id>
  "client_secret": <client_secret>
  "allow_unprotected_path": <true|false>
  "client_jwks_uri": <client_jwks_uri>
  "client_token_endpoint_auth_method": <client_token_endpoint_auth_method>
  "client_token_endpoint_auth_signing_alg": <client_token_endpoint_auth_signing_alg>
}
```

| FORM PARAMETER | DEFAULT | DESCRIPTION |
|----------------|---------|-------------|
| name | | The name to associate to the credential. In OAuth 2.0 this would be the application name. |
| op_host | | Open Id connect provider. Example: https://gluu.example.org |
| oxd_http_url | | OXD https extenstion url. |
| oauth_mode(semi-optional) | | If true, kong act as OAuth client only. |
| uma_mode(semi-optional) | | This indicates your client is a valid UMA client, and obtain and send an RPT as the access token. |
| mix_mode(semi-optional) | | If Yes, then the gluu-oauth2 plugin will try to obtain an UMA RPT token if the RS returns a 401/Unauthorized. |
| oxd_id(optional) | | If you have existing oxd entry then enter oxd_id(also client id, client secret and client id of oxd id). If you have client created from OP server then skip it and enter only client_id and client_secret. |
| client_name(optional) | kong_oauth2_bc_client | An optional string value for client name. |
| client_id(optional) | | You can use existing client id. |
| client_secret(optional) | | You can use existing client secret. |
| allow_unprotected_path(false) | | It is used to allow or deny unprotected path by UMA-RS. |
| client_jwks_uri(optional) | | An optional string value for client jwks uri. |
| client_token_endpoint_auth_method(optional) | | An optional string value for client token endpoint auth method. |
| client_token_endpoint_auth_signing_alg(optional) | | An optional string value for client token endpoint auth signing alg. |

### Verify that your API is protected by gluu-oauth2-client-auth

You need to pass token as per your authentication mode(oauth_mode, uma_mode, and mix_mode). In oauth_mode and mix_mode, you need to pass oauth2 access token and in uma_mode, you need to RPT token.

```
$ curl -X GET \
    http://localhost:8000/your_api_endpoint \
    -H 'authorization: Bearer 481aa800-5282-4d6c-8001-7dcdf37031eb' \
    -H 'host: your.api.server.com'
```

If your toke is not valid or time expired then you will get failed message.

```
HTTP/1.1 401 Unauthorized
{
    "message": "Unauthorized"
}
```

### Verify that your API can be accessed with valid token
(This sample assumes that below bearer token is valid and grant by OP server).

```
$ curl -X GET \
    http://localhost:8000/your_api_endpoint \
    -H 'authorization: Bearer 7475ebc5-9b92-4031-b849-c70a0e3024f9' \
    -H 'host: your_api_server'
```

### Upstream Headers
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
 - [Gluu Server](https://www.gluu.org)
 - [oxd](https://gluu.org/docs/oxd)