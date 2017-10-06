# KONG API Gateway

KONG API Gateway is provide API endpoint for configured kong API and plugin and also make UMA RPT policy and added it to scope. 

## Configuration
Use `.env-dev` file for configuration. There are following properties which allow you to set the environment of the application. 

*Server configuration*
1. PORT: Use to set port number on which the application is run. 
2. BASE_URL: Set base url.
4. APP_SECRET: kongAPIGateway is authenticate by OpenID Connect oAuth security and then it's secure by using JWT Token. APP_SECRET is use to set the secret key for the generate and verify JWT Token.
5. JWT_EXPIRES_IN: JWT token expired in given expire time. [Details..](https://www.npmjs.com/package/jsonwebtoken)

*Ldap Configuration*

6. LDAP_MAX_CONNS: Use to set maximum connection for ldap
7. LDAP_SERVER_URL: LDAP server URL
8. LDAP_BIND_DN: LDAP bind DN
9. LDAP_BIND_CREDENTIALS: LDAP connection credential(password)
10. LDAP_LOG_LEVEL: LDAP log Example: debug, error, info
11. LDAP_CLIENT_ID: LDAP client ID.

*UMA Script configuration*

12. SCRIPT_TYPE: Type of UMA RPT policy script. which set type in oxScriptType attribute in ldap

*OpenID Client Configuration using [oxd-https-extension](https://gluu.org/docs/oxd/3.1.1/oxd-https/install/)*

13. OXD_ID: Use to set OXD ID. You need to create client using [oxd-https-extension](https://gluu.org/docs/oxd/3.1.1/oxd-https/install/)
14. OP_HOST: kongAPIGateway is OP specific so it's use this OP_HOST for authentication.
15. CLIENT_ID: Use to set the OpenID client Id. It's use at the time of getting client token process([get-client-token](https://gluu.org/docs/oxd/3.1.1/oxd-https/api/#get-client-token))
16. CLIENT_SECRET: Use to set the OpenID client secret. It's use at the time of getting client token process([get-client-token](https://gluu.org/docs/oxd/3.1.1/oxd-https/api/#get-client-token)) 
17. OXD_WEB: kongAPIGateway use oxd-https-extension so only need to give the oxd web url to use oxd-https-extension.

*[KONG](https://getkong.org) Configuration*

18. KONG_URL: This is the kong web url for access the kong Admin API's. [See details here for kong proxy](https://getkong.org/docs/0.10.x/proxy/)

## Installation
This is assumed that node and npm are installed on the machine.

 * node js
 * npm
 
For installing node and npm please refer [here](https://nodejs.org/en/download/package-manager/).

Clone the repository and move to cloned directory and hit:

```npm install```

This will install all the dependencies for the project.

To start the project hit:  

```node index.js```

This will start the project.

## SSL Settings

For run application on https you need to give the ssl certificate in option on index.js
```
var options = {
  key: fs.readFileSync('key.pem'),
  cert: fs.readFileSync('cert.pem'),
  requestCert: true,
  rejectUnauthorized: false,
  ca: [fs.readFileSync('careq.pem')]
};
```

For LDAPS you need to configured the tlsOptions in /ldap/client.js file
```
var tlsOptions = {
    key: fs.readFileSync('key.pem'),
    cert: fs.readFileSync('cert.pem'),
    ca: [ fs.readFileSync('cacert.pem'), {encoding: 'utf-8'} ],
  };

```

## API

### Manage KONG Resources Endpoint
REST full api endpoint for add resource(API) in kong.

1. GET All API REQUEST
```
GET /api/apis
Header Authorization: Bearer {{token}}
```

RESPONSE
```
{
    "data": [
        {
            "http_if_terminated": true,
            "id": "8a0886c8-ae21-4fd5-9a14-8393c923ae44",
            "retries": 5,
            "preserve_host": false,
            "created_at": 1507128209300,
            "upstream_connect_timeout": 60000,
            "upstream_url": "https://gluu.local.org:8008/app",
            "upstream_send_timeout": 60000,
            "https_only": false,
            "upstream_read_timeout": 60000,
            "strip_uri": true,
            "name": "gluu",
            "hosts": [
                "gluu.local.org"
            ]
        }
    ],
    "total": 1
}
```
2. Add API REQUEST
```
POST /api/apis
Header Authorization: Bearer {{token}}
Body
{
    "name": "gluu",
    "upstream_url": "https://your-app.com",
    "hosts": ["gluu.local.org"]
}
```

RESPONSE
```
{
            "http_if_terminated": true,
            "id": "8a0886c8-ae21-4fd5-9a14-8393c923ae44",
            "retries": 5,
            "preserve_host": false,
            "created_at": 1507128209300,
            "upstream_connect_timeout": 60000,
            "upstream_url": "https://gluu.local.org:8008/app",
            "upstream_send_timeout": 60000,
            "https_only": false,
            "upstream_read_timeout": 60000,
            "strip_uri": true,
            "name": "gluu",
            "hosts": [
                "gluu.local.org"
            ]
}
```

3. Update API REQUEST
```
PUT /api/apis
Header Authorization: Bearer {{token}}
Body
{
    "id": "8a0886c8-ae21-4fd5-9a14-8393c923ae44",
    "name": "gluu",
    "upstream_url": "https://your-app.com",
    "hosts": ["gluu.local.org"]
}
```

RESPONSE
```
{
            "http_if_terminated": true,
            "id": "8a0886c8-ae21-4fd5-9a14-8393c923ae44",
            "retries": 5,
            "preserve_host": false,
            "created_at": 1507128209300,
            "upstream_connect_timeout": 60000,
            "upstream_url": "https://gluu.local.org:8008/app",
            "upstream_send_timeout": 60000,
            "https_only": false,
            "upstream_read_timeout": 60000,
            "strip_uri": true,
            "name": "gluu",
            "hosts": [
                "gluu.local.org"
            ]
}
```

4. Delete API Request
```
DELETE /api/apis/:id
Header Authorization: Bearer {{token}}
```

RESPONSE
```
HTTP 204 NO CONTENT
```

### Manage UMA RPT Script Endpoints

1. GET All Script REQUEST
```
GET /api/scripts
Header Authorization: Bearer {{token}}
```

RESPONSE
```
[
    {
        "displayName": "uma_rpt_policy",
        "inum": "@!E50B.8593.F4E0.879A!0001!8868.855A!0011!2DAF.F995",
        ...
    },
    {
        "displayName": "test_rpt_policy",
        "inum": "@!E50B.8593.F4E0.879A!0001!8868.855A!0011!2DAF.F996",
        ...
    }
]

```
2. Add Script REQUEST

```
POST /api/scripts
Header Authorization: Bearer {{token}}
Body
{
    "name": "test_policy",
    "description": "UMA RPT Policy",
    "status": true,
    "keyValues": [
        {
            "key": "email",
            "value": "test@example.com",
            "claimDefinition": `{
                                           "issuer" : [ "%1$s" ],
                                           "name" : "country",
                                           "claim_token_format" : [ "http://openid.net/specs/openid-connect-core-1_0.html#IDToken" ],
                                           "claim_type" : "string",
                                           "friendly_name" : "country"
                                }`
        }
    ]
}
```

RESPONSE
```
{
    "result": true
}
```

3. Update Script REQUEST
```
PUT /api/scripts/:inum
Header Authorization: Bearer {{token}}
Body
{
    "name": "test_policy",
    "description": "UMA RPT Policy",
    "status": true,
    "keyValues": [
        {
            "key": "email",
            "value": "test@example.com",
            "claimDefinition": `{
                                           "issuer" : [ "%1$s" ],
                                           "name" : "country",
                                           "claim_token_format" : [ "http://openid.net/specs/openid-connect-core-1_0.html#IDToken" ],
                                           "claim_type" : "string",
                                           "friendly_name" : "country"
                                }`
        }
    ]
}
```

RESPONSE
```
{
    "result": true
}
```

4. Delete API Request
```
DELETE /api/scripts/:id
Header Authorization: Bearer {{token}}
```

RESPONSE
```
{
    "result": true
}
```

5. Get Script by Inum
```
GET /api/scripts/:inum
Header Authorization: Bearer {{token}}
```

RESPONSE
```
{
        "displayName": "uma_rpt_policy",
        "inum": "@!E50B.8593.F4E0.879A!0001!8868.855A!0011!2DAF.F995",
        ...
}
```

3. Manage Scope

1. GET All Scope REQUEST
```
GET /api/scopes
Header Authorization: Bearer {{token}}
```

RESPONSE
```
[
    {
        "dn": "inum=@!E50B.8593.F4E0.879A!0001!8868.855A!0010!8CAD.B06D,ou=scopes,ou=uma,o=@!E50B.8593.F4E0.879A!0001!8868.855A,o=gluu",
        "displayName": "SCIM Access",
        "inum": "@!E50B.8593.F4E0.879A!0001!8868.855A!0010!8CAD.B06D",
        ...
    },
    {
        "dn": "inum=@!E50B.8593.F4E0.879A!0001!8868.855A!0010!8CAD.B06E,ou=scopes,ou=uma,o=@!E50B.8593.F4E0.879A!0001!8868.855A,o=gluu",
        "displayName": "Passport Access",
        "inum": "@!E50B.8593.F4E0.879A!0001!8868.855A!0010!8CAD.B06E",
        ...
    }
]
```

2. Add Script into scopes

```
POST /api/scopes
Header Authorization: Bearer {{token}}
Body
{
    scopeInums: [Array of scope inums],
    scriptInum: "script Inum..."
}
```
