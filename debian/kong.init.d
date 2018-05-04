#!/bin/bash
### BEGIN INIT INFO
# Provides:          kong
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start daemon at boot time
# Description:       Enable service provided by daemon.
### END INIT INFO

SERVICE_NAME=kong
PID_PATH_NAME=/usr/local/kong/pids/nginx.pid
KONG_CMD=`which kong`

### If "which" command is unable to search for command at boot time.
### Feed it with this fixed value.
### Solution applies to trusty for now
if [ "x" = "x$KONG_CMD" ]; then
        KONG_CMD="/usr/local/bin/kong"
fi

get_pid() {
        if [ -f $PID_PATH_NAME ]; then
                PID_NUM=$(cat $PID_PATH_NAME)
                echo "$PID_NUM"
        fi
}

do_start () {
        PID_NUM=`get_pid`
        if [ "x$PID_NUM" = "x" ]; then
                echo "Starting $SERVICE_NAME ..."
                $KONG_CMD start
                PID_NUM=`get_pid`
        else
                echo "$SERVICE_NAME is already running ..."
        fi
        echo "PID: [$PID_NUM]"
}

do_stop () {
        PID_NUM=`get_pid`
        if [ "x$PID_NUM" != "x" ]; then
                echo "Stopping $SERVICE_NAME ..."
                $KONG_CMD stop
        else
                echo "$SERVICE_NAME is not running ..."
        fi
}

do_reload () {
        PID_NUM=`get_pid`
        if [ "x$PID_NUM" != "x" ]; then
                echo "Reloading $SERVICE_NAME ..."
                $KONG_CMD reload
        else
                echo "$SERVICE_NAME is not running ..."
        fi
}

get_version () {
                $KONG_CMD version
}

case $1 in
    start)
            do_start
    ;;
    stop)
            do_stop
    ;;
    reload)
            do_reload
    ;;
    version)
            get_version
    ;;
    restart)
            do_stop
            do_start
    ;;
    status)
        if [ -f $PID_PATH_NAME ]; then
            echo "$SERVICE_NAME is running ...";
            PID_NUM=$(cat $PID_PATH_NAME)
            echo "PID: [$PID_NUM]"
        else
           echo "$SERVICE_NAME is not running ..."
        fi
    ;;
    *)
        echo "Usage: $0 {start|stop|status|restart}"
        RETVAL=2
    ;;
esac
