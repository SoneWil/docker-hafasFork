#!/bin/bash
#-------------------------------------------------------------------------------
# create_server_wrapper.sh - Create a HAFAS server environment
#-------------------------------------------------------------------------------
# This script should be used to create a new environment for a HAFAS server. It 
# tries to respect all differences between several types of HAFAS servers and is 
# based on the defined standards for them.
#-------------------------------------------------------------------------------
# (C) Copyright 2006-2010 HaCon Ingenieurgesellschaft mbH
# Authors: Kai Fricke <kai.fricke@hacon.de>
#          Lars Bohn <lars.bohn@hacon.de>
# $Header: /cvs/hafas/script/create_server_wrapper.sh,v 1.27 2015-03-30 09:07:09 rja Exp $
#-------------------------------------------------------------------------------

# Set up the shell to complain about undefined (not initialized) variables
set -u

# Only usefull for testing purposes
SUPER_BASE_DIR=""

# This super base directory describes the location of all HAFAS stuff on this
# server.
HAFAS_BASE_DIR="${SUPER_BASE_DIR}/opt/hafas"

# Source some usefull functions
. ${HAFAS_BASE_DIR}/script/functions.sh
RETVAL=$?

if [ ${RETVAL} -ne 0 ]; then
    echo "Failed to include helper functions '${HAFAS_BASE_DIR}/script/functions.sh'. Exitting!"
    exit 1
fi

#-------------------------------------------------------------------------------
function create_dir
#-------------------------------------------------------------------------------
# Creates a directory and changes the ownership to the hafas service user and 
# the group to the hafas group. Additionally this method logs the action to the 
# console and logfile.
#
# Arguments:
#  1. The directory to be creted
#  2. A description of the directory (sensible logging)
#-------------------------------------------------------------------------------
{
	_path=$1
	_descr=$2
	
	if [ ! -d ${_path} ]; then
	    log_info_and_console "Creating directory for ${_descr} '${_path}'."
	    mkdir -p ${_path}
	    if [ $? -gt 0 ]; then
	        log_error "Failed to create directory for ${_descr}. Exitting!"
	        exit 1
	    fi
	    chmod 775 ${_path}
		if [ ${UID} -eq 0 ]; then chown ${RUNAS_USER} ${_path}; fi
	    chgrp ${HAFAS_GROUP} ${_path}
	else
	    log_info_and_console "Directory '${_path}' for ${_descr} already exists. Continuing!"
	fi
}


#-------------------------------------------------------------------------------
function create_symlink
#-------------------------------------------------------------------------------
# Creates a symbolic link to the specified target and changes the ownership to 
# the hafas service user and the group to the hafas group. Additionally this 
# method logs the action to the console and logfile.
#
# Arguments:
#  1. The target of the link
#  2. The name of the link
#  3. A description of the to be linked target (sensible logging)
#-------------------------------------------------------------------------------
{
	_target=$1
	_link_name=$2
	_descr=$3
	if [ ! -e ${_target} ]; then
		log_info_and_console "Target '${_target}' of symbolic link for ${_descr} does not exists. Continuing!"
	fi
	if [ ! -e ${_link_name} ]; then
	    log_info_and_console "Creating symbolic link for ${_descr} from '${_target}' to '${_link_name}'."
		ln -s ${_target} ${_link_name}
		if [ $? -gt 0 ]; then
	        log_error "Failed to create symbolic link to ${_descr}. Exitting!"
	        exit 1
    	fi
		chmod 775 ${_path}
		if [ ${UID} -eq 0 ]; then chown -h ${RUNAS_USER} ${_path}; fi
	    chgrp -h ${HAFAS_GROUP} ${_path}
	else
		log_info_and_console "A file with name of symbolic link '${_link_name}' for ${_descr} already exists. Continuing!"
	fi
}


# Plan lists of valid values for some answers
VALID_PRODUCT_STATES="dev test pub rel prod"
VALID_SERVER_TYPES="datacollector p2w-broker p2w-converter p2w-main simple main main-realtime match trigger sqlbroker"

# The user group for the hafas services. This group is used for the to be 
# created directories and files to assure the access-rights for the later 
# running service.
HAFAS_GROUP="hafas"

# Initializing the answers
# Setting defaults here forces the parameters to be set, as no input is always 
# replaced with previous value (done by the method read_user_input)
#RUNAS_USER=`whoami`
RUNAS_USER="hafas"
PRIMARY_NAME="${RUNAS_USER}"
SECONDARY_NAME="main"
PLAN_VERSION="5.20"
PLAN_SUFFIX=""
PRODUCT_STATE="prod"
SERVER_TYPE="main"
PORT="10001"

YES="no"

# Set text face to white & bold
echo -e '\E[37;40m\033[1m'
cat <<EOT
Please answer the following questions to create a new HAFAS environment.

A pre-configured start script for the HAFAS server will be placed in the
directory which is constructed from your input.
While creating the start script and the environment, some sanity checks are 
executed to prevent this script from disturbing other HAFAS servers.

Please be patient while entering the values, because your answers are not 
checked to be valid or reasonable at all. Just some examples and descriptions 
are printed with each question. This way you have maximum flexibility without 
restricting you!

Needless to say you should need to know what you can do by using combinations
of parameters (espacially PLAN_VERSION and PLAN_SUFFIX). Consult the 
documentation to this topics.
EOT
# Set text face to yellow & bold
echo -e '\E[33;40m\033[1m'

#until [ "${YES}" = "yes" ]; do
	cat <<EOT
While answering this questions you can always exit by pressing "Ctrl-c"!
EOT
	# Set text face to white & normal
	echo -e '\E[37;40m\033[0m'
	
	
	echo_bold 'What state of use will the server have?'
cat <<EOT
Possible values are: ${VALID_PRODUCT_STATES}
EOT
    echo -n "(${PRODUCT_STATE}) > "
#    read_user_input ${PRODUCT_STATE}
#    PRODUCT_STATE=${USER_INPUT}
    echo
    
    echo_bold 'What type of server do you want to wrap with this script?'
    cat <<EOT
Possible values are: ${VALID_SERVER_TYPES}
EOT
    echo -n "(${SERVER_TYPE}) > "
#    read_user_input ${SERVER_TYPE}
#    SERVER_TYPE=${USER_INPUT}
#    SECONDARY_NAME=${SERVER_TYPE}
    echo
    
    echo_bold 'What will the primary name of this server be?'
    cat <<EOT
This is usually the name of the project, client or developer.
EOT
    echo -n "(${PRIMARY_NAME}) > "
#    read_user_input ${PRIMARY_NAME}
#    PRIMARY_NAME=${USER_INPUT}
    echo
    
    echo_bold 'What should the secondary name be?'
    cat <<EOT
This is a rather abstract description of the server.
EOT
    echo -n "(${SECONDARY_NAME}) > "
#    read_user_input ${SECONDARY_NAME}
#    SECONDARY_NAME=${USER_INPUT}
    echo

	echo_bold 'What plan version should set?'
    cat <<EOT
This is a prefix used to construct the plan data directory (consult the 
documentation for details). 
EOT
    echo -n "(${PLAN_VERSION}) > "
#    read_user_input ${PLAN_VERSION}
#    PLAN_VERSION=${USER_INPUT}
    echo

    echo_bold 'What plan directory suffix should be set?'
    cat <<EOT
This will be appended to the primary name when constructing the plan data 
directory (consult the documentation for details).
EOT
    echo -n "(${PLAN_SUFFIX}) > "
#    read_user_input ${PLAN_SUFFIX}
#    PLAN_SUFFIX=${USER_INPUT}
    echo

    echo_bold 'Which port should this server listen to?'
    cat <<EOT
This is usually a value within the range of 1024-65535.
EOT
    echo -n "(${PORT}) > "
#    read_user_input ${PORT}
#    PORT=${USER_INPUT}
    echo
    
    echo_bold 'Which user should this server run as?'
    cat <<EOT
This is usually the username of you (the developer) or a project user.
EOT
    echo -n "(${RUNAS_USER}) > "
#    read_user_input ${RUNAS_USER}
#    RUNAS_USER=${USER_INPUT}

    if [ "${PLAN_VERSION}" = "" ]; then
        PLAN_DIR="${HAFAS_BASE_DIR}/plan/${PRIMARY_NAME}${PLAN_SUFFIX}/${SECONDARY_NAME}"
    else
        PLAN_DIR="${HAFAS_BASE_DIR}/plan/${PLAN_VERSION}/${PRIMARY_NAME}${PLAN_SUFFIX}"
    fi
    SERVER_BASE_DIR="${HAFAS_BASE_DIR}/${PRODUCT_STATE}/${PRIMARY_NAME}/${SECONDARY_NAME}"
    
	INT_NAME="${PRIMARY_NAME}-${PRODUCT_STATE}-hafas-server-${SECONDARY_NAME}"
    
    SERVER_DIR="${SERVER_BASE_DIR}/server"
    WRAPPER_BIN="${SERVER_DIR}/server.sh"
    LIB_DIR="${SERVER_BASE_DIR}/lib"
    
    PID_DIR="${SUPER_BASE_DIR}/var/opt/hafas/run/${PRIMARY_NAME}"
    PID_FILE="${PID_DIR}/${INT_NAME}.pid"
    
    LOG_DIR="${SUPER_BASE_DIR}/var/opt/hafas/log/${PRIMARY_NAME}"
    LOG_FILE="${LOG_DIR}/${INT_NAME}.log"
    LOG_FILE_REALTIME="${LOG_DIR}/${INT_NAME}-realtime.log"
    LOG_FILE_REALTIME_SYMLINK_NAME="${SERVER_DIR}/realtime.log"
    
	case ${SERVER_TYPE} in
		p2w-broker)
			LOG_FILE_SYMLINK_NAME=${SERVER_DIR}/broker.log
			CREATE_PLAN_DIR="NO"
			;;
		datacollector)
			LOG_FILE_SYMLINK_NAME=${SERVER_DIR}/datacollector.log
			CREATE_PLAN_DIR="NO"
			;;
		*)
			LOG_FILE_SYMLINK_NAME=${SERVER_DIR}/server.log
			CREATE_PLAN_DIR="YES"
			;;
	esac
    
    STATIST_FILE="${LOG_DIR}/${INT_NAME}.statist"
    SPOOL_DIR="${SUPER_BASE_DIR}/var/opt/hafas/spool/${PRIMARY_NAME}/${INT_NAME}"
    
    # Set text face to red & bold
    echo -e '\E[31;40m\033[1m'
    cat <<EOT
! Please verify that the following was your intended input and review it for 
! typing errors, as it will be used to construct files and directories! Later 
! fixing of directories and names can only be made manually with some 
! additional effort.
EOT
	# Set text face to white & normal
	echo -e '\E[37;40m\033[0m'

	echo '(press enter to continue...)'
#	read _trash
	
    cat <<EOT
User to run as:        ${RUNAS_USER}
Primary name:          ${PRIMARY_NAME}
Secondary name:        ${SECONDARY_NAME}
Plan data version:     ${PLAN_VERSION}
Plan data suffix:      ${PLAN_SUFFIX}
State of the product:  ${PRODUCT_STATE}
Type of the server:    ${SERVER_TYPE}
Port to listen to:     ${PORT}

The wrapper script:               ${WRAPPER_BIN}
The server directory:             ${SERVER_DIR}
The library directory:            ${LIB_DIR} 
Plan data directory:              ${PLAN_DIR}
The PID file:                     ${PID_FILE}
The server log file:              ${LOG_FILE}
Symbolic link to log file:        ${LOG_FILE_SYMLINK_NAME}
Spool data directory (P2W only):  ${SPOOL_DIR}

EOT
	echo_bold 'Have you reviewed the above information and want to construct the environment?'
	cat <<EOT
(Enter 'yes' to construct the environment or anything else to start all over)
EOT
    echo -n "(no) > "
    read YES
#done

echo

_RUNNING_USER=`whoami`

log_info "The user ${_RUNNING_USER} is creating an HAFAS server wrapper (PRODUCT_STATE: ${PRODUCT_STATE}, PRIMARY_NAME: ${PRIMARY_NAME}, SECONDARY_NAME: ${SECONDARY_NAME}, SEVRER_TYPE: ${SERVER_TYPE})"
log_info_and_console "Constructing the environment and the wrapper script..."

create_dir ${SERVER_DIR} "the HAFAS server binary"

if [ ! -f ${WRAPPER_BIN} ]; then
    log_info_and_console "Creating a new server wrapper in the server directory."
    cat ${SUPER_BASE_DIR}/opt/hafas/script/server.sh \
        | sed "s§^# Provides: primary_name-product_state-hafas-server-secondary_name$§# Provides: ${INT_NAME}§" \
        | sed "s§^RUNAS_USER=\"\"$§RUNAS_USER=\"${RUNAS_USER}\"§" \
        | sed "s§^PRIMARY_NAME=\"\"$§PRIMARY_NAME=\"${PRIMARY_NAME}\"§" \
        | sed "s§^SECONDARY_NAME=\"\"$§SECONDARY_NAME=\"${SECONDARY_NAME}\"§" \
        | sed "s§^PLAN_VERSION=\"\"$§PLAN_VERSION=\"${PLAN_VERSION}\"§" \
        | sed "s§^PLAN_SUFFIX=\"\"$§PLAN_SUFFIX=\"${PLAN_SUFFIX}\"§" \
        | sed "s§^PRODUCT_STATE=\"\"$§PRODUCT_STATE=\"${PRODUCT_STATE}\"§" \
        | sed "s§^SERVER_TYPE=\"std\"$§SERVER_TYPE=\"${SERVER_TYPE}\"§" \
        | sed "s§^SERVER_TYPE=\"main\"$§SERVER_TYPE=\"${SERVER_TYPE}\"§" \
        | sed "s§^PORT=\"\"$§PORT=\"${PORT}\"§" \
        | sed "s§^CONFIGURED=\"NO\"$§CONFIGURED=\"YES_BUT_NOT_REVIEWED\"§" \
        > ${WRAPPER_BIN}
    if [ $? -gt 0 ]; then
        log_error "Failed to create new wrapper script. Exitting!"
        exit 1
    fi
    chmod 775 ${WRAPPER_BIN}
	if [ ${UID} -eq 0 ]; then chown ${RUNAS_USER} ${WRAPPER_BIN}; fi
    chgrp ${HAFAS_GROUP} ${WRAPPER_BIN}
else
    log_error "Wrapper script already exists. Exitting!"
    exit 1
fi

if [ ! -x ${WRAPPER_BIN} ]; then
    log_info_and_console "Setting execute permission for wrapper script"
    chmod ug+x ${WRAPPER_BIN}
    if [ $? -gt 0 ]; then
        log_error "Failed to set execute permission for wrapper script. Exitting!"
        exit 1
    fi
fi

# It is always possible/usefull to have a personal library directory
create_dir ${LIB_DIR} "libraries the server depends on"

# Create the direcotory for the log files if not present.
if [ ! -d ${LOG_DIR} ]; then
	create_dir ${LOG_DIR} "log files"
fi

# Create the direcotory for the PID files if not present.
if [ ! -d ${PID_DIR} ]; then
	create_dir ${PID_DIR} "process ID files"
fi

# Only create the direcotory for the plan data if the server supports/needs 
# data plan.
if [ "${CREATE_PLAN_DIR}" = "YES" ]; then
	create_dir ${PLAN_DIR} "plan data"
fi

# Create the symbolic link to the log file named as the server (type) likes it.
create_symlink ${LOG_FILE} ${LOG_FILE_SYMLINK_NAME} "the logfile within the server directory"

# Some server types have additional environments which are created now...
case ${SERVER_TYPE} in 
        main|main-realtime|p2w-main|trigger)
		log_info_and_console "Creating additionally links..."
                create_symlink ${LOG_FILE_REALTIME} ${LOG_FILE_REALTIME_SYMLINK_NAME} "realtime logfile"
                ;;
	p2w-broker)
		log_info_and_console "Creating additionally P2W broker directories..."
			
		REQUEST_SPOOL_DIR="${SPOOL_DIR}/request"
		REQUEST_LINK_NAME="${SERVER_BASE_DIR}/request"
		MAIL_SPOOL_DIR="${SPOOL_DIR}/mail"
		MAIL_LINK_NAME="${SERVER_BASE_DIR}/mail"
		MAILTEMPLATES_DIR="${SERVER_BASE_DIR}/mailtemplates"
		ERROR_LOG_DIR="${LOG_DIR}/${INT_NAME}.error"
		ERROR_LINK_NAME="${SERVER_BASE_DIR}/error"
		SENDMAIL_LOG="${LOG_DIR}/${INT_NAME}-sendmail.log"
		SENDMAIL_LOG_LINK_NAME="${SERVER_DIR}/sendmail.log"
		STATISTIC_DIR="${LOG_DIR}/${INT_NAME}.statistic"
		STATISTIC_LINK_NAME="${SERVER_BASE_DIR}/statistic"
		
		create_dir ${REQUEST_SPOOL_DIR} "P2W requests spools"
		create_symlink ${REQUEST_SPOOL_DIR} ${REQUEST_LINK_NAME} "P2W requests spools"
		create_dir ${MAIL_SPOOL_DIR} "P2W mail spools"
		create_symlink ${MAIL_SPOOL_DIR} ${MAIL_LINK_NAME} "P2W mail spools"
		create_dir ${MAILTEMPLATES_DIR} "P2W mail templates"
		create_dir ${ERROR_LOG_DIR} "P2W error logfiles"
		create_symlink ${ERROR_LOG_DIR} ${ERROR_LINK_NAME} "P2W error logfiles"
		create_symlink ${SENDMAIL_LOG} ${SENDMAIL_LOG_LINK_NAME} "P2W Sendmail logfile"
		create_dir ${STATISTIC_DIR} "P2W statistic"
		create_symlink ${STATISTIC_DIR} ${STATISTIC_LINK_NAME} "P2W statistic"
		;;
	p2w-converter)
		log_info_and_console "Creating additionally P2W converter directories..."
		
		TEMP_DIR="${SPOOL_DIR}/temp"
		TEMP_LINK_NAME="${SERVER_BASE_DIR}/temp"
		XML2OUTPUT_TEMPLATES_DIR="${SERVER_BASE_DIR}/xml2output_templates"
		
		create_dir ${TEMP_DIR} "P2W temporary files"
		create_symlink ${TEMP_DIR} ${TEMP_LINK_NAME} "P2W temporary files"
		create_dir ${XML2OUTPUT_TEMPLATES_DIR} "P2W XML2OUTPUT templates"
		;;
	match)
		MATCH_RT_DELAY_DIR="${SERVER_DIR}/rt_delay"
		MATCH_LOG_DIR="${LOG_DIR}/${INT_NAME}.data"
		MATCH_LOG_BACKUP_DIR="${MATCH_LOG_DIR}/backup"
		MATCH_LOG_LINK_NAME="${SERVER_DIR}/log"
		
		# rt_delay & log Verzeichnis
		
		create_dir ${MATCH_RT_DELAY_DIR} "match rt_delay"
		create_dir ${MATCH_LOG_DIR} "match data logfiles"
		create_symlink ${MATCH_LOG_DIR} ${MATCH_LOG_LINK_NAME} "match data logfiles"
		create_dir ${MATCH_LOG_BACKUP_DIR} "match data logfiles backup"

		# create rotate_logs.sh script for delay_log* rotation
		log_info_and_console "Creating 'rotate_logs.sh' for match data logfile in '${MATCH_LOG_DIR}'."
		MATCH_ROTATE_LOGS_BIN="${MATCH_LOG_DIR}/rotate_logs.sh"
		cat ${HAFAS_BASE_DIR}/script/rotate_logs.sh \
			| sed "s§^RT_MATCH_DIR=\"\"$§RT_MATCH_DIR=\"${SERVER_DIR}\"§" \
			> ${MATCH_ROTATE_LOGS_BIN}
		chmod 775 ${MATCH_LOG_DIR}/rotate_logs.sh
		if [ ${UID} -eq 0 ]; then chown ${RUNAS_USER} ${MATCH_ROTATE_LOGS_BIN}; fi
		chgrp ${HAFAS_GROUP} ${MATCH_ROTATE_LOGS_BIN}
		;;
		
	datacollector)
		OUTPUT_DIR="${LOG_DIR}/${INT_NAME}.output"
		OUTPUT_DIR_LINK_NAME="${SERVER_BASE_DIR}/output"
		
		create_dir ${OUTPUT_DIR} "datacollector output directory"
		create_symlink ${OUTPUT_DIR} ${OUTPUT_DIR_LINK_NAME} "datacollector output directory"
		;;
	*)
esac

cat <<EOT

Finished creating the new server wrapper at location: 
  '${WRAPPER_BIN}'

EOT
