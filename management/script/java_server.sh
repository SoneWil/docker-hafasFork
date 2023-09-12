#!/bin/bash
#-------------------------------------------------------------------------------
# java_server.sh - HAFAS JAVA Server start and stop script
#-------------------------------------------------------------------------------
#
#	JAVA_SERVER_WRAPPER
#
#-------------------------------------------------------------------------------
# (C) Copyright 2008-2011 HaCon Ingenieurgesellschaft mbH
# Authors: Lars Bohn <Lars.Bohn@HaCon.de>
# $Header: /cvs/hafas/script/java_server.sh,v 1.5 2014-03-05 09:26:56 lb Exp $
#-------------------------------------------------------------------------------

# LSB comment for init scripts
### BEGIN INIT INFO
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Provides: hafas-java-server-product_state-primary_name-secondary_name
# Required-Start: $local_fs $network $syslog $time
# Required-Stop: $local_fs $network
# Should-Start: nscd nslcd
# Short-Description: HAFAS JAVA server
# Description: This is the init script for an HAFAS JAVA server.
### END INIT INFO

################################################################################
# You should only need to edit the part within this block
#-------------------------------------------------------------------------------

# server name and/or short description
SERVER_NAME="HAFAS JAVA server"

# Server home directory
# PRODUCT_STATE should be dev, test, pub or prod
# PRIMARY_NAME should be the project or customer name
# SECONDARY_NAME should be the type or server name
# Example:
#	SERVER_HOME="/opt/hafas/prod/hacon/my-java-server"
SERVER_HOME="/opt/hafas/<PRODUCT_STATE>/<PRIMARY_NAME>/<SECONDARY_NAME>"

# logfile - should be set to ${SERVER_HOME}/logs/jprocess.log or /dev/null
#SERVER_LOG_FILE="${SERVER_HOME}/logs/jprocess.log"
SERVER_LOG_FILE="/dev/null"

# Server lib directory
SERVER_LIB="${SERVER_HOME}/lib"

# PID file
SERVER_PID_FILE="${SERVER_HOME}/jprocess.pid"

# server application to start
# Example:
#	SERVER_APP="de.hacon.hafas.example"
SERVER_APP=""

# JAVA_HOME
# Example:
#	JAVA_HOME="/usr/lib/jvm/java-6-sun/"
JAVA_HOME=""

# JAVA Options
# Example:
#	JAVA_OPTS="-Xms16m -Xmx256m"
JAVA_OPTS=""

# some more JAVA Options
# Example:
#	FILE_ENCODING=ISO-8859-1
#	RTDEBUG=off
#	JAVA_OPTS="${JAVA_OPTS} -Dfile.encoding=${FILE_ENCODING} -Ddebug=${RTDEBUG}"

# System account to run the server under.
RUNAS_USER=""

#-------------------------------------------------------------------------------
# Normally there should be no need to edit anything below this line. If you
# need to edit anything please make a variable for it, define it in the block
# above and check in a new revision of the change into the template of this
# script.
################################################################################

# Path to the 'su'-command. Used to change to the service user
SU="/bin/su"

#-------------------------------------------------------------------------------
# Normally there should be no need to edit anything below this line. If you
# need to edit anything please make a variable for it, define it in the block
# above.
################################################################################


# If needed start this script under the RUNAS_USER
if [ -z ${RUNAS_USER} ]; then
	echo "ERROR: No RUNAS_USER was specified!"
	exit 1;
fi
# Buggy logrotate - Sometimes logrotate doesn't set the environment variable USER.
if [ -z ${USER} ]; then
	echo "Setting the environment variable USER."
	USER=`/usr/bin/id -n -u`
fi

if [ ${USER} != ${RUNAS_USER} ]; then
	echo "WARNING: The current username is \"${USER}\", but the server must be run under username \"${RUNAS_USER}\"! Using su ..."
	${SU} ${RUNAS_USER} -c "$0 $@" || exit 1;
	exit 0;
fi

# Do not run JAVA Server as root!
if [ ${UID} -eq 0 ]; then
	echo "Starting this command as user root is a very bad idea! Quitting..."
	exit 1
fi

#-------------------------------------------------------------------------------
function start_java_server ()
# Starts the Java server in safe mode 
#-------------------------------------------------------------------------------
{
	echo -n "Starting ${SERVER_NAME} in safe mode ..."

	# older versions of bash doesn't support the variable BASHPID
	if [ -z $BASHPID ]; then
		read BASHPID REST < /proc/self/stat
	fi

	# CLASSPATH 
	CLASSPATH=""
	JARS=`ls -1 ${SERVER_LIB}/*.jar`
	# find all jars in ${SERVER_LIB}/lib and their subdirectories
	#JARS=`find ${SERVER_LIB}/lib -type f -name *.jar`
	for jar in ${JARS} ; do
		JAR_LIST="${JAR_LIST} `basename $jar`"
		CLASSPATH="$jar:${CLASSPATH}"
	done

	# echo $CLASSPATH
	# echo $JAR_LIST

	if [ -O ${SERVER_PID_FILE} ]; then
		kill -0 $(cat ${SERVER_PID_FILE})
		if [ $? -eq 0 ]; then
			echo "PID file already exists and process is running! Canceling startup..."
			exit 1
		else
			echo "PID file already exists but no proccess is running! Removing PID file..."
			rm -f ${SERVER_PID_FILE}
		fi
	fi
	cd ${SERVER_HOME}
	while [ 1 ]; do
		#echo "${JAVA_HOME}/bin/java -classpath ${CLASSPATH} ${JAVA_OPTS} ${SERVER_APP} >> $SERVER_LOG_FILE 2>&1 &"
		${JAVA_HOME}/bin/java -classpath ${CLASSPATH} ${JAVA_OPTS} ${SERVER_APP} >> $SERVER_LOG_FILE 2>&1 &
		PID=$!
		RETVAL=$?
		if [ ${RETVAL} -ne 0 ]; then
			echo "Server not started as desired!"
		else
			echo "$BASHPID ${PID}" > ${SERVER_PID_FILE}
			echo "Started with PID `cat ${SERVER_PID_FILE}`"
		fi
		# Restart Loop if RETVAL != 0
		wait ${PID}
		RETVAL=$?
		if [ ${RETVAL} -ne 0 ]; then
			echo "Process ${PID} exited with return code: ${RETVAL}. Waiting 15 seconds before restart ..."
			sleep 15
			echo -n "Restarting ${SERVER_NAME} ..."
		else
			echo "Process ${PID} exited with return code: ${RETVAL}. Leaving Restart-Loop!"
			rm -f ${SERVER_PID_FILE}
			if [ $? -ne 0 ]; then
				echo "Could not delete PID file \"${SERVER_PID_FILE}\""
				exit 1
			fi
				exit 0
			fi
	done	
	
}

#-------------------------------------------------------------------------------
function start_java_server_unsafe ()
# Starts the Java server in unsafe mode
#-------------------------------------------------------------------------------
{
	echo -n "Starting ${SERVER_NAME} in unsafe mode ..."

	# CLASSPATH 
	CLASSPATH=""
	JARS=`ls -1 ${SERVER_LIB}/*.jar`
	# find all jars in ${SERVER_LIB}/lib and their subdirectories
	#JARS=`find ${SERVER_LIB}/lib -type f -name *.jar`
	for jar in ${JARS} ; do
		JAR_LIST="${JAR_LIST} `basename $jar`"
		CLASSPATH="$jar:${CLASSPATH}"
	done

	# echo $CLASSPATH
	# echo $JAR_LIST

	if [ -O ${SERVER_PID_FILE} ]; then
		kill -0 $(cat ${SERVER_PID_FILE})
		if [ $? -eq 0 ]; then
			echo "PID file already exists and process is running! Canceling startup..."
			exit 1
		else
			echo "PID file already exists but no proccess is running! Removing PID file..."
			rm -f ${SERVER_PID_FILE}
		fi
	fi
	cd ${SERVER_HOME}
	#echo "${JAVA_HOME}/bin/java -classpath ${CLASSPATH} ${JAVA_OPTS} ${SERVER_APP} >> $SERVER_LOG_FILE 2>&1 &"
	${JAVA_HOME}/bin/java -classpath ${CLASSPATH} ${JAVA_OPTS} ${SERVER_APP} >> $SERVER_LOG_FILE 2>&1 &
	RETVAL=$?
	if [ ${RETVAL} -ne 0 ]; then
		echo "Server not started as desired!"
	else
		echo $! > ${SERVER_PID_FILE}
		echo "Started with PID `cat ${SERVER_PID_FILE}`"
	fi
}

#-------------------------------------------------------------------------------
function stop_java_server ()
# Stops the Java server
#-------------------------------------------------------------------------------
{
	echo -n "Stopping ${SERVER_NAME} ..."
	# 
	if ! [ -O ${SERVER_PID_FILE} ]; then
		echo "PID file does not exist or is not mine! Canceling shutdown..."
		exit 1
	fi

	kill -SIGKILL `cat ${SERVER_PID_FILE}`
	RETVAL=$?
	if [ ${RETVAL} -ne 0 ]; then
		echo "Failed to terminate process with PID `cat ${SERVER_PID_FILE}`!"
		exit 1
	else
		echo "done!"
		rm -f ${SERVER_PID_FILE}
		if [ $? -ne 0 ]; then
			echo "Could not delete PID file \"${SERVER_PID_FILE}\""
			exit 1
		fi
	fi
}

#-------------------------------------------------------------------------------
function status_java_server ()
# Output the status of the Java server
#-------------------------------------------------------------------------------
{
	echo -n "Status ${SERVER_NAME} ..."
	if [ -O ${SERVER_PID_FILE} ]; then
		kill -0 $(cat ${SERVER_PID_FILE})
		if [ $? -eq 0 ]; then
			echo "PID file exists and process is running (`cat ${SERVER_PID_FILE}`)!"
			exit 0
		else
			echo "PID file exists but no proccess is running!"
			exit 1
		fi
	else
		echo "PID file does not exist or is not mine!"
		exit 1
	fi
	
}

#-------------------------------------------------------------------------------
function clean_java_server ()
# Output the status of the Java server
#-------------------------------------------------------------------------------
{
	echo "clean data and logs directory"
	echo "deleting \"${SERVER_HOME}/logs\""
	rm -rf ${SERVER_HOME}/logs
	echo "deleting \"${SERVER_HOME}/data\""
	rm -rf ${SERVER_HOME}/data
	echo "creating directory \"${SERVER_HOME}/logs\""
	mkdir ${SERVER_HOME}/logs
	echo "creating directory \"${SERVER_HOME}/data\""
	mkdir ${SERVER_HOME}/data
}


case "$1" in
	start|start_safe)
		start_java_server &
		;;
	start_unsafe)
		start_java_server_unsafe
		;;
	stop)
		stop_java_server
		;;
	reload|restart)
		stop_java_server
		sleep 2
		start_java_server &
		;;
	status)
		status_java_server
		;;
	clean)
		clean_java_server
		;;
	*)
		echo "Usage: $0 {start|start_safe|start_unsafe|stop|reload|restart|status|clean}"
		RETVAL=1
esac

exit ${RETVAL}
