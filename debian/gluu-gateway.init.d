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
        /etc/init.d/postgresql start
        /etc/init.d/kong start
        /etc/init.d/oxd-server-4.0.beta start
        /etc/init.d/konga start
}

do_stop () {        
        /etc/init.d/postgresql stop
        /etc/init.d/kong stop
        /etc/init.d/oxd-server-4.0.beta stop
        /etc/init.d/konga stop
}

do_status () {        
        /etc/init.d/postgresql status
        /etc/init.d/kong status
        /etc/init.d/oxd-server-4.0.beta status
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
