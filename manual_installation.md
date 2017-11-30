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

## Konga config

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
