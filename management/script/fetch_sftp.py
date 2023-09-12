#!/usr/bin/env python
"""
NAME
    Fetch-SFTP - Fetch files via SFTP respecting special conditions

SYNOPSIS
    fetch_sftp.py [--dry-run] [-h|--help] [-l|--local-dir <dir>] \\
        [-r|--remote-dir <dir>] [--remote-port <port>] \\
        [--remote-server <server>] [--ssh-host-key-file <file>] \\
        [--delete-remote-file] [--delete-remote-all-statefiles] \\
        [--delete-remote-previous-statefiles] \\
        [--force-state-check] [--skip-state-check] [--list-files] \\
        [--no-fetch] [--ssh-rsa-id-file <file>] \\
        -u|--remote-user <remote_user> \\
        -p|--previous-state <previous_state> ... \\
        -n|--next-state <next_state> ... 

DESCRIPTION
    Fetch files specified by a 'special state' from a SFTP server only by using
    password-less public key authentication (If the private key is passphrase 
    protected it needs to be entered at the command line each time this script 
    is called). The meaning of a 'special state' is described in the section 
    "What are States" below.
    
    By using the argument '--no-fetch' this script can be used to alter the 
    states on the remote server.
    This is very usefull to alter the state on the remote server for progress 
    reports or triggering other scripts in case of an local event (e.g. an 
    HAFAS server could be started with new plan data and this should be 
    reported as a progress or to rtigger another script).
    It does not completely avoid fetching the file, because the whole file is 
    needed for hash digest generation. So in the case of to be created new 
    states, the file nevertheless is beeing fetched.

    
    WHAT ARE STATES?
        
    The remote file will only be fetched if some states exists. This states are
    defined by the existance of files with an additional suffix in their 
    filename while the prefix of this files is the filename of the file which 
    the state is defined for. This suffixes are called 'states' in this 
    context.
        
    It is possible to use zero size files as state files. But if you want some 
    level of security, in the meaning of integrity and authenticity of the 
    remote file and its state files, you should use this script to let it write
    the hexadecimal representation of a SHA-1 hash combined from the whole 
    remote file and the complete (pathless) filename of the state file into the
    state file. Thereby you can assure that the state file refers to the remote
    file and that the state file has not been recycled from a previous state. 
    This is always done by default when new state files are created using this
    script.
    To force this security check you should use the argument 
    '--force-state-check'. This argument is disabled at the moment to provide 
    backward compatibility but in the near future this switch will be activted
    by default. Needless to say thath then it will still be possible to use 
    '--skip-state-check'.
        
    EXAMPLE:
        
        The following list of files indicate the states 'TRANSFERED', 
        'FETCHED_TO_WEBSERVER_A' and 'FETCHED_TO_APPLICATIONSERVER_A' for the 
        file 'test.zip':
        
          test.zip
          test.zip.TRANSFERED
          test.zip.FETCHED_TO_WEBSERVER_A
          test.zip.FETCHED_TO_APPLICATIONSERVER_A
        
        The states can be given at the command line using the options '-p', 
        '--previous-state', '-n' and '--next-state'. This options can be 
        repeated and are defining the state the file must have before beeing 
        fetched.
        Previous states define the states the file must be in before it gets 
        fetched.
        Next states define the state files which will be created after the file 
        got fetched. If the next states are met before the file got fetched, 
        the file will not get fetched.
    
    This script is based on the following non standard python modules:
        paramiko - SSH 2 protocol for python (licensed under the GNU LGPL)
        syslog   - This module is only available in Python on the Unix platform
        
    Python version 2.2 is required because paramiko suggest this version. If 
    available features of newer versions of python are used (e.g. hashlib).

OPTIONS
    -u, --remote-user
        Specifies the remote user to be used as the login name at the remote 
        server.
        
    -p, --previous-state
        This argument can be repeated and describes a state that must exist 
        before the file will be fetched. Multiple occurences of this option are 
        ANDed.
        
    -n, --next-state
        After fetching the remote file state files with can be created. use 
        this option to describe the to be created state. This option can also 
        be repeated.
        
    -l, --local-dir
        The local directory where the fetched file should be placed in.
        
    -r, --remote-dir
        Specifies the directory on the remote (SFTP-)server in which to look 
        for files matching the given previous state(s). The next state(s) are 
        beeing created in this directory too.
        
    --force-state-check
        This argument forces the check for SHA-1 hashes in the state files. 
        If these hashes are missing the state is simply ignored.
        
    --delete-remote-file
        This switch can be given if the remote file should be deleted after 
        beeing fetched.
        
    --delete-remote-all-statefiles
        If the file should be deleted after fetching it (see option 
        --delete-remote-file), this option triggers the deletion of all 
        possible state files.
        Please use the a safer way of specifying all to be deleted states as 
        previous states and delete them by using the option 
        '--delete-remote-previous-statefiles'. This is a lot safer and "keeps 
        it simple, stupid".
        This can be dangerous, as remote states are stupidly constructed by 
        appending them as '.<state_as_suffix>'. 
        Nested states or files sharing prefixes can easily be deleted this way.
        The only sanity check to avoid this is done by checking for file sizes 
        greater than zero and skipping those files from deletion. Sadly this 
        also omits state files containing SHA-1 keys! 
    
    --delete-remote-previous-statefiles
        This option can independently of the option '--delete-remote-file' or
        '--delete-remote-all-statefiles' be used to delete the previous state 
        after fetching the file. This helps to keep the remote directory clean, 
        but you loose the effect of be able to see what has been done already.
        
    --list-files
        Lists the remote files matching the given previous states. If no 
        previous state is given all files are listed.
        
    --no-fetch
        Does not fetch the remote file. Only the states are respected and 
        altered on the remote side.
        This can be used to only alter states on the remote server without 
        fetching the file.
        
    --remote-port
        If you want to connect to a special remote SSH port use this option to 
        specify it. This option defaults to the standard SSh port 22.
        
    --remote-server
        The name of the SSH server to connect to. Because this is a tool mostly 
        used by the company HaCon this defaults to 'ftp.hacon.de'.
    
    --skip-state-check
        If this argument is given the mere existence of the state files is 
        always sufficient to accept the state. Otherwise (which is the default 
        behaviour) if the state file is not emtpy (size is not zero) the state 
        file must contain the hexadecimal representation of a SHA-1 hash based 
        on the content of the remote file and the name of the state file 
        (case-sensitive and excluding the complete path, so the file can be 
        moved).
    
    --ssh-host-key-file
        If you need to specify a non-standard ssh host key file you can use 
        this option. The default location ''~/.ssh/known_hosts'' is beeing used 
        otherwise.
        The default value contains a Unix specific path.
    
    --ssh-rsa-id-file
        If your identity changes from the standard location ('~/.ssh/id_rsa') 
        use this option to specify its private key file.
        The default value contains a Unix specific path.
    
    --debug
        Activates printing of debugging output of all operations to the console.
        This option implicates the option '--verbose' to get a more reasonable 
        output.
    
    -d --dry-run
        If this parameter is given, no files will be fetched. The steps that 
        would be done are printed to the console. No logging via syslog is done 
        as this would pollute the logfiles.
        This switch activates verbose output as well. Otherwise nothing really 
        usefull will happen!
        
    -v, --verbose
        If not sure what is happening try this switch to see which steps are 
        taken to fetch the file(s). In combination with '--debug' a lot of what 
        is really happening is printed to the console.

    -h, --help 
        Prints this little help screen.

KNOWN BUGS
    None known (yet!)

AUTHORS
    Kai Fricke <kai.fricke@hacon.de>

COPYRIGHT
    (C) Copyright 2007 HaCon Ingenieurgesellschaft mbH 
    
VERSION
    $Header: /cvs/hafas/script/fetch_sftp.py,v 1.16 2012-02-13 09:07:28 kf Exp $
"""

# Additionally needed Python modules
import paramiko

# Built-in Python modules
import datetime
import getpass
import getopt
import sys
# Load the hashlib if available (Python 2.5)
if sys.version_info[0] >= 2 and sys.version_info[1] >= 5:
    import hashlib
else:
    import sha
import os
import random
import socket
import string
import tempfile
import time

SYSLOG_ENABLED = True

try:
    import syslog
    syslog.openlog('fetch-sftp', syslog.LOG_PID, syslog.LOG_LOCAL0)
except ImportError:
    print('Failed to import syslog module. Maybe not in an UNIX environment.')
    print('Disableing syslog logging!')
    SYSLOG_ENABLED = False
    f_log_file = open(os.path.expanduser(os.path.join('~', 
                                                      'import_hafas', 
                                                      'fetch_sftp.log')), 'a')    
    
import traceback    
   

class SFTPFetcher:
    """A SFTPFetcher can be used to authenticate against a SSH server which 
    supports the SFTP protocol. Remote files can be fetched based on so called 
    state files."""
    
    def __init__(self):
        """Initializes this class."""
        # The TCP socket used for the SSH connection
        self.sock = None
        
        # The SSH transport (connection)
        self.transp = None
        
        # The SFTP client
        self.sftp = None
        
        # global settings
        
        base_dir = os.path.expanduser(os.path.join('~', 'import_hafas_data'))
        
        self.local_dir = os.path.join(base_dir, 'incoming')
        
        self.next_states = []
        self.previous_states = []
        self.remote_dir = 'incoming'
        self.remote_port = 22
        self.remote_server = 'ftp.hacon.de'
        self.remote_user = None
        
        self.ssh_log_file = os.path.join(base_dir, 'fetch_sftp_paramiko.log')
        
        ssh_base_dir = os.path.expanduser(os.path.join('~', '.ssh'))
        
        self.ssh_host_key_file = os.path.join(ssh_base_dir, 'known_hosts')
        self.ssh_rsa_id_file = os.path.join(ssh_base_dir, 'id_rsa')
    
        self.no_fetch = False
        
        # A switch if the SHA1 hash digests should be used to verify the 
        # previous states.
        self.state_check = True
        self.force_state_check = False
        
        self.list_files = False
        
        # A cache for the file hashes on the remote side
        self.hash_cache = {}
        
        # A cache for file contents
        self.file_cache = {}
        
        self.delete_remote_file = False
        self.delete_remote_all_statefiles = False
        self.delete_remote_previous_statefiles = False
    
        self.dry_run = False
        self.print_verbose = False
        self.print_debug = False
        
        # Parse command line arguments
        self.parse_arguments()
        
        
    def log(self, message):
        """Log via syslog if available else to the console only."""
        if SYSLOG_ENABLED and not self.dry_run:
            syslog.syslog(syslog.LOG_INFO, message)
        else:
            print("%s - %s" % (time.strftime("%a, %d %b %Y %H:%M:%S +0000", 
                                             time.gmtime()), 
                                             message))
            if not self.dry_run:
                f_log_file.write("%s - %s" % 
                                 (time.strftime("%a, %d %b %Y %H:%M:%S +0000", 
                                                time.gmtime()), 
                                                message))

    def verbose(self, message):
        """This method prints verbose output if wanted to the console. If no 
        verbosity is wanted, nothing is done instead."""
        if self.print_verbose:
            print("%s - %s" % (time.strftime("%a, %d %b %Y %H:%M:%S +0000", 
                                             time.gmtime()), 
                                             message))


    def debug(self, message):
        """This method prints debug output if wanted to the console. If no 
        debug output is wanted, nothing is done instead."""
        if self.print_debug:
            print("%s - %s" % (time.strftime("%a, %d %b %Y %H:%M:%S +0000", 
                                             time.gmtime()), 
                                             message))


    def usage(self, error_code, message=''):
        """Print usage information and a given message and exit the program.
        Print the documentation block of this script as the general usage
        information. A userdefined message can also be appended."""
        print >> sys.stderr, __doc__
        
        if message:
            print >> sys.stderr, message
            
        sys.exit(error_code)        
        

    def parse_arguments(self):
        """Read the arguments given at the command line and validate them."""
        self.verbose("Parsing command line arguments")
        
        try:
            options, unknown_arguments = getopt.getopt(
                sys.argv[1:],
                'dhp:l:n:r:u:v',
                ['dry-run',
                 'debug',
                 'delete-remote-file',
                 'delete-remote-all-statefiles',
                 'delete-remote-previous-statefiles',
                 'force-state-check',
                 'help',
                 'list-files',
                 'local-dir=',
                 'next-state=',
                 'no-fetch',
                 'previous-state=',
                 'remote-dir=',
                 'remote-port=',
                 'remote-server=',
                 'remote-user=',
                 'skip-state-check',
                 'ssh-debug',
                 'ssh-host-key-file=',
                 'ssh-rsa-id-file=',
                 'verbose',
                 ])
        except getopt.error, message:
            self.usage(1, message)
            
        # Evaluate the parsed options
        for (option, argument) in options:
            if option in ('-h', '--help'):
                self.usage(0)
            elif option in ('-d', '--dry-run'):
                self.dry_run = True
                self.print_verbose = True
                self.debug('Dry-run (includes verbose output) activated!')
            elif option in ('--ssh-debug'):
                # Enable Paramiko logging into logfile
                paramiko.util.log_to_file(self.ssh_log_file)
                self.debug("SSH connection debugging activated to file '%s'" % 
                           (self.ssh_log_file))
            elif option in ('-l', '--local-dir'):
                self.local_dir = os.path.expanduser(argument)
                self.debug("Using local directory '%s'" % (argument))
            elif option in ('-n', '--next-state'):
                self.next_states.append(argument)
                self.debug("Adding next state '%s'" % (argument))
            elif option in ('-p', '--previous-state'):
                self.previous_states.append(argument)
                self.debug("Adding previous state '%s'" % (argument))
            elif option in ('-r', '--remote-dir'):
                self.remote_dir = argument
                self.debug("Using remote directory '%s'" % (argument))
            elif option in ('--remote-port'):
                self.remote_port = argument
                self.debug("Using remote port '%s'" % (argument))
            elif option in ('--remote-server'):
                self.remote_server = argument
                self.debug("Using remote server '%s'" % (argument))
            elif option in ('-u', '--remote-user'):
                self.remote_user = argument
                self.debug("Using remote user '%s'" % (argument))
            elif option in ('--ssh-host-key-file'):
                self.ssh_host_key_file = argument
                self.debug("Using host-key file '%s'" % (argument))
            elif option in ('--ssh-rsa-id-file'):
                self.ssh_rsa_id_file = argument
                self.debug("Using SSH RSA identity '%s'" % (argument))
            elif option in ('--debug'):
                self.print_debug = True
                self.print_verbose = True
                self.debug('Activating printing of debugging output!')
            elif option in ('-v', '--verbose'):
                self.print_verbose = True
                self.debug('Activating printing of verbose output!')
            elif option in ('--delete-remote-file'):
                self.delete_remote_file = True
                self.debug('Activating deletion of remote file!')
            elif option in ('--delete-remote-all-statefiles'):
                self.delete_remote_all_statefiles = True
                self.debug('Activating deletion of all remote statefiles!')
            elif option in ('--delete-remote-previous-statefiles'):
                self.delete_remote_previous_statefiles = True
                self.debug('Activating deletion of remote previous statefiles!')
            elif option in ('--no-fetch'):
                self.no_fetch = True
                self.debug('Not fetching the remote file!')
            elif option in ('--skip-state-check'):
                self.state_check = False
                self.debug('Not checking for previous state checksums!')
            elif option in ('--force-state-check'):
                self.state_check = True
                self.force_state_check = True
                self.debug('Forcing state check!')
            elif option in ('--list-files'):
                self.list_files = True
                self.debug('Listing remote files!')
            else:
                self.usage(1, "Unknown option (%s %s)" % (option, argument))
        
        # Check for mandatory command line options
        if not self.remote_user:
            self.usage(1, 'The remote username must be specified!')
        
        if self.previous_states == []:
            if self.list_files:
                self.no_fetch = True
            else:
                self.usage(1, 'At least one previous state must be specified!')

        if len(self.next_states) == 0 and self.delete_remote_all_statefiles:
            self.usage(1, 'I prevent you from deleting all state files of a '
                          'file without deleting the file too!')

        if len(self.next_states) == 0 and not self.delete_remote_file and not self.list_files:
            self.usage(1, 'At least one next state must be specified when no '
                          'deletion of remote file is wanted!')
            
        if len(self.next_states) > 0 and self.delete_remote_all_statefiles:
            self.usage(1, 'It makes no sense to specify a next state and '
                          'delete it immediately!')

        if len(self.next_states) > 0 and self.delete_remote_file:
            self.usage(1, 'It makes no sense to specify a next state and '
                          'deleting the file it belongs to!')

        self.log("Importing HAFAS data from '%s@%s:%s' to '%s'" % 
            (self.remote_user, 
             self.remote_server, 
             self.remote_dir, 
             self.local_dir))
        
        self.debug("Previous states %s" % (self.previous_states))
        self.debug("Next states %s" % (self.next_states))
        self.debug("Local directory '%s'" % (self.local_dir))
        self.debug("Remote directory '%s'" % (self.remote_dir))
        self.debug("Remote server '%s'" % (self.remote_server))
        self.debug("Remote port %i" % (self.remote_port))
        self.debug("Remote user '%s'" % (self.remote_user))
        self.debug("Deletion of remote file wanted? '%s'" % 
                   (self.delete_remote_file))
        self.debug("Deletion of all remote state file wanted? '%s'" % 
                   (self.delete_remote_all_statefiles))
        self.debug("Deletion of previous remote state file wanted? '%s'" % 
                   (self.delete_remote_previous_statefiles))
        self.debug("Verbose output wanted? '%s'" % (self.print_verbose))
        self.debug("Debugging output wanted? '%s'" % (self.print_debug))
        self.debug("Dry run!? '%s'" % (self.dry_run))
        

    def open_connection(self):
        """Open the TCP connection to SSH server."""
        self.debug("Connection to remote server...")
        try:
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.sock.connect((self.remote_server, self.remote_port))
        except Exception, e:
            self.log("Connecting to SSH server '%s:%i' failed (%s). Exitting!" % 
                     (self.remote_server, 
                      self.remote_port, 
                      str(e)))
            traceback.print_exc()
            sys.exit(1)
    

    def create_transport(self):
        """Initiate SSH connection over the previously opened socket."""
        self.debug("Creating SSH connection to remote server...")
        try:
            keys = None
            self.transp = paramiko.Transport(self.sock)
            try:
                self.transp.start_client()
            except paramiko.SSHException:
                self.log("Negotiation with SSH server '%s' failed. Exitting!" % 
                         (self.remote_server))
                sys.exit(1)
        except Exception, e:
            self.log("Failed to open SSH transport: %s: %s" % 
                     (str(e.__class__), 
                      str(e)))
            traceback.print_exc()
            try:
                self.transp.close()
            except:
                self.log("Failed to close (maybe partly open) SSH transport!")
            sys.exit(1)


    def authenticate_transport(self):
        """First open host keys and check the server's hostkey, then 
        authenticate using the local RSA public key."""
        self.debug("Authenticating SSH connection...")
        keys = None
        try:
            keys = paramiko.util.load_host_keys(self.ssh_host_key_file)
        except IOError:
            try:
                keys = paramiko.util.load_host_keys(self.ssh_host_key_file)
            except IOError:
                self.log("Unable to open host keys file 'host_key_file'." % 
                         (self.ssh_host_key_file))
                keys = {}
    
            # Check server's host key -- this is important.
            key = self.transp.get_remote_server_key()
            
            if not keys.has_key(self.remote_server):
                self.log("WARNING: Unknown SSH hostkey for '%s'!" % 
                         (self.remote_server))
            elif not keys[self.remote_server].has_key(key.get_name()):
                self.log("WARNING: Unknown SSH server '%s' (Invalid hostkey)!" % 
                         (self.remote_server))
            elif keys[self.remote_server][key.get_name()] != key:
                self.log("WARNING: SSH hostkey changed for '%s'. Exitting!" % 
                         (self.remote_server))
                sys.exit(1)
            else:
                self.log("Host key OK.")
            
        # Open the local RSA identity
        path = os.path.expanduser(self.ssh_rsa_id_file)
        
        try:
            # Try to open the RSA identity
            key = paramiko.RSAKey.from_private_key_file(path)
        except paramiko.PasswordRequiredException:
            # If needed enter the pass phrase for the private key of the local 
            # RSA identity.
            password = getpass.getpass('Please enter the passphrase for your '
                                       'RSA identity: ')
            key = paramiko.RSAKey.from_private_key_file(path, password)
            
        # Authenticate transport using just opened RSA public key
        self.transp.auth_publickey(self.remote_user, key)
        
        # Create SFTP client
        self.sftp = paramiko.SFTPClient.from_transport(self.transp)
        self.sftp.get_channel().settimeout(30.0)
        

    def fetch_files_by_state(self):
        """Fetch file list on remote host if they match the pattern given by 
        the states."""
        self.verbose("Fetching files from remote directory '%s'." % 
                     (self.remote_dir))
        self.verbose("Fetching files matching the previous states: %s" % 
                     (self.previous_states))
        self.verbose("Fetched files will get the following new states: %s" % 
                     (self.next_states))
        
        # Remember the number of created remote states
        states_created = 0
        
        # Keep track of all files which got fetched
        fetched_filenames = []
        
        # The list of files on the remote side
        remote_filename_list = self.sftp.listdir(self.remote_dir)
        self.debug("%i remote files found (%s)!" % 
                   (len(remote_filename_list), remote_filename_list))
        
        # Iterate over the list of remote files and search for the state files
        for remote_filename in remote_filename_list:
            remote_pathname = os.path.join(self.remote_dir, remote_filename)
            
            self.debug("Checking file '%s' for states..." % (remote_pathname))
            
            # Open the remote file for hash digest generation
            if self.state_check or self.force_state_check:
                remote_file_sha = self.hash_remote_file(remote_pathname)
                self.debug("The Hash digest this file is '%s'." % 
                           (remote_file_sha.hexdigest()))
            
            # Check if all state files do exist by collecting states found on 
            # remote side in this lists
            previous_states_found = []
            next_states_found = []
            
            # Check for the previous state files in the remote file list
            for state in self.previous_states:
                remote_state_filename = remote_filename + '.' + state
                remote_state_pathname = os.path.join(self.remote_dir, 
                                                     remote_state_filename)
                self.debug("Checking for previous state file '%s'..." % 
                           (remote_state_filename))
                
                if remote_state_filename in remote_filename_list:
                    state_file = self.sftp.file(remote_state_pathname, 'r')
                    
                    if self.state_check and state_file.stat().st_size > 0:
                        # Update the hash for the state file
                        state_hash = self.hash_remote_file(remote_pathname)
                        state_hash.update(remote_state_filename)
                        
                        # Compare the hash hexdigest of the remote file and the 
                        # state filename with the content of the statefile
                        if state_hash.hexdigest() == self.get_remote_file(remote_state_pathname):
                            self.verbose("Found previous state '%s' "
                                         "(Hash digest matches)!" % 
                                         (state))
                            previous_states_found.append(state)
                        else:
                            self.verbose("Invalid Hash-Digest of the previous "
                                         "state file (Should be: '%s', "
                                         "content of state_file: %s)!" % 
                                         (state_hash.hexdigest(), 
                                          self.get_remote_file(remote_state_pathname)))
                    elif not self.force_state_check:
                        self.verbose("Found previous state '%s' "
                                     "(Hash digest check omitted; "
                                     "empty statefile)!" % 
                                     (state))
                        previous_states_found.append(state)
                    else:
                        self.verbose("Forced Hash-Digest comparison renders "
                                     "the state useless. Ignoring it "
                                     "(state: %s)!" % (state))
                    
                    state_file.close()
                    
            # Check for the next state files in the remote file list
            for state in self.next_states:
                remote_state_filename = remote_filename + '.' + state
                remote_state_pathname = os.path.join(self.remote_dir, 
                                                     remote_state_filename)
                self.debug("Checking for next state file '%s'..." % 
                           (remote_state_filename))
                
                if remote_state_filename in remote_filename_list:
                    state_file = self.sftp.file(remote_state_pathname, 'r')
                    
                    if self.state_check and state_file.stat().st_size > 0:
                        # Update the hash for the state file
                        state_sha = self.hash_remote_file(remote_pathname)
                        state_sha.update(remote_state_filename)
                        
                        # Compare the hash hexdigest of the remote file and the 
                        # state filename with the content of the statefile
                        if state_sha.hexdigest() == self.get_remote_file(remote_state_pathname):
                            self.verbose("Found next state '%s' "
                                         "(Hash-Digest matches)!" % 
                                         (state))
                            next_states_found.append(state)
                        else:
                            self.verbose("Hash-Digest of the remote file does "
                                         "not match to the next state file "
                                         "(state: %s)!" % 
                                         (state))
                    elif not self.force_state_check:
                        self.verbose("Hash-Digest comparison of the next "
                                     "remote file omitted (state: %s)!" % 
                                     (state))
                        next_states_found.append(state)
                    else:
                        self.verbose("Forced Hash-Digest comparison renders "
                                     "the state useless. Ignoring it "
                                     "(state: %s)!" % 
                                     (state))
                        
                    state_file.close()
                    
            # If all next states were found simply skip this file
            if len(self.next_states) > 0:
                if len(next_states_found) == len(self.next_states):
                    self.verbose("Skipping the file '%s' because all next "
                                 "states are already reached!" % 
                                 (remote_pathname))
                    continue
                    
            # Only react if all states files were found in remote files list
            if len(previous_states_found) == len(self.previous_states):
                
                if not self.dry_run and not self.no_fetch:
                    local_pathname = os.path.join(self.local_dir, 
                                                   remote_filename)
                    self.verbose("Fetching the file '%s' to '%s'!" % 
                                 (remote_pathname, local_pathname))
                    local_file = open(local_pathname, 'w')
                    local_file.write(self.get_remote_file(remote_pathname))
                    local_file.close()
                else:
                    self.verbose("Not fetching the file '%s'!" % (remote_pathname))
                    
                # Remember this file as fetched
                fetched_filenames.append(remote_filename)
                
                # Create the next state files
                for next_state in self.next_states:
                    remote_state_filename = remote_filename + '.' + next_state
                    if not next_state in next_states_found:
                        
                        if not self.dry_run:
                            self.debug("Creating new remote state  %s" % 
                                       (next_state))
                            next_state_file = self.sftp.file(os.path.join(self.remote_dir, 
                                                                          remote_state_filename),
                                                             'a')
                            state_hash = self.hash_remote_file(remote_pathname)
                            state_hash.update(remote_state_filename)
                            self.verbose("Writing hash '%s' to next state "
                                         "file." % 
                                         (state_hash.hexdigest()))
                            next_state_file.write(state_hash.hexdigest())
                            next_state_file.flush
                            next_state_file.close()
                            states_created = states_created + 1
                        else:
                            self.verbose("!Dry-run! Not creating remote state "
                                         "'%s'!" % 
                                         (next_state))
                
                # Delete the fetched remote file
                if self.delete_remote_file:
                    if not self.dry_run:
                        self.verbose("Deleting this remote file as wanted!")
                        self.sftp.unlink(os.path.join(self.remote_dir, 
                                                      remote_filename))
                    else:
                        self.verbose("!Dry-run! Not deleting this remote file!")
                
                # Delete all remote state files
                if self.delete_remote_all_statefiles:
                    if not self.dry_run:
                        self.verbose("Deleting all state files for this remote "
                                     "file!")
                        
                        for deletion_candidate_filename in remote_filename_list:
                            deletion_candidate_pathename = os.path.join(self.remote_dir, 
                                                                        deletion_candidate_filename)
                            if deletion_candidate_file.startswith(remote_filename) and remote_filename != deletion_candidate_filename:
                                if self.sftp.stat(deletion_candidate_pathename).st_size == 0:
                                    self.sftp.unlink(deletion_candidate_pathename)
                                else:
                                    self.log("Not deleting remote file '%s', "
                                             "because it is not an empty file!"
                                             % (deletion_candidate_pathename))
                    else:
                        self.verbose("!Dry-run! Not deleting all state files "
                                     "for this remote file!")
                elif self.delete_remote_previous_statefiles:
                    # Delete only the remote previous state files
                    if not self.dry_run:
                        self.verbose("Deleting previous state files for this "
                                     "remote file!")
                        for state in self.previous_states:
                            state_pathname = os.path.join(self.remote_dir, 
                                                          remote_filename + 
                                                          '.' + state)
                            try:
                                self.sftp.unlink(state_pathname)
                            except IOError:
                                self.log("Failed to delete state file '%s' for "
                                         "state '%s'!" % 
                                         (state_pathname, state))
                            
                            # remove the deleted statefile from the list of 
                            # remote files as well!
                            remote_filename_list.remove(remote_filename + '.' + 
                                                        state) 
                    else:
                        self.verbose("!Dry-run! Not deleting previous state "
                                     "files for this remote file!")
        
        if not self.no_fetch and len(fetched_filenames) < 1:
            self.verbose("No files got fetched!")
            return 1
        elif self.no_fetch and states_created < 1:
            self.verbose("No next states have been created!")
            return 2
        elif not self.no_fetch:
            self.log("Just fetched the following local files %s" %
                    (fetched_filenames))
        else:
            return 0


    def list_files_with_state(self, states=None):
        """List files with the given list of states. If no state is specified, 
        all files are listed. The output is printed to the console."""
        filenames_with_states = []
        
        if states:
            self.verbose("Listing files matching the following state(s):")
            for state in states:
                self.verbose("  %s" % (state))
                
            remote_filename_list = self.sftp.listdir(self.remote_dir)
            self.debug("Checking states for %i remote files: %s!" % 
                       (len(remote_filename_list), remote_filename_list))
            
            for remote_filename in remote_filename_list:
                self.debug("Checking file '%s' for matching states." % 
                           (remote_filename))
                # This list remembers the states found for the current remote 
                # filename.
                found_states = []
                
                for state in states:
                    remote_state_filename = remote_filename + '.' + state
                    
                    if remote_state_filename in remote_filename_list:
                        self.debug("File '%s' matches state '%s'." % 
                           (remote_filename, state))
                        
                        # Remove the state filename from the filename list to 
                        # prevent a possible future check on states for this 
                        # file.
                        remote_filename_list.remove(remote_state_filename)
                        
                        # Remember the found state.
                        found_states.append(state)
                        
                # If the same number of states were found we assume the 
                # condition of all states beeing matched as fullfilled.
                if len(self.previous_states) == len(found_states):
                    self.debug("File '%s' matches all previous states!" % 
                           (remote_filename))
                    
                    filenames_with_states.append(remote_filename)
                else:
                    self.debug("File '%s' does not match all previous states!" %
                               (remote_filename))
        else:
            self.verbose("Listing all remote files with no respect to states!")
            filenames_with_states = self.sftp.listdir(self.remote_dir)
        
        if filenames_with_states:
            for filename in filenames_with_states:
                print(filename)
            return 0
        else:
            return 1

        
    def hash_remote_file(self, remote_filename, force_update=False):
        """Returns a hash object which was already updated with the content of 
        the remote file.
        Internally this method builds an cache for the remote filenames and 
        their hash objects.
        Only copies of the cached hash objects are returned!
        The has algorithm SHA-1 is always used, but the availability of the 
        hashlib module (introduced with Python 2.5) is determined. If the 
        hashlib module is available it is going to be used. Older versions of 
        python try to use the SHA-1 algorithm."""
        
        if not self.hash_cache.has_key(remote_filename):
            self.debug("Hash cache miss for file '%s'." % (remote_filename))
            if sys.version_info[0] >= 2 and sys.version_info[1] >= 5:
                self.hash_cache[remote_filename] = hashlib.sha1(self.get_remote_file(remote_filename))
            else:
                self.hash_cache[remote_filename] = sha.new(self.get_remote_file(remote_filename))
        else:
            self.debug("Hash cache hit for file '%s'." % (remote_filename))
            
        self.debug("Hash for file '%s' is '%s'." % (remote_filename, 
                                                    self.hash_cache[remote_filename].hexdigest()))
        return self.hash_cache[remote_filename].copy()    

            
    def get_remote_file(self, remote_filename):
        """Returns the content of the remote file based on a local cache.
        Internally this method returns the cached content of the remote file.
        """
        self.debug("Fetching content of remote filename '%s'." % 
                   (remote_filename))
        
        if not self.file_cache.has_key(remote_filename):
            self.debug("Feeding file cache with '%s'." % (remote_filename))
            
            # Creating a secure temporyry file            
            (temp_file_fd, temp_filename) = tempfile.mkstemp()
            
            # Fetch the file using SFTP GET
            try:
                self.sftp.get(remote_filename, temp_filename)
            except IOError:
                self.debug("Failed to fetch file '%s' (maybe a directory)" % 
                           (remote_filename))
                self.file_cache[remote_filename] = ''
            else:
                # Feed the cache with the content of the temporary file
                temp_file = os.fdopen(temp_file_fd)
                self.file_cache[remote_filename] = temp_file.read()
                temp_file.close()
            os.unlink(temp_filename)
        else:
            self.debug("File cache hit for file '%s'" % (remote_filename))
        
        self.debug("Returning content of file '%s' (%i bytes)." % 
                   (remote_filename, 
                    len(self.file_cache[remote_filename])))
        
        return self.file_cache[remote_filename]


    def connect(self):
        """Opens the SSH connection to the remote server and authenticates 
        using RSA a identity (public key)."""
        self.verbose("Connecting to sftp://%s@%s:%s" % 
                     (self.remote_user, 
                      self.remote_server, 
                      self.remote_port))
        
        # Open the TCP connection
        sftp.open_connection()
        
        # Create the SSH transport
        sftp.create_transport()
        
        # Authenticate the SSH transport using PSA public keys
        sftp.authenticate_transport()

            
    def disconnect(self):
        """Closes all network connections in the correct order."""
        self.transp.close()
        self.sftp.close()
        self.sock.close()
        
        
    def run(self):
        """Performes all actions this fetcher should do. Opening and closing 
        the connection and fetching or listing the remote files respecting the 
        states."""
        result = 0
        
        # Open the SSH connection
        self.connect()
        
        if self.list_files:
            result = self.list_files_with_state(self.previous_states)
        
        # The value of result may contains non-zero if the previously printed 
        # list of files is emtpy. Then we don't need to lock for to be fetched
        # files
        if not result:
            result = self.fetch_files_by_state()
        
        self.disconnect()
        
        return result


if __name__ == '__main__':
    sftp = SFTPFetcher()

    # Sleep for a random timespan to spread possible load on the SFTP server
    time.sleep(random.randint(0, 15))
    
    success = sftp.run()
    
    for hash in sftp.hash_cache.keys():
        sftp.debug("Hash for file '%s' was '%s'" % 
                   (hash, 
                    sftp.hash_cache[hash].hexdigest()))
        
    for file in sftp.file_cache.keys():
        sftp.debug("File '%s' had %i bytes in cache." % 
                   (file, 
                    len(sftp.file_cache[file])))
    
    # Exit with the return code of the previous function, as it describes a 
    # successfull operation if zero.
    sys.exit(success)
