## Introduction

* The Gluu Gateway is the platform for protecting resources (Web application or API application) using the [Kong](https://getkong.org) plugins and proxy with konga GUI.

* Functions provided by gluu-gateway
    1. Add Resources(API) in kong
    2. Config and add plugins in registered resources(API)
    3. Provide kong proxy endpoint to access and protect resources
    4. Make [custom UMA RPT Policy](https://gluu.org/docs/ce/3.1.1/admin-guide/uma/#uma-rpt-authorization-policies)


* Gluu Gateway has four components:
1. **[kong](https://getkong.org/)**: The open-source API Gateway and Microservices Management Layer, delivering high performance and reliability.
2. **[UMA Plugin](https://github.com/GluuFederation/gluu-gateway/tree/master/kong-uma-rs)**: Protect your resources by using UMA resource protection.
3. **[konga](https://github.com/GluuFederation/kong-plugins/tree/master/konga)**:  An admin GUI for calls [Kong admin API's](https://getkong.org/docs/0.11.x/admin-api/)
4. **[oxd](https://oxd.gluu.org)**: (optional) OAuth client service. It can be run locally or you can use an existing oxd server which is available via HTTPS.

## Package Installation using Gluu repo
```
1. Add Gluu repo:
   # echo "deb https://repo.gluu.org/ubuntu/ trusty-devel main" > /etc/apt/sources.list.d/gluu-repo.list
   # curl https://repo.gluu.org/ubuntu/gluu-apt.key | apt-key add -

2. Add openjdk-8 PPA:
   # add-apt-repository ppa:openjdk-r/ppa

3. Add Postgresql repo:
   # echo "deb http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main" > /etc/apt/sources.list.d/psql.list
   # wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

4. Add Kong repo:
   # echo "deb https://kong.bintray.com/kong-community-edition-deb trusty main" > /etc/apt/sources.list.d/kong.list
   
5. Update your system and install the package:
   # apt-get update
   # apt-get install gluu-gateway
```


## Run Setup script

```
# cd /opt/gluu-gateway/setup
# python setup-gluu-gateway.py
```

You will be prompted to answer some questions. Just hit Enter to accept the default value, specified in square brackets. The following table should help you answer the questions correctly.

| Question | Explanation |
|----------|-------------|
| Enter IP Address | IP Address for kong configuration. |
| Enter Kong hostname | Internet-facing hostname, FQDN, or CNAME whichever your organization follows to be used to generate certificates and metadata. Do not use an IP address or localhost. |
| Country | Used to generate X.509 certificate for kong and konga. |
| State | Used to generate certificate for kong and konga. |
| City | Used to generate certificate for kong and konga. |
| Organization | Used to generate certificate for kong and konga. |
| Email | Used to generate certificate for kong and konga. |
| Enter password | Used for postgres database configuration. If you have already postgres user password then enter existing password otherwise enter new password. |
| Would you like to configure oxd-server? | If you have a pre-registered client, you can enter it here. |
| OP hostname | The hostname of your Gluu Sever (i.e. `your.domain.com`). |
| License Id | For oxd-server |
| Public key | For oxd-server |
| Public password | For oxd-server |
| License password | For oxd-server |
| oxd web url | Used to configure konga for the oxd-https-extension. |
| Would you like to generate client_id/client_secret for konga? | You can register a new OpenID Client or enter manually enter existing client credentials. |
| oxd_id | Used to manually set oxd id for konga. |
| client_id | Used to manually set client id for konga. |
| client_secret | Used to manually set client secret for konga. |

When you're done, point your browser to https://your.domain.com:1338

> Note: After login, Go to `connection` tab and create connections to Kong Nodes and select the one to use by clicking on the respective star icon.
