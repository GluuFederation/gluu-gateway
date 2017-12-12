## Gluu Gateway

* The Gluu Gateway is the platform for protecting resources (Web application or API application) using the [Kong](https://getkong.org) plugins and proxy with konga GUI.

* Gluu Gateway has four components:
1. **[kong](https://getkong.org/)**: The open-source API Gateway and Microservices Management Layer, delivering high performance and reliability.
2. **[UMA Plugin](https://github.com/GluuFederation/gluu-gateway/tree/master/kong-uma-rs)**: Protect your resources by using UMA resource protection.
3. **[konga](https://github.com/GluuFederation/kong-plugins/tree/master/konga)**:  An admin GUI for calls [Kong admin API's](https://getkong.org/docs/0.11.x/admin-api/)
4. **[oxd](https://oxd.gluu.org)**: (optional) OAuth client service. It can be run locally or you can use an existing oxd server which is available via HTTPS.

## Features

1. Gluu-Gateway uses kong as the proxy gateway. So, It inherits all the features of kong.

| Legacy Architecture | Kong Architecture |
|---------------------|-------------------|
| :x: Common functionality is duplicated across multiple services | :white_check_mark: Kong centralizes and unifies functionality into one place |
| :x: Systems tend to be monolithic and hard to maintain | :white_check_mark: Build efficient distributed architectures ready to scale |
| :x: Difficult to expand without impacting other services | :white_check_mark: Expand functionality from one place with a simple command |
| :x: Productivity is inefficient because of system constraints | :white_check_mark: Your team is focused on the product, Kong does the REST |

2. Gluu gateway provides KONGA GUI to operates kong very easily.

![konga](doc/konga.png)

- Manage all Kong Admin API Objects.
- OAuth 2.0 authentication.
- Import Consumers from remote sources (Databases, files, APIs etc.).
- Manage multiple Kong Nodes.
- Backup, restore and migrate Kong Nodes using Snapshots.
- Monitor Node and API states using health checks.
- Allow to configure kong-uma-rs plugin.

3. Gluu-Gateway provides custom kong-uma-rs plugin. kong-uma-rs plugin dealing with UMA Resource server to registere and validate the resources.

4. Gluu-Gateway uses oxd-server to dealing with OP server for authentication and resource management.


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

5. Add node repo:
   # curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
   
6. Update your system and install the package:
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
| Password | Used for postgres database configuration. If you have already database user(i:e postgres) with password then enter existing password otherwise enter new password. |
| Would you like to configure oxd-server? | If you have already have oxd-server and oxd-https-extension then skip this configuration. |
| OP hostname | The hostname of your Gluu Sever (i.e. `your.domain.com`). |
| License Id | For oxd-server |
| Public key | For oxd-server |
| Public password | For oxd-server |
| License password | For oxd-server |
| oxd web url | Used to configure konga for the oxd-https-extension. Make sure oxd web url(oxd-https-extension) is in the running state, if not then start it manually. |
| Would you like to generate client_id/client_secret for konga? | You can register a new OpenID Client or enter manually enter existing client credentials. If you choose 'y' then make sure oxd web url(oxd-https-extension) is in the running state otherwise it does not allow to make new client. |
| oxd_id | Used to manually set oxd id for konga. |
| client_id | Used to manually set client id for konga. |
| client_secret | Used to manually set client secret for konga. |

```
Gluu Gateway configuration successful!!! https://localhost:1338
```
When you got this above message that means installation done successful. Next, process is to make tunnel to `https://localhost:1338` and use konga. If your port is open then you use konga directly in browser i:e `https://hostname:1338`.

> Note: After login, Go to `connection` tab and select the one to use by clicking on the respective star icon.

## Configuration

### Configure kong
* You can configure kong by using kong.conf file.

```
/etc/kong/kong.conf
```
* Start/Stop/Restart
```
 # service kong [restart|stop|restart|status]
```

### Configure konga
* You can configure konga by setting properties in local.js file. This is used to set port, oxd, OP and client settings.
```
/opt/gluu-gateway/konga/config/local.js
```
* Start/Stop/Restart/Status
```
 # service gluu-gateway [start|stop|restart|status]
```

### Configure oxd

* Configure oxd-server
```
/opt/oxd-server/conf/oxd-conf.json
```
* Start/Stop/Restart/Status oxd-server
```
 # service oxd-server [start|stop|restart|status]
```

* Configure oxd-https-extension
```
/opt/oxd-https-extension/lib/oxd-https.yml
```
* Start/Stop/Restart/Status oxd-https-extension
```
 # service oxd-https-extension [start|stop|restart|status]
```
