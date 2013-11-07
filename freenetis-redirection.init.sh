#! /bin/bash

### BEGIN INIT INFO
# Provides:          freenetis-redirection
# Required-Start:    $remote_fs
# Required-Stop:     $remote_fs
# Should-Start:      $network $syslog
# Should-Stop:       $network $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start and stop freenetis synchronization daemon
# Description:       FreenetIS redirection synchronization script.
### END INIT INFO

################################################################################
#                                                                              #
# This script serves for redirection IP policy of IS FreenetIS                 #
#                                                                              #
# author  Kliment Michal, Sevcik Roman                                         #
# email   kliment@freenetis.org, sevcik.roman@slfree.net                       #
#                                                                              #
# name    freenetis-redirection.init.sh                                        #
# version 2.2                                                                  #
#                                                                              #
################################################################################

#Load variables from config file
CONFIG=/etc/freenetis/freenetis-redirection.conf

# Path to redirection synchronization file
REDIRECTION_FILE=/usr/sbin/freenetis-redirection

#Path to redirection pid file
REDIRECTION_PIDFILE=/var/run/freenetis-redirection.pid

# Path to HTTP 302 redirector
REDIRECTION_HTTP_REDIRECTOR=/usr/sbin/freenetis-http-302-redirection

# Path to HTTP 302 redirector
REDIRECTION_HTTP_REDIRECTOR_PIDFILE=/var/run/freenetis-http-302-redirection.pid

#Load variables
if [ -f ${CONFIG} ]; then
	. $CONFIG;
else
	echo "Config file is missing at path $CONFIG."
	echo "Terminating..."
	exit 0
fi

# Tests whether program is running
is_running ()
{
    ps aux | grep -v grep | grep "$@" | wc -l
}

# Starts Freenetis redirection daemon
start_redirection ()
{
    if [ `is_running "$REDIRECTION_FILE"` -eq 0 ];
    then
        echo -n "Starting FreenetIS redirection daemon: "
        start-stop-daemon --start --quiet --make-pidfile --pidfile="$REDIRECTION_PIDFILE" --background --exec "$REDIRECTION_FILE" -- run "$LOG_FILE" 2>> "$LOG_FILE"
        sleep 2
        if [ $? -eq 0 ];
            then
                echo "OK"
            else
                echo "FAILED!"
            fi
    else
        echo "Already started."
    fi
}

# Stops Freenetis redirection daemon
stop_redirection ()
{
    if [ `is_running "$REDIRECTION_FILE"` -eq 1 ];
    then
        echo -n "Stopping FreenetIS redirection daemon: "
        start-stop-daemon --stop --quiet --pidfile="$REDIRECTION_PIDFILE" 2>> "$LOG_FILE"
	sleep 2
        if [ $? -eq 0 ];
        then
            echo "OK"
        else
            echo "FAILED!"
        fi
    else
        echo "Already stopped."
    fi

    rm -f "$REDIRECTION_PIDFILE"
}

# Prints status of Freenetis redirection daemon
status_redirection ()
{
    if [ `is_running "$REDIRECTION_FILE"` -eq 1 ];
    then
        echo "FreenetIS redirection daemon is running with PID "`cat "$REDIRECTION_PIDFILE"`

        if [ `is_running "$REDIRECTION_HTTP_REDIRECTOR"` -eq 1 ];
        then
             echo "FreenetIS HTTP redirector is running with PID "`cat "$REDIRECTION_HTTP_REDIRECTOR_PIDFILE"`
        fi
        else
                echo "FreenetIS redirection is not running."
        echo "FreenetIS HTTP redirector is not running."
    fi
}

# Prints version
version_redirection ()
{
    VERSION=`"$REDIRECTION_FILE" version 2>/dev/null`

    echo $VERSION
}

# Prints usage
usage_redirection ()
{
    echo "usage : `echo $0` (start|stop|restart|status|version|help)"
}

# Prints help
help_redirection ()
{
    echo "  start - starts FreenetIS redirection daemon"
    echo "  stop - stops FreenetIS redirection daemon"
    echo "  restart - restarts FreenetIS redirection daemon"
    echo "  reload - reloads configuration and restarts FreenetIS redirection daemon"
    echo "  status - returns actual status of FreenetIS redirection daemon"
    echo "  version - prints version"
    echo "  help - prints help"
}

# Is parameter #1 zero length?
if [ -z "$1" ]; then
    usage_redirection
    exit 0
fi;

case "$1" in

   start)
        start_redirection
        exit 0
   ;;

   restart|reload|force-reload) # reload is same thing as reload
        stop_redirection
        start_redirection
        exit 0
   ;;

   stop)
        stop_redirection
        exit 0
   ;;

   status)
        status_redirection
        exit 0
   ;;

   version)
        version_redirection
        exit 0
   ;;

   help)
        usage_redirection
        help_redirection
        exit 0
   ;;

   *)
        usage_redirection
        exit 0
   ;;

esac

exit 0