#!/bin/bash
#-------------------------------------------------------------------------------
# create_cgi_environment.sh - Create a HAFAS CGI environment
#-------------------------------------------------------------------------------
# This script creates an environment for the HAFAS CGI environment. The 
# complete directory structure for an apache virtual host is going to be 
# created. At last a configuration template for the Apache webserver can be
# printed to the console.
#-------------------------------------------------------------------------------
# (C) Copyright 2006-2013 HaCon Ingenieurgesellschaft mbH
# Authors: Kai Fricke <kai.fricke@hacon.de>
#          Lars Bohn <lars.bohn@hacon.de>
# $Header: /cvs/hafas/script/create_cgi_environment.sh,v 1.11 2013-04-26 06:25:46 lb Exp $
#-------------------------------------------------------------------------------

# Set up the shell to complain about undefined (not initialized) variables
set -u

# Only usefull for testing purposes
SUPER_BASE_DIR=""

# This super base directory describes the location of all HAFAS stuff on this
# server.
HAFAS_BASE_DIR="${SUPER_BASE_DIR}/opt/hafas"

# define some colors
COLOR_DEF="\033[0m"
COLOR_BOLD="\033[1m"
COLOR_ERR="\033[1;31m"
COLOR_WARN="\033[1;33m"

# Source some usefull functions
. ${HAFAS_BASE_DIR}/script/functions.sh
RETVAL=$?

if [ ${RETVAL} -ne 0 ]; then
	echo -e "\n${COLOR_ERR}Failed to include helper functions '${HAFAS_BASE_DIR}/script/functions.sh'. Exiting!${COLOR_DEF}\n"
	exit 1
fi


# Default values for usernames which may be overridden by commandline arguments.
HAFAS_USER="hafas"
HTTPD_USER="www-data"


#---------------------------------------
# Parse the arguments the simpe way...
#
if [ ${#} -lt 2 ]; then
	cat <<EOT 
Wrong number of arguments (${#}). At least two are expected!

Usage: `basename "${0}"` <name of virtual Host> \\
		<username of the HAFAS service user> \\
		[<username of the webserver service user (default: ${HTTPD_USER})>]
EOT
	exit 1
else
	VIRTUAL_HOST="${1}"
	HAFAS_USER="${2}"
fi


# Parsing the third argument (name of the webserver service user)
if [ ${#} -lt 3 ]; then
	echo "Assuming the default value '${HTTPD_USER}' as the name of the webserver service user!"
else
	HTTPD_USER="${3}"
fi

# check the existence of the webserver service user
if ! id -u "${HTTPD_USER}" > /dev/null 2>&1; then
	echo -e "\n${COLOR_ERR}Couldn't find the webserver service user '${HTTPD_USER}'. Exiting!${COLOR_DEF}\n"
	exit 1
fi

# fetching the default group of the webserver service user
HTTPD_GROUP=`id -gn "${HTTPD_USER}"`
if ! getent group "${HTTPD_GROUP}" > /dev/null 2>&1; then
	echo -e "\n${COLOR_ERR}Couldn't find the default group '${HTTPD_GROUP}' of the webserver service user '${HTTPD_USER}'. Exiting!${COLOR_DEF}\n"
	exit 1
fi
echo "The default group of the webserver service user '${HTTPD_USER}' is '${HTTPD_GROUP}'."


# check the existence of the HAFAS service user
if ! id -u "${HAFAS_USER}" > /dev/null 2>&1; then
	echo -e "\n${COLOR_ERR}Couldn't find the HAFAS service user '${HAFAS_USER}'. Exiting!${COLOR_DEF}\n"
	exit 1
fi

_primary_group=`id -gn "${HAFAS_USER}"`
if [ ! -z "${_primary_group}" -a "${_primary_group}" == "${HAFAS_USER}" ]; then
	HAFAS_GROUP=${_primary_group}
else
	cat <<EOT
The primary group group does not match the username (and hence does not seem
to be a dedicated usergroup). Trying to find a generic HAFAS group...

EOT
	# Test for existence of group by matching the group name more than once 
	# (test -gt 0 instead of -eq 1). This is needed because multiple auth 
	# backends can report the requested group.
	if getent group hafas > /dev/null 2>&1; then
		HAFAS_GROUP="hafas"
	elif getent group hafas_local > /dev/null 2>&1; then
		HAFAS_GROUP="hafas_local"
	else
		cat << EOT
Could not determine a reasonable group of the HAFAS service user '${HAFAS_USER}'!
Please enter the to be used group or exit now using 'Ctrl-C'
EOT
		echo -n "> "
	    read_user_input ""
	    HAFAS_GROUP=${USER_INPUT}
	    if ! getent group "${HAFAS_GROUP}" > /dev/null 2>&1; then
	    	echo -ne '\E[31;40m\033[1m'
	    	cat <<EOT
Couldn't find entered group '${HAFAS_GROUP}'. Exiting!"

EOT
	    	echo -ne '\E[37;40m\033[0m'
	    	exit 1
	    fi
	fi
fi

echo "Using group '$HAFAS_GROUP' for the HAFAS service user"

# check the existence of the virtual host name
if host "${VIRTUAL_HOST}" | grep NXDOMAIN > /dev/null 2>&1; then
	echo -e "${COLOR_WARN}Warning: Virtual host '${VIRTUAL_HOST}' was not found in DNS!${COLOR_DEF}"
fi

#---------------------------------------
# This script must be run as root
if [ ${UID} -ne 0 ]
then
	echo -e "\n${COLOR_ERR}This script must be run as user root. Exiting!${COLOR_DEF}\n"
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
	_path=${1}
	_descr=${2}

	if [ ! -d ${_path} ]; then
	    log_info_and_console "Creating directory for the ${_descr} '${_path}'."
	    mkdir -p ${_path}
	    if [ $? -gt 0 ]; then
	        log_error "Failed to create directory for the ${_descr}. Exiting!"
	        exit 1
	    fi
	    chmod 750 ${_path}
		if [ ${?} -ne 0 ]; then
			log_error "Failed to set the ownership and membership of the directory for the ${_descr}. Exiting!"
			exit 1
		fi
		
		chown ${HAFAS_USER}:${HTTPD_GROUP} ${_path}
		if [ ${?} -ne 0 ]; then
			log_error "Failed to set the access rights of the directory for the ${_descr}. Exiting!"
			exit 1
		fi

	else
	    log_info_and_console "Directory '${_path}' for the ${_descr} already exists. Continuing!"
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
	    log_info_and_console "Creating symbolic link for ${_descr} from '${_target}' to the '${_link_name}'."
		ln -s ${_target} ${_link_name}
		if [ $? -gt 0 ]; then
	        log_error "Failed to create symbolic link to the ${_descr}. Exiting!"
	        exit 1
    	fi
		chown -h ${HAFAS_USER}:${HTTPD_GROUP} ${_path}
		if [ ${?} -ne 0 ]; then
			log_error "Failed to set the ownership and membership of the symbolic link to the ${_descr}. Exiting!"
			exit 1
		fi
	else
		log_info_and_console "A file with name of symbolic link '${_link_name}' for the ${_descr} already exists. Continuing!"
	fi
}

log_info "Creating the HAFAS CGI environment for the virtual host '${VIRTUAL_HOST}'..."

OPT_BASE_DIR=/opt/httpd/${VIRTUAL_HOST}
VAR_OPT_BASE_DIR=/var/opt/httpd/${VIRTUAL_HOST}

create_dir ${OPT_BASE_DIR}/hafas "HAFAS base"
create_dir ${OPT_BASE_DIR}/html "static document root"
create_dir ${OPT_BASE_DIR}/cgi-bin "non-HAFAS CGI programs"
create_dir ${OPT_BASE_DIR}/hafas/cgi-bin "HAFAS CGI programs"
create_dir ${OPT_BASE_DIR}/hafas/hafas-res "static HAFAS documents"
create_dir ${OPT_BASE_DIR}/hafas/templates "HAFAS CGI webpage templates"
create_dir ${OPT_BASE_DIR}/log "all logfiles"

create_dir ${VAR_OPT_BASE_DIR} "virtual hosts variable contents (contains symlinks only)"
create_dir ${VAR_OPT_BASE_DIR}/hafas "HAFAS variable contents (contains symlinks only)"
create_symlink ${OPT_BASE_DIR}/log ${VAR_OPT_BASE_DIR}/log "all logfiles (HAFAS, Apache)"

create_dir ${OPT_BASE_DIR}/log/apache "webserver logfiles"
chmod 2770 ${OPT_BASE_DIR}/log/apache

create_dir ${OPT_BASE_DIR}/log/hafas "HAFAS CGI program logfiles"
chown ${HTTPD_USER}:${HAFAS_GROUP} ${OPT_BASE_DIR}/log/hafas
chmod 2770 ${OPT_BASE_DIR}/log/hafas
create_symlink ${OPT_BASE_DIR}/log/hafas ${VAR_OPT_BASE_DIR}/hafas/log "HAFAS CGI program logfiles"

create_dir ${OPT_BASE_DIR}/hafas/download "HAFAS CGI downloads"
chmod 2770 ${OPT_BASE_DIR}/hafas/download
create_symlink ${OPT_BASE_DIR}/hafas/download ${VAR_OPT_BASE_DIR}/hafas/download "HAFAS CGI downloads"

create_dir ${OPT_BASE_DIR}/hafas/spool "HAFAS CGI session spool files"
chown ${HTTPD_USER}:${HAFAS_GROUP} ${OPT_BASE_DIR}/hafas/spool
chmod 2770 ${OPT_BASE_DIR}/hafas/spool
create_symlink ${OPT_BASE_DIR}/hafas/spool ${VAR_OPT_BASE_DIR}/hafas/spool "HAFAS CGI session spool files"

create_dir ${OPT_BASE_DIR}/hafas/stat "HAFAS statistics"
chmod 2770 ${OPT_BASE_DIR}/hafas/stat
create_symlink ${OPT_BASE_DIR}/hafas/stat ${VAR_OPT_BASE_DIR}/hafas/stat "HAFAS statistics"

create_dir /srv/${HTTPD_GROUP}/vhosts "static service data (LSB proposed)"
create_symlink ${OPT_BASE_DIR}/html /srv/${HTTPD_GROUP}/vhosts/${VIRTUAL_HOST} "static service data (LSB proposed)" www-data

# creating a standard robots.txt file for HAFAS
# check for the existence of the file
if [ -e ${OPT_BASE_DIR}/html/robots.txt ]; then
	log_info_and_console "A file with name '${OPT_BASE_DIR}/html/robots.txt' already exists. Continuing!"
else
	# creating robots.txt
	log_info_and_console "Creating file '${OPT_BASE_DIR}/html/robots.txt'."
	echo -e "# robots.txt for HAFAS CGI\nUser-agent: *\nDisallow: /bin\nDisallow: /hafas\nDisallow: /hafas-res" > ${OPT_BASE_DIR}/html/robots.txt
	if [ ${?} -ne 0 ]; then
		log_info_and_console "Failed to create the file '${OPT_BASE_DIR}/html/robots.txt'. Continuing!"
	else
		# change the ownership and group membership of the file
		chown -h ${HAFAS_USER}: ${OPT_BASE_DIR}/html/robots.txt
		if [ ${?} -ne 0 ]; then
			log_info_and_console "Failed to set the ownership and membership of the file '${OPT_BASE_DIR}/html/robots.txt'. Continuing!"
		fi
	fi
fi


log_info "Creation of CGI environment for the virtual host '${VIRTUAL_HOST}' finished!"

echo -e "\n${COLOR_BOLD}Should a template for the webserver virtual host be printed to the console?${COLOR_DEF}\n"

echo -n "Please answer 'y' or 'n' > (n) "
read_user_input "n"
if [ "${USER_INPUT}" == "y" ]; then
	cat <<EOT

<VirtualHost *:80>
        ServerAdmin wwwadmin@hacon.de
        ServerName ${VIRTUAL_HOST}

        <Directory />
                Options None
                AllowOverride None
                Order allow,deny
                deny from all
        </Directory>
        
        DocumentRoot /opt/httpd/${VIRTUAL_HOST}/html
        <Directory /opt/httpd/${VIRTUAL_HOST}/html>
                Options None
                AllowOverride None
                Order allow,deny
                allow from all
        </Directory>

        ScriptAlias /cgi-bin      /opt/httpd/${VIRTUAL_HOST}/cgi-bin
        <Directory /opt/httpd/${VIRTUAL_HOST}/cgi-bin>
                Options ExecCGI
                AllowOverride None
                Order allow,deny
                allow from all
        </Directory>

        ScriptAlias /bin        /opt/httpd/${VIRTUAL_HOST}/hafas/cgi-bin
        ScriptAlias /hafas      /opt/httpd/${VIRTUAL_HOST}/hafas/cgi-bin
        <Directory /opt/httpd/${VIRTUAL_HOST}/hafas/cgi-bin>
		<IfModule mod_deflate.c>
			# gzip compression for application/json (e.g. livemaps)
			AddOutputFilterByType DEFLATE application/json
		</IfModule>
                Options ExecCGI
                AllowOverride None
                Order allow,deny
                allow from all
        </Directory>

        Alias /hafas-res        /opt/httpd/${VIRTUAL_HOST}/hafas/hafas-res
        <Directory /opt/httpd/${VIRTUAL_HOST}/hafas/hafas-res>
		<IfModule mod_deflate.c>
			SetOutputFilter	DEFLATE
		</IfModule>
		<IfModule mod_expires.c>
			ExpiresActive   On
        	        ExpiresDefault  "access plus 1 month"
		</IfModule>
                Options None
                AllowOverride None
                Order allow,deny
                allow from all
        </Directory>

        RedirectMatch ^/$       /bin/query.exe/dn

        LogLevel warn
        ErrorLog /opt/httpd/${VIRTUAL_HOST}/log/apache/error.log
        CustomLog /opt/httpd/${VIRTUAL_HOST}/log/apache/access.log combined
</VirtualHost>

Rember the following:
  - Eventually another default redirect should be set.
  - When adding another Alias or ScriptAlias you must allow the access to the 
    specified directory using the <Directory ...> directive.
    
EOT
fi
