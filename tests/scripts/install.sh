#!/bin/bash

OXD_LICENSE_ID=$1
OXD_SERVER_PUBLIC_KEY=$2
OXD_PUBLIC_PASSWORD=$3
OXD_SERVER_LICENSE_PASSWORD=$4
OXD_SERVER_PUBLIC_PASSWORD=$5
DISTRIBUTION=$6

function prepareSourcesTrusty {
    echo "deb https://repo.gluu.org/ubuntu/ trusty-devel main" > /etc/apt/sources.list.d/gluu-repo.list
    curl https://repo.gluu.org/ubuntu/gluu-apt.key | apt-key add -
    echo "deb http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main" > /etc/apt/sources.list.d/psql.list
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
}

function prepareSourcesXenial {
    echo "deb https://repo.gluu.org/ubuntu/ xenial-devel main" > /etc/apt/sources.list.d/gluu-repo.list
    curl https://repo.gluu.org/ubuntu/gluu-apt.key | apt-key add -
    echo "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main" > /etc/apt/sources.list.d/psql.list
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
}

function prepareSourcesJessie {
    echo "deb https://repo.gluu.org/debian/ testing main" > /etc/apt/sources.list.d/gluu-repo.list
    curl https://repo.gluu.org/debian/gluu-apt.key | apt-key add -
    echo "deb http://apt.postgresql.org/pub/repos/apt/ jessie-pgdg main" > /etc/apt/sources.list.d/psql.list
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
    curl -sL https://deb.nodesource.com/setup_8.x |  bash -
}

function prepareSourcesForDistribution {
    case $DISTRIBUTION in
        "trusty") prepareSourcesTrusty ;;
        "xenial") prepareSourcesXenial ;;
        "debian8") prepareSourcesJessie ;;
    esac
}


function installGG {
 apt update
 apt install gluu-gateway -y
}

function configureGG {
 sed -i "18ihost: '0.0.0.0'," /opt/gluu-gateway/konga/config/env/development.js
 sed -i "18ihost: '0.0.0.0'," /opt/gluu-gateway/konga/config/env/production.js
 cd /opt/gluu-gateway/setup
 python setup-gluu-gateway.py '{"oxdAuthorizationRedirectUri":"dev1.gluu.org","license":true,"ip":"104.131.18.41","hostname":"dev1.gluu.org","countryCode":"TS","state":"Test","city":"Test","orgName":"Test","admin_email":"admin@test.com","pgPwd":"test123","installOxd":true,"kongaOPHost":"ce-dev6.gluu.org","oxdServerOPDiscoveryPath":"oxauth","oxdServerLicenseId":"'"$OXD_LICENSE_ID"'","oxdServerPublicKey":"'"$OXD_SERVER_PUBLIC_KEY"'","public_password":"'"$OXD_PUBLIC_PASSWORD"'","oxdServerPublicPassword":"'"$OXD_SERVER_PUBLIC_PASSWORD"'","oxdServerLicensePassword":"'"$OXD_SERVER_LICENSE_PASSWORD"'","kongaOxdWeb":"https://localhost:8443","generateClient":true}'
}

function createSwap {
    fallocate -l 4G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
}

function displayLogs {
    echo ""
    echo "--------------------------------/var/log/konga.log-----------------------------------------"
    echo ""
    cat /var/log/konga.log
    echo ""
    echo "--------------------------------/var/log/oxd-server/oxd-server.log----------------------------------------"
    echo ""
    cat /var/log/oxd-server/oxd-server.log
    echo ""
    echo "----------------------/opt/gluu-gateway/setup/gluu-gateway-setup_error.log-----------------------------------"
    echo ""
    cat /opt/gluu-gateway/setup/gluu-gateway-setup_error.log
    echo ""
    echo "----------------------/opt/gluu-gateway/setup/gluu-gateway-setup.log-----------------------------------"
    echo ""
    cat /opt/gluu-gateway/setup/gluu-gateway-setup.log
    echo ""
    echo "----------------------netstat -tulpn----------------------------------"
    echo ""
    netstat -tulpn
    echo ""
    echo "----------------------services----------------------------------"
    echo ""
    service kong status
    service konga status
    service oxd-server status
    service oxd-https-extension status
}

function checkKonga {
    if lsof -Pi :1338 -sTCP:LISTEN -t >/dev/null ; then
        echo "Konga is running"
    else
        echo "ERROR: Konga is not running"
        exit 1
    fi
}

function checkKong {
    if lsof -Pi :8000 -sTCP:LISTEN -t >/dev/null ; then
        echo "Kong is running"
    else
        echo "ERROR: Kong is not running"
        exit 1
    fi
}

function checkOxdHttps {
    if lsof -Pi :8443 -sTCP:LISTEN -t >/dev/null ; then
        echo "Oxd-https-extension is running"
    else
        echo "ERROR: oxd-https-extension is not running"
        exit 1
    fi
}

function checkOxd {
    if lsof -Pi :8099 -sTCP:LISTEN -t >/dev/null ; then
        echo "Oxd-server is running"
    else
        echo "ERROR: Oxd is not running"
        exit 1
    fi
}

function checkServices {
    checkKonga
    checkKong
    checkOxd
    checkOxdHttps
}

createSwap
prepareSourcesForDistribution
installGG
configureGG
sleep 60
displayLogs
checkServices