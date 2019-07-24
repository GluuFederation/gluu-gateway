#!/bin/bash
### BEGIN INIT INFO
# Provides:          gluu-gateway
# Required-Start:    $syslog $local_fs $remote_fs postgresql
# Required-Stop:     $syslog $local_fs $remote_fs postgresql
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
        service konga start
}

do_stop () {        
        service kong stop
        service oxd-server stop
        service konga stop
}

do_status () {        
        /etc/init.d/postgresql status
        /etc/init.d/kong status
        /etc/init.d/oxd-server status
        /etc/init.d/konga status
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
