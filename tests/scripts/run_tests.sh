#!/usr/bin/env bash

EMAIL=$1
PASSWORD=$2
PROJECT_PATH=$3


function install_katalon {
    if [ -d "$DIRECTORY" ]; then
        echo "Installing katalon"
        mkdir -p /opt/katalon
        cd /opt/katalon
        wget http://download.katalon.com/5.4.0/Katalon_Studio_Linux_64-5.4.tar.gz
        tar -xvf Katalon_Studio_Linux_64-5.4.tar.gz
        chmod 700 Katalon_Studio_Linux_64-5.4/katalon
    else
        echo "Katalon already installed"
    fi
}

function install_ff {
    which xvfb
    if [ $? == 1 ]; then
        echo "Installing FF & xvfb"
        apt-get install -y firefox xvfb
        Xvfb :10 -ac & > /dev/null
        export DISPLAY=:10
    fi
}
function run_tests {
   /opt/katalon/Katalon_Studio_Linux_64-5.4/katalon --args -runMode=console -projectPath="$PROJECT_PATH" -reportFolder="Reports" -reportFileName="report" -retry=0 -testSuitePath="Test Suites/GG_tests" -browserType="Firefox (headless)" -email="$EMAIL" -password"$PASSWORD"
}

install_ff
install_katalon