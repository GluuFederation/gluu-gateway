#!/bin/bash

DISTRIBUTION=$6

function prepareSourcesXenial {
    sleep 120
    echo "deb https://repo.gluu.org/ubuntu/ xenial-devel main" > /etc/apt/sources.list.d/gluu-repo.list
    curl https://repo.gluu.org/ubuntu/gluu-apt.key | apt-key add -
    echo "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main" > /etc/apt/sources.list.d/psql.list
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
    pkill .*upgrade.*
    rm /var/lib/dpkg/lock
}

function prepareSourcesJessie {
    apt-get install xvfb curl apt-transport-https -y
    echo "deb https://repo.gluu.org/debian/ testing main" > /etc/apt/sources.list.d/gluu-repo.list
    curl https://repo.gluu.org/debian/gluu-apt.key | apt-key add -
    echo "deb http://apt.postgresql.org/pub/repos/apt/ jessie-pgdg main" > /etc/apt/sources.list.d/psql.list
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
    curl -sL https://deb.nodesource.com/setup_8.x |  bash -
}

function prepareSourcesStretch {
    export DEBIAN_FRONTEND="noninteractive"
    echo "deb http://deb.debian.org/debian/ stable main contrib non-free" > /etc/apt/sources.list
    echo "deb-src http://deb.debian.org/debian/ stable main contrib non-free" >> /etc/apt/sources.list
    echo "deb http://deb.debian.org/debian/ stable-updates main contrib non-free" >> /etc/apt/sources.list
    echo "deb-src http://deb.debian.org/debian/ stable-updates main contrib non-free" >> /etc/apt/sources.list
    echo "deb http://deb.debian.org/debian-security stable/updates main" >> /etc/apt/sources.list
    echo "deb-src http://deb.debian.org/debian-security stable/updates main" >> /etc/apt/sources.list

    apt-get update
    apt-get install lsof curl apt-transport-https -y
    echo "deb https://repo.gluu.org/debian/ stretch-testing main" > /etc/apt/sources.list.d/gluu-repo.list
    curl https://repo.gluu.org/debian/gluu-apt.key | apt-key add -
    echo "deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main" > /etc/apt/sources.list.d/psql.list
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
    curl -sL https://deb.nodesource.com/setup_8.x |  bash -
}

function prepareSourcesCentos6 {
    yum -y install curl lsof xvfb
    wget https://repo.gluu.org/centos/Gluu-centos-testing.repo -O /etc/yum.repos.d/Gluu.repo
    wget https://repo.gluu.org/centos/RPM-GPG-KEY-GLUU -O /etc/pki/rpm-gpg/RPM-GPG-KEY-GLUU
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-GLUU
    rpm -Uvh https://yum.postgresql.org/10/redhat/rhel-6-x86_64/pgdg-redhat10-10-2.noarch.rpm
    curl -sL https://rpm.nodesource.com/setup_8.x | sudo -E bash -
}


function prepareSourcesCentos7 {
    dd if=/dev/zero of=/myswap count=4096 bs=1MiB
    chmod 600 /myswap
    mkswap /myswap
    swapon /myswap
    yum -y install wget curl lsof xvfb
    wget https://repo.gluu.org/centos/Gluu-centos-7-testing.repo -O /etc/yum.repos.d/Gluu.repo
    wget https://repo.gluu.org/centos/RPM-GPG-KEY-GLUU -O /etc/pki/rpm-gpg/RPM-GPG-KEY-GLUU
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-GLUU
    rpm -Uvh https://yum.postgresql.org/10/redhat/rhel-7-x86_64/pgdg-centos10-10-2.noarch.rpm
    curl -sL https://rpm.nodesource.com/setup_8.x | sudo -E bash -
}

function prepareSourcesForDistribution {
    case $DISTRIBUTION in
        "xenial") prepareSourcesXenial ;;
        "debian8") prepareSourcesJessie ;;
        "debian9") prepareSourcesStretch ;;
        "centos6") prepareSourcesCentos6 ;;
        "centos7") prepareSourcesCentos7 ;;
    esac
}

function installGGDeb {
    apt update
    apt install gluu-gateway -y
}

function installGGRpm {
    yum clean all
    yum -y install gluu-gateway
}

function installGG {
    case $DISTRIBUTION in
        "xenial") installGGDeb ;;
        "debian8") installGGDeb ;;
        "debian9") installGGDeb ;;
        "centos6") installGGRpm ;;
        "centos7") installGGRpm ;;
    esac
}

function configureGG {
 sed -i "18ihost: '0.0.0.0'," /opt/gluu-gateway/konga/config/env/development.js
 sed -i "18ihost: '0.0.0.0'," /opt/gluu-gateway/konga/config/env/production.js
 cd /opt/gluu-gateway/setup
 python setup-gluu-gateway.py '{"oxdAuthorizationRedirectUri":"dev1.gluu.org","license":true,"ip":"104.131.18.41","hostname":"dev1.gluu.org","countryCode":"TS","state":"Test","city":"Test","orgName":"Test","admin_email":"admin@test.com","pgPwd":"test123","installOxd":true,"kongaOPHost":"ce-dev6.gluu.org","oxdServerOPDiscoveryPath":"oxauth","kongaOxdWeb":"https://localhost:8443","generateClient":true, "oxdHost":"dev1.gluu.org"}'
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
    service oxd-server-4.0.beta status
}

function checkKonga {
    if lsof -Pi :1338 -sTCP:LISTEN -t >/dev/null ; then
        echo "Konga is running"
    else
        echo "ERROR: Konga is not running. Waiting 1 min more"
        if lsof -Pi :1338 -sTCP:LISTEN -t >/dev/null ; then
            echo "Konga is running"
        else
            echo "ERROR: Konga is not running. Waiting 1 min more"
            if lsof -Pi :1338 -sTCP:LISTEN -t >/dev/null ; then
                echo "Konga is running"
            else
                exit 1
            fi
        fi
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

function checkOxd {
    if lsof -Pi :8443 -sTCP:LISTEN -t >/dev/null ; then
        echo "OXD is running"
    else
        echo "ERROR: OXD is not running"
        exit 1
    fi
}

function checkServices {
    checkKonga
    checkKong
    checkOxd
}

createSwap
prepareSourcesForDistribution
installGG
configureGG
sleep 60
displayLogs
checkServices
