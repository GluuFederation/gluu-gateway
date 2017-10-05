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

