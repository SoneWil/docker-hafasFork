#!/bin/bash
#-------------------------------------------------------------------------------
# server_safe.sh - A safe for a HAFAS server
#-------------------------------------------------------------------------------
# This script basically starts process or service in a safety wrapper (the so 
# called safe).
#
# In the unexpected situation that the process or service crashes or exited, 
# this safe restarts the process.
# If an notification about the unexpected restart is desired, the email address 
# of the recipient can be specified in the environment variable 
# HAFAS_SERVER_RESTART_MAIL_NOTIFICATION_ADDRESS.
#
# Additionally it writes its own and the PID of the started server process to
# file which contains all PIDs of processes which serve the specific service.
# That PID file can be used to securely shut down that service.
#
# SYNTAX
#   $0 <pid_file> <command> [ <args> ... ]
#
#-------------------------------------------------------------------------------
# (C) Copyright 2006-2007 HaCon Ingenieurgesellschaft mbH
# Authors: Kai Fricke <kai.fricke@hacon.de>
# $Header: /cvs/hafas/script/server_safe.sh,v 1.26 2015-08-12 13:03:57 adu Exp $
#-------------------------------------------------------------------------------

################################################################################
# You should not need to edit anything within this script!
################################################################################

# Only usefull for testing purposes
SUPER_BASE_DIR=""

# This directory describes the location of all HAFAS stuff on this server.
HAFAS_BASE_DIR="${SUPER_BASE_DIR}/opt/hafas"
if [ ! -d ${HAFAS_BASE_DIR} ]; then
    echo "Error: Directory '${HAFAS_BASE_DIR}' not found!"
    echo "Check the variable HAFAS_BASE_DIR in the script '${0}'"
    exit 1
fi

# Source some usefull functions
. ${HAFAS_BASE_DIR}/script/functions.sh

# Server stop requested to stop server by sending signal 15
SERVER_STOP_REQUESTED=0

# Trap sensible signals sent to this script!
trap_signals

# Just remember when the instance got started.
START_DATE=`date -R`

# Count the mails sent to avoid sending too many mails.
MAILS_SENT=0

# Only start sending mails five minutes after the startup.
SECONDS_TIMESTAMP_LAST_MAIL=`date +%s`

# The amount of seconds between the checks for the HAFAS process
SECONDS_BETWEEN_CHECKS=10

# Read the PID file from the argument list
PID_FILE=$1

# Shift the first argument (the PID file) away
shift

# The resulting argument string is the command to start the server
SERVER_CMD="$*"

# The following crippled version of the commandline is used because the later
# test for the vitality of the HAFAS process is based on a lookup in the proc
# filesystem, which tells the commandline of a PID with missing space
# seperators between the command and the arguments.
SERVER_CMDL=`echo $SERVER_CMD | sed 's/[ ]//g'`

# Checking if this script is run as user root
if [ ${UID} -eq 0 ]
then
    log "Starting this command as user root is a very bad idea! Quitting..."
    exit 1
fi

# Don't start if another instance seems to run!
if [ -f ${PID_FILE} ]
then
    log_error "Start aborted because PID file exists (PID-File=${PID_FILE})!"
    exit 1
fi

LOOP_COUNT=0
RESTART_LOOP_COUNT=0

# Endless loop for starting the server
while [ true ]
do
    LOOP_COUNT=$((${LOOP_COUNT} + 1))

    # Log the own PID to the file
    echo -n "$$" > ${PID_FILE}
    RETVAL=$?

    if [ ${RETVAL} -ne 0 ]; then
        log_error "Problem while trying to write my own PID to the PID file (PID-File=${PID_FILE}). Exiting!"
        exit 1
    fi
    unset RETVAL

    log_info "Starting safe-mode server (Commandline=${SERVER_CMD})..."

    ${SERVER_CMD} &
    SERVER_PID=$!

    # Check if the server process can be signaled (and thus is running)
    sleep 3
    kill -0 ${SERVER_PID} > /dev/null 2>&1
    RETVAL=$?

    if [ ${RETVAL} -ne 0 ]; then
        log_error "Problem trying to start the HAFAS server (Commandline=${SERVER_CMD}, Exitcode is not available (because it got started in the background!))!"
	
	# Try to catch a foreign HAFAS process matching the to be started
	# instance
	FOREIGN_PROCESS_FOUND=0

	# Search for PIDs of processes using the same command line as we
	# wanted a HAFAS server to start with.
	# Only considering my own processes!
	COUNT_PIDS_WITH_SERVER_CMD=`ps x | grep "${SERVER_CMD}"| grep -v grep | grep -v server_safe.sh | awk '{print $1}' | wc -l`

	if [ ${COUNT_PIDS_WITH_SERVER_CMD} -eq 1 ]; then
		STRANGE_PID=`ps x | grep "${SERVER_CMD}"| grep -v grep | grep -v server_safe.sh | awk '{print $1}'`
	elif [ ${COUNT_PIDS_WITH_SERVER_CMD} -gt 1 ]; then
		log_error "Too many foreign HAFAS processes found (possibly using a forked server). Sadly this makes it not easy to catch the main process. Therefore giving up on catching it. Exitting!"
		# Alternative not implemented: Probably dumbly kill all 
		# HAFAS servers to do a clean restart instead of giving up!?
		rm ${PID_FILE}
		exit 1
	else
		STRANGE_PID=""
	fi

	# In case we found a foreign process ID now checking this process...
	if [ "${STRANGE_PID}" != "" ]; then
		log_info "Foreign server found! Trying to send it a signal..."
		kill -0 ${STRANGE_PID} > /dev/null 2>&1
		RETVAL=$?

		if [ ${RETVAL} -eq 0 ]; then
			log_info "Signal successfully sent to the strange server. Dumbly assuming it is running and working!"
			SERVER_PID=${STRANGE_PID}
			FOREIGN_PROCESS_FOUND=1
		else
			log_error "Sending a signal to the foreign server failed!"
		fi
	fi

	if [ ${FOREIGN_PROCESS_FOUND} -eq 0 ]; then
	        log_error "Searching for another foreign HAFAS server failed. Exitting!"
		
		# Exit if this is the initial start of HAFAS to immediately 
		# signal a problem while starting the HAFAS server.
		if [ ${LOOP_COUNT} -eq 1 ]; then
			log_error "The inital start of HAFAS failed. Exitting!"
	        	rm ${PID_FILE}
		        exit 1
			
		# Check for a restart loop
		elif [ ${LOOP_COUNT} -eq $((${LAST_SEEN_LOOP_COUNT} + 1)) ]; then
			RESTART_LOOP_COUNT=$((${RESTART_LOOP_COUNT} + 1))
			log_error "Restart loop detected (duration: approx. $((${RESTART_LOOP_COUNT} * (${SECONDS_BETWEEN_CHECKS} + 3))) seconds, number of iterations: ${RESTART_LOOP_COUNT})!"
		fi

		# Wait for 2 minutes for the restart loop to settle.
		if [ ${RESTART_LOOP_COUNT} -gt $((120 / (${SECONDS_BETWEEN_CHECKS} + 3))) ]; then
			log_error "Restart loop lasted more than 2 minutes. Giving up on restarting the HAFAS server. Exitting!"
			rm ${PID_FILE}
			exit 1
		fi

		# Remember the loop that reached this point to detect 
		# restart loops.
		LAST_SEEN_LOOP_COUNT=${LOOP_COUNT}
	else
		log_error "Resuming normal operations after catching the foreign HAFAS process using the PID ${SERVER_PID}"
	fi
    else
    	# Each successfull start of the HAFAS process resets the counter 
	# that determines a restart loop.
    	if [ ${RESTART_LOOP_COUNT} -gt 0 ]; then
		log_error "Reasons for a start loop seem to have been resolved. Resetting restart loop counter."
		RESTART_LOOP_COUNT=0
	fi
    fi
    unset RETVAL

    # Append the PID of the started HAFAS Server to the PID-file
    echo -n " ${SERVER_PID}" >> ${PID_FILE}
    RETVAL=$?

    if [ ${RETVAL} -ne 0 ]; then
        log_error "Problem while appending the PID of the HAFAS server to the PID file (PID=${SERVER_PID}, PID-File=${PID_FILE})!"
        log_error "Exiting!"
        exit 1
    fi
    unset RETVAL

    # Fetch the commandline of the servers PID
    PROC_CMDL=`cat /proc/${SERVER_PID}/cmdline`
    RETVAL=$?

    # It may take a little time to let the server PID appear in the Proc-FS.
    # Because of that we fetch the first failing try to read the command line
    # and retry it after a little time.
    if [ ${RETVAL} -ne 0 ]; then
        log_warning "Problem checking the command line of the server process (PID=${SERVER_PID})!"
        log_warning "Waiting for the HAFAS server to appear in the process list..."

        sleep 10

        # Try to fetch the commandline of the servers PID again
        PROC_CMDL=`cat /proc/${SERVER_PID}/cmdline`
        RETVAL=$?

        if [ ${RETVAL} -ne 0 ]; then
            log_warning "Server did not start up, giving up this try and killing it (PID=${SERVER_PID})!"
            kill -15 ${SERVER_PID}
            SERVER_PROCESS_ID_APPEARED="NO"
        else
            log_warning "Server appeared with a little delay (PID=${SERVER_PID})!"
            SERVER_PROCESS_ID_APPEARED="YES"
        fi
    else
        log_info "Server started successfully (PID=${SERVER_PID})!"
        SERVER_PROCESS_ID_APPEARED="YES"
    fi
    unset RETVAL

    # Only watch for the existance of the server if the process started
    # successfull.
    CRASHED=0
    if [ "${SERVER_PROCESS_ID_APPEARED}" == "YES" ]; then
        # Loop while the HAFAS server process seems to exist. If the server
	# disappears (dies etc.) the following comparison of the 
	# commandlines fails and the safe-loop is interrupted. The global 
	# restart loop is started again after a few more steps (see below).
        while [ "${PROC_CMDL}" == "${SERVER_CMDL}" ]; do
            if [ ${SERVER_STOP_REQUESTED} -eq 1 ]; then
              log_info "Quit safe loop due to stop request. (PID=$$)"
              break 2
            fi 

            PROC_CMDL=`cat /proc/${SERVER_PID}/cmdline`
            RETVAL=$?
            if [ ${RETVAL} -eq 0 ]; then
                # Sleep a while before checking the next time
                sleep ${SECONDS_BETWEEN_CHECKS:?}
            else
                CRASHED=${RETVAL}
            fi
            unset RETVAL
        done
    fi

    log_error "ERROR: HAFAS server disappeared (PID=${SERVER_PID}, Number of restarts=${LOOP_COUNT})!"
    if [ ${HAFAS_SERVER_CRASH_BACKUP} -eq 1 ]; then
      # Safe information after crash for further investigation
      if [ $CRASHED -ne 0 ]; then
        case "${SERVER_TYPE}" in
          match)
                  if [ -d ${RT_HAFAS_DIR} ]; then
                    log_error "ERROR: HAFAS server disappeared (PID=${SERVER_PID}, backup realtime situation for further investigation!"
                    CRASH_BACKUP_RT_FILES="`ls -1 rt_delay/delay_liste rt_delay/delay_old rt_delay/planrt* | grep -Ev \"planrt_copy|planrt_clean|planrt_clean.next\"`"
                    CRASH_BACKUP_LOG_FILES="realtime.log"
                    tar -hcvzf ${RT_LOG_BACKUP_DIR}/delay_log_crash_`date +%Y%m%d%H%M%S`.tgz ${CRASH_BACKUP_RT_FILES} ${CRASH_BACKUP_LOG_FILES} 2>&1>/dev/null

                    log_error "ERROR: Remove possible corrupted realtime situation."
                    rm -vf ${CRASH_BACKUP_RT_FILES} ${CRASH_BACKUP_LOG_FILES}
                  fi 
                  ;;
        esac
      fi
    fi

    # Restart immediatly because we already waited 10 seconds in the inner loop
    log_error "Restarting HAFAS server immediately..."

    # Only send mails if the enviroment wants them to be sent
    if [ ! -z ${HAFAS_SERVER_RESTART_MAIL_NOTIFICATION_ADDRESS} ]; then

        # Limit the amount of sent mails over time
        _NOW_SECONDS=`date +%s`
        
        if [ ${MAILS_SENT} -lt 6 ]; then        
            
            ((SECONDS_SINCE_LAST_MAIL=${_NOW_SECONDS}-${SECONDS_TIMESTAMP_LAST_MAIL}))
            if [ ${SECONDS_SINCE_LAST_MAIL} -gt 300 ]; then
                HOSTNAME=$(hostname -f)
                mail -s "HAFAS server disappeared! Restarting immediately!" ${HAFAS_SERVER_RESTART_MAIL_NOTIFICATION_ADDRESS} <<EOM
The HAFAS server has disappeared unexpectedly.

The command line to start the server on ${HOSTNAME} was: ${SERVER_CMD}

This server crashed ${LOOP_COUNT} times since ${START_DATE}.

This is not the normal behaviour and an evidence of problems. Please take care 
of it.

Sincerly,
--
your HAFAS server-safe
EOM
                SECONDS_TIMESTAMP_LAST_MAIL=`date +%s`
                ((MAILS_SENT+=1))
            fi
        else
            mail -s "LAST NOTIFICATION about this crashing HAFAS server!" ${HAFAS_SERVER_RESTART_MAIL_NOTIFICATION_ADDRESS} <<EOM
This is the last email regarding this badly crashing HAFAS server. Please take 
care of it.

No additional email will be sent until the next scheduled or manual 
restart of this service.

The command line to start the server was: ${SERVER_CMD}

This crashed ${LOOP_COUNT} times since ${START_DATE}.

Sincerly,
--
your HAFAS server-safe

EOM
            
            # After sending the last notification mail unset the initial 
            # variable which is responsible for triggering this mechanism
            unset HAFAS_SERVER_RESTART_MAIL_NOTIFICATION_ADDRESS
        fi
    fi
    
done
