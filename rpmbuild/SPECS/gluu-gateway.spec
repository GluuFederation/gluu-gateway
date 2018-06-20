Name:		gluu-gateway
Version:	3.1.3
Release:	1%{?dist}
Summary:	OAuth protected API
License:	MIT
URL:		https://www.gluu.org
Source0:	gluu-gateway-3.1.3.tar.gz
Source1:	gluu-gateway.init.d
Source2:	konga.init.d
Source3:	kong.init.d
BuildArch:      noarch
Requires:	oxd-server = 3.1.3, postgresql >= 10, postgresql-server >= 10, nodejs, git, lua-cjson, kong-community-edition = 0.11.0, unzip, python-requests

%description
The Gluu Gateway is a package which can be used to quickly
deploy an OAuth protected API gateway

%prep
%setup -q

%install
mkdir -p %{buildroot}/opt/
mkdir -p %{buildroot}/etc/init.d
cp -a %{SOURCE1} %{buildroot}/etc/init.d/gluu-gateway
cp -a %{SOURCE2} %{buildroot}/etc/init.d/konga
cp -a %{SOURCE3} %{buildroot}/etc/init.d/kong
cp -a opt/gluu-gateway %{buildroot}/opt/
#cp -a setup %{buildroot}/opt/gluu-gateway
#cp -a dist %{buildroot}/opt/gluu-gateway

%pre
mkdir -p /opt/gluu-gateway/konga/config/locales
mkdir -p /opt/gluu-gateway/konga/config/env

%post
/etc/init.d/gluu-gateway stop > /dev/null 2>&1

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
/etc/init.d/kong
/etc/init.d/konga
/etc/init.d/gluu-gateway

%changelog
* Mon Mar 07 2016 Adrian Alves <adrian@gluu.org> - 3.1.3-1
- Release 3.1.3
