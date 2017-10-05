# Kong Plugins

[KONG](https://getkong.org) plugins for Gluu's [OpenID Connect and UMA client software](https://gluu.org/docs/oxd). 

## [OpenID Connect RP plugin](/kong-openid-rp)

[Kong](https://getkong.org) plugin that allows you to protect your API (which is proxied by Kong) with the [OpenID Connect](https://gluu.org/docs/ce/admin-guide/openid-connect/) OAuth-based identity protocol.

## [UMA RS plugin](/kong-uma-rs)

[Kong](https://getkong.org) plugin that allows you to protect your API (which is proxied by Kong) with the [UMA](https://kantarainitiative.org/confluence/display/uma/Home) OAuth-based access management protocol.

## Installation

1. [Install kong](https://getkong.org/install)
    Start kong
    ```
    kong start
    ```
2. [oxd (oxd-server and oxd-https-extension)](https://gluu.org/docs/oxd/3.1.1/)
3. [Install kongAPIGateway]()
4. [Install kong-uma-rs](https://github.com/GluuFederation/kong-plugins/tree/master/kong-uma-rs)
5. [Install kongGUI](https://github.com/GluuFederation/kong-plugins/tree/master/kongGUI)

## Sequence flow of system
![Sequence flow](/doc/kong-uma-rs.png)

## Guide for kongGUI

## 1. Welcome page
After successful authentication the administrator is taken to the Dashboard.
![Sequence flow](/doc/home.png)

## 2. Register resources
From Register resources tab you can create or register your resources(e.g web application, API application) in the kong.
After registration you can use [kong proxy](https://getkong.org/docs/0.11.x/proxy/) to access your resources.

* Registered resources list
![Resource list](/doc/api-list.png)

* Add resource
![Add Resource](/doc/add-api.png)
     
## 3. kong UMA RS 
From this tab you can config [kong-uma-rs](https://github.com/GluuFederation/kong-plugins/tree/master/kong-uma-rs).
After configured the plugin, you can not access the resources directly. [Read more...](https://github.com/GluuFederation/kong-plugins/tree/master/kong-uma-rs#verify-that-your-api-is-protected-by-kong-uma-rs) 
![UMA-RS](/doc/ums-rs.png)

## 4. UMA Script
From this tab you can create the UMA RPT policy and assign it to scopes
* List of UMA RPT policies
There are 4 buttons. 
    1. Add script into the scopes
    2. See the sample of script
    3. Edit the script
    4. Delete the script

![UMA-RS](/doc/uma-rpt-policy-list.png)

* Add policy script
This create the automatic UMA RPT policy.
![Add-policy-script](/doc/add-policy-script.png)

* Add Script into scope
You can select multiple scope to add script into it.
![Add-policy-script](/doc/add-policy-script.png)
