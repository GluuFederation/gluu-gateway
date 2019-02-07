Name:		gluu-gateway
Version:	4.0
Release:	1%{?dist}
Summary:	OAuth protected API
License:	MIT
URL:		https://www.gluu.org
Source0:	gluu-gateway-4.0.tar.gz
Source1:	gluu-gateway.service
Source2:	kong.service
BuildArch:      noarch
Requires:	oxd-server-4.0.beta, postgresql >= 10, postgresql-server >= 10, nodejs, lua-cjson, kong-community-edition = 0.14.1, unzip, python-requests

%description
The Gluu Gateway is a package which can be used to quickly
deploy an OAuth protected API gateway

%prep
%setup -q

%install
mkdir -p %{buildroot}/opt/
mkdir -p %{buildroot}/etc/init.d
cp -a %{SOURCE1} %{buildroot}/lib/systemd/system/
cp -a %{SOURCE2} %{buildroot}/lib/systemd/system/
cp -a opt/gluu-gateway %{buildroot}/opt/

%pre
mkdir -p /opt/gluu-gateway/konga/config/locales
mkdir -p /opt/gluu-gateway/konga/config/env

%post
systemctl enable kong > /dev/null 2>&1
systemctl enable gluu-gateway > /dev/null 2>&1
systemctl stop gluu-gateway > /dev/null 2>&1

%config(missingok, noreplace) /opt/gluu-gateway/konga/config/application.js
%config(missingok, noreplace) /opt/gluu-gateway/konga/config/blueprints.js
%config(missingok, noreplace) /opt/gluu-gateway/konga/config/bootstrap.js
%config(missingok, noreplace) /opt/gluu-gateway/konga/config/connections.js
%config(missingok, noreplace) /opt/gluu-gateway/konga/config/cors.js
%config(missingok, noreplace) /opt/gluu-gateway/konga/config/csrf.js
%config(missingok, noreplace) /opt/gluu-gateway/konga/config/globals.js
%config(missingok, noreplace) /opt/gluu-gateway/konga/config/http.js
%config(missingok, noreplace) /opt/gluu-gateway/konga/config/i18n.js
%config(missingok, noreplace) /opt/gluu-gateway/konga/config/jwt.js
%config(missingok, noreplace) /opt/gluu-gateway/konga/config/load-db.js
%config(missingok, noreplace) /opt/gluu-gateway/konga/config/local_example.js
%config(missingok, noreplace) /opt/gluu-gateway/konga/config/local.js
%config(missingok, noreplace) /opt/gluu-gateway/konga/config/log.js
%config(missingok, noreplace) /opt/gluu-gateway/konga/config/models.js
%config(missingok, noreplace) /opt/gluu-gateway/konga/config/orm.js
%config(missingok, noreplace) /opt/gluu-gateway/konga/config/passport.js
%config(missingok, noreplace) /opt/gluu-gateway/konga/config/paths.js
%config(missingok, noreplace) /opt/gluu-gateway/konga/config/policies.js
%config(missingok, noreplace) /opt/gluu-gateway/konga/config/pubsub.js
%config(missingok, noreplace) /opt/gluu-gateway/konga/config/routes.js
%config(missingok, noreplace) /opt/gluu-gateway/konga/config/session.js
%config(missingok, noreplace) /opt/gluu-gateway/konga/config/sockets.js
%config(missingok, noreplace) /opt/gluu-gateway/konga/config/views.js
%config(missingok, noreplace) /opt/gluu-gateway/konga/config/locales/en.json
%config(missingok, noreplace) /opt/gluu-gateway/konga/config/locales/_README.md
%config(missingok, noreplace) /opt/gluu-gateway/konga/config/env/development.js
%config(missingok, noreplace) /opt/gluu-gateway/konga/config/env/production.js

%files
/opt/gluu-gateway/*
/lib/systemd/system/kong.service
/lib/systemd/system/gluu-gateway.service

%changelog
* Mon Mar 07 2016 Adrian Alves <adrian@gluu.org> - %VERSION%-1
- Release %VERSION%
