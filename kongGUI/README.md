# KongGUI Angular admin panel front-end framework

## Installation
```
npm install
```

## Run for development
```
gulp serve
```

## Deploy on server

Changed the constants in [app.js](https://github.com/GluuFederation/kong-plugins/blob/master/kongGUI/src/app/app.js)
```
 .constant('urls', {
   AUTH_URL: 'https://{{server_url}}/login.html',
   KONG_NODE_API: 'https://{{kongAPIGateway_url}}'
 })
```

Use the `gulp build` command to create the build. It's create the `release` folder. It is like html project and we can deploy it on any http server.
```
gulp build
```

## Sequence flow of system
![Sequence flow](../doc/kong-uma-rs.png)

## Guide for kongGUI

## 1. Welcome page
After successful authentication the administrator is taken to the Dashboard.
![Sequence flow](../doc/home.png)

## 2. Register resources
From Register resources tab you can create or register your resources(e.g web application, API application) in the kong.
After registration you can use [kong proxy](https://getkong.org/docs/0.11.x/proxy/) to access your resources.

* Registered resources list
![Resource list](../doc/api-list.png)

* Add resource
![Add Resource](../doc/add-api.png)
     
## 3. kong UMA RS 
From this tab you can config [kong-uma-rs](https://github.com/GluuFederation/kong-plugins/tree/master/kong-uma-rs).
After configured the plugin, you can not access the resources directly. [Read more...](https://github.com/GluuFederation/kong-plugins/tree/master/kong-uma-rs#verify-that-your-api-is-protected-by-kong-uma-rs) 
![UMA-RS](../doc/uma-rs.png)

## 4. UMA Script
From this tab you can create the UMA RPT policy and assign it to scopes
* List of UMA RPT policies
There are 4 buttons. 
    1. Add script into the scopes
    2. See the sample of script
    3. Edit the script
    4. Delete the script

![UMA-RS](../doc/uma-rpt-policy-list.png)

* Add policy script
This create the automatic UMA RPT policy.
![Add-policy-script](../doc/add-policy-script.png)

* Add Script into scope
You can select multiple scope to add script into it.
![Add-policy-script](../doc/add-scope.png)
