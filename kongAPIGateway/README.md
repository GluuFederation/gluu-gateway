# KONG API Gateway

KONG API Gateway provides API endpoint for configured kong API and plugin and also make UMA RPT policy and added it to scope. 

## Configuration
The `.env-dev` property file is used to configured the application. 

**Server configuration**

1. PORT: This property is used to set port number on which the application is run. 
2. BASE_URL: This property contains the application base URL.
4. APP_SECRET: This property contains application secret for JWT key generation and verification.
5. JWT_EXPIRES_IN: This property is used to set the JWT token expiration time. [Details..](https://www.npmjs.com/package/jsonwebtoken).

**Ldap Configuration**

6. LDAP_MAX_CONNS: This property used to set maximum connection for ldap. Example: LDAP_MAX_CONNS=10
7. LDAP_SERVER_URL: This property used to set LDAP server URL. Example: ldaps://localhost:1636
8. LDAP_BIND_DN: The Username for the authentication server (local LDAP/remote LDAP/remote Active Directory) goes here. Example: LDAP_BIND_DN=cn=directory manager,o=gluu
9. LDAP_BIND_CREDENTIALS: This property contains the LDAP connection credential(password).
10. LDAP_LOG_LEVEL: This property is used to set log level. Example: debug, error, info
11. LDAP_CLIENT_ID: This property contains the LDAP client ID.

**UMA Script configuration**

12. SCRIPT_TYPE: This property contains a type of UMA RPT policy script. which set type in the oxScriptType attribute in LDAP.

**OpenID Client Configuration using [oxd-https-extension](https://gluu.org/docs/oxd/3.1.1/oxd-https/install/)**

You need to first create the client using oxd-https-extension for the set below properties. 

13. OXD_ID: This property contains OXD ID.
14. OP_HOST: This property contains the OpenID provider address. kongAPIGateway is OP specific.
15. CLIENT_ID: This property contains the OpenID connect client Id. It uses at the time of getting client token process([get-client-token](https://gluu.org/docs/oxd/3.1.1/oxd-https/api/#get-client-token))
16. CLIENT_SECRET: This property contains the OpenID connect client secret. It uses at the time of getting client token process([get-client-token](https://gluu.org/docs/oxd/3.1.1/oxd-https/api/#get-client-token)) 
17. OXD_WEB: This is use to set oxd-https-extension's web address(URL).

**[KONG](https://getkong.org) Configuration**

18. KONG_URL: This is the kong web URL for accessing the kong Admin API's. [See details here for kong proxy](https://getkong.org/docs/0.10.x/proxy/)

## Installation
This is assumed that node and npm are installed on the machine.

 * node js >= 6.9.x version
 * npm >= 3.10.x version
 
For installing node and npm please refer [here](https://nodejs.org/en/download/package-manager/).

1. Clone the repository and move to cloned directory and hit:

    ```
    npm install
    ```

    This will install all the dependencies for the project.

2. To start the project:  

    ```
    node index.js
    ```

    This will start the project.

## SSL Settings

For run application on https, you need to give the SSL certificate in option on index.js
```
var options = {
  key: fs.readFileSync('key.pem'),
  cert: fs.readFileSync('cert.pem'),
  requestCert: true,
  rejectUnauthorized: false,
  ca: [fs.readFileSync('careq.pem')]
};
```

For LDAPS you need to configure the tlsOptions in /ldap/client.js file
```
var tlsOptions = {
    key: fs.readFileSync('key.pem'),
    cert: fs.readFileSync('cert.pem'),
    ca: [ fs.readFileSync('cacert.pem'), {encoding: 'utf-8'} ],
  };

```

## API

### Manage KONG Resources Endpoint
REST full API endpoint for add resource(API) in the kong.

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

### Manage Scope

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
