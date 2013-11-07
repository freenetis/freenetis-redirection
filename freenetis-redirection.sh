#!/bin/bash
################################################################################
#                                                                              #
# This script serves for redirection IP policy of IS FreenetIS                 #
#                                                                              #
# author  Kliment Michal, Sevcik Roman                                         #
# email   kliment@freenetis.org, sevcik.roman@slfree.net                       #
#                                                                              #
# name    freenetis-redirection.sh                                             #
# version 2.2                                                                  #
#                                                                              #
################################################################################

# Version
VERSION="2.2"

# Load variables from config file
CONFIG=/etc/freenetis/freenetis-redirection.conf

# Local variable contains path to iptables - mandatory
IPTABLES=/sbin/iptables

# Local variable contains path to ipset - mandatory
IPSET=/usr/sbin/ipset

# Local variable contains path to wget - mandatory
WGET=/usr/bin/wget

# Path to HTTP 302 redirector
REDIRECTION_HTTP_REDIRECTOR=/usr/sbin/freenetis-http-302-redirection

# Path to HTTP 302 redirector
REDIRECTION_HTTP_REDIRECTOR_PIDFILE=/var/run/freenetis-http-302-redirection.pid

#Paths where temporary data will be saved.
PATH_ERRORS=`mktemp`

#Load variables
if [ -f ${CONFIG} ]; then
    . $CONFIG;
else
    echo "Config file is missing at path $CONFIG."
    echo "Terminating..."
    exit 0
fi

# Runs command and print result (OK = success, FAILED = error)
run_and_print_result ()
{
    $@ 2> "$PATH_ERRORS"
    if [ $? -eq 0 ];
    then
        echo "OK"
    else
        echo "FAILED! Error: $? "`cat "$PATH_ERRORS" | awk '{$1 = "";  print}'`
    fi
}

# Tests whether iptables rule already exists
rule_exists ()
{
    iptables-save | grep -q "$@"
    if [ $? -eq 0 ];
    then
        echo 1
    else
        echo 0
    fi
}

# Tests whether program is running
is_running ()
{
    ps aux | grep -v grep | grep "$@" | wc -l
}

# Adds iptables rules
add_rules()
{
    echo -n "Adding iptables rule for self canceling..."

    #Rule for allowing access. If come packet to $PORT_SELF_CANCEL then we add source address do set allowed and to set seen
    #Set seen is used for ip synchronization with FreenetIS.
    if [ `rule_exists "PREROUTING -p tcp -m set --match-set self_cancel src -m tcp --dport $PORT_SELF_CANCEL -j SET --add-set allowed src"` -eq 0 ];
    then
        run_and_print_result "$IPTABLES -t nat -A PREROUTING -m set --match-set self_cancel src -p tcp --dport $PORT_SELF_CANCEL -j SET --add-set allowed src"
    else
        echo "already added"
    fi

    echo -n "Adding iptables rule for allowed..."

    #If IP is allowed then it is not redirected
    if [ `rule_exists "PREROUTING -m set --match-set allowed src -j ACCEPT"` -eq 0 ];
    then
        run_and_print_result "$IPTABLES -t nat -A PREROUTING -m set --match-set allowed src -j ACCEPT"
    else
        echo "already added"
    fi

    echo -n "Adding iptables rule for allowed..."

    #If IP is allowed then it is not redirected
    if [ `rule_exists "PREROUTING -m set --match-set allowed dst -j ACCEPT"` -eq 0 ];
    then
        run_and_print_result "$IPTABLES -t nat -A PREROUTING -m set --match-set allowed dst -j ACCEPT"
    else
        echo "already added"
    fi

    echo -n "Adding iptables rule for redirection..."

    #Redirect everything trafic what has destination port $PORT_WEB to $PORT_REDIRECT
    if [ `rule_exists "PREROUTING -p tcp -m set --match-set ranges src -m tcp --dport $PORT_WEB -j REDIRECT --to-ports $PORT_REDIRECT"` -eq 0 ];
    then
        run_and_print_result "$IPTABLES -t nat -A PREROUTING -m set --match-set ranges src -p tcp --dport $PORT_WEB -j REDIRECT --to-port $PORT_REDIRECT"
    else
        echo "already added"
    fi

    echo -n "Adding iptables rule for allowed..."

    #If IP is allowed then it is not redirected
    if [ `rule_exists "FORWARD -m set --match-set allowed src -j ACCEPT"` -eq 0 ];
    then
        run_and_print_result "$IPTABLES -I FORWARD 1 -m set --match-set allowed src -j ACCEPT"
    else
        echo "already added"
    fi

    echo -n "Adding iptables rule for allowed..."

    #If IP is allowed then it is not redirected
    if [ `rule_exists "FORWARD -m set --match-set allowed dst -j ACCEPT"` -eq 0 ];
    then
        run_and_print_result "$IPTABLES -I FORWARD 2 -m set --match-set allowed dst -j ACCEPT"
    else
        echo "already added"
    fi

    echo -n "Adding iptables rule for block others..."

    #Else everything drop
    if [ `rule_exists "FORWARD -m set --match-set ranges src -j DROP"` -eq 0 ];
    then
        run_and_print_result "$IPTABLES -I FORWARD 3 -m set --match-set ranges src -j DROP"
    else
        echo "already added"
    fi
}

# Deletes iptables rules
delete_rules()
{
    echo -n "Deleting iptables rule for self canceling..."
    #Rule for allowing access. If come packet to $PORT_SELF_CANCEL then we add source address do set allowed and to set seen
    #Set seen is used for ip synchronization with FreenetIS.
    if [ `rule_exists "PREROUTING -p tcp -m set --match-set self_cancel src -m tcp --dport $PORT_SELF_CANCEL -j SET --add-set allowed src"` -eq 1 ];
    then
        run_and_print_result "$IPTABLES -t nat -D PREROUTING -m set --match-set self_cancel src -p tcp --dport $PORT_SELF_CANCEL -j SET --add-set allowed src"
    else
        echo "already deleted"
    fi

    echo -n "Deleting iptables rule for allowed..."
    #If IP is allowed then it is not redirected
        if [ `rule_exists "PREROUTING -m set --match-set allowed src -j ACCEPT"` -eq 1 ];
    then
        run_and_print_result "$IPTABLES -t nat -D PREROUTING -m set --match-set allowed src -j ACCEPT"
    else
        echo "already deleted"
    fi

    echo -n "Deleting iptables rule for allowed..."
    #If IP is allowed then it is not redirected
        if [ `rule_exists "PREROUTING -m set --match-set allowed dst -j ACCEPT"` -eq 1 ];
    then
        run_and_print_result "$IPTABLES -t nat -D PREROUTING -m set --match-set allowed dst -j ACCEPT"
    else
        echo "already deleted"
    fi

    echo -n "Deleting iptables rule for redirection..."
    #Redirect everything trafic what has destination port $PORT_WEB to $PORT_REDIRECT
        if [ `rule_exists "PREROUTING -p tcp -m set --match-set ranges src -m tcp --dport $PORT_WEB -j REDIRECT --to-ports $PORT_REDIRECT"` -eq 1 ];
    then
        run_and_print_result "$IPTABLES -t nat -D PREROUTING -m set --match-set ranges src -p tcp --dport $PORT_WEB -j REDIRECT --to-port $PORT_REDIRECT"
    else
        echo "already deleted"
    fi

    echo -n "Deleting iptables rule for allowed..."
    #If IP is allowed then it is not redirected
        if [ `rule_exists "FORWARD -m set --match-set allowed src -j ACCEPT"` -eq 1 ];
    then
        run_and_print_result "$IPTABLES -D FORWARD -m set --match-set allowed src -j ACCEPT"
    else
        echo "already deleted"
    fi

    echo -n "Deleting iptables rule for allowed..."
    #If IP is allowed then it is not redirected
        if [ `rule_exists "FORWARD -m set --match-set allowed dst -j ACCEPT"` -eq 1 ];
    then
        run_and_print_result "$IPTABLES -D FORWARD -m set --match-set allowed dst -j ACCEPT"
    else
        echo "already deleted"
    fi

    echo -n "Deleting iptables rule for block others..."
    #Else everything drop
        if [ `rule_exists "FORWARD -m set --match-set ranges src -j DROP"` -eq 1 ];
    then
        run_and_print_result "$IPTABLES -D FORWARD -m set --match-set ranges src -j DROP"
    else
        echo "already deleted"
    fi
}

# Adds ipsets
add_ipsets()
{
    echo -n "Adding ipset allowed... "

    if [ -n "`$IPSET -L allowed 2>&1>/dev/null`" ];
    then
        run_and_print_result "$IPSET -N allowed iphash --hashsize 10000 --probes 8 --resize 50"
    else
        echo "already added"
    fi

    echo -n "Adding ipset self_cancel..."

    if [ -n "`$IPSET -L self_cancel 2>&1>/dev/null`" ];
    then
        run_and_print_result "$IPSET -N self_cancel iphash --hashsize 10000 --probes 8 --resize 50"
    else
        echo "already added"
    fi

    echo -n "Adding ipset ranges..."

    if [ -n "`$IPSET -L ranges 2>&1>/dev/null`" ];
    then
        run_and_print_result "$IPSET -N ranges nethash --hashsize 1024 --probes 4 --resize 50"
    else
        echo "already added"
    fi

    echo -n "Adding temporary ipset for ipset allowed..."

    if [ -n "`$IPSET -L allowed_tmp 2>&1>/dev/null`" ];
    then
        run_and_print_result "$IPSET -N allowed_tmp iphash --hashsize 10000 --probes 8 --resize 50"
    else
        echo "already added"
    fi

    echo -n "Adding temporary ipset for ipset self_cancel..."

    if [ -n "`$IPSET -L self_cancel_tmp 2>&1>/dev/null`" ];
    then
        run_and_print_result "$IPSET -N self_cancel_tmp iphash --hashsize 10000 --probes 8 --resize 50"
    else
        echo "already added"
    fi

    echo -n "Adding temporary ipset for ipset ranges..."

    if [ -n "`$IPSET -L ranges_tmp 2>&1>/dev/null`" ];
    then
        run_and_print_result "$IPSET -N ranges_tmp nethash --hashsize 1024 --probes 4 --resize 50"
    else
        echo "already added"
    fi
}

# Deletes ipsets
delete_ipsets()
{
    echo -n "Deleting ipset allowed... "

    if [ -z "`$IPSET -L allowed 2>&1>/dev/null`" ];
    then
        run_and_print_result "$IPSET -X allowed"
    else
        echo "already deleted"
    fi

    echo -n "Deleting ipset self_cancel..."

    if [ -z "`$IPSET -L self_cancel 2>&1>/dev/null`" ];
    then
        run_and_print_result "$IPSET -X self_cancel"
    else
        echo "already deleted"
    fi

    echo -n "Deleting ipset ranges..."

    if [ -z "`$IPSET -L ranges 2>&1>/dev/null`" ];
    then
        run_and_print_result "$IPSET -X ranges"
    else
        echo "already deleted"
    fi

    echo -n "Deleting temporary ipset for ipset allowed..."

    if [ -z "`$IPSET -L allowed_tmp 2>&1>/dev/null`" ];
    then
        run_and_print_result "$IPSET -X allowed_tmp"
    else
        echo "already deleted"
    fi

    echo -n "Deleting temporary ipset for ipset self_cancel..."

    if [ -z "`$IPSET -L self_cancel_tmp 2>&1>/dev/null`" ];
    then
        run_and_print_result "$IPSET -X self_cancel_tmp"
    else
        echo "already deleted"
    fi

    echo -n "Deleting temporary ipset for ipset ranges..."

    if [ -z "`$IPSET -L ranges_tmp 2>&1>/dev/null`" ];
    then
        run_and_print_result "$IPSET -X ranges_tmp"
    else
        echo "already deleted"
    fi
}

# Starts HTTP 302 redirector
start_http_redirector ()
{
    echo -n "Starting FreenetIS redirection HTTP deamon: "

    if [ `is_running "$REDIRECTION_HTTP_REDIRECTOR"` -eq 0 ];
    then
        run_and_print_result "start-stop-daemon --start --quiet --make-pidfile --pidfile=$REDIRECTION_HTTP_REDIRECTOR_PIDFILE --background --exec $REDIRECTION_HTTP_REDIRECTOR -- $PORT_REDIRECT $PATH_FN $LOG_FILE_REDIRECTOR"
    else
        echo "already started"
    fi
}

# Stops HTTP 302 redirector
stop_http_redirector ()
{
    echo -n "Stopping FreenetIS redirection HTTP deamon: "

    if [ `is_running "$REDIRECTION_HTTP_REDIRECTOR"` -eq 1 ];
        then
            run_and_print_result "start-stop-daemon --stop --quiet --pidfile=$REDIRECTION_HTTP_REDIRECTOR_PIDFILE"
    else
        echo "already stopped"
    fi

    rm -f "$REDIRECTION_HTTP_REDIRECTOR_PIDFILE"
}

# Starts redirection - only adds ipsets, rules and starts HTTP redirector
start_redirection ()
{
    echo "[STARTING]"

    add_ipsets
    add_rules
    start_http_redirector
}

# Stops redirection - only deletes ipset, rules and stops HTTP redirector
stop_redirection ()
{
    echo "[STOPPING]"

    delete_rules
    delete_ipsets
    stop_http_redirector
}

# Syncs ipsets with FreenetIS - only one time
sync_ipsets ()
{
    echo "[SYNCING]"

    PATH_ALLOWED=`mktemp`
    PATH_SELF_CANCEL=`mktemp`
    PATH_RANGES=`mktemp`

    for URL in "$SET_URL_ALLOWED";
    do
        echo -n "Downloading list of allowed IP addresses from $URL: ";
        $WGET -qO- $URL --no-check-certificate >> $PATH_ALLOWED 2>/dev/null
        if [ $? -eq 0 ];
        then
            echo "OK"
        else
            echo "FAILED!"
        fi
    done

    for URL in "$SET_URL_SELF_CANCEL";
    do
        echo -n "Downloading list of self-cancel IP addresses from $URL: ";
        $WGET -qO- $URL --no-check-certificate >> $PATH_SELF_CANCEL 2>/dev/null
        if [ $? -eq 0 ];
        then
            echo "OK"
        else
            echo "FAILED!"
        fi
    done

    for URL in "$SET_URL_RANGES";
    do
        echo -n "Downloading list of ranges from $URL: ";
        $WGET -qO- $URL --no-check-certificate >> $PATH_RANGES 2>/dev/null
        if [ $? -eq 0 ];
        then
            echo "OK"
        else
            echo "FAILED!"
        fi
    done

    $IPSET -F ranges_tmp 2>/dev/null
    $IPSET -F allowed_tmp 2>/dev/null
    $IPSET -F self_cancel_tmp 2>/dev/null

    echo -n "Adding IP addresses to temporary ipset for ipset allowed..."

    for i in $(cat $PATH_ALLOWED);
    do
        $IPSET -A allowed_tmp $i 2>/dev/null
    done

    echo `cat $PATH_ALLOWED | wc -l`" addresses added "

    echo -n "Adding IP addresses to temporary ipset for ipset self_cancel..."

    for i in $(cat $PATH_SELF_CANCEL);
    do
        $IPSET -A self_cancel_tmp $i 2>/dev/null
    done

    echo `cat $PATH_SELF_CANCEL | wc -l`" addresses added "

    echo -n "Adding IP addresses to temporary ipset for ipset ranges..."

    for i in $(cat $PATH_RANGES);
    do
        $IPSET -A ranges_tmp $i 2>/dev/null
    done

    echo `cat $PATH_RANGES | wc -l`" addresses added "

    echo -n "Replacing content of ipset ranges with content of temporary ipset..."

    run_and_print_result "$IPSET -W ranges_tmp ranges"

    echo -n "Replacing content of ipset allowed with content of temporary ipset..."

    run_and_print_result "$IPSET -W allowed_tmp allowed"

    echo -n "Replacing content of ipset self_cancel with content of temporary ipset..."

    run_and_print_result "$IPSET -W self_cancel_tmp self_cancel"

    #Cleaning up...
    rm -f $PATH_RANGES
    rm -f $PATH_ALLOWED
    rm -f $PATH_SELF_CANCEL
}

# Runs whole redirections (start, sync, stop) in endless loop
run ()
{
    echo "[STARTING]"

    trap 'stop_redirection' EXIT

    while (true);
    do
        # makes sure ipsets exist
        add_ipsets

        # makes sure iptables rules exist
        add_rules

        # makes sure HTTP 302 redirector is running
        start_http_redirector

        # syncs ipsets with FreenetIS
        sync_ipsets

        echo "Sleeping now for $DELAY seconds..."
        sleep $DELAY;
    done
}

# Prints usage
usage ()
{
   echo "Usage : `echo $0` ACTION [ LOG FILE ]"
   echo "where ACTION := { start | stop | restart | sync | run | version | help }"
}

# Prints version
version ()
{
    echo $VERSION
}

# Prints help
help ()
{
    echo "  start - creates firewall rules and ipsets for redirection"
    echo "  stop - deletes firewall rules and ipsets for redirection"
    echo "  restart - deletes and recreates firewall rules and ipsets for redirection"
    echo "  sync - sync content of ipsets with FreenetIS"
    echo "  run - run complete redirection in endless loop"
    echo "  version - print version"
    echo "  help - prints help for redirection"
}

# Second parameter is set => will used as log file
if [ -n "$2" ]; then
    exec > "$2"
fi;

# Is parameter #1 zero length?
if [ -z "$1" ]; then
    usage
    exit 0
fi;

case "$1" in

   start)
        start_redirection
        exit 0
   ;;

   stop)
        stop_redirection
        exit 0
   ;;

   restart)
        stop_redirection
        start_redirection
        exit 0
   ;;

   sync)
        sync_ipsets
        exit 0
   ;;

   run)
        run
        exit 0
   ;;

   version)
        version
        exit 0
   ;;

   help)
        usage
        help
        exit 0
   ;;

   *)
        usage
        exit 0
   ;;

esac

exit 0
