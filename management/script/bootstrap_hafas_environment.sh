#!/bin/bash
#-------------------------------------------------------------------------------
# bootstrap_hafas_environment.sh - Bootstrap an HAFAS directory structure
#-------------------------------------------------------------------------------
# This script can be used to initialize the basic directory structures for 
# HAFAS.
#-------------------------------------------------------------------------------
# (C) Copyright 2006-2007 HaCon Ingenieurgesellschaft mbH
# Authors: Kai Fricke <kai.fricke@hacon.de>
# $Header: /cvs/hafas/script/bootstrap_hafas_environment.sh,v 1.3 2007-08-20 09:26:15 kf Exp $
#-------------------------------------------------------------------------------

# Only usefull for testing purposes
SUPER_BASE_DIR=""

# This super base directory describes the location of all HAFAS stuff on this
# server.
HAFAS_BASE_DIR="${SUPER_BASE_DIR}/opt/hafas"

# To store variable data the directory '/var' is used on Unix systems. In 
# respect of testin purposes this can be configured too.
VAR_HAFAS_BASE_DIR="${SUPER_BASE_DIR}/var/opt/hafas"

# The user group for the hafas services. This group is used for the to be 
# created directories and files to assure the access-rights for the later 
# running services.
HAFAS_GROUP="hafas"

echo
echo "Bootstrapping HAFAS environment..."
echo

#
# Create the HAFAS group if needed
#
if [ `getent group ${HAFAS_GROUP} | wc -l` -eq 0 ]; then
	echo "Adding group '${HAFAS_GROUP}'..."
	groupadd ${HAFAS_GROUP} 
else
	echo "Group '${HAFAS_GROUP}' already exists!"
fi

# Create directories for static files
for dir in {plan,dev,pub,rel,prod}; do 
	echo "Creating '${HAFAS_BASE_DIR}/${dir}'..."
	
	mkdir -p ${HAFAS_BASE_DIR}/${dir}
	chgrp ${HAFAS_GROUP} ${HAFAS_BASE_DIR}/${dir}
	chmod 770 ${HAFAS_BASE_DIR}/${dir}
done

# Create directories for variable files
for dir in {log,run,spool}; do 
	echo "Creating '${VAR_HAFAS_BASE_DIR}/${dir}'..."
	
	mkdir -p ${VAR_HAFAS_BASE_DIR}/${dir}
	chgrp ${HAFAS_GROUP} ${VAR_HAFAS_BASE_DIR}/${dir}
	chmod 770 ${VAR_HAFAS_BASE_DIR}/${dir}
	ln -s ${VAR_HAFAS_BASE_DIR}/${dir} ${HAFAS_BASE_DIR}
done

echo
echo "Finished!"
