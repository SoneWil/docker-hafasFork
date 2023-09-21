#! /bin/sh

#
# Copyright (c) 1999, 2006 Tanuki Software Inc.
#
# Java Service Wrapper sh script.  Suitable for starting and stopping
#  wrapped Java applications on UNIX platforms.
#

### BEGIN INIT INFO
# Provides: hafas-proxy
# Required-Start: $local_fs $network $remote_fs
# Required-Stop: $local_fs $network $remote_fs
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: hafas-proxy
# Description: hafas-proxy
### END INIT INFO

#-----------------------------------------------------------------------------
# These settings can be modified to fit the needs of your application
SCRIPT=$(readlink -f $0)
export BASEPATH=${SCRIPT%/*/*}

# Application
APP_NAME="hafas-proxy"
APP_LONG_NAME="hafas-proxy"

# Wrapper
WRAPPER_CMD="${BASEPATH}/bin/wrapper"
WRAPPER_CONF="${BASEPATH}/config/wrapper.conf"

# Priority at which to run the wrapper.  See "man nice" for valid priorities.
#  nice is only used if a priority is specified.
PRIORITY=

# Location of the pid file.
PIDDIR="${BASEPATH}/"

# If uncommented, causes the Wrapper to be shutdown using an anchor file.
#  When launched with the 'start' command, it will also ignore all INT and
#  TERM signals.
#IGNORE_SIGNALS=true

# If specified, the Wrapper will be run as the specified user.
# IMPORTANT - Make sure that the user has the required privileges to write
#  the PID file and wrapper.log files.  Failure to be able to write the log
#  file will cause the Wrapper to exit without any way to write out an error
#  message.
# NOTE - This will set the user which is used to run the Wrapper as well as
#  the JVM and is not useful in situations where a privileged resource or
#  port needs to be allocated prior to the user being changed.
RUN_AS_USER=$(stat -c %U ${SCRIPT})

# The following two lines are used by the chkconfig command. Change as is
#  appropriate for your application.  They should remain commented.
# chkconfig: 2345 20 80
# description: Test Wrapper Sample Application

# Do not modify anything beyond this point
#-----------------------------------------------------------------------------

# Get the fully qualified path to the script
case $0 in
    /*)
        SCRIPT="$0"
        ;;
    *)
        PWD=`pwd`
        SCRIPT="$PWD/$0"
        ;;
esac

# Resolve the true real path without any sym links.
CHANGED=true
while [ "X$CHANGED" != "X" ]
do
    # Change spaces to ":" so the tokens can be parsed.
    SAFESCRIPT=`echo $SCRIPT | sed -e 's; ;:;g'`
    # Get the real path to this script, resolving any symbolic links
    TOKENS=`echo $SAFESCRIPT | sed -e 's;/; ;g'`
    REALPATH=
    for C in $TOKENS; do
        # Change any ":" in the token back to a space.
        C=`echo $C | sed -e 's;:; ;g'`
        REALPATH="$REALPATH/$C"
        # If REALPATH is a sym link, resolve it.  Loop for nested links.
        while [ -h "$REALPATH" ] ; do
            LS="`ls -ld "$REALPATH"`"
            LINK="`expr "$LS" : '.*-> \(.*\)$'`"
            if expr "$LINK" : '/.*' > /dev/null; then
                # LINK is absolute.
                REALPATH="$LINK"
            else
                # LINK is relative.
                REALPATH="`dirname "$REALPATH"`""/$LINK"
            fi
        done
    done

    if [ "$REALPATH" = "$SCRIPT" ]
    then
        CHANGED=""
    else
        SCRIPT="$REALPATH"
    fi
done

# Change the current directory to the location of the script
cd "`dirname "$REALPATH"`"
REALDIR=`pwd`

# If the PIDDIR is relative, set its value relative to the full REALPATH to avoid problems if
#  the working directory is later changed.
FIRST_CHAR=`echo $PIDDIR | cut -c1,1`
if [ "$FIRST_CHAR" != "/" ]
then
    PIDDIR=$REALDIR/$PIDDIR
fi
# Same test for WRAPPER_CMD
FIRST_CHAR=`echo $WRAPPER_CMD | cut -c1,1`
if [ "$FIRST_CHAR" != "/" ]
then
    WRAPPER_CMD=$REALDIR/$WRAPPER_CMD
fi
# Same test for WRAPPER_CONF
FIRST_CHAR=`echo $WRAPPER_CONF | cut -c1,1`
if [ "$FIRST_CHAR" != "/" ]
then
    WRAPPER_CONF=$REALDIR/$WRAPPER_CONF
fi

# Process ID
ANCHORFILE="$PIDDIR/$APP_NAME.anchor"
PIDFILE="$PIDDIR/$APP_NAME.pid"
LOCKDIR="/var/lock/subsys"
LOCKFILE="$LOCKDIR/$APP_NAME"
pid=""

# Resolve the location of the 'ps' command
PSEXE="/usr/bin/ps"
if [ ! -x "$PSEXE" ]
then
    PSEXE="/bin/ps"
    if [ ! -x "$PSEXE" ]
    then
        echo "Unable to locate 'ps'."
        echo "Please report this message along with the location of the command on your system."
        exit 1
    fi
fi

# Resolve the os
DIST_OS=`uname -s | tr [:upper:] [:lower:] | tr -d [:blank:]`
case "$DIST_OS" in
    'sunos')
        DIST_OS="solaris"
        ;;
    'hp-ux' | 'hp-ux64')
        # HP-UX needs the XPG4 version of ps (for -o args)
        DIST_OS="hpux"
        UNIX95=""
        export UNIX95
        ;;
    'darwin')
        DIST_OS="macosx"
        ;;
    'unix_sv')
        DIST_OS="unixware"
        ;;
    'os/390')
        DIST_OS="zos"
        ;;
    'linux')
        DIST_OS="linux"
        ;;
esac

# Compare Versions $1<$2=0, $1==$2=1, $1>$2=2
compareVersions () {
    if [ "$1" = "$2" ]
    then
        return 1
    else
        local i=1
        while true
        do
            local v1=`echo "$1" | cut -d '.' -f $i`
            local v2=`echo "$2" | cut -d '.' -f $i`
            if [ "X$v1" = "X" ]
            then
                if [ "X$v2" = "X" ]
                then
                    return 1
                fi
                v1="0"
            elif [ "X$v2" = "X" ]
            then
                v2="0"
            fi
            if [ $v1 -lt $v2 ]
            then
                return 0
            elif [ $v1 -gt $v2 ]
            then
                return 2
            fi
            i=`expr $i + 1`
        done
    fi
}

# Resolve the architecture
if [ "$DIST_OS" = "macosx" ]
then
    OS_VER=`sw_vers | grep 'ProductVersion:' | grep -o '[0-9]*\.[0-9]*\.[0-9]*\|[0-9]*\.[0-9]*'`
    DIST_ARCH="universal"
    compareVersions "$OS_VER" "10.5.0"
    if [ $? -lt 1 ]
    then
        DIST_BITS="32"
        KEY_KEEP_ALIVE="OnDemand"
    else
        # Note: "OnDemand" has been deprecated and replaced from Mac OS X 10.5 by "KeepAlive"
        KEY_KEEP_ALIVE="KeepAlive"

        if [ "X`/usr/sbin/sysctl -n hw.cpu64bit_capable`" = "X1" ]
        then
            DIST_BITS="64"
        else
            DIST_BITS="32"
        fi
    fi
    APP_PLIST_BASE=${PLIST_DOMAIN}.${APP_NAME}
    APP_PLIST=${APP_PLIST_BASE}.plist
elif [ "$DIST_OS" = "zos" ] ; then
    # Z/Os is not supported in the Delta Pack, therefore we only provide a binary
    # file named "wrapper". However this script will still check for a file named
    # "wrapper-zos-390-32" and "wrapper-zos-390-64" in case the user edited the name.
    DIST_ARCH="390"
    DIST_BITS="64"
else
    if [ "$DIST_OS" = "linux" ]
    then
        DIST_ARCH=
    else
        DIST_ARCH=`uname -p 2>/dev/null | tr [:upper:] [:lower:] | tr -d [:blank:]`
    fi
    if [ "X$DIST_ARCH" = "X" ]
    then
        DIST_ARCH="unknown"
    fi
    if [ "$DIST_ARCH" = "unknown" ]
    then
        DIST_ARCH=`uname -m 2>/dev/null | tr [:upper:] [:lower:] | tr -d [:blank:]`
    fi
    case "$DIST_ARCH" in
        'athlon' | 'i386' | 'i486' | 'i586' | 'i686')
            DIST_ARCH="x86"
            if [ "${DIST_OS}" = "solaris" ] ; then
                DIST_BITS=`isainfo -b`
            else
                DIST_BITS="32"
            fi
            ;;
        'amd64' | 'x86_64')
            DIST_ARCH="x86"
            DIST_BITS="64"
            ;;
        'ia32')
            DIST_ARCH="ia"
            DIST_BITS="32"
            ;;
        'ia64' | 'ia64n' | 'ia64w')
            DIST_ARCH="ia"
            DIST_BITS="64"
            ;;
        'ip27')
            DIST_ARCH="mips"
            DIST_BITS="32"
            ;;
        'ppc64le')
            DIST_ARCH="ppcle"
            DIST_BITS="64"
            ;;
        'power' | 'powerpc' | 'power_pc' | 'ppc64')
            if [ "${DIST_ARCH}" = "ppc64" ] ; then
                DIST_BITS="64"
            else
                DIST_BITS="32"
            fi
            DIST_ARCH="ppcbe"

            if [ "${DIST_OS}" = "aix" ] ; then
                DIST_ARCH="ppc"
                if [ `getconf KERNEL_BITMODE` -eq 64 ]; then
                    DIST_BITS="64"
                else
                    DIST_BITS="32"
                fi
            fi
            ;;
        'pa_risc' | 'pa-risc')
            DIST_ARCH="parisc"
            if [ `getconf KERNEL_BITS` -eq 64 ]; then
                DIST_BITS="64"
            else
                DIST_BITS="32"
            fi
            ;;
        'sun4u' | 'sparcv9' | 'sparc')
            DIST_ARCH="sparc"
            DIST_BITS=`isainfo -b`
            ;;
        '9000/800' | '9000/785')
            DIST_ARCH="parisc"
            if [ `getconf KERNEL_BITS` -eq 64 ]; then
                DIST_BITS="64"
            else
                DIST_BITS="32"
            fi
            ;;
        s390* )
            DIST_ARCH="390"
            if [ `getconf LONG_BIT` -eq 64 ] ; then
                DIST_BITS="64"
            else
                DIST_BITS="32"
            fi
            ;;
        aarch64* | arm64*)
            # 'aarch64_be', 'aarch64', 'arm64', etc.
            # => only armhf is 64-bit
            DIST_ARCH="armhf"
            DIST_BITS="64"
            ;;
        armv*)
            # 'armv8b', 'armv8l', 'armv7l', 'armv5tel', etc.
            # => armv8 and above should be 64-bit, but it is more reliable to check the bits with getconf.
            if [ `getconf LONG_BIT` -eq 64 ]; then
                DIST_ARCH="armhf"
                DIST_BITS="64"
            else
                # Note: The following command returns nothing on SUSE for Raspberry Pi 3 (aarch64).
                #       An alternative command would be 'dpkg --print-architecture', but dpkg may not exist.
                if [ -z "`readelf -A /proc/self/exe | grep Tag_ABI_VFP_args`" ] ; then
                    DIST_ARCH="armel"
                else
                    DIST_ARCH="armhf"
                fi
                DIST_BITS="32"
            fi
            ;;
    esac
fi

outputFile() {
    if [ -f "$1" ]
    then
        echo "  $1 (Found but not executable.)";
    else
        echo "  $1"
    fi
}

# Decide on the wrapper binary to use.
# If a 32-bit wrapper binary exists then it will work on 32 or 64 bit
#  platforms, if the 64-bit binary exists then the distribution most
#  likely wants to use long names.  Otherwise, look for the default.
# For macosx, we also want to look for universal binaries.
WRAPPER_TEST_CMD="$WRAPPER_CMD-$DIST_OS-$DIST_ARCH-$DIST_BITS"
if [ -x "$WRAPPER_TEST_CMD" ]
then
    WRAPPER_CMD="$WRAPPER_TEST_CMD"
else
    if [ "$DIST_OS" = "macosx" ]
    then
        WRAPPER_TEST_CMD="$WRAPPER_CMD-$DIST_OS-universal-$DIST_BITS"
        if [ -x "$WRAPPER_TEST_CMD" ]
        then
            WRAPPER_CMD="$WRAPPER_TEST_CMD"
        else
            WRAPPER_TEST_CMD="$WRAPPER_CMD-$DIST_OS-$DIST_ARCH-$DIST_BITS"
            if [ -x "$WRAPPER_TEST_CMD" ]
            then
                WRAPPER_CMD="$WRAPPER_TEST_CMD"
            else
                WRAPPER_TEST_CMD="$WRAPPER_CMD-$DIST_OS-universal-$DIST_BITS"
                if [ -x "$WRAPPER_TEST_CMD" ]
                then
                    WRAPPER_CMD="$WRAPPER_TEST_CMD"
                else
                    if [ ! -x "$WRAPPER_CMD" ]
                    then
                        echo "Unable to locate any of the following binaries:"
                        outputFile "$WRAPPER_CMD-$DIST_OS-$DIST_ARCH-$DIST_BITS"
                        outputFile "$WRAPPER_CMD-$DIST_OS-universal-$DIST_BITS"
                        outputFile "$WRAPPER_CMD-$DIST_OS-$DIST_ARCH-32"
                        outputFile "$WRAPPER_CMD-$DIST_OS-universal-32"
                        outputFile "$WRAPPER_CMD"
                        exit 1
                    fi
                fi
            fi
        fi
    else
        WRAPPER_TEST_CMD="$WRAPPER_CMD-$DIST_OS-$DIST_ARCH-32"
        if [ -x "$WRAPPER_TEST_CMD" ]
        then
            WRAPPER_CMD="$WRAPPER_TEST_CMD"
        else
            if [ ! -x "$WRAPPER_CMD" ]
            then
                echo "Unable to locate any of the following binaries:"
                outputFile "$WRAPPER_CMD-$DIST_OS-$DIST_ARCH-$DIST_BITS"
                outputFile "$WRAPPER_CMD-$DIST_OS-$DIST_ARCH-32"
                outputFile "$WRAPPER_CMD"
                exit 1
            fi
        fi
    fi
fi

# Build the nice clause
if [ "X$PRIORITY" = "X" ]
then
    CMDNICE=""
else
    CMDNICE="nice -$PRIORITY"
fi

# Build the anchor file clause.
if [ "X$IGNORE_SIGNALS" = "X" ]
then
   ANCHORPROP=
   IGNOREPROP=
else
   ANCHORPROP=wrapper.anchorfile=\"$ANCHORFILE\"
   IGNOREPROP=wrapper.ignore_signals=TRUE
fi

# Build the lock file clause.  Only create a lock file if the lock directory exists on this platform.
LOCKPROP=
if [ -d $LOCKDIR ]
then
    if [ -w $LOCKDIR ]
    then
        LOCKPROP=wrapper.lockfile=\"$LOCKFILE\"
    fi
fi

checkUser() {
    # $1 touchLock flag
    # $2 command

    # Check the configured user.  If necessary rerun this script as the desired user.
    if [ "X$RUN_AS_USER" != "X" ]
    then
        # Resolve the location of the 'id' command
        IDEXE="/usr/xpg4/bin/id"
        if [ ! -x "$IDEXE" ]
        then
            IDEXE="/usr/bin/id"
            if [ ! -x "$IDEXE" ]
            then
                echo "Unable to locate 'id'."
                echo "Please report this message along with the location of the command on your system."
                exit 1
            fi
        fi

        if [ "`$IDEXE -u -n`" = "$RUN_AS_USER" ]
        then
            # Already running as the configured user.  Avoid password prompts by not calling su.
            RUN_AS_USER=""
        fi
    fi
    if [ "X$RUN_AS_USER" != "X" ]
    then
        # If LOCKPROP and $RUN_AS_USER are defined then the new user will most likely not be
        # able to create the lock file.  The Wrapper will be able to update this file once it
        # is created but will not be able to delete it on shutdown.  If $2 is defined then
        # the lock file should be created for the current command
        if [ "X$LOCKPROP" != "X" ]
        then
            if [ "X$1" != "X" ]
            then
                # Resolve the primary group
                RUN_AS_GROUP=`groups $RUN_AS_USER | awk '{print $3}' | tail -1`
                if [ "X$RUN_AS_GROUP" = "X" ]
                then
                    RUN_AS_GROUP=$RUN_AS_USER
                fi
                touch $LOCKFILE
                chown $RUN_AS_USER:$RUN_AS_GROUP $LOCKFILE
            fi
        fi

        # Still want to change users, recurse.  This means that the user will only be
        #  prompted for a password once. Variables shifted by 1
        su -m $RUN_AS_USER -c "\"$REALPATH\" $2"

        # Now that we are the original user again, we may need to clean up the lock file.
        if [ "X$LOCKPROP" != "X" ]
        then
            getpid
            if [ "X$pid" = "X" ]
            then
                # Wrapper is not running so make sure the lock file is deleted.
                if [ -f "$LOCKFILE" ]
                then
                    rm "$LOCKFILE"
                fi
            fi
        fi

        exit 0
    fi
}

getpid() {
    if [ -f "$PIDFILE" ]
    then
        if [ -r "$PIDFILE" ]
        then
            pid=`cat "$PIDFILE"`
            if [ "X$pid" != "X" ]
            then
                # It is possible that 'a' process with the pid exists but that it is not the
                #  correct process.  This can happen in a number of cases, but the most
                #  common is during system startup after an unclean shutdown.
                # The ps statement below looks for the specific wrapper command running as
                #  the pid.  If it is not found then the pid file is considered to be stale.
                pidtest=`$PSEXE -p $pid -o args | grep "$WRAPPER_CMD" | tail -1`
                if [ "X$pidtest" = "X" ]
                then
                    # This is a stale pid file.
                    rm -f "$PIDFILE"
                    echo "Removed stale pid file: $PIDFILE"
                    pid=""
                fi
            fi
        else
            echo "Cannot read $PIDFILE."
            exit 1
        fi
    fi
}

testpid() {
    pid=`$PSEXE -p $pid | grep $pid | grep -v grep | awk '{print $1}' | tail -1`
    if [ "X$pid" = "X" ]
    then
        # Process is gone so remove the pid file.
        rm -f "$PIDFILE"
        pid=""
    fi
}

console() {
    echo "Running $APP_LONG_NAME..."
    getpid
    if [ "X$pid" = "X" ]
    then
        # The string passed to eval must handles spaces in paths correctly.
        COMMAND_LINE="$CMDNICE \"$WRAPPER_CMD\" \"$WRAPPER_CONF\" wrapper.syslog.ident=$APP_NAME wrapper.pidfile=\"$PIDFILE\" $ANCHORPROP $LOCKPROP"
        eval $COMMAND_LINE
    else
        echo "$APP_LONG_NAME is already running."
        exit 1
    fi
}

start() {
    echo "Starting $APP_LONG_NAME..."
    getpid
    if [ "X$pid" = "X" ]
    then
        # The string passed to eval must handles spaces in paths correctly.
        COMMAND_LINE="$CMDNICE \"$WRAPPER_CMD\" \"$WRAPPER_CONF\" wrapper.syslog.ident=$APP_NAME wrapper.pidfile=\"$PIDFILE\" wrapper.daemonize=TRUE $ANCHORPROP $IGNOREPROP $LOCKPROP"
        eval $COMMAND_LINE
    else
        echo "$APP_LONG_NAME is already running."
        exit 1
    fi
}

stopit() {
    echo "Stopping $APP_LONG_NAME..."
    getpid
    if [ "X$pid" = "X" ]
    then
        echo "$APP_LONG_NAME was not running."
    else
        if [ "X$IGNORE_SIGNALS" = "X" ]
        then
            # Running so try to stop it.
            kill $pid
            if [ $? -ne 0 ]
            then
                # An explanation for the failure should have been given
                echo "Unable to stop $APP_LONG_NAME."
                exit 1
            fi
        else
            rm -f "$ANCHORFILE"
            if [ -f "$ANCHORFILE" ]
            then
                # An explanation for the failure should have been given
                echo "Unable to stop $APP_LONG_NAME."
                exit 1
            fi
        fi

        # We can not predict how long it will take for the wrapper to
        #  actually stop as it depends on settings in wrapper.conf.
        #  Loop until it does.
        savepid=$pid
        CNT=0
        TOTCNT=0
        while [ "X$pid" != "X" ]
        do
            # Show a waiting message every 5 seconds.
            if [ "$CNT" -lt "5" ]
            then
                CNT=`expr $CNT + 1`
            else
                echo "Waiting for $APP_LONG_NAME to exit..."
                CNT=0
            fi
            TOTCNT=`expr $TOTCNT + 1`

            sleep 1

            testpid
        done

        pid=$savepid
        testpid
        if [ "X$pid" != "X" ]
        then
            echo "Failed to stop $APP_LONG_NAME."
            exit 1
        else
            echo "Stopped $APP_LONG_NAME."
        fi
    fi
}

status() {
    getpid
    if [ "X$pid" = "X" ]
    then
        echo "$APP_LONG_NAME is not running."
        exit 1
    else
        echo "$APP_LONG_NAME is running ($pid)."
        exit 0
    fi
}

dump() {
    echo "Dumping $APP_LONG_NAME..."
    getpid
    if [ "X$pid" = "X" ]
    then
        echo "$APP_LONG_NAME was not running."

    else
        kill -3 $pid

        if [ $? -ne 0 ]
        then
            echo "Failed to dump $APP_LONG_NAME."
            exit 1
        else
            echo "Dumped $APP_LONG_NAME."
        fi
    fi
}

case "$1" in

    'console')
        checkUser touchlock $1
        console
        ;;

    'start')
        checkUser touchlock $1
        start
        ;;

    'stop')
        checkUser "" $1
        stopit
        ;;

    'restart')
        checkUser touchlock $1
        stopit
        start
        ;;

    'status')
        checkUser "" $1
        status
        ;;

    'dump')
        checkUser "" $1
        dump
        ;;

    *)
        echo "Usage: $0 { console | start | stop | restart | status | dump }"
        exit 1
        ;;
esac

exit 0
