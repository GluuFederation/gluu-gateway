#!/bin/bash
### BEGIN INIT INFO
# Provides:          gluu-gateway
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start daemon at boot time
# Description:       Enable service provided by daemon.
### END INIT INFO

SERVICE_NAME=gluu-gateway
GLUU_GATEWAY_INIT_LOG=/var/log/gluu-gateway.log

do_start () {
        service postgresql start
        service kong start
        service oxd-server start
        service oxd-https-extension start
        service konga start
}

do_stop () {        
        service postgresql stop
        service kong stop
        service oxd-server stop
        service oxd-https-extension stop
        service konga stop
}

do_status () {        
        service postgresql status
        service kong status
        service oxd-server status
        service oxd-https-extension status
        service konga status
}

case $1 in
    start)
            do_start
    ;;
    stop)
            do_stop
    ;;
    restart)
            do_stop
            do_start
    ;;
    status)
	    do_status
    ;;
    *)
        echo "Usage: $0 {start|stop|status|restart}"
        RETVAL=2
    ;;
esac 
