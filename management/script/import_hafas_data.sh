#!/bin/bash
#-------------------------------------------------------------------------------
# import_hafas_data.sh - Import script for HAFAS plan data
#-------------------------------------------------------------------------------
# This script imports HAFAS plan data files into a running HAFAS server. The
# currently used (old) plan data files are being backed up to safely restore 
# the old state of the plan data, when a server start with the new plan data 
# failes.
# This script is normally called by the server wrapper script (server.sh). The
# wrapper script implements the action 'data-update'
# The to be imported hafas plan data is fetched from a directory called 
# 'import_hafas_data/incoming' which must exist within the users home directory.
# Only one file may exist there and that one will be extracted to the plan data
# directory. The users name can be given as the third argument to this script. 
# If not present the current username will be used.
#
# All output which is beeing generated by the executed commands (tar, unzip and
# the like) is logged into the file called '/var/opt/hafas/log/update.log'. This
# can be used in case of problems.
#
#-------------------------------------------------------------------------------
# (C) Copyright 2006-2007 HaCon Ingenieurgesellschaft mbH
# Authors: Kai Fricke <kai.fricke@hacon.de>
# $Header: /cvs/hafas/script/import_hafas_data.sh,v 1.40 2013-11-05 08:30:57 rja Exp $
#-------------------------------------------------------------------------------

# Set up the shell to complain about undefined (not initialized) variables
set -u

# Only usefull for testing purposes
SUPER_BASE_DIR=""

# This super base directory describes the location of all HAFAS stuff on this
# server.
HAFAS_BASE_DIR="${SUPER_BASE_DIR}/opt/hafas"

# Retry Backup
MAX_BACKUP_RETRY=5

# Source some usefull functions
. ${HAFAS_BASE_DIR}/script/functions.sh
RETVAL=$?

if [ ${RETVAL} -ne 0 ]; then
    echo "Failed to include helper functions '${HAFAS_BASE_DIR}/script/functions.sh'. Exitting!"
    exit 1
fi

LOG_FILE="/var${HAFAS_BASE_DIR}/log/update.log"

#-------------------------------------------------------------------------------
function exit_now()
# Exit with error code '1' and write a message to the logfiles
#-------------------------------------------------------------------------------
{
    log_info "Plan data update failed for server wrapper '${SERVER_WRAPPER}'."
    log_file ${LOG_FILE} "Plan data update failed for server-wrapper '${SERVER_WRAPPER}'"
    
    if [ -s ${PLAN_BACKUP} ]; then 
        _now=`date +%Y%m%d-%H%M%S`
        mv ${PLAN_BACKUP} ${BACKUP_IMPORT_DIR}/${_now}.tar.gz
    fi
    
    if [ -n "${IMPORT_ARCHIVE-}" ]; then
	    if [ -f ${IMPORT_ARCHIVE}.lock ]; then
	        rm ${IMPORT_ARCHIVE}.lock
	    fi
    fi
    
    exit 1    
}


# This variable decides if the server should be started after importing the 
# hafas plan data. If the initial stop of the server failed the value changes
# to 'no'
RESTART_SERVER='yes'

# Fetch the command line arguments
if [[ ${#} -eq 3 ]]; then
	SERVER_WRAPPER=${1}
	DATA_IMPORT_DIR=${2}
	PLAN_DIR=${3}
else
    _myself=`basename "$0"`
    echo
    echo "Usage: ${_myself} <server-wrapper> <data_import_dir> <plan_data_dir>"
    echo
    exit 65
fi

# Convert relative to absolute path
echo "${SERVER_WRAPPER}" | grep '^/' >/dev/null 2>&1
if [ $? -ne 0 ]; then
    _pwd=`pwd`
    SERVER_WRAPPER="${_pwd}/${SERVER_WRAPPER}"
    unset _pwd
fi

# Clean up the path. If all seds supported true regular expressions, then this 
# is what it would be:
# echo "${_path}" |sed -r 's/[^/]*\/+\.{2}\/*//g;s/\/\.\//\//;s/\/+$//'
SERVER_WRAPPER=`echo "${SERVER_WRAPPER}" | sed 's/[^/]*\/*\.\.\/*//g;s/\/\.\//\//'`

# Let mktemp create a backup archive (tempfile would be more scure but is not
# available on all installations)
PLAN_BACKUP=`mktemp`

# Construct the import directories
INCOMING_IMPORT_DIR="${DATA_IMPORT_DIR}/incoming"
DEPLOYED_IMPORT_DIR="${DATA_IMPORT_DIR}/deployed"
BACKUP_IMPORT_DIR="${DATA_IMPORT_DIR}/backup"

log_info "Plan data update initiated for server wrapper '${SERVER_WRAPPER}'."
log_file ${LOG_FILE} "Plan data update initiated for server-wrapper '${SERVER_WRAPPER}'"

if [ ! -d ${PLAN_DIR} ]; then
    log_error "Plan data directory '${PLAN_DIR}' not found. Exitting!"
    exit_now
fi

if [ ! -w ${PLAN_DIR} ]; then
    log_error "Plan data directory '${PLAN_DIR}' is not writeable. Exitting!"
    exit_now
fi

# Check for the base and constructed import directories
if [ ! -d ${DATA_IMPORT_DIR} ]; then
    log_error "Base import directory '${DATA_IMPORT_DIR}' not found. Exitting!"
    exit_now
fi

if [ ! -r ${DATA_IMPORT_DIR} ]; then
    log_error "Could not read base import directory '${DATA_IMPORT_DIR}'. Exitting!"
    exit_now
fi

if [ ! -d ${INCOMING_IMPORT_DIR} ]; then
    log_error "Directory for incoming (to be deployed) plan data '${INCOMING_IMPORT_DIR}' not found. Exitting!"
    exit_now
fi

if [ ! -r ${INCOMING_IMPORT_DIR} ]; then
    log_error "Could not read directory for incoming (to be deployed) plan data '${INCOMING_IMPORT_DIR}'. Exitting!"
    exit_now
fi

if [ ! -d ${DEPLOYED_IMPORT_DIR} ]; then
    log_error "Directory for the just deployed plan data '${DEPLOYED_IMPORT_DIR}' not found. Exitting!"
    exit_now
fi

if [ ! -r ${DEPLOYED_IMPORT_DIR} ]; then
    log_error "Could not read directory for the just deployed plan data '${DEPLOYED_IMPORT_DIR}'. Exitting!"
    exit_now
fi

if [ ! -d ${BACKUP_IMPORT_DIR} ]; then
    log_error "Directory for old productive plan data '${BACKUP_IMPORT_DIR}' not found. Exitting!"
    exit_now
fi

if [ ! -r ${BACKUP_IMPORT_DIR} ]; then
    log_error "Could not read directory for old productive plan data '${BACKUP_IMPORT_DIR}'. Exitting!"
    exit_now
fi

# Check for the server wrapper
if [ ! -f ${SERVER_WRAPPER} ]; then
    log_error "Server wrapper '${SERVER_WRAPPER}' not found. Exitting!"
    exit_now
fi

if [ ! -x ${SERVER_WRAPPER} ]; then
    log_error "Server wrapper '${SERVER_WRAPPER}' is not executable. Exitting!"
    exit_now
fi

#
# Try to identify the to be imported archive
#
if [ `ls -1 ${INCOMING_IMPORT_DIR} | wc -l` -gt 1 ]; then
    _msg="Too many files in plan data import directory '${INCOMING_IMPORT_DIR}' (There must be exactly one archive). Exitting!"
    log_error "${_msg}"
    log_file ${LOG_FILE} "${_msg}"
    exit_now
elif [ `ls -1 ${INCOMING_IMPORT_DIR} | wc -l` -lt 1 ]; then
	_msg="No file found in plan data import directory '${INCOMING_IMPORT_DIR}' (There must be exactly one archive containing plan data). Exitting!"
	log_error "${_msg}"
	log_file ${LOG_FILE} "${_msg}"
    exit_now
fi

IMPORT_ARCHIVE=${INCOMING_IMPORT_DIR}/`ls -1 ${INCOMING_IMPORT_DIR}`
if [ -f ${IMPORT_ARCHIVE}.lock ]; then
    log_error "The lock file of already running plan data update exists ('${IMPORT_ARCHIVE}.lock')!"
    exit_now
else
	touch ${IMPORT_ARCHIVE}.lock
fi

if [ ! -r ${IMPORT_ARCHIVE} ]; then
    log_error "Could not read import archive '${IMPORT_ARCHIVE}'. Exitting!"
    exit_now
fi

log_info_and_console "Stopping HAFAS server before updating the plan data."
${SERVER_WRAPPER} stop
RETVAL=$?
            
if [ ${RETVAL} -ne 0 ]; then
    RESTART_SERVER="no"
fi

log_info_and_console "Backing up plan data."
log_file ${LOG_FILE} "Backing up plan data..."

if [ `ls -1 ${PLAN_DIR} | wc -l` -gt 0 ]; then
	pushd ${PLAN_DIR} > /dev/null
        for ((BACKUP_RETRY=0; ${BACKUP_RETRY} <= ${MAX_BACKUP_RETRY}; $((BACKUP_RETRY++)))); do
	  tar czvf ${PLAN_BACKUP} * >> ${LOG_FILE} 2>&1
	  RETVAL=$?
          if [ ${RETVAL} -ne 0 ]; then
            if [ ${BACKUP_RETRY} -lt ${MAX_BACKUP_RETRY} ]; then 
              log_info_and_console "Backup retry ($((BACKUP_RETRY+1)))."
              log_file ${LOG_FILE} "Backup retry ($((BACKUP_RETRY+1)))."
              sleep 2
            fi
          else
            break
          fi
        done
       
	if [ ${RETVAL} -ne 0 ]; then
	    log_error "Problems backing up the old plan data."
	    log_file ${LOG_FILE} "Error backing up plan data."
	    
	    log_error "(Re-)Starting HAFAS server and Exitting!"
	    log_file ${LOG_FILE} "Restarting HAFAS server!"
	
	    popd > /dev/null
	
	    if [ ${RESTART_SERVER} == "yes" ]; then
	        ${SERVER_WRAPPER} start
	    fi
	
	    rm -f ${PLAN_BACKUP}
	    exit_now
	else
	    log_file ${LOG_FILE} "Deleting old plan data..."
	    
	    rm -rf ${PLAN_DIR}/* >> ${LOG_FILE} 2>&1
	    RETVAL=$?
	    
	    log_file ${LOG_FILE} "Deleting old plan data completed!"
	    
	    if [ ${RETVAL} -ne 0 ]; then
	        log_error "Problems deleting the old plan data."
	        log_file ${LOG_FILE} "Problems deleting the old plan data."
	        log_error "(Re-)Starting HAFAS server with old plan data."
	        log_file ${LOG_FILE} "Restarting HAFAS with old plan data."
	        
	        log_file ${LOG_FILE} "Restoring old plan data..."
	
	        tar xzvf ${PLAN_BACKUP} >> ${LOG_FILE} 2>&1
	        RETVAL=$?
	
	        log_file ${LOG_FILE} "Restoring old plan data completed!"
	    	
	        if [ ${RETVAL} -ne 0 ]; then
	            log_error "Problems occured while restoring the old plan data."
	            log_error "Possibly we are in a very bad state."
	            log_error "Please check the logfile '${LOG_FILE}' for errors."
	            log_error "Make sure the HAFAS server is started correctly!"
	        fi        
	        
	        log_error "Exitting after having problems backing up the old plan data!"
	        
	        popd > /dev/null
	        
	        if [ ${RESTART_SERVER} == "yes" ]; then
	            ${SERVER_WRAPPER} start
	        fi
	        
	        exit_now
	    fi
	fi
	log_file ${LOG_FILE} "Backing up plan data completed!"
else
	log_info_and_console "No previous plan data found."
	log_file ${LOG_FILE} "No previous plan data found."
	
	# Delete the not used plan data backup archive.
	rm ${PLAN_BACKUP}
fi

log_file ${LOG_FILE} "Extracting new plan data from plan data archive..."

if [[ ${IMPORT_ARCHIVE/*.[zZ][iI][pP]/zip} = "zip" ]]; then
    unzip ${IMPORT_ARCHIVE} >> ${LOG_FILE} 2>&1
elif [[ ${IMPORT_ARCHIVE/*.[tT][aA][rR].[gG][zZ]/tar.gz} = "tar.gz" ]] || [[ ${IMPORT_ARCHIVE/*.[tT][gG][zZ]/tgz} = "tgz" ]]; then
    tar xzvf ${IMPORT_ARCHIVE} >> ${LOG_FILE} 2>&1
else
	log_error "Failed to identify archive type of file '${IMPORT_ARCHIVE}'."
	
	log_file ${LOG_FILE} "Restoring old plan data..."
	
	tar xzvf ${PLAN_BACKUP} -C ${PLAN_DIR} >> ${LOG_FILE} 2>&1
    RETVAL=$?
    if [ ${RETVAL} -ne 0 ]; then
        log_error "Problems occured while restoring the old plan data."
        log_error "Possibly we are in a very bad state."
        log_error "Please check the logfile '${LOG_FILE}' for errors."
    fi
    log_file ${LOG_FILE} "Restoring old plan data completed!"

	log_error "Aborting plan data update. Exitting!"
	log_file ${LOG_FILE} "Failed to identify archive type of file '${IMPORT_ARCHIVE}'. Aborting plan data update and Exitting!"
		
	exit_now
fi

_now=`date +%Y%m%d-%H%M%S`
_import_archive_filename=`basename ${IMPORT_ARCHIVE}`
mv ${IMPORT_ARCHIVE} ${DEPLOYED_IMPORT_DIR}/${_now}_${_import_archive_filename} >> ${LOG_FILE} 2>&1
RETVAL=$?

if [ ${RETVAL} -ne 0 ]; then
    log_error "Failed to move the deployed plan data '${IMPORT_ARCHIVE}' to it's final destination '${DEPLOYED_IMPORT_DIR}/${_now}_${_import_archive_filename}'."
    log_error "Please check the logfile '${LOG_FILE}' for additional output."
    log_error "Exitting with no backup of the deployed plan data. MAYBE A BAD STATE!!!"
    exit_now
fi

log_file ${LOG_FILE} "Extracting new plan data from plan data archive completed!"

log_info_and_console "Testing HAFAS plan data by starting the server in unsafe mode..."

${SERVER_WRAPPER} start_unsafe
RETVAL=$?
UPDATE_STATE=${RETVAL}
            
if [ ${RETVAL} -ne 0 ]; then
    log_error "Failed to start HAFAS server with new plan data."
    log_error "Restoring previous state (using old plan data)!"
    log_file ${LOG_FILE} "Restoring previous plan data set..."
    
    log_file ${LOG_FILE} "Deleting new plan data..."
    rm -rf ${PLAN_DIR}/* >> ${LOG_FILE} 2>&1
    
    if [ -s ${PLAN_BACKUP} ]; then
	    log_file ${LOG_FILE} "Restoring old plan data..."
    	tar -xzvf ${PLAN_BACKUP} >> ${LOG_FILE} 2>&1
	else
		log_file ${LOG_FILE} "No previous plan data backup exists!"
	fi
    
    log_file ${LOG_FILE} "Restoring previous plan data completed!"
else
    log_info_and_console "Testing HAFAS plan data succeeded!"
    ${SERVER_WRAPPER} stop
fi

if [ ${RESTART_SERVER} == "yes" ]; then
    log_info_and_console "Restarting the HAFAS server (in safe mode)."

    ${SERVER_WRAPPER} start
    RETVAL=$?

    if [ ${RETVAL} -ne 0 ]; then
        log_error "Final restart of HAFAS server failed."
        log_error "Please check the logfile of the HAFAS and maybe'${LOG_FILE}'."
        log_error "Exitting with no HAFAS server running! YERY BAD STATE!!!"
        exit_now
    fi
else
    log_info_and_console "Not Restarting the HAFAS server because it was not running when this script was called!"
fi

log_info_and_console "Plan data update finished for server-wrapper '${SERVER_WRAPPER}'."
log_file ${LOG_FILE} "Plan data update finished for server-wrapper '${SERVER_WRAPPER}'."

if [ -s ${PLAN_BACKUP} ]; then
	_now=`date +%Y%m%d-%H%M%S`
	mv ${PLAN_BACKUP} ${BACKUP_IMPORT_DIR}/${_now}.tar.gz >> ${LOG_FILE} 2>&1
	RETVAL=$?

    if [ ${RETVAL} -ne 0 ]; then
        log_error "Failed to move the plan data backup '${PLAN_BACKUP}' to it's final destination '${BACKUP_IMPORT_DIR}/${_now}.tar.gz'."
        log_error "Please check the logfile '${LOG_FILE}' for additional output."
        log_error "Exitting with no backup of the old plan data. MAYBE A BAD STATE!!!"
        exit_now
    fi
fi

rm ${IMPORT_ARCHIVE}.lock

popd > /dev/null
exit ${UPDATE_STATE}