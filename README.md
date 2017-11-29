# gluu-gateway

## Introduction

* The gluu-gateway is the platform for protecting resources(Web application or API application) using the [Kong](https://getkong.org) plugins and proxy with konga GUI.

* Functions provided by gluu-gateway 
    1. Add Resources(API) in kong
    2. Config and add plugins in registered resources(API)
    3. Provide kong proxy endpoint to access and protect resources
    4. Make [custom UMA RPT Policy](https://gluu.org/docs/ce/3.1.1/admin-guide/uma/#uma-rpt-authorization-policies)
 

* gluu-gateway has three components
    1. **[kong](https://getkong.org/)**: The open-source API Gateway and Microservices Management Layer, delivering high performance and reliability.

    2. **Plugins**: There are two Gluu Kong plugins for resource protection. 

        1. **[kong-openid-rp](/kong-openid-rp)**: kong-openid-rp is the OpenID Connect RP kong plugin. This allows you to protect your Resources(API) with the [OpenID Connect](https://gluu.org/docs/ce/admin-guide/openid-connect/) OAuth-based identity protocol.
 
        2. **[kong-uma-rs](/kong-uma-rs)**: kong-uma-rs is the Gluu UMA RS kong plugin. This allows you to protect your Resources(API) with the [UMA](https://kantarainitiative.org/confluence/display/uma/Home) OAuth-based access management protocol.

    3. **[konga](https://github.com/GluuFederation/kong-plugins/tree/master/konga)**:  This provides GUI for communicating with [kong Admin API](https://getkong.org/docs/0.11.x/admin-api/) to add resources(API), add a plugin, UMA RPT policy script and add this script into the scopes.

## Manually Installation

1. [Install kong](https://getkong.org/install) Version: 0.11.0
    
    Kong provides several packages as per different platform. [Here kong installation](https://getkong.org/install) Version: 0.11.0 guide as per platform.

    !! Note: kong supports two databases Postgres 9.4 and Cassandra. [Here](https://getkong.org/docs/0.11.x/configuration/#datastore-section) is the configuration detail.

2. [oxd (oxd-server and oxd-https-extension)](https://gluu.org/docs/oxd/3.1.1/) Version: 3.1.1
    
    oxd installation [click here](https://gluu.org/docs/oxd/3.1.1/install/)

4. [Install kong-uma-rs](https://github.com/GluuFederation/kong-plugins/tree/master/kong-uma-rs)
    1. Stop kong : `kong stop`
    2. 
        Using luarocks `luarocks install kong-uma-rs`.
        
        It also required some luarocks packages. you need to install those package also.
        
        `luarocks install kong-uma-rs`

        `luarocks install stringy`
        
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

    !! Note: kong supports two databases Postgres 9.4 and Cassandr

2. Install GLUU-GATEWAY Package

3. Run setup-gluu-gateway.py

    Configuration is completed by running the setup-gluu-gateway.py script. This generates certificates and renders configuration files.

    ```
    # python setup-gluu-gateway.py
    ```
    
    You will be prompted to answer some questions. Just hit Enter to accept the default value specified in square brackets. The following table should help you answer the questions correctly.
    
    | Question | Explanation |
    |----------|-------------|
    | Enter IP Address | IP Address for kong configuration |
    | Enter Kong hostname | Internet-facing hostname, FQDN, or CNAME whichever your organization follows to be used to generate certificates and metadata. Do not use an IP address or localhost. |
    | Country | Used to generate certificates |
    | State | Used to generate certificates |
    | City | Used to generate certificates |
    | Organization | Used to generate certificates |
    | email | Used to generate certificates |
    | Enter password | Used for postgres database configuration.If you have already postgres user password then enter existing password otherwise enter new password. |
    | Would you like to configure oxd-server? | Default is yes. You can configured oxd server or skip it. If you select yes then next 6 properties will ask to enter details |
    | OP(OpenId provider) server | Used to set your OpenID provider server for oxd-server |
    | License Id | Used to set License Id for oxd-server |
    | Public key | Used to set Public key for oxd-server |
    | Public password | Used to set Public password for oxd-server |
    | License password | Used to set License password for oxd-server |
    | Authorization redirect uri | Used to set Authorization redirect uri for oxd-server default configuration |
    | oxd web URL | Used to set oxd-https-extensions. which used to create OpenID client for konga. |
    | Would you like to generate client_id/client_secret? | Default is yes. You can make new OpenID Client or enter manually. |
    | oxd_id | Used to set oxd id for konga |
    | client_id | Used to set client id for konga |
    | client_secret | Used to set client secret for konga |
    | OP(OpenId provider) server | Used to set OpenId provider server for konga |
    | Authorization redirect uri | Used to set authorization redirect uri to authenticate konga |
    | Kong Admin URL | Used to set kong admin URL used by konga |

4. Start konga

    ```
    https://your.domain.com:1338
    ```

    > Note: After login, Go to `connection` tab and create connections to Kong Nodes and select the one to use by clicking on the respective star icon.

    If you want to change the konga port then use configuration /opt/gluu-gateway/konga/config/local.js file.
    There are following properties which used to configure konga.

    | Properties | Explanation |
    |----------|-------------|
    | kong_admin_url | Used to set default connection to kong admin url. |
    | connections | Used to set the postgres connection porperties. |
    | models | Used to set the database adapter for konga. By default is postgres. |
    | session | Used to secret key for your JWT token. |
    | ssl | Used to set ssl certificate path to run application on https. If you don't want https then comment this properties. |
    | port | Used to set port number for run konga |
    | environment | Used to set environment. By default is development. |
    | log | Used to set konga log level. |
    | oxdWeb | Used to set oxd-https-extensions url. |
    | opHost | Used to set OpenId provider server for konga |
    | oxdId | Used to set oxd id for konga |
    | clientId | Used to set client id for konga |
    | clientSecret | Used to set client secret for konga |
    | oxdVersion | Used to set oxd server version |
