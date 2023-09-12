#!/bin/bash
#-------------------------------------------------------------------------------
# HAFAS Cleanup
#-------------------------------------------------------------------------------
# This script will be run then the operating system boot and not any server
# was started.
# It's delete all old PID-files and clean the spool directories
# 
# ToDo:
#  - Build a list of spool_dirs from the existing virtual hosts under /var/opt/httpd/
#  - Status can print out the space used in each spool dir
#  - 
#-------------------------------------------------------------------------------
# (C) Copyright 2006-2009 HaCon Ingenieurgesellschaft mbH
# Authors: Lars Bohn <lars.bohn@hacon.de>
#          Kai Fricke <kai.fricke@hacon.de>
# $Header: /cvs/hafas/script/hafas-cleanup.sh,v 1.10 2011-01-17 14:23:00 lb Exp $
#-------------------------------------------------------------------------------

# LSB comment for init scripts
### BEGIN INIT INFO
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Provides: hafas-cleanup
# Required-Start: $local_fs
# Required-Stop: $local_fs
# Short-Description: HAFAS cleanup
# Description: This script delete all old HAFAS server PID-files and clean the spool directories.
### END INIT INFO

NAME="HAFAS Cleanup"

# This file will be delete on every system boot by bootclean.sh
LOCK_FILE="/var/lock/hafas-cleanup"

# Only usefull for testing purposes
SUPER_BASE_DIR=""

# This super base directory describes the location of all HAFAS stuff on this
# server.
HAFAS_BASE_DIR="${SUPER_BASE_DIR}/opt/hafas"

# To store variable data the directory '/var' is used on Unix systems. In 
# respect of testin purposes this can be configured too.
VAR_HAFAS_BASE_DIR="${SUPER_BASE_DIR}/var/opt/hafas"

# HAFAS PID-files directory
HAFAS_PID_DIR="${VAR_HAFAS_BASE_DIR}/run/"
# HAFAS spool directory
HAFAS_SPOOL_DIR="${VAR_HAFAS_BASE_DIR}/spool/"

FIND="/usr/bin/find"
XARGS="/usr/bin/xargs"

# Enable the next line for debugging
#set -x

hafas_cleanup_pid_dir() {
    if [ ! -d ${HAFAS_PID_DIR} ]; then
        echo "Directory '${HAFAS_PID_DIR}' does not exists."
        echo "Could not cleanup PID files!"
        return
    fi
    echo "Searching for PID files in '${HAFAS_PID_DIR}' and deleting them."
    ${FIND} ${HAFAS_PID_DIR} -name *.pid | ${XARGS} rm -f
}

hafas_status_pid_dir() {
    if [ ! -d ${HAFAS_PID_DIR} ]; then
        echo "Directory '${HAFAS_PID_DIR}' does not exists."
        return
    fi
    echo "Searching for PID files in '${HAFAS_PID_DIR}'."
    echo "Found the following files:"
    ${FIND} ${HAFAS_PID_DIR} -name *.pid
}

hafas_cleanup_spool_dir() {
    if [ ! -d ${HAFAS_SPOOL_DIR} ]; then 
        echo "Directory '${HAFAS_SPOOL_DIR}' does not exists."
        echo "Could not cleanup spool directories."
        return
    fi
    echo "Searching for spool files in '${HAFAS_SPOOL_DIR}' and cleaning them."
    ${FIND} ${HAFAS_SPOOL_DIR} -type f | ${XARGS} rm -f
}

hafas_status_spool_dir() {
    if [ ! -d ${HAFAS_SPOOL_DIR} ]; then
        echo "Directory '${HAFAS_SPOOL_DIR}' does not exists."
        return
    fi
    echo "Searching for spool files in '${HAFAS_SPOOL_DIR}'."
    echo "Found the following:"
    ${FIND} ${HAFAS_SPOOL_DIR} -type f
}


case "${1}" in
    start)
        echo "${NAME} - Starting..."
        # Only run once
        if [ -f ${LOCK_FILE} ]; then
            echo "${NAME} was already started after system boot. Exitting!"
            exit 1
        fi
        touch ${LOCK_FILE}
    
        hafas_cleanup_pid_dir
        hafas_cleanup_spool_dir &
        ;;
    stop)
        echo "${NAME} - Stopping..."
        if [ -w ${LOCK_FILE} ]; then
            rm ${LOCK_FILE}
        fi
        ;;
    status)
        echo "${NAME} - Status report..."
        if [ -f ${LOCK_FILE} ]; then
            echo "${NAME} was already started after system boot!"
        fi
        
        hafas_status_pid_dir
        hafas_status_spool_dir
        ;;
    *)
        echo "${NAME}"
        echo "Usage: ${0} {start|stop|status}"
        exit 1
esac
