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
        /ect/init.d/postgresql start
        /ect/init.d/kong start
        /ect/init.d/oxd-server-4.0.beta start
        /ect/init.d/konga start
}

do_stop () {        
        /ect/init.d/postgresql stop
        /ect/init.d/kong stop
        /ect/init.d/oxd-server-4.0.beta stop
        /ect/init.d/konga stop
}

do_status () {        
        /ect/init.d/postgresql status
        /ect/init.d/kong status
        /ect/init.d/oxd-server-4.0.beta status
        /ect/init.d/konga status
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
