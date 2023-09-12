#-------------------------------------------------------------------------------
# functions.sh -A collection of helper functions
#-------------------------------------------------------------------------------
# This is simply a collection of helper functions
#-------------------------------------------------------------------------------
# (C) Copyright 2006-2011 HaCon Ingenieurgesellschaft mbH
# Authors: Kai Fricke <kai.fricke@hacon.de>
#          Lars Bohn <lars.bohn@hacon.de>
#          Rene Janitschke <rene.janitschke@hacon.de>
# $Header: /cvs/hafas/script/functions.sh,v 1.48 2015-08-12 13:03:57 adu Exp $
#-------------------------------------------------------------------------------

HAFAS_SYSLOG_FACILITY="local0"

USER_INPUT=""
WAIT_FOR_EXIT_PIDS=""
export SERVER_TYPE

HAFAS_SERVER_CRASH_BACKUP=${HAFAS_SERVER_CRASH_BACKUP:-0}
export HAFAS_SERVER_CRASH_BACKUP

#-------------------------------------------------------------------------------
function log_file()
#-------------------------------------------------------------------------------
# Log a message to a logfile. A date and PID prefix is printed before the
# message.
#
# Parameters:
#   1. The filename to log to
#   1. The string to log
#-------------------------------------------------------------------------------
{
    MYSELF=`basename $0`
    echo -n `date -R` >> ${1}
    echo " ${MYSELF} ($$) - ${2}" >> ${1}

    return 0
}


#-------------------------------------------------------------------------------
function log_info()
# Logs a message to syslog using the daemon facility, the tag 'hafas' and use a
# priority at level 'info'.
#
# Parameters:
#   1. The message to log.
#-------------------------------------------------------------------------------
{
    logger -t `basename $0` -p ${HAFAS_SYSLOG_FACILITY}.info "(${$}) - '${1}'"
    return ${?}
}


#-------------------------------------------------------------------------------
function log_info_and_console()
# Logs a message to syslog using the daemon facility, the tag 'hafas' and use a
# priority at level 'info'.
#
# Parameters:
#   1. The message to log.
#-------------------------------------------------------------------------------
{
    echo ${1}
    logger -t `basename $0` -p ${HAFAS_SYSLOG_FACILITY}.info "(${$}) - '${1}'"
    return ${?}
}


#-------------------------------------------------------------------------------
function log_warning()
# Logs a message to syslog using the daemon facility, the tag 'hafas' and use a
# priority at level 'warning'.
#
# Parameters:
#   1. The message to log.
#-------------------------------------------------------------------------------
{
    logger -t `basename $0` -p ${HAFAS_SYSLOG_FACILITY}.warning "(${$}) - '${1}'"
    return ${?}
}


#-------------------------------------------------------------------------------
function log_error()
# Logs a message to syslog using the daemon facility, the tag 'hafas' and use a
# priority at level 'error'.
#
# Parameters:
#   1. The message to log.
#-------------------------------------------------------------------------------
{
    logger -s -t `basename $0` -p ${HAFAS_SYSLOG_FACILITY}.error "(${$}) - '${1}'"
    return ${?}
}


#-------------------------------------------------------------------------------
function log()
#-------------------------------------------------------------------------------
# Logs an informational message using syslog.
#
# Parameters:
#   1. The message to log.
#-------------------------------------------------------------------------------
{
    log_info ${@}
    return ${?}
}


#-------------------------------------------------------------------------------
function read_user_input()
#-------------------------------------------------------------------------------
# Read a string from stdin and return if something was entered (no empty 
# string). If nothing was entered the value given as a parameter will be 
# returned
#
# Parameters:
#   1. The default value to use if no input is given.
# Returns:
#   - The input is stored in the variable USER_INPUT
#-------------------------------------------------------------------------------
{
    USER_INPUT=${1:-""}
    read _input
    if [ -n "${_input}" ]; then
        USER_INPUT=${_input}
    fi
    return 0
}


#-------------------------------------------------------------------------------
function mount_p2w_download_dir()
#-------------------------------------------------------------------------------
# Mounts P2W download directory located on a SMB network share to a local 
# directory.
# The service to mount from must be specified with the variable 
# MOUNT_P2W_DOWNLOAD_DIR_FROM and the local directory to mount to with the 
# variable MOUNT_P2W_DOWNLOAD_DIR_TO.
#-------------------------------------------------------------------------------
{
	_CREDENTIALS_FILE="/home/hafas/my_credentials"
	
    if [ ! -f ${_CREDENTIALS_FILE} ]; then
		_CREDENTIALS_FILE="/home/${RUNAS_USER}/smbmount_credentials"
    fi
    
    if [ ! -d ${MOUNT_P2W_DOWNLOAD_DIR_TO} ]; then
        log_error "Mount point does not exist. Exitting!"
        exit 1
    fi
	    
    if [ -f ${_CREDENTIALS_FILE} ]; then
        log_info "Mounting P2W download directory '${MOUNT_P2W_DOWNLOAD_DIR_FROM:?}' to local path '${MOUNT_P2W_DOWNLOAD_DIR_TO:?}'"    

        /usr/bin/smbmount ${MOUNT_P2W_DOWNLOAD_DIR_FROM} ${MOUNT_P2W_DOWNLOAD_DIR_TO} -o credentials=${_CREDENTIALS_FILE},rw,fmask=777,dmask=777
        
        if [ ${?} -ne 0 ]; then
            log_error "Failed to mount the download directory. Mount command failed!"
            exit 1
        fi
    else
        log_error "Failed to mount the download directory. The credentials file is not available!"
        exit 1
    fi
}


#-------------------------------------------------------------------------------
function umount_p2w_download_dir()
#-------------------------------------------------------------------------------
# Unmounts a previously mounted SMB share on the mount point specified in the 
# variable MOUNT_P2W_DOWNLOAD_DIR_TO.
#-------------------------------------------------------------------------------
{
    log_info "Unmounting P2W download directory '${MOUNT_P2W_DOWNLOAD_DIR_FROM:?}' on local path '${MOUNT_P2W_DOWNLOAD_DIR_TO:?}'"    

    /usr/bin/smbumount ${MOUNT_P2W_DOWNLOAD_DIR_TO}

    if [ ${?} -ne 0 ]; then
        log_error "Failed to unmount the download directory. Unmount command failed!"
    fi
}


#-------------------------------------------------------------------------------
function report_sighup()
#-------------------------------------------------------------------------------
{
	log_info "Exitting due to hangup signal (SIGHUP)!"
}


#-------------------------------------------------------------------------------
function report_sigint()
#-------------------------------------------------------------------------------
{
	log_info "Exitting due to interrupt signal (SIGINT)!"
        export SERVER_STOP_REQUESTED=1
}


#-------------------------------------------------------------------------------
function report_sigkill()
#-------------------------------------------------------------------------------
{
	log_info "Exitting due to kill signal (SIGKILL)!"
}


#-------------------------------------------------------------------------------
function report_sigterm()
#-------------------------------------------------------------------------------
{
	log_info "Exitting due to terminate signal (SIGTERM)!"
        export SERVER_STOP_REQUESTED=1
}


#-------------------------------------------------------------------------------
function trap_signals()
#-------------------------------------------------------------------------------
# This method registers some report functions in order to report received 
# signals to syslog.
# Only signals commonly received by a shell are trapped!
#-------------------------------------------------------------------------------
{
	# Trap signals and call the reporting functions
	trap report_sighup 1
	trap report_sigint 2
	trap report_sigkill 9
	trap report_sigterm 15
}


#-------------------------------------------------------------------------------
function echo_bold()
#-------------------------------------------------------------------------------
# Simply print the given argument in bold font
# 
# Arguments:
#  1. The text to print
#-------------------------------------------------------------------------------
{
	echo -e "\E[37;40m\033[1m$1\E[37;40m\033[0m"
}


#-------------------------------------------------------------------------------
function start_hafas_server()
#-------------------------------------------------------------------------------
# Starts an HAFAS server based on the current environment.
# This method is called from the server wrapper which configures the 
# environment in advance. The current script name ($0) is used with the command
# argument 'start' to achieve this.
#-------------------------------------------------------------------------------
{
    local RETVAL
	
    log_info_and_console "Starting HAFAS server '${TITLE}'..."
    
    if [ -f ${PID_FILE} ]; then
        log_error "Start aborted because PID file exists. Exitting!"
        return 0
    fi
    
    # Before starting the server a P2W download directory may need to be 
    # mounted.
    if [ "${MOUNT_P2W_DOWNLOAD_DIR}" = "YES" ]; then
        mount_p2w_download_dir
    fi

    export LD_LIBRARY_PATH=${LIB_DIR}
    cd ${SERVER_DIR}

    ${HAFAS_BASE_DIR}/script/server_safe.sh \
        ${PID_FILE} ${SERVER_BIN} ${HAFAS_OPTIONS} > /dev/null 2>&1 &
    SERVER_SAFE_PID=$!

    # Check if the server-safe process can be signaled (and thus is running)
    sleep 4
    kill -0 ${SERVER_SAFE_PID} > /dev/null 2>&1
    RETVAL=$?

    if [ ${RETVAL} -ne 0 ]; then
        log_error "Failed to start the HAFAS server safe. Exitting!"
	else
		log_info_and_console "HAFAS server '${TITLE}' started successfully."
    fi
    
    return ${RETVAL}
}


#-------------------------------------------------------------------------------
function start_hafas_server_unsafe()
#-------------------------------------------------------------------------------
# Starts an HAFAS server withouth the server safe based on the current 
# environment.
# This method is called from the server wrapper which configures the 
# environment in advance. The current script name ($0) is used with the command
# argument 'start' to achieve this.
#-------------------------------------------------------------------------------
{
	local RETVAL
	
	log_info_and_console "Starting HAFAS server '${TITLE}' without server safe..."

    if [ -f ${PID_FILE} ]; then
        log_error "Start aborted because PID file exists. Exitting!"
        return 0
    fi

    # Before starting the server a P2W download directory may need to be 
    # mounted.
    if [ "${MOUNT_P2W_DOWNLOAD_DIR}" = "YES" ]; then
        mount_p2w_download_dir
    fi

    export LD_LIBRARY_PATH=${LIB_DIR}
    cd "${SERVER_DIR}"

    ${SERVER_BIN} ${HAFAS_OPTIONS} > /dev/null 2>&1 &
    SERVER_PID=$!
    
    # Check if the server process can be signaled (and thus is running)
    sleep 3
    kill -0 ${SERVER_PID} > /dev/null 2>&1
    RETVAL=$?

    if [ $RETVAL -ne 0 ]; then
        log_error "Failed to start HAFAS server '${TITLE}' unsafe (PID=${SERVER_PID})!"
    else
        echo "${SERVER_PID}" > ${PID_FILE}
        log_info_and_console "HAFAS server '${TITLE}' started successfully (without server safe!)."
    fi
    
    return ${RETVAL}
}


#-------------------------------------------------------------------------------
function stop_hafas_server()
#-------------------------------------------------------------------------------
# Stopps an HAFAS server based on the current environment.
# This method is called from the server wrapper which configures the 
# environment in advance. The current script name ($0) is used with the command
# argument 'start' to achieve this.
#-------------------------------------------------------------------------------
{
	local RETVAL
	
	log_info_and_console "Stopping HAFAS server '${TITLE}'..."

    if [ ! -f ${PID_FILE} ]; then
        log_error "Stop aborted because PID file does not exist. Exitting!"
        return 0
    fi

    if [ ! -O ${PID_FILE} ]; then
        log_error "Stop aborted because PID file is not mine. Exitting!"
        return 1
    fi

    SERVER_PIDS=`cat ${PID_FILE}`

    for TOBEKILLED_PID in ${SERVER_PIDS}
    do
        filename=`ps -f | grep ${TOBEKILLED_PID} | grep -v grep | awk '{ print $8 }'`
        extension=`echo ${filename/*./}`
        case $extension in
          "exe") kill -SIGTERM ${TOBEKILLED_PID}
                 RETVAL=$?
                 sleep 1
                 ;;
          *)     KVAL=0
                 KCOUNT=1
                 KMAX=60
                 while [ $KVAL -eq 0 ]; do
                   kill -SIGTERM ${TOBEKILLED_PID}
                   RETVAL=$?
                   if [ ${RETVAL} -ne 0 ]; then
                     log_error "Failed to terminate process with PID ${TOBEKILLED_PID}!"
                   else
                     log_info "Terminated process with PID ${TOBEKILLED_PID}!"
                     log_info_and_console "HAFAS server '${TITLE}' stopped successfully."
                   fi

                   sleep 1
                   kill -0 ${SERVER_PID} > /dev/null 2>&1
                   KVAL=$?
                   if [ $KVAL -eq 0 ]; then
                     log_info_and_console "PID ${TOBEKILLED_PID} doesn't dissapear. Retry to kill process again: $((KCOUNT))"
                     log_warning "PID ${TOBEKILLED_PID} doesn't dissapear. Retry to kill process again: $((KCOUNT))"
                   fi
                   KCOUNT=$((KCOUNT+1))
                   if [ $KCOUNT -ge $KMAX ]; then
                     log_info_and_console "PID ${TOBEKILLED_PID} doesn't dissapear. Max retry count reached $((KCOUNT)) will quit now. Please check manualy."
                     log_warning "PID ${TOBEKILLED_PID} doesn't dissapear. Max retry count reached $((KCOUNT)) will quit now. Please check manualy."
                     break;
                   fi
                 done
                 ;;
        esac
        
    done

    RETVAL=1
    while [ $RETVAL -eq 1 ]; do 
      wait_for_exit
      RETVAL=$?
   
      for TOBEKILLED_PID in $WAIT_FOR_EXIT_PIDS; do 
        log_info_and_console "Force kill of PID: ${TOBEKILLED_PID}"
        log_warning "Force kill of PID: ${TOBEKILLED_PID}"
        kill -SIGKILL ${TOBEKILLED_PID}
      done
    done  

    rm -f ${PID_FILE}
    RETVAL=$?
    if [ ${RETVAL} -ne 0 ]; then
        log_error "Failed to remove PID file."
    fi

    # After stopping the server a P2W download directory may need to be 
    # unmounted.
    if [ "${MOUNT_P2W_DOWNLOAD_DIR}" = "YES" ]; then
        umount_p2w_download_dir
    fi
	
    return ${RETVAL}
}


#-------------------------------------------------------------------------------
function restart_hafas_if_running()
#-------------------------------------------------------------------------------
# Restarts an HAFAS server if it was previosly running.
# This method is called from the server wrapper which configures the 
# environment in advance. The current script name ($0) is used with the command
# arguments 'stop' and 'start' to achieve this.
#-------------------------------------------------------------------------------
{
	local RETVAL
	
	log_info_and_console "Trying to restart the HAFAS server '${TITLE}' (if running)..."

    # Check if the PID file exists
    # "$0 stop" return 0 (success) (LSB conformance) if PID file does not exist, but HAFAS server shouldn't be started!
    if [ ! -f ${PID_FILE} ]; then
        log_error "Stop aborted because PID file does not exist. Exitting!"
        return 0
    fi
    
    $0 stop
    RETVAL=$?

    if [ ${RETVAL} -ne 0 ]; then
        log_error "Failed to stop the HAFAS server during restart. Exitting!"
        return ${RETVAL}
    fi

    sleep 2
    $0 start
    RETVAL=$?

    if [ ${RETVAL} -eq 0 ]; then
	log_info_and_console "HAFAS server '${TITLE}' restarted successfully."
	sleep 2
    fi
    
    return ${RETVAL}
}


#-------------------------------------------------------------------------------
function restart_hafas()
#-------------------------------------------------------------------------------
# Restarts an HAFAS server. If it was not running this method tries to start 
# the HAFAS server.
# This method is called from the server wrapper which configures the 
# environment in advance. The current script name ($0) is used with the command
# arguments 'stop' and 'start' to achieve this.
#-------------------------------------------------------------------------------
{
	local RETVAL
	
	log_info_and_console "Restarting HAFAS server '${TITLE}'..."
    
    $0 stop
    RETVAL=$?

    if [ ${RETVAL} -ne 0 ]; then
        log_error "Failed to stop the HAFAS server during restart. Starting it now!"
    fi
    
    sleep 2
    $0 start
    RETVAL=$?

    if [ ${RETVAL} -eq 0 ]; then
	log_info_and_console "HAFAS server '${TITLE}' restarted successfully."
	sleep 2
    fi
    
    return ${RETVAL}
}


#-------------------------------------------------------------------------------
function print_status()
#-------------------------------------------------------------------------------
# Prints the status of the HAFAS server to the console and returns LSB conform
# values (maybe used by caller for exit codes).
#-------------------------------------------------------------------------------
{
	local _result=0
	local _proces_status
	
	# Check if the PID file exists. This indicates the server is running
	if [ ! -f ${PID_FILE} ]; then
		log_info_and_console "Status report for ${INT_NAME}: HAFAS server is not running!"
		_result=3
	else
		local _pids=`cat ${PID_FILE}`
		check_process_running ${_pids}
		_process_status=$?
		
		if [ ${_process_status} -ne 0 ]; then
			log_info_and_console "Status report for ${INT_NAME}: The HAFAS server not running (maybe automatically restarting if started in a server safe)!"
			_result=1
		else
			log_info_and_console "Status report for ${INT_NAME}: The HAFAS server is running!"
		fi
	fi
	
	cat <<EOT

Product state:       ${PRODUCT_STATE}
Primary name:        ${PRIMARY_NAME}
Secondary name:      ${SECONDARY_NAME}
Internal name:       ${INT_NAME}

Logfile:             ${LOG_FILE}
Server directory:    ${SERVER_DIR}
LD library path:     ${LIB_DIR}

Server binary:       ${SERVER_BIN}
Server config file:  ${CONFIG_FILE}
HAFAS options:       ${HAFAS_OPTIONS}

Plan data directory: ${PLAN_DIR}
Plan data version:   ${PLAN_VERSION}
Plan data suffix:    ${PLAN_SUFFIX}

Service user is:     ${RUNAS_USER}

EOT

	if [ -x ${SERVER_BIN} ]; then
		SERVER_VERSION=`LD_LIBRARY_PATH=${LIB_DIR} ${SERVER_BIN} -v`
		if [ $? -ne 0 ]; then
			echo "HAFAS version could not be determined (failed to execute server binary)!"
		else
			# Call the server binary with the parameter '-v' and ignore all 
			# output to stderr (no config file specified at the commandline, 
			# etc.)
			LD_LIBRARY_PATH=${LIB_DIR} ${SERVER_BIN} -v 2> /dev/null
		fi
	fi
	

	return $_result
}


#-------------------------------------------------------------------------------
function update_hafas_data()
#-------------------------------------------------------------------------------
# Tries to update the HAFAS server configured in the current environment with 
# new plan data.
# This is done by calling the script 'import_hafas_data.sh' with parameters 
# resulting from the current environment:
#   - The current command (preverably a server wrapper).
#   - A default data import directory (the directory 
#     '/import_hafas_data/${INT_NAME}' within the service users home 
#     directory).
#   - The plan data directory defined by the environment variable 'PLAN_DIR'.
#-------------------------------------------------------------------------------
{
	local RETVAL
	
	log_info_and_console "Updating plan data for HAFAS server '${TITLE}'..."
    
    if [ $# -eq 0 ]; then
    	DATA_IMPORT_DIR=`getent passwd ${2-$RUNAS_USER} | awk -F: '{print $6}'`/import_hafas_data/${INT_NAME}
	elif [ $# -eq 1 ]; then
		DATA_IMPORT_DIR=$1
	fi
    
    ${HAFAS_BASE_DIR}/script/import_hafas_data.sh ${0} ${DATA_IMPORT_DIR} ${PLAN_DIR}
    RETVAL=$?

    if [ ${RETVAL} -ne 0 ]; then
        log_error "Failed to update plan data!"
	else
		log_info_and_console "Plan data update for HAFAS server '${TITLE}' finished successfully."
    fi
    
    return ${RETVAL}
}

#-------------------------------------------------------------------------------
function configure_hafas_environment()
#-------------------------------------------------------------------------------
# Makes sure that the current environment is configured based on the previously
# configured options. This is done in respect to the different server types.
#-------------------------------------------------------------------------------
{
	# The directory which contains the HAFAS plan data. If the variable 
	# PLAN_DIR is set before the previously defined value will be used! This 
	# way you can externally override this value/construction.
	if [ -z "${PLAN_DIR}" ]; then
		if [ "${PLAN_VERSION}" = "" ]; then
		    PLAN_DIR="${HAFAS_BASE_DIR}/plan/${PRIMARY_NAME:?}${PLAN_SUFFIX}/${SECONDARY_NAME:?}"
		else
	    	PLAN_DIR="${HAFAS_BASE_DIR}/plan/${PLAN_VERSION}/${PRIMARY_NAME:?}${PLAN_SUFFIX}"
		fi
	fi
	export HAFAS_DIR=${PLAN_DIR}
	
	# The base dir where all other files and directories, belonging to this
	# server, are located.
	SERVER_BASE_DIR="${HAFAS_BASE_DIR}/${PRODUCT_STATE:?}/${PRIMARY_NAME}/${SECONDARY_NAME}"
	
	# An internal name for file and directory names
	INT_NAME="${PRIMARY_NAME}-${PRODUCT_STATE}-hafas-server-${SECONDARY_NAME}"
	
	# The name of the HAFAS server is constructed
	NAME="$PRIMARY_NAME (${SECONDARY_NAME})"
	
	# A descriptive name which is used for logging
	if [ "${SERVER_TYPE}" = "simple" ]; then
	    TITLE="Server - ${NAME}"
	else
	    TITLE="HAFAS Server - ${NAME}"
	fi
	
	# The path to the server
	SERVER_DIR="${SERVER_BASE_DIR}/server"
	
	# A library path to be set as a LD_LIBRARY_PATH for the HAFAS executeable
	LIB_DIR="${SERVER_BASE_DIR}/lib"
	
	# PID file an logging
	PID_FILE="${SUPER_BASE_DIR}/var/opt/hafas/run/${PRIMARY_NAME}/${INT_NAME}.pid"
	LOG_FILE="${SUPER_BASE_DIR}/var/opt/hafas/log/${PRIMARY_NAME}/${INT_NAME}.log"
	STATIST_FILE="${SUPER_BASE_DIR}/var/opt/hafas/log/${PRIMARY_NAME}/${INT_NAME}.statist"
		
	HAFAS_OPTIONS="-1${LOG_FILE} -2${LOG_LEVEL} -30"

	# The following line constructs the options passed to the HAFAS server.
	# It is placed here in case you want to add things by hand. But that should
	# not be needed because they should be set indirect by using the previous
	# variables or defined in the HAFAS config file directly.
	#
	# Description of options generally set:
	#   SERVER_BIN    - The path to the server binary
	#   CONFIG_FILE   - The path to the configuration file (passed as parameter
	#                   '-7' in the HAFAS_OPTIONS.
	#   HAFAS_OPTIONS - Constructed HAFAS options based on what a server type can
	#                   or wants to be told at the command line
	#
	# Notes about some HAFAS options left out or statically set:
	#  - The screen log level (parameter "-3") is statically set to zero because
	#    all output is forced to the logfile anyway. This is mostly usefull for
	#    internal development purposes.
	#  - The parameter "-4${MAX_CONNECTIONS}" is not included here to let in HAFAS
	#    decide about it.
	case "${SERVER_TYPE}" in
	    data-collector|datacollector)
	        SERVER_BIN="${SERVER_DIR}/datacollector.exe"
	        # CONFIG_FILE is hard-coded datacollector.cfg
	        CONFIG_FILE="${SERVER_DIR}/datacollector.cfg"
	        #HAFAS_OPTIONS="${HAFAS_OPTIONS} "
	        ;;
	    dispatcher)
	        SERVER_BIN="${SERVER_DIR}/dispatcher.exe"
	        # CONFIG_FILE is hard-coded dispatcher.cfg
	        CONFIG_FILE="${SERVER_DIR}/dispatcher.cfg"
	        #HAFAS_OPTIONS="${HAFAS_OPTIONS} "
	        ;;
	    p2w-main)
	        SERVER_BIN="${SERVER_DIR}/server-p2w.exe"
	        CONFIG_FILE="${SERVER_DIR}/server.cfg"
	        HAFAS_OPTIONS="${HAFAS_OPTIONS} -7${CONFIG_FILE}"
	        ;;
	    p2w-converter)
	        SERVER_BIN="${SERVER_DIR}/server-p2w.exe"
	        CONFIG_FILE="${SERVER_DIR}/server.cfg"
	        HAFAS_OPTIONS="${HAFAS_OPTIONS} -7${CONFIG_FILE}"
	
	        # The converter get confused by a HAFAS_DIR environment variable
	        unset HAFAS_DIR
	
	        # This collides with the locale name used for i18n support in Linux.
	        # So we set it only when needed and in a minimum scope.
	        export LANG="german"
	        ;;
	    p2w-broker)
	        SERVER_BIN="${SERVER_DIR}/broker.exe"
	        # CONFIG_FILE is hard-coded broker.cfg
	        CONFIG_FILE="${SERVER_DIR}/broker.cfg"
	        HAFAS_OPTIONS="${HAFAS_OPTIONS} -5${PORT:?}"
	
	        # If the P2W broker service does not run on the same system as the web 
	        # server, the broker can actively mount a SMB (Samba or Windows 
	        # networking) networ share to communicate with the CGI environment.
	        # Set this option to "YES" to mount the download dircetory using the 
	        # following additional options.
	        MOUNT_P2W_DOWNLOAD_DIR="NO"
	        
	        # To specify the source for the download directory you can set the 
	        # following option to a so called 'service' (use the the syntax 
	        # '//server/path').
	        MOUNT_P2W_DOWNLOAD_DIR_FROM="//demo/p2w_download"
	
	        # To change the location of the download directory you can set the 
	        # following option. This should not be necessary, please use this path 
	        # in the configuration file of yout P2W broker.
	        MOUNT_P2W_DOWNLOAD_DIR_TO="${SERVER_BASE_DIR}/download"
	        ;;
	    match)
	        SERVER_BIN="${SERVER_DIR}/server.exe"
	        CONFIG_FILE="${SERVER_DIR}/server.cfg"
	        HAFAS_OPTIONS="${HAFAS_OPTIONS} -7${CONFIG_FILE}"
	
	        # Reatime Match server specific environment variables
	        export RT_MATCH_DIR="${SERVER_DIR}"
	        export RT_HAFAS_DIR="${RT_MATCH_DIR}/rt_delay"
	        export RT_SKRIPT_DIR="${RT_MATCH_DIR}/rt_delay"
	        export RT_DATEN_DIR="${RT_MATCH_DIR}/rt_delay"
                export RT_LOG_BACKUP_DIR="${RT_MATCH_DIR}/log/backup"
	        
	        # Activate debug output of the match server
	        export DEBUG_MODE=0
	        ;;
	    sqlbroker|sql-broker)
	        SERVER_BIN="${SERVER_DIR}/server.exe"
	        CONFIG_FILE="${SERVER_DIR}/server.cfg"
	        HAFAS_OPTIONS="${HAFAS_OPTIONS} -5${PORT:?} -7${CONFIG_FILE}"
	
	        # The ODBC configuration for the SQL-Broker needs to be placed in the 
	        # server directory
	        export ODBCINI="${SERVER_DIR}/odbc.ini"
	        
	        # In case of an Oracle Database connection (with ODBC in between) the 
	        # Oracle specific data sources (TNS) need to be configured too. They 
	        # are also located in the server directory.
	        export TNS_ADMIN="${SERVER_DIR}/"
	        # Oracle Libraries seem to need a NLS_LANG environment variable to be 
	        # set. Else strange mappings occur (e.g. 'ö' -> 'o').
	        export NLS_LANG="GERMAN_GERMANY.WE8ISO8859P1"
	        ;;
	    main|std|delfi|euspirit|trigger)
	        SERVER_BIN="${SERVER_DIR}/server.exe"
	        CONFIG_FILE="${SERVER_DIR}/server.cfg"
                REALTIME_LOG_FILE="${SUPER_BASE_DIR}/var/opt/hafas/log/${PRIMARY_NAME}/${INT_NAME}-realtime.log"
		# if MAX_CONNECTIONS is defined in server.sh, numeric and > 0
		# then use it as commandline parameter
		if [ $((${MAX_CONNECTIONS})) -gt "0" ]; then
			HAFAS_OPTIONS="${HAFAS_OPTIONS} -4${MAX_CONNECTIONS}"
		fi
	        HAFAS_OPTIONS="${HAFAS_OPTIONS} -5${PORT:?} -7${CONFIG_FILE}"
	        ;;
	    main-realtime|std-realtime)
	        SERVER_BIN="${SERVER_DIR}/server.exe"
	        CONFIG_FILE="${SERVER_DIR}/server.cfg"
	        REALTIME_LOG_FILE="${SUPER_BASE_DIR}/var/opt/hafas/log/${PRIMARY_NAME}/${INT_NAME}-realtime.log"
	        HAFAS_OPTIONS="${HAFAS_OPTIONS} -5${PORT:?} -7${CONFIG_FILE} -pl${REALTIME_LOG_FILE}"
	        ;;
	    *)
	        SERVER_BIN="${SERVER_DIR}/server.exe"
	        CONFIG_FILE="${SERVER_DIR}/server.cfg"
	        #HAFAS_OPTIONS="${HAFAS_OPTIONS} "
	        ;;
	esac
}


#-------------------------------------------------------------------------------
function check_hafas_environment()
#-------------------------------------------------------------------------------
# Tries to makes sure that the (hopefully) configured HAFAS environment is 
# existing and fits into the access rights of the running user.
#-------------------------------------------------------------------------------
{
	# Check if the HAFAS server binary exists at all and is executeable
	if [ ! -e "${SERVER_BIN}" ]; then
		log_error "HAFAS server file \"${SERVER_BIN}\" does not exist. Exitting!"
		exit 1
	elif [ ! -x "${SERVER_BIN}" ]; then
		log_error "Could not execute HAFAS server (\"${SERVER_BIN}\"). Exitting!"
		exit 1
	fi
	
	# Append additional HAFAS options which are derived from other variables.
	if [ ${HAFAS_KERNEL_STATIST} ]; then
	    HAFAS_OPTIONS="${HAFAS_OPTIONS} -l${HAFAS_KERNEL_STATIST}"
	fi
	
	# Only check if the config file can be read if the variable is set!
	if [ ${CONFIG_FILE} ]; then
	    if [ ! -r ${CONFIG_FILE} ]; then
	        log_warning "Configuration file '${CONFIG_FILE}' not found or readable!"
	    fi
	fi
}


#-------------------------------------------------------------------------------
function change_uid_to_service_uid()
#-------------------------------------------------------------------------------
# If needed restarts the current environment as the service user described in 
# the environment variable RUNSAS_USER.
#-------------------------------------------------------------------------------
{
	# Path to the 'su'-command. Used to change to the service user
	SU="/bin/su"
	
	# Fetch the current numerical UID
	USERNAME=`/usr/bin/id -nu`
	
	# Check if this script is beeing run as the desired service user
	if [ ${USERNAME:?} != ${RUNAS_USER:?} ] ; then
		# Change the user to the user which this service should run as.
	    ${SU} ${RUNAS_USER} -c "$0 $@"
	    RETVAL=$?
	
	    if [ ${RETVAL} -ne 0 ]; then
	        log_error "Failed to start HAFAS as the service user \"${RUNAS_USER}\". Exitting!"
	        exit 1
	    fi
	    unset RETVAL
	
	    exit 0;
	fi
}


#-------------------------------------------------------------------------------
function check_process_running()
#-------------------------------------------------------------------------------
# Checks for the existence of the processes using the process ids passed as 
# arguments to this function.
# Returns 0 if all processes exist or 1 if not. If an empty argument list is 
# passes the result will be 0.
#-------------------------------------------------------------------------------
{
	local _result=0;
	
	for _pid in $@ ; do
		# Send signal 0 to the PID to check if signal communication is possible
		# This indicates existance of processes.
		kill -0 $_pid
		if [ $? -ne 0 ]; then
			_result=1
		fi
	done
	
	return $_result
}

#-------------------------------------------------------------------------------
function wait_for_exit()
#-------------------------------------------------------------------------------
# Wait until processes were stopped or timeout exceeded.
#-------------------------------------------------------------------------------
{
    local SLEEP_TIME=1
    local TIMEOUT=30
    local RETVAL=0

    let COUNT=0
    let DURATION=0
    RUNNING=1
    while [ "$RUNNING" = "1" ]; do
        let COUNT=$(($COUNT + 1))
        let DURATION=$(($COUNT * SLEEP_TIME))
        BASE_SERVER_BIN=`basename ${SERVER_BIN}`
        PIDS=`ps -fC ${BASE_SERVER_BIN} | grep "${SERVER_BIN}" | awk '{ printf("%s ", $2); }'`
        if [ $DURATION -lt $TIMEOUT ]; then
            if [ "$PIDS" != "" ]; then
                log_info_and_console "($DURATION sec): Waiting for child process(es) to exit: (PIDs) $PIDS"
                log_warning "($DURATION sec): Waiting for child process(es) to exit: (PIDs) $PIDS"
            else
                log_info_and_console "Process termination completed."
                log_warning "Process termination completed."

                WAIT_FOR_EXIT_PIDS=""      
                RUNNING=0
            fi
        else
            log_info_and_console "Process termination failed! Remaining (PIDs) $PIDS"
            log_warning "Process termination failed! Remaining (PIDs) $PIDS"

            WAIT_FOR_EXIT_PIDS="$PIDS"
            RUNNING=0
	    RETVAL=1
        fi

        if [ "$RUNNING" = "1" ]; then
            sleep $SLEEP_TIME
        fi
    done
    return ${RETVAL}
}

#-------------------------------------------------------------------------------
function gen_logrotate_conf()
#-------------------------------------------------------------------------------
# Generate a logrotate example configuration
#-------------------------------------------------------------------------------
{
  local ALL_LOG_FILES=""
  local SERVER_SH=""

  if [ -x "/etc/init.d/${INT_NAME}" ]; then
      SERVER_SH=/etc/init.d/${INT_NAME}
  else
      SERVER_SH=${SERVER_DIR}/server.sh
  fi

  case "${SERVER_TYPE}" in
      main|std|delfi|euspirit|trigger|main-realtime|std-realtime|p2w-main)
          if [ -f "${CONFIG_FILE}" ]; then
              ALL_LOG_FILES=`grep "log_file" "${CONFIG_FILE}" | awk '{ print $2; }' | grep -vE "%.*"`
          fi 

          if [ "x${REALTIME_LOG_FILE}" != "x" ]; then
              ALL_LOG_FILES="${ALL_LOG_FILES} ${REALTIME_LOG_FILE}"
          else
              if [ -f "${SERVER_DIR}/realtime.log" ]; then
                  LOG_TMP=`readlink -f ${SERVER_DIR}/realtime.log`
                  ALL_LOG_FILES="${ALL_LOG_FILES} ${LOG_TMP}"
              fi
          fi
          ;;
  esac 

  if [ "x${LOG_FILE}" != "x" ]; then
      ALL_LOG_FILES="${ALL_LOG_FILES} ${LOG_FILE}"
  fi

  log_info_and_console "#"
  log_info_and_console "# ${INT_NAME}"
  log_info_and_console "#"
  if [ "x${ALL_LOG_FILES}" != "x" ]; then
      for LOG in ${ALL_LOG_FILES}; do
          LOG_TMP=`readlink -f ${LOG}`
          if [ $? -eq 0 ]; then
              log_info_and_console "${LOG_TMP}"
          else
              log_info_and_console "$LOG"
          fi
      done
      log_info_and_console "{"
  fi  

cat <<EOT
        weekly
        rotate 26
        dateext
        missingok
        notifempty
        compress
        delaycompress
        sharedscripts
        postrotate
                ${SERVER_SH} try-restart > /dev/null
        endscript
}
EOT
}
