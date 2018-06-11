#Gluu Gateway UMA study case.


### 1. Parties

![alt text](uma.png "Logo Title Text 1")

### 2. Flow
![alt text](flow.png "Logo Title Text 1")

### 3. RS Configuration
RS configuration can be done either via REST calls or via GluuGateway GUI
#### REST Configuration
1. Resource configuration (Kong API configuration)
````
curl -X POST http://gg.example.com:8001/apis 
    --data "name=demo_api" 
    --data "hosts=demo_host" 
    --data "upstream_url=https://gluu.org"
````

2. Configuration of oAuth plugin

````
curl -X POST http://gg.example.com:8001/apis/demo_api/plugins 
    --data "name=gluu-oauth2-client-auth" 
    --data "config.op_server=https://ce-gluu.example.com" 
    --data "config.oxd_http_url=https://localhost:8443"

````

3. Securing RS with UMA

````
curl -X POST --url http://gg.example.com:8001/apis/demo_api/plugins/ 
    --data "name=gluu-oauth2-rs" 
    --data "config.oxd_host=https://localhost:8443" 
    --data "config.uma_server_host=https://ce-gluu.example.com" 
    --data "config.protection_document=[ { \"path\": \"<YOUR_PATH>\", \"conditions\": [ { \"httpMethods\": [ \"GET\" ], \"scope_expression\": { 
    \"rule\": { \"and\": [ { \"var\": 0 } ] }, \"data\": [ \"http://photoz.example.com/dev/actions/view\" ] } } ] } ]"`
````

protection_document (pretty printed)
```json
[
  {
    "path": "<YOUR_PATH>",
    "conditions": [
      {
        "httpMethods": [
          "GET"
        ],
        "scope_expression": {
          "rule": {
            "and": [
              {
                "var": 0
              }
            ]
          },
          "data": [
            "<YOUR_SCOPE>"
          ]
        }
      }
    ]
  }
]
```
From the last call you get oxd_id, client_id and client_secret

#### Gluu Gateway GUI configuration
1. Resource configuration (Kong API configuration)
* Enter https://gg.example.com:1338/#!/apis
* Click "Add new API"
* Fill required fields

2. Configuration of oAuth plugin
* Click edit icon of created API
* Click plugins button in left menu
* Add new plugin
* Select custom
* Click plus icon in Gluu oauth2 client auth plugin

3. Securing RS with UMA
* Click security button in API list
* Fill UMA resource fields
* Update configuration

### 4. UMA client registration
UMA client registraion can be done either via REST calls or via GluuGateway GUI

#### REST Configuration
4. Register consumer
````
curl -X POST http://gg.example.com:8001/consumers/ 
    --data "username=uma_client"
````
5. Register UMA credentials
````
curl -X POST http://gg.example.com:8001/consumers/uma_client/gluu-oauth2-client-auth/ 
    --data name="uma_consumer_cred" 
    --data op_host="ce-gluu.example.com" 
    --data oxd_http_url="https://localhost:8443" 
    --data uma_mode=true
````
From the last call you get oxd_id, client_id and client_secret
#### Gluu Gateway GUI configuration
4. Register consumer
* Enter https://gg.example.com:1338/#!/consumers
* Click create consumer
* Fill new consumer form

5. Register UMA credentials
* Click on created consumer
* Click on credentials
* Select OAUTH2
* Click Create Credentials
* Select UMA Mode in Credentials form
* Save credentials


### 5. Call UMA protected API
6. LogIn Consumer
 ````
 curl -X POST https://gg.example.com:8443/get-client-token 
     --data oxd_id="<YOUR_OXD_ID>" 
     --data client_id="<YOUR_CLIENT_ID>" 
     --data client_secret="<YOUR_CLIENT_SECRET>" 
 ````
 From this call you get Consumer accessToken

 7. LogIn UmaResource
  ````
  curl -X POST https://gg.example.com:8443/get-client-token 
      --data oxd_id="<YOUR_UMA_OXD_ID>" 
      --data client_id="<YOUR_UMA_CLIENT_ID>" 
      --data client_secret="<YOUR_UMA_CLIENT_SECRET>" 
  ````
From this call you get resource accessToken

8. Get resource ticket
  ````
  curl -X POST https://gg.example.com:8443/uma-rs-check-access
      --Header "Authorization Bearer <UMA_RESOURCE_TOKEN>"
      --Header "Content-Type: application/json" 
      --data '{"oxd_id": "<YOUR_UMA_OXD_ID>","rpt":"","path":"<YOUR_RESOURCE_PATH>,"http_method" : "<YOUR_RESOURCE_METHOD>" }
'
  ````
 From this call you get ticket
  
9. Get RPT token
  ````
  curl -X POST https://gg.example.com:8443/uma-rp-get-rpt
      --Header "Authorization Bearer <CONSUMER_TOKEN>"
      --Header "Content-Type: application/json" 
      --data '{"oxd_id": "<YOUR_CONSUMER_OXD_ID>","ticket":"<YOUR_TICKET>"}'
````
From this call you get accesstoken (RPT)

10. Call UMA protected API
  ````
  curl -X GET http://gg.example.com:8000/<YOUR_PATH>
      --Header "Authorization: Bearer <YOUR_RPT>"
      --Header "Host: <YOUR_HOST>" 
````

### 6. UMA flow with claims gathering
8.1. Prerequisites 
* UMA scope with Authorization Policy 
![alt text](uma_scope.png "Logo Title Text 1")
* Enabled UMA RPT Polices & UMA Claims Gathering
![alt text](scripts.png "Logo Title Text 1")
* Register RS with correct scope

8.2. Getting need_info ticket
  ````
  curl -X POST https://gg.example.com:8443/uma-rp-get-rpt
      --Header "Authorization Bearer <CONSUMER_TOKEN>"
      --Header "Content-Type: application/json" 
      --data '{"oxd_id": "<YOUR_CONSUMER_OXD_ID>","ticket":"<YOUR_TICKET>","scope":[<YOUR_SCOPE>]}'
````
From this call you get need_info ticket

8.3. Getting claims gathering url
  ````
  curl -X POST https://gg.example.com:8443/uma-rp-get-claims-gathering-url"
      --Header "Authorization Bearer <CONSUMER_TOKEN>"
      --Header "Content-Type: application/json" 
      --data '{"oxd_id": "<YOUR_CONSUMER_OXD_ID>","ticket":"<YOUR_TICKET>",""claims_redirect_uri"":[<YOUR_CLAIMS_URI>]}'
````
From this call you get ticket

8.4. Enter gathering url in browser
    
You may need to add your claims redirect url to your client configuration in CE

Continue to 9.