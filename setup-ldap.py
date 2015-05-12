#!/usr/bin/python
import rpm
import subprocess
import os
import shlex
import shutil
import ldap
import ldap.modlist as modlist

def check_package():
    print "Check if the package openldap-servers is installed"
    package = "openldap-servers"
    ts = rpm.TransactionSet()
    mi = ts.dbMatch('name', package)
    if (len(mi) == 0):
        print "%s not found, Installing...." % package
        cmd = "yum -y install %s" % package
        stdout,return_code = run_cmd(cmd)
        if return_code == 0:
            print stdout
        else:
            print stdout
    else:
        for h in mi:
            print "%s-%s-%s is already installed" % (h['name'], h['version'], h['release'])
	del mi, ts

def run_cmd(cmd,stdin=None,capture_output=True):
    p_in = None
    p_out = None
    p_err = None
    if stdin:
		p_in = subprocess.PIPE
    else:
        p_out = subprocess.PIPE
        p_err = subprocess.PIPE    	
    
    args = shlex.split(cmd)
    p = subprocess.Popen(args, stdin=p_in, stdout=p_out, stderr=p_err, close_fds=True)
    stdout, stderr = p.communicate(stdin)
    stdout, stderr = str(stdout), str(stderr)
    if capture_output:
        return stdout, p.returncode
    else:
        print p.returncode

def basicsetupopenldap():

    # test if slapd service is already running, if so stop the service 
    cmd = "systemctl stop slapd.service"
    stdout,return_code = run_cmd(cmd)
    if return_code == 0:
        print "slapd service stopped successfully"
    else:
        print "slapd process did not stop"
    #test if directory slapd.d exists 
    slapd_dir = "/etc/openldap/slapd.d"
    bdb_dir = "/var/lib/ldap"
    #todo: Do this operation once instead of twice
    if os.path.exists(slapd_dir):
        for file_path in os.listdir(slapd_dir):
            file_path_object = os.path.join(slapd_dir, file_path)
            if os.path.isfile(file_path_object):
                print "deleting file ", file_path_object
                try:
                    os.remove(file_path_object)
                except:
                    raise
            elif os.path.isdir(file_path_object):
                print "deleting directory ", file_path_object
                try:
                    shutil.rmtree(file_path_object)
                except:
                    raise
    # test if /var/lib/ldap directory exists and if any files/directories exist delete it
    if os.path.exists(bdb_dir):
        if os.listdir(bdb_dir):
            for file_path in os.listdir(bdb_dir):
                file_path_object = os.path.join(bdb_dir, file_path)
                if os.path.isfile(file_path_object):
                    print "deleting file ", file_path_object
                    try:
                        os.remove(file_path_object)
                    except:
                        raise
                elif os.path.isdir(file_path_object):
                    print "deleting directory ", file_path_object
                    try:
                        shutil.rmtree(file_path_object)
                    except:
                        raise
        else:
            print "Directory is empty"

    # From current working directory run slaptest command to populate default cn=config database
    sample_slapd_conf="sample-slapd.conf"
    slapd_dir="/etc/openldap/slapd.d"
    sample_slapd_conf_path=os.path.join(os.getcwd(), sample_slapd_conf)
    print "Running slaptest with sample slapd.conf"
    cmd = "slaptest -f %s -F %s" % (sample_slapd_conf_path, slapd_dir)
    stdout,return_code = run_cmd(cmd)
    if return_code == 0:
        print "slaptest executed successfully"

    # change ownership of files and directories of /et/openldap/slapd.d directory 
    for dirpath,dirnames,filenames in os.walk(slapd_dir):
        for dirs in dirnames:
            os.chown(os.path.join(dirpath, dirs),55, 55)
        for files in filenames:
            os.chown(os.path.join(dirpath, files),55, 55)

    # start slapd service 
    cmd = "systemctl start slapd.service"
    stdout,return_code = run_cmd(cmd)
    if return_code == 0:
        print "slapd service started successfully"
        cmd = "systemctl status slapd.service"
        stdout,return_code = run_cmd(cmd)
        print stdout
    else:
        print "slapd service did not start successfully"
def setup_bdb():
    l = ldap.open('localhost', 389)
    try:
        l.bind("cn=admin,cn=config", "config")
    except ldap.SERVER_DOWN, e:
        print "ldap server is down"

    entry={
        'objectClass': ['olcDatabaseConfig', 'olcBdbConfig'],
        'olcDatabase': ['{1}bdb'],
        'olcSuffix' : ['dc=example,dc=org'],
        'olcDbDirectory': ['/var/lib/ldap'],
        'olcRootDN' : ['cn=Manager,dc=example,dc=org'],
        'olcRootPW' : ['redhat'],
        'olcDbCacheSize' : ['1000'],
        'olcDbCheckpoint' : ['1024 10'],
        'olcDbIDLcacheSize' : ['3000'],
        'olcDbConfig' : ['set_cachesize 0 10485760 0'],
        'olcDbConfig' : ['set_lg_bsize 2097152'],
        'olcLimits' : ['dn.exact="cn=Manager,dc=example,dc=org" time.soft=unlimited time.hard=unlimited size.soft=unlimited size.hard=unlimited'],
        'olcDbIndex' : ['uid pres,eq','cn,sn,displayName pres,eq,approx,sub','uidNumber,gidNumber eq','memberUid eq','objectClass eq','entryUUID pres,eq','entryCSN pres,eq'],
        'olcAccess' : ['to attrs=userPassword by self write by anonymous auth by dn.children="ou=admins,dc=example,dc=org" write by * none']
        }
    dn = 'olcDatabase=bdb,cn=config'
    ldif = modlist.addModlist(entry)
    try:
        l.add_s(dn, ldif)
    except:
        raise
    l.unbind()
def enable_dit():
    l = ldap.open('localhost', 389)
    try:
        l.bind("cn=Manager,dc=example,dc=org", "redhat")
    except ldap.SERVER_DOWN, e:
        print "ldap server is down"
    dn = 'dc=example,dc=org'
    entry={
            'objectClass': ['top', 'domain'],
            'dc' : ['example']
            }
    ldif = modlist.addModlist(entry)
    print type(ldif)
    try:
        l.add_s(dn, ldif)
    except:
        raise
    
    dn = 'ou=People,dc=example,dc=org'
    entry={
            'objectClass' : ['top', 'organizationalUnit'],
            'ou': ['People']
            }
    ldif = modlist.addModlist(entry)
    try:
        l.add_s(dn, ldif)
    except:
        raise
    l.unbind()


check_package()
basicsetupopenldap()
setup_bdb()
enable_dit()
