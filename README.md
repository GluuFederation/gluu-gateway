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

## Manually Installation

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

5. Install konga

    konga installation [click here](https://github.com/GluuFederation/kong-plugins/tree/master/konga)    

## Installation using Setup script

1. [Install kong](https://getkong.org/install) Version: 0.11.0
    
    Kong provides several packages as per different platform. [Here kong installation](https://getkong.org/install) Version: 0.11.0 guide as per platform.

    !! Note: kong supports two databases Postgres and Cassandr

2. Install GLUU-GATEWAY Package

3. Run setup-gluu-gateway.py

    Configuration is completed by running the setup-gluu-gateway.py script. This generates certificates and renders configuration files.

    ```
    # python setup-gluu-gateway.py
    ```
    
    You will be prompted to answer some questions. Just hit Enter to accept the default value specified in square brackets. The following table should help you answer the questions correctly.
    
    | Question | Explanation |
    |----------|-------------|
    | Enter IP Address | IP Address |
    | Enter Kong hostname | Internet-facing hostname, FQDN, or CNAME whichever your organization follows to be used to generate certificates and metadata. Do not use an IP address or localhost. |
    | Country | Used to generate certificates |
    | State | Used to generate certificates |
    | City | Used to generate certificates |
    | Organization | Used to generate certificates |
    | email | Used to generate certificates |
    | Enter password | Used for postgres database configuration.If you have already postgres user password then enter existing password otherwise enter new password. |
    | Would you like to configure oxd-server? | Default is yes. You can configured oxd server or skip it. | 
    | oxd web URL | Used to set oxd-https-extensions. which used to create OpenID client for konga. |
    | Would you like to generate client_id/client_secret? | Default is yes. You can make new OpenID Client or enter manually. |
    | OP(OpenId provider) server | Used to set OpenId provider server for konga |
    | Authorization redirect uri | Used to set authorization redirect uri to authenticate konga |
    | Kong Admin URL | Used to set kong admin URL used by konga |