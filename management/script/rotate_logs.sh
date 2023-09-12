#! /bin/bash
#-------------------------------------------------------------------------------
# The delay logs (and optionally the copy logs) of yesterday are beeing moved 
# (also called rotated) into an own directory. The target directory is beeing 
# created and the log backups are moved based on the date pattern contained in 
# their filename.
# As the last step files older then a given number of days are deleted from the 
# backup directory.
#
# This script does not change the environment in any way and can safely be 
# called from any location.
#-------------------------------------------------------------------------------
# (C) Copyright 2008 HaCon Ingenieurgesellschaft mbH
# Authors: Andreas Dietz <andras.dietz@hacon.de>
#          Kai Fricke <kai.fricke@hacon.de>
#          Lars Bohn <lars.bohn@hacon.de>
# $Id: rotate_logs.sh,v 1.9 2015-04-10 10:07:18 rja Exp $
#-------------------------------------------------------------------------------

# Make the BASH a bit safer for unattended execution:
#  errexit - exit immediatley if a command exits with a non-zero exitcode
#  nounset - ends execution if an uninitialized variable is used
set -o errexit -o nounset

# Specifies the maximum age of the log backups. Files older than this are 
# simply deleted in the last step of this script.
# The command 'find ... -ctime +<days> ...' is used to do this. So be aware 
# of the following fact (extract from 'man find'):
#   "When find figures out how many day periods ago the file was last changed, 
#    any fractional part is ignored, so to match -ctime +1, a file has to have 
#    been changed at least two days ago."
# This means that you can use the value 0 to delete all files older then today
#
# Set this option to -1 (or below) to disable the automatic deletion of files 
# (do not simply comment it out)!
DELETE_OLDER_THEN_DAYS=7

# The base directory of the HAFAS match server
RT_MATCH_DIR=""

# The directory which contains the delay log backups
BACKUP_DIR="${RT_MATCH_DIR}/log/backup"

# The directory for the log files of yesterday
YESTERDAY_BACKUP_DIR="${BACKUP_DIR}/`date -d YESTERDAY +%y/%m/%d`"

# Create a directory for yesterdays log files
mkdir -p ${YESTERDAY_BACKUP_DIR}

# Move the delay logs of the last day into the previously created directory
find ${BACKUP_DIR} -maxdepth 1 -name "delay_log_`date -d YESTERDAY +%y%m%d`*" -exec mv {} ${YESTERDAY_BACKUP_DIR} \;

if [ ${DELETE_OLDER_THEN_DAYS} -gt -1 ]; then
	# delete files only at first
	find ${BACKUP_DIR} -maxdepth 4 \( -mtime +${DELETE_OLDER_THEN_DAYS} -o -mtime ${DELETE_OLDER_THEN_DAYS} \) -type f -exec rm -f {} \;
	# delete old directories as well (this delayed th number of days, because
	# the above file deletion updates an directory mtime)
	find ${BACKUP_DIR} -mindepth 1 -maxdepth 4 -depth \( -mtime +${DELETE_OLDER_THEN_DAYS} -o -mtime ${DELETE_OLDER_THEN_DAYS} \) -type d -empty -exec rmdir --ignore-fail-on-non-empty {} \;
fi

