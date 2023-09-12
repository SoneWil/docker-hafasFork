#!/bin/bash
#-------------------------------------------------------------------------------
# server.sh - HAFAS start script
#-------------------------------------------------------------------------------
# This is the script to control the HAFAS server. It should be used to start,
# stop and restart the HAFAS server.
# 
# Please consult the documentation for more information about this script.
#-------------------------------------------------------------------------------
# (C) Copyright 2006-2007 HaCon Ingenierugesellschaft mbH
# Authors: Kai Fricke <kai.fricke@hacon.de>
# $Header: /cvs/hafas/script/server.sh,v 1.64 2015-03-30 11:20:06 rja Exp $
#-------------------------------------------------------------------------------

# LSB comment for init scripts
### BEGIN INIT INFO
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Provides: primary_name-product_state-hafas-server-secondary_name
# Required-Start: $local_fs $network $syslog $time
# Required-Stop: $local_fs $network
# Should-Start: nscd nslcd
# Short-Description: HAFAS server
# Description: This is the init script for an HAFAS server.
### END INIT INFO

################################################################################
# You should only need to edit the part within this block
#-------------------------------------------------------------------------------

# Change the following line to something other than "NO" or delete it to make 
# this server wrapper run. If not this wrapper will refuse to start.
CONFIGURED="NO"

# Setting the system locale (maybe you need to set other variables too 
# depending on the system environment e.g. LC_ALL).
# e.g.: export LANG=ch_CH@euro
#export LANG=en_GB@euro

#
# If the rather long but meaningful environment variable 
# HAFAS_SERVER_RESTART_MAIL_NOTIFICATION_ADDRESS is set, the server-safe will 
# send an email to the specified address when the HAFAS server died 
# unexpectedly. This can be used to monitor the hafas server on a very basic 
# level.
#export HAFAS_SERVER_RESTART_MAIL_NOTIFICATION_ADDRESS="admins@hacon.de"

#
# Do a backup of data in case of a crash. At the moment only match server is 
# implemented
#export HAFAS_SERVER_CRASH_BACKUP=1

#
# Parameters for the HAFAS environment on this server.
#

# System account to run the server under. If empty the server
# will run under the current user, but not root.
RUNAS_USER=""

# The primary name is either a client name, project name. Even a standard or
# internal HAFAS server should get the name "hacon" here.
# This name should be lowercase!
PRIMARY_NAME=""

# The secondary name should describe the type of the HAFAS server. Use "main"
# for the standard HAFAS server, because all are servers and only very few
# are a real standard HAFAS server.
# (e.g.: p2w, main, delfi, euspirit, p2w-broker, p2w-main)
# This name should be lowercase!
SECONDARY_NAME=""

# The HAFAS plan data format version of the plan data files. If this parameter
# is given, the PLAN_DIR is constructed without the SECONDARY_NAME as a 
# subdirectory. Using this parameter in combination with the PLAN_SUFFIX it is 
# possible to share plan data directories with several HAFAS servers.
# This parameter may be empty.
PLAN_VERSION=""

# Maybe you want to add a suffix to plan data directory names? This is always 
# appended to the primary name when constructing the name of the plan data 
# directory.
# This makes it easier to share plan data with other servers when used in 
# combination with the PLAN_VERSION variable.
# (e.g.: Setting the plan version to "baim" and the suffix to ".p2w" results 
# in a plan data directory like "/opt/hafas/plan/baim.p2w/...")
# This does not need to be set.
PLAN_SUFFIX=""

# The state of the HAFAS server.
# test - testing while in development
# pub  - public test version
# rel  - release preview or candidate
# prod - productive
PRODUCT_STATE=""

# The type of the server. This value is used later in the script to safely
# construct variants of different settings (server binary names, passive
# servers, etc.).
# The default for this value is "std".
# datacollector  - The data collector server connects to realtime data
#                  streams and collects realtime data for the match server.
#                  The binary is called 'datacollector.exe' and the config
#                  file 'datacollector.cfg'
# p2w-broker     - Print2web broker servers do bind to a server port and the
#                  server binary is called "broker.exe"
#                  If the P2W broker service does not run on the same system 
#                  as the web server, the broker can actively mount a SMB 
#                  (Samba or Windows Networkin) networ share to communicate 
#                  with the CGI environment.
#                  See the options MOUNT_P2W_DOWNLOAD_DIR_FROM and 
#                  MOUNT_P2W_DOWNLOAD_DIR_TO for more details.
# p2w-converter  - Print2web converter servers do not bind to a server port
#                  and the server binary is called "server-p2w.exe".
# p2w-main       - Print2web servers don't bind to a server port and the
#                  server binary is called "server-p2w.exe"
# simple         - No HAFAS Arguments are constructed and passed to the
#                  server. Only the paths and other controlling mechanisms
#                  are used.
# main, std      - A standard HAFAS server is binding to a server port and
#                  the server binary is called "server.exe"
# main-realtime, - A realtime HAFAS server is binding to a server port and
# std-realtime     the server binary is called "server.exe". It additionally
#                  writes a realtime log which is not being fetched away
#                  automatically (as done with the math server).
# match          - Match server don't expect HAFAS options, do bind to a port
#                  and are configured through environment variables. It
#                  additionally writes a realtime log which is being fetched
#                  away automatically (by some internal rt-helper scripts).
# sqlbroker      - A SQL broker is used to relay database request to the 
#                  database which is normally accessed via ODBC. The ODBC 
#                  Driver Manager must be provided by the operating system, the 
#                  database specific driver (ODBC and the native database 
#                  driver) need to be placed in the LIB_DIR of the current 
#                  context.
#                  SQL-broker server do listen to a TCP-Port and do mostly 
#                  behave like a standard HAFAS server (appearing to this 
#                  script).
# transform      - Not yet implemented!
SERVER_TYPE="main"

#
# HAFAS parameters which can also be defined in the server.cfg
#

# Sets the maximum number of connections the HAFAS server can handle at a time.
# This parameter is at the moment not included in the constructed variable
# named HAFAS_OPTIONS below.
# Please consult your HAFAS server documentation for further ionfromation!
MAX_CONNECTIONS="1"

# The level of messages to be logged. Possible values are:
# 0 - Deactivate logging
# 1 - Only errors
# 2 - Errors and normal operation (needed to gather data for statistics)
# 3 - Debugging and additional information in the case of errors
LOG_LEVEL="3"

# The port the HAFAS server should listen at. It must be unique on one system
# and needs to be in the range 1024-65535.
PORT=""

#-------------------------------------------------------------------------------
# Particular HAFAS options mostly used for development and debugging
#-------------------------------------------------------------------------------

# HAFAS kernel statist is a feature to debug the HAFAS kernel. It writes 
# detailed information into the file 'statist' located in the current working 
# directory (when started whith this script that is the SERVER_DIR).
# The filename for the HAFAS kernel 'statist' file is constructed the same way 
# as the default logfile. Because of that this file is located beneath that
# logfile with the suffix '.statist' instead of '.log'.
#
# One dependency of this option to work is a HAFAS server binary with debugging 
# symbols compiled in.
#
#Example: HAFAS_KERNEL_STATIST="0x1cb9"
#Example: HAFAS_KERNEL_STATIST="7353"
#
#HAFAS_KERNEL_STATIST=""

#-------------------------------------------------------------------------------
# Normally there should be no need to edit anything below this line. If you
# need to edit anything please make a variable for it, define it in the block
# above and check in a new revision of the change into the template of this
# script.
################################################################################

# Check if this script was configured
if [ "${CONFIGURED}" = "NO" ]; then
    cat <<EOF

ERROR: First configure the values within this script and finally delete the
       line containing 'CONFIGURED="NO"' and the comment above that one.

EOF
    exit 1
fi

# Only usefull for testing purposes
SUPER_BASE_DIR=""

# This super base directory describes the location of all HAFAS stuff on this
# server.
HAFAS_BASE_DIR="${SUPER_BASE_DIR}/opt/hafas"

# Source static and system wide methods and functions. This included file 
# contains among other things the methods to configure the HAFAS environment 
# and to start, stop and restart the server.
. ${HAFAS_BASE_DIR}/script/functions.sh
RETVAL=$?

if [ ${RETVAL} -ne 0 ]; then
    echo "Error: Failed to include helper functions '${HAFAS_BASE_DIR}/script/functions.sh'!"
    exit 1
fi

change_uid_to_service_uid $@

configure_hafas_environment

check_hafas_environment

# Do not run a HAFAS server as root! This prevents setting the RUNAS_USER to 
# the value 'root'.
if [ ${UID} -eq 0 ]
then
    log_error "Preventing this service from running as user root (uid=0). Exitting!"
    exit 1
fi

RETVAL=0

case "$1" in
    start|start_safe)
    	# Start the server in a safe mode.
        start_hafas_server
        RETVAL=$?
        ;;
        
    start_unsafe)
    	# Start the server without the server safe.
        start_hafas_server_unsafe
        RETVAL=$?
        ;;

    stop)
    	# Stop the running HAFAS server.
        stop_hafas_server
        RETVAL=$?
        ;;

    try-restart)
    	# Try to restart the HAFAS server if it is running.
        restart_hafas_if_running
        RETVAL=$?
        ;;
        
    restart|force-reload)
        # Restart the HAFAS server even if it was not running before.
        restart_hafas
        RETVAL=$?
        ;;
        
    update-data|update_data)
    	# Initiate the plan data update for this server.
    	if [ $# -eq 1 ]; then
	    update_hafas_data
	    elif [ $# -eq 2 ]; then
	        update_hafas_data $2
    	fi
        RETVAL=$?
        ;;

    status)
        # Print the status of the server to the console
        print_status
        RETVAL=$?
        ;;

    gen-logrotate-conf|gen_logrotate_conf)
        # Generate a logrotate template 
        gen_logrotate_conf
        ;;
    *)
        echo "Usage: $0 {start|start_safe|start_unsafe|status|stop|restart|try-restart|force-reload|update_data|gen-logrotate-conf}"
        RETVAL=1
esac

exit ${RETVAL}
