Name:		gluu-gateway
Version:	1.0
Release:	1%{?dist}
Summary:	OAuth protected API
License:	The Gluu Support License (GLUU-SUPPORT)
URL:		https://www.gluu.org
Source0:	gluu-gateway-1.0.tar.gz
Source1:	gluu-gateway.init.d
Source2:	kong
Source3:	konga
BuildArch:      noarch
Requires:	oxd-server = 4.0, postgresql >= 10, postgresql-server = 10, nodejs, lua-cjson, kong-community-edition = 0.14.1, unzip, python-requests

%description
The Gluu Gateway is a package which can be used to quickly
deploy an OAuth protected API gateway

%prep
%setup -q

%install
mkdir -p %{buildroot}/opt/
mkdir -p %{buildroot}/etc/init.d
mkdir -p %{buildroot}/lib/systemd/system/
cp -a %{SOURCE1} %{buildroot}/etc/init.d/
cp -a %{SOURCE2} %{buildroot}/etc/init.d/
cp -a %{SOURCE3} %{buildroot}/etc/init.d/
cp -a opt/gluu-gateway %{buildroot}/opt/

%pre
mkdir -p /opt/gluu-gateway/konga/config/locales
mkdir -p /opt/gluu-gateway/konga/config/env

%post
update-rc.d kong remove > /dev/null 2>&1
/etc/init.d/kong stop > /dev/null 2>&1
update-rc.d gluu-gateway defaults > /dev/null 2>&1
/etc/init.d/gluu-gateway stop > /dev/null 2>&1
chmod +x /opt/gluu-gateway/setup/setup-gluu-gateway.py > /dev/null 2>&1
if [ `ulimit -n` -le 4095 ]; then
if ! cat /etc/security/limits.conf | grep "* soft nofile 4096" > /dev/null 2>&1; then
echo "* soft nofile 4096" >> /etc/security/limits.conf
echo "* hard nofile 4096" >> /etc/security/limits.conf
fi
ulimit -n 4096 > /dev/null 2>&1
fi

%preun
/etc/init.d/gluu-gateway stop > /dev/null 2>&1

%postun
if [ "$1" = 0 ]; then 
mkdir -p /opt/gluu-gateway.rpmsavefiles  > /dev/null 2>&1
cp /opt/gluu-gateway/konga/config/*.rpmsave /opt/gluu-gateway.rpmsavefiles/  > /dev/null 2>&1
rm -rf /opt/gluu-gateway/* > /dev/null 2>&1
mkdir -p /opt/gluu-gateway/konga/config/  > /dev/null 2>&1
mv /opt/gluu-gateway.rpmsavefiles/*.rpmsave /opt/gluu-gateway/konga/config/  > /dev/null 2>&1
rm -rf /opt/gluu-gateway.rpmsavefiles  > /dev/null 2>&1
rm -rf /opt/jdk1.8.0_162 > /dev/null 2>&1
rm -rf /opt/jre > /dev/null 2>&1
/etc/init.d/postgresql start > /dev/null 2>&1
su postgres -c "psql -c \"DROP DATABASE kong;\"" > /dev/null 2>&1
su postgres -c "psql -c \"DROP DATABASE konga;\"" > /dev/null 2>&1
fi

%files
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
/opt/gluu-gateway/*
/etc/init.d/gluu-gateway
/etc/init.d/kong
/etc/init.d/konga

%changelog
* Mon Mar 07 2016 Adrian Alves <adrian@gluu.org> - %VERSION%-1
- Release %VERSION%
