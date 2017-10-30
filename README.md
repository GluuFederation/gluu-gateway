# Gluu-oxd-kong

## Introduction

* The Gluu-oxd-kong is the platform for protecting resources(Web application or API application) using the [Kong](https://getkong.org) plugins and proxy. This provides kong-GUI to registered the resources, add resource protection plugins, make custom UMA RPT policy script and provide a kong proxy to protect the resources using the registered plugin in resources. 

* Functions provided by Gluu-oxd-kong 
    1. Add Resources(API) in kong
    2. Config and add plugins in registered resources(API)
    3. Provide kong proxy endpoint to access and protect resources
    4. Make [custom UMA RPT Policy](https://gluu.org/docs/ce/3.1.1/admin-guide/uma/#uma-rpt-authorization-policies)
    5. Allow adding policy script into [UMA Scopes](https://gluu.org/docs/ce/3.1.1/admin-guide/uma/#scopes)

* Gluu-oxd-kong has three components
    1. **[kong](https://getkong.org/)**: The open-source API Gateway and Microservices Management Layer, delivering high performance and reliability.

    2. **Plugins**: There are two Gluu Kong plugins for resource protection. 

        1. **[kong-openid-rp](/kong-openid-rp)**: kong-openid-rp is the OpenID Connect RP kong plugin. This allows you to protect your Resources(API) with the [OpenID Connect](https://gluu.org/docs/ce/admin-guide/openid-connect/) OAuth-based identity protocol.
 
        2. **[kong-uma-rs](/kong-uma-rs)**: kong-uma-rs is the Gluu UMA RS kong plugin. This allows you to protect your Resources(API) with the [UMA](https://kantarainitiative.org/confluence/display/uma/Home) OAuth-based access management protocol.

    3. **[kongAPIGateway](https://github.com/GluuFederation/kong-plugins/tree/master/kongAPIGateway)**:  This provides API endpoint for communicating with [kong Admin API](https://getkong.org/docs/0.11.x/admin-api/) to add resources(API) and plugin into the kong. Also, provide Script endpoint for add UMA RPT policy script and add this script into the scopes.  

    4. **[kongGUI](https://github.com/GluuFederation/kong-plugins/tree/master/kongGUI)**:  This provides GUI for communicating with [kong Admin API](https://getkong.org/docs/0.11.x/admin-api/) to add resources(API), add a plugin, UMA RPT policy script and add this script into the scopes.

## Installation

1. [Install kong](https://getkong.org/install) Version: 0.11.0
    
    Kong provides several packages as per different platform. [Here kong installation](https://getkong.org/install) Version: 0.11.0 guide as per platform.

    !! Note: kong supports two databases Postgres and Cassandra. [Here](https://getkong.org/docs/0.11.x/configuration/#datastore-section) is the configuration detail.

2. [oxd (oxd-server and oxd-https-extension)](https://gluu.org/docs/oxd/3.1.1/) Version: 3.1.1
    
    oxd installation [click here](https://gluu.org/docs/oxd/3.1.1/install/)
 
3. [Install kongAPIGateway](https://github.com/GluuFederation/kong-plugins/tree/master/kongAPIGateway)

    kongAPIGateway installation [click here](https://github.com/GluuFederation/kong-plugins/tree/master/kongAPIGateway)

4. [Install kong-uma-rs](https://github.com/GluuFederation/kong-plugins/tree/master/kong-uma-rs)

    kong-uma-rs installation [click here](https://github.com/GluuFederation/kong-plugins/tree/master/kong-uma-rs)

5. [Install kongGUI](https://github.com/GluuFederation/kong-plugins/tree/master/kongGUI)

    kongGUI installation [click here](https://github.com/GluuFederation/kong-plugins/tree/master/kongGUI)

## Sequence flow of system
![Sequence flow](/doc/kong-uma-rs.png)

## Guide for kongGUI

## 1. Welcome page
After successful authentication, the administrator is taken to the Dashboard.
![Sequence flow](/doc/home.png)

## 2. Register resources
From Register resources tab you can create or register your resources(e.g web application, API application) in the kong.
After registration, you can use [kong proxy](https://getkong.org/docs/0.11.x/proxy/) to access your resources.

* Registered resources list

    We can delete and update resources using `delete` and `edit` button.

![Resource list](/doc/api-list.png)

* Add resource: Click on `Add` button for add new resource. This provides facility to add resources in the kong.

    1.Name: Required, This field contains the name of the resource(API)
    
    2.Upstream URL: Required, The base target URL that points to your API server. This URL will be used for proxying requests. For example https://example.com

    3.Hosts: Required, A list of domain names that point to your API.
    
    * Kong proxy check the host (in HTTP header) and according to host it serves resources
    * If you want to use directly in browser then you need to set same host URL as kong proxy URL
                example: if kong proxy is example.org:8000 then the host must be example.org
    * If we added resources with hostname "test.com" then we must need to passed host key in header with value "test.com" otherwise kong gives error API not found
    
![Add Resource](/doc/add-api.png)
     
## 3. kong UMA RS 
From this tab, you can config [kong-uma-rs](https://github.com/GluuFederation/kong-plugins/tree/master/kong-uma-rs).
After configuring the plugin, you can not access the resources directly. [Read more...](https://github.com/GluuFederation/kong-plugins/tree/master/kong-uma-rs#verify-that-your-api-is-protected-by-kong-uma-rs) 

1. Kong Resource: Required, It displays all the resources in dropdown which we registered using above `Register Resources` step.

2. UMA sever(OP) host: Required, UMA Server that implements UMA 2.0 specification. E.g. https://example.gluu.org (For example Gluu Server). Check that UMA implementation is up and running by visiting .well-known/uma-configuration endpoint. E.g. https://example.gluu.org/.well-known/uma-configuration.

3. UMA Resource: This section contains several fields. You can fill value as per instruction(placeholder) in every field. 

![UMA-RS](/doc/uma-rs.png)

## 4. UMA Script
From this tab, you can create the UMA RPT policy and assign it to scopes
* List of UMA RPT policies
There are 4 buttons. 
    1. Add script into the scopes
    2. See the sample of script
    3. Edit the script
    4. Delete the script

![UMA-RS](/doc/uma-rpt-policy-list.png)

* Add policy script
This creates the automatic UMA RPT policy. You can add multiple claims using `Add new claim` button and also remove it using remove `x`  button.
    
    1. Script name: This field contains the name of the script.
    2. Status: This field is used to set the status for a script. It must be enabled if you want to execute it at the time of getting RPT token.
    3. Description: This field is used to set the description for a script.
    4. Key: It contains the claim key name.
    5. value: It contains the value of the claim.
    
![Add-policy-script](/doc/add-policy-script.png)

* Add Script into scope
You can select multiple scopes to add the script into it.
![Add-policy-script](/doc/add-scope.png)
