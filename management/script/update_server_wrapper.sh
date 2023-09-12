#! /bin/bash
#-------------------------------------------------------------------------------
# create_server_wrapper.sh - Update a HAFAS server wrapper
#-------------------------------------------------------------------------------
# This script can be used to easily update a HAFAS server wrapper script.
#
# The following things are being done by this script:
#   - check for a server.sh to update (given as a parameter, look in current
#     directory or quit if none found)
#   - Operate with a safe temporary directory only.
#   - Check out the last version from CVS.
#   - Check out the wrapper version from CVS.
#   - Merge changes from both CVS versions to the to be updated wrapper script.
#
# ToDo:
#   - (Default) Argument to merge differences to the CVS revision tagged as 
#     'STABLE'.
#   - Optional argument merge differences to the CVS HEAD revision. Eases 
#     testing of new not stable revisions.
#
#-------------------------------------------------------------------------------
# (C) Copyright 2006-2007 HaCon Ingenieurgesellschaft mbH
# Authors: Kai Fricke <kai.fricke@hacon.de>
# $Header: /cvs/hafas/script/update_server_wrapper.sh,v 1.15 2007-08-20 09:25:27 kf Exp $
#-------------------------------------------------------------------------------

CVSROOT=":pserver:anoncvs@cvs-dev.local.hacon.de:/cvs/hafas/"
DEBUG_MODE=0

if [ $# -eq 0 ]; then
    SERVER_WRAPPER='./server.sh'
elif [ $# -eq 1 ]; then
    if [ ${1} = "-d" ]; then
        DEBUG_MODE=1
        SERVER_WRAPPER='./server.sh'
    else
        SERVER_WRAPPER=${1}
    fi
elif [ $# -eq 2 ]; then
    if [ $1 = "-d" ]; then
        DEBUG_MODE=1
        SERVER_WRAPPER=${2}
    fi
else
    cat <<EOF

Usage: ${0} <-d> <server-sh-to-be-merged>"

    If no server wrapper is given the file 'server.sh' in the current working
    directory will be used if it exists.

    -d - Enable debugging mode. Only show differences and change nothing."

EOF
    exit 1
fi

if [ ${DEBUG_MODE} -eq 1 ]; then
    echo "Running in previewing debug mode!"
fi

# Check if server wrapper is writeable
if [ ! -w ${SERVER_WRAPPER} ]; then
    echo "Failed to open server wrapper '${SERVER_WRAPPER}'!"
    exit 1
fi

# Check for the version of the server wrapper
OLD_REVISION=`cat ${SERVER_WRAPPER} | grep 'Header: ' | awk '{print $4}'`
echo "Old revision is ${OLD_REVISION}"

# Create a temporary directory
TEMP_DIR=`mktemp -d`

if [ $? -ne 0 ]; then
    echo "Failed to create temporary directory!"
    exit 1
fi

# Create a directory to contain the stable CVS revision
TEMP_DIR_STABLE=${TEMP_DIR}/stable
mkdir ${TEMP_DIR_STABLE}

if [ $? -ne 0 ]; then
    echo "Failed to create directory for the stable revision!"
    rm -rf ${TEMP_DIR}
    exit 1
fi

# Check out the last version of the server wrapper
pushd ${TEMP_DIR_STABLE} > /dev/null
cvs -Q -d ${CVSROOT} co -r STABLE script/server.sh

if [ $? -ne 0 ]; then
    echo "Failed check out the stable revision from CVS!"
    rm -rf ${TEMP_DIR}
    exit 1
fi

popd > /dev/null

# Create a directory to contain the original CVS version of the local server
# wrapper script.
TEMP_DIR_OLD=${TEMP_DIR}/old
mkdir ${TEMP_DIR_OLD}

if [ $? -ne 0 ]; then
    echo "Failed to create directory for the old revision!"
    rm -rf ${TEMP_DIR}
    exit 1
fi

# Check out the server wrapper revision from CVS
pushd ${TEMP_DIR_OLD} > /dev/null
cvs -Q -d ${CVSROOT} co -r ${OLD_REVISION} script/server.sh

if [ $? -ne 0 ]; then
    echo "Failed check out the old revision from CVS!"
    rm -rf ${TEMP_DIR}
    exit 1
fi

popd > /dev/null

# Merge the differences between the two CVS revisions to the local one
if [ ${DEBUG_MODE} -eq 0 ]; then
    merge ${SERVER_WRAPPER} ${TEMP_DIR_OLD}/script/server.sh \
        ${TEMP_DIR_STABLE}/script/server.sh

    if [ $? -ne 0 ]; then
        echo "Failed to merge the differences to the wrapper script!"
        echo
        echo "You need to manually edit the server wrapper and merge the changes"
        echo "between the markers '>>>>>', '=====' and '<<<<<' manually."
        echo
        rm -rf ${TEMP_DIR}
        exit 1
    fi
else
    merge -p ${SERVER_WRAPPER} ${TEMP_DIR_OLD}/script/server.sh \
        ${TEMP_DIR_STABLE}/script/server.sh | diff - ${SERVER_WRAPPER}

    if [ $? -ne 0 ]; then
        echo "Failed to compare the differences to the wrapper script!"
        rm -rf ${TEMP_DIR}
        exit 1
    fi
fi

# Purge the temporary directory
rm -rf ${TEMP_DIR}

# Print out the new revision of the server wrapper
NEW_REVISION=`cat ${SERVER_WRAPPER} | grep 'Header: ' | awk '{print $4}'`
echo "New revision is ${NEW_REVISION}"
