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
PID_PATH_NAME=/var/run/gluu-gateway.pid
TMP_PID_PATH_NAME=/tmp/gluu-gateway.pid
BASEDIR=/opt/gluu-gateway/konga/
GLUU_GATEWAY_INIT_LOG=/var/log/gluu-gateway.log

get_pid() {
	if [ -f $PID_PATH_NAME ]; then                
		PID_NUM=$(cat $PID_PATH_NAME)
		echo "$PID_NUM"
	else
		OTHER_GATEWAY_PID="`ps -eaf|grep -i node|grep -v grep|grep -i 'app.js'|awk '{print $2}'`"                
		###For one more possible bug, find and kill oxd                
		if [ "x$OTHER_GATEWAY_PID" != "x" ]; then
			echo "$OTHER_GATEWAY_PID"
		fi
	fi
}

check_service_running () {
        if [ "$1" = "postgresql" ]; then
                PID=`cat /var/run/postgresql/10-main.pid`
        else
                PID=`service $1 status|tail -1 |tr -d "a-zA-Z:[]()/\.\- "`
        fi
        if [ "x$PID" = "x" ]; then
                echo "Service $1 failed to start..."
                echo "Exiting..."
                exit 255
        else
                echo "Service $1 started successfully..."
                echo "PID: [$PID]"
        fi
}

start_dependencies () {
        service postgresql start > /dev/null 2>&1
        check_service_running postgresql

        service kong start > /dev/null 2>&1
        check_service_running kong

        service oxd-server start > /dev/null 2>&1
        check_service_running oxd-server

        service oxd-https-extension start > /dev/null 2>&1
        check_service_running oxd-https-extension
}

do_start () {        
	PID_NUM=`get_pid`
        if [ "x$PID_NUM" = "x" ]; then         
                start_dependencies
                echo "Starting $SERVICE_NAME ..."                

		cd $BASEDIR
                nohup node --harmony app.js >> $GLUU_GATEWAY_INIT_LOG 2>&1 &
                echo $! > $TMP_PID_PATH_NAME        
                START_STATUS=`tail -n 12 $GLUU_GATEWAY_INIT_LOG|grep -i 'To see your app, visit'`
                ERROR_STATUS=`tail -n 10 $GLUU_GATEWAY_INIT_LOG|grep -i 'Error'`
                if [ "x$START_STATUS" = "x" ]; then
			###If by chance log file doesn't provide necessary string, sleep another 10 seconds and check again PID of process
			sleep 5
			PID_NUM=`get_pid`
        		if [ "x$PID_NUM" = "x" ]; then
                        	### Since error occurred, we should remove the PID file at this point itself.                        
                        	echo "Some error encountered..."                        
                        	echo "See log below: "                        
                        	echo ""                        
                        	echo "$ERROR_STATUS"                        
                        	echo ""                        
                        	echo "For details please check $GLUU_GATEWAY_INIT_LOG ."                        
                        	echo "Exiting..."                        
                        	exit 255
                	fi

		fi
                mv $TMP_PID_PATH_NAME $PID_PATH_NAME                        
        	PID_NUM=$(cat $PID_PATH_NAME)
        else                
                echo "$SERVICE_NAME is already running ..."        
        fi        
        echo "PID: [$PID_NUM]"
}

do_stop () {        
	PID_NUM=`get_pid`
        if [ "x$PID_NUM" != "x" ]; then                
                echo "$SERVICE_NAME stoping ..."            
                kill -s 9 $PID_NUM;            
                rm -f $PID_PATH_NAME        
        else   
                echo "$SERVICE_NAME is not running ..."        
        fi
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
