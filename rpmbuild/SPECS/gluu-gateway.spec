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

%config 
/opt/gluu-gateway/konga/config/application.js
/opt/gluu-gateway/konga/config/blueprints.js
/opt/gluu-gateway/konga/config/bootstrap.js
/opt/gluu-gateway/konga/config/connections.js
/opt/gluu-gateway/konga/config/cors.js
/opt/gluu-gateway/konga/config/csrf.js
/opt/gluu-gateway/konga/config/globals.js
/opt/gluu-gateway/konga/config/http.js
/opt/gluu-gateway/konga/config/i18n.js
/opt/gluu-gateway/konga/config/jwt.js
/opt/gluu-gateway/konga/config/load-db.js
/opt/gluu-gateway/konga/config/local_example.js
/opt/gluu-gateway/konga/config/local.js
/opt/gluu-gateway/konga/config/log.js
/opt/gluu-gateway/konga/config/models.js
/opt/gluu-gateway/konga/config/orm.js
/opt/gluu-gateway/konga/config/passport.js
/opt/gluu-gateway/konga/config/paths.js
/opt/gluu-gateway/konga/config/policies.js
/opt/gluu-gateway/konga/config/pubsub.js
/opt/gluu-gateway/konga/config/routes.js
/opt/gluu-gateway/konga/config/session.js
/opt/gluu-gateway/konga/config/sockets.js
/opt/gluu-gateway/konga/config/views.js
/opt/gluu-gateway/konga/config/locales/en.json
/opt/gluu-gateway/konga/config/locales/_README.md
/opt/gluu-gateway/konga/config/env/development.js
/opt/gluu-gateway/konga/config/env/production.js

%files
/opt/gluu-gateway/*
/etc/init.d/kong
/etc/init.d/konga
/etc/init.d/gluu-gateway

%changelog
* Mon Mar 07 2016 Adrian Alves <adrian@gluu.org> - 3.1.3-1
- Release 3.1.3
