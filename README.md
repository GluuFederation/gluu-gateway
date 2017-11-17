# oxd-kong

## Introduction

* The oxd-kong is the platform for protecting resources(Web application or API application) using the [Kong](https://getkong.org) plugins and proxy. This provides kong-GUI to registered the resources, add resource protection plugins, make custom UMA RPT policy script and provide a kong proxy to protect the resources using the registered plugin in resources. 

* Functions provided by oxd-kong 
    1. Add Resources(API) in kong
    2. Config and add plugins in registered resources(API)
    3. Provide kong proxy endpoint to access and protect resources
    4. Make [custom UMA RPT Policy](https://gluu.org/docs/ce/3.1.1/admin-guide/uma/#uma-rpt-authorization-policies)
 

* oxd-kong has three components
    1. **[kong](https://getkong.org/)**: The open-source API Gateway and Microservices Management Layer, delivering high performance and reliability.

    2. **Plugins**: There are two Gluu Kong plugins for resource protection. 

        1. **[kong-openid-rp](/kong-openid-rp)**: kong-openid-rp is the OpenID Connect RP kong plugin. This allows you to protect your Resources(API) with the [OpenID Connect](https://gluu.org/docs/ce/admin-guide/openid-connect/) OAuth-based identity protocol.
 
        2. **[kong-uma-rs](/kong-uma-rs)**: kong-uma-rs is the Gluu UMA RS kong plugin. This allows you to protect your Resources(API) with the [UMA](https://kantarainitiative.org/confluence/display/uma/Home) OAuth-based access management protocol.

    3. **[oxd-kong](https://github.com/GluuFederation/kong-plugins/tree/master/oxd-kong)**:  This provides GUI for communicating with [kong Admin API](https://getkong.org/docs/0.11.x/admin-api/) to add resources(API), add a plugin, UMA RPT policy script and add this script into the scopes.

## Installation

1. [Install kong](https://getkong.org/install) Version: 0.11.0
    
    Kong provides several packages as per different platform. [Here kong installation](https://getkong.org/install) Version: 0.11.0 guide as per platform.

    !! Note: kong supports two databases Postgres and Cassandra. [Here](https://getkong.org/docs/0.11.x/configuration/#datastore-section) is the configuration detail.

2. [oxd (oxd-server and oxd-https-extension)](https://gluu.org/docs/oxd/3.1.1/) Version: 3.1.1
    
    oxd installation [click here](https://gluu.org/docs/oxd/3.1.1/install/)

4. [Install kong-uma-rs](https://github.com/GluuFederation/kong-plugins/tree/master/kong-uma-rs)
    1. Stop kong : `kong stop`
    2. 
        Using luarocks `luarocks install kong-uma-rs`.
        
        It also required some luarocks packages. you need to install those package also.
        
        `luarocks install kong-uma-rs`
        
        `luarocks install oxd-web-lua`
        
        `luarocks install json-lua`
        
        `luarocks install lua-cjson`
            
    3. Enable plugin in your `kong.conf` (typically located at `/etc/kong/kong.conf`) and start kong `kong start`.
    
    ```
        custom_plugins = kong-uma-rs
    ```
    Detail description [click here](https://github.com/GluuFederation/kong-plugins/tree/master/kong-uma-rs)

5. Install oxd-kong

    oxd-kong installation [click here](https://github.com/GluuFederation/kong-plugins/tree/master/oxd-kong)    
