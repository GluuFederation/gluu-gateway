Licensed under the [GLUU SUPPORT LICENSE](./LICENSE). Copyright Gluu 2017.

## Gluu Gateway

The Gluu Gateway is a package which can be used to quickly deploy an OAuth protected API gateway with four components:

1. **[Kong Community Edition](https://getkong.org/)**: The open-source API Gateway and Microservices Management Layer, delivering high performance and reliability.
2. **[Gluu Kong plugin for UMA](https://github.com/GluuFederation/gluu-gateway/tree/master/kong-uma-rs)**: Protect your resources by using UMA resource protection.
3. **[Gluu Gateway Admin Portal](https://github.com/GluuFederation/kong-plugins/tree/master/konga)**:  An admin user interface that calls the [Kong admin API's](https://getkong.org/docs/0.11.x/admin-api/)
4. **[oxd](https://oxd.gluu.org)**: (optional) OAuth client service required by the Kong and Admin UI. If you already have and oxd-web sever available on your network, you don't need to install oxd again.

## Features

1. Add | Edit | Delete API's
1. Restict access to tokens with certain OAuth scopes
1. API Dashboard to configure and monitor the health of your servers.
1. Manage your api gateway cluster for high availability
1. Backup, restore and migrate Kong instances using snapshots
1. Leverages the security and upgradability of the oxd-server

## Installation

Installation is a three part process:

1. Add required third party repositories
2. Install `gluu-gateway` package
3. Run `setup-gluu-gateway.py`

### Required Third Party repositories

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

5. Add Node repo:
   # curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
   
```

### Install gluu-gateway pacakge
   
```
   # apt update
   # apt install gluu-gateway
```


### Run setup script

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
| oxd https url | Used to configure konga for the oxd-https-extension. Make sure oxd web url(oxd-https-extension) is in the running state, if not then start it manually. |
| Would you like to generate client_id/client_secret for konga? | You can register a new OpenID Client or enter manually enter existing client credentials. If you choose 'y' then make sure oxd web url(oxd-https-extension) is in the running state otherwise it does not allow to make new client. You need to take care of client by extending the client expiration date and enable "pre-authorization". |
| oxd_id | Used to manually set oxd id for konga. |
| client_id | Used to manually set client id for konga. |
| client_secret | Used to manually set client secret for konga. |

```
Gluu Gateway configuration successful!!! https://localhost:1338
```
When you got this above message that means installation done successful. Next, process is to make tunnel to `https://localhost:1338` and use konga. If your port is open then you use konga directly in browser i:e `https://hostname:1338`.

> Note: After login, Go to `connection` tab and select the one kong node to use by clicking on the respective star icon.

## Configuration

### Configure gluu-gateway
Gluu-gateway service used to manage all the gluu-gateway componets(konga, kong, postgres, oxd-server, oxd-https).
* Start/Restart/Status
```
 # service gluu-gateway [start|restart|status]
```

### Configure konga
* You can configure konga by setting properties in local.js file. This is used to set port, oxd, OP and client settings.
```
/opt/gluu-gateway/konga/config/local.js
```
* Start/Stop/Restart/Status
```
 # service konga [start|stop|restart|status]
```

### Configure kong
* You can configure kong by using kong.conf file.

```
/etc/kong/kong.conf
```
* Start/Stop/Restart
```
 # service kong [restart|stop|restart|status]
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

## KONGA Guide

> Note: After installation and first time login, Go to `connection` tab and select the one kong node to use by clicking on the respective star icon.

### 1. Dashboard

Dashboard section shows all application configuration details. You can see oxd and client details used by konga.
![dashboard](doc/1_dashboard.png)

### 2. Info

Info section shows generic details about the kong node.
![info](doc/2_info.png)

### 3. APIS

The API object describes an API that's being exposed by Kong. Kong needs to know how to retrieve the API when a consumer is calling it from the Proxy port. Each API object must specify a request host, a request path or both. Kong will proxy all requests to the API to the specified upstream URL.
![apis](doc/3_apis.png)

Add your API by using `+ ADD NEW API` button. Add form shows details of every field.
![api_add](doc/3_api_add.png)

For Add UMA RS plugin click on `SECURITY` option in apis list.
![api_uma_rs](doc/3_add_uma_rs.png)

### 4. Consumers

The Consumer object represents a consumer - or a user - of an API. You can either rely on Kong as the primary datastore, or you can map the consumer list with your database to keep consistency between Kong and your existing primary datastore.
![consumers](doc/4_consumers.png)

Add consumers by using `+ CREATE CONSUMER` button. Add form shows details of every field.
![consumers_add](doc/4_customer_add.png)

### 5. Plugins

A Plugin entity represents a plugin configuration that will be executed during the HTTP request/response workflow, and it's how you can add functionalities to APIs that run behind Kong, like Authentication or Rate Limiting for example.
![plugins](doc/5_plugins.png)

Add Plugins by using `+ ADD GLOBAL PLUGINS` button.
![plugins_add](doc/5_plugins_add.png)

### 6. Upstreams

The upstream object represents a virtual hostname and can be used to loadbalance incoming requests over multiple services (targets). So for example an upstream named service.v1.xyz with an API object created with an upstream_url=https://service.v1.xyz/some/path. Requests for this API would be proxied to the targets defined within the upstream.
![upstreams](doc/6_upstream.png)

Add Plugins by using `+ CREATE UPSTREAM` button.
![plugins_add](doc/6_upstream_add.png)

### 7. CERTIFICATE

A certificate object represents a public certificate/private key pair for an SSL certificate. These objects are used by Kong to handle SSL/TLS termination for encrypted requests. Certificates are optionally associated with SNI objects to tie a cert/key pair to one or more hostnames.
![cert](doc/7_cert.png)

Add Plugins by using `+ CREATE CERTIFICATE` button.
![cert_add](doc/7_cert_add.png)

### 8. Connections

Create connections to Kong Nodes and select the one to use by clicking on the respective star icon.
![conn](doc/8_conn.png)

Add Plugins by using `+ NEW CONNECTION` button.
![conn_add](doc/8_conn_add.png)

### 9. Snapshots

Take snapshots of currently active nodes.
All APIs, Plugins, Consumers, Upstreams and Targetswill be saved and available for later import.
![snapshot](doc/9_snapshot.png)
