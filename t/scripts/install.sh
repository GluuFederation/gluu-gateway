#!/bin/bash

DISTRIBUTION=$1
OP_HOST=$2
HOST=$3
HOST_IP=$4
OXD_HOST=$5

function prepareSourcesXenial {
    sleep 120
    apt-get update
    echo "deb https://repo.gluu.org/ubuntu/ xenial-devel main" > /etc/apt/sources.list.d/gluu-repo.list
    curl https://repo.gluu.org/ubuntu/gluu-apt.key | apt-key add -
    echo "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main" > /etc/apt/sources.list.d/psql.list
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
    pkill .*upgrade.*
    rm /var/lib/dpkg/lock
    sleep 120
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
        "centos7") prepareSourcesCentos7 ;;
    esac
}

function installGGDeb {
    apt-get update
    apt-get install gluu-gateway -y
}

function installGGRpm {
    yum clean all
    yum -y install gluu-gateway
}

function installGG {
    case $DISTRIBUTION in
        "xenial") installGGDeb ;;
        "centos7") installGGRpm ;;
    esac
}

function configureGG {
 # Used to open port publicly
 sed -i "76s/explicitHost: 'localhost'/explicitHost: '0.0.0.0'/" /opt/gluu-gateway/setup/templates/local.js

 cd /opt/gluu-gateway/setup
 python setup-gluu-gateway.py '{"konga_redirect_uri":"'$HOST'","konga_oxd_web":"https://'$OXD_HOST':8443","license":true,"ip":"'$HOST_IP'","host_name":"'$HOST'","country_code":"US","state":"US","city":"NY","org_name":"Test","admin_email":"test@test.com","pg_pwd":"admin","install_oxd":true,"konga_op_host":"'$OP_HOST'","generate_client":true}'
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
