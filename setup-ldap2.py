#!/usr/bin/python
import rpm
import subprocess
import os
import shlex
import shutil
import ldap
import ldap.modlist as modlist
import ldap.sasl
import ldif
import sys

def check_package():
    print "Check if the package openldap-servers is installed"
    package = "openldap-servers-2.4.40-11.fc23.x86_64.rpm"
    ts = rpm.TransactionSet()
    mi = ts.dbMatch('name', package)
    if (len(mi) == 0):
        print "%s not found, Installing...." % package
        cmd = "yum -y localinstall /root/%s" % package
        stdout,return_code = run_cmd(cmd)
        if return_code == 0:
            print stdout
        else:
            print stdout
            print "%s package did not install" % package
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

def add_dn():
    # We check if service slapd is started, else start the slapd server
    cmd = "systemctl status slapd.service"
    stdout,return_code = run_cmd(cmd)
    if return_code == 0:
        print stdout
    else:
        print "slapd service not running"
        print "starting slapd service"
        cmd = "systemctl start slapd.service"
        stdout,return_code = run_cmd(cmd)
        if return_code == 0:
            print "slapd service started successfully"
            print stdout
        else:
            print stdout
    ldap.sasl._trace_level=0
    ldap.set_option(ldap.OPT_DEBUG_LEVEL,0)
    sasl_auth = ldap.sasl.sasl({},'EXTERNAL')
    l = ldap.initialize("ldapi://", trace_level=0)
    try:
        l.sasl_interactive_bind_s("",sasl_auth)
    except ldap.LDAPError,e:
        print 'Error using SASL mechanism',sasl_auth.mech,str(e)
    else:
        print 'Sucessfully bound using SASL mechanism:',sasl_auth.mech
        dn = "olcDatabase={0}config,cn=config"
        mod_attrs = [(ldap.MOD_ADD, 'olcRootPW', ['config'])]
        try:
            l.modify_s(dn, mod_attrs)
        except ldap.SERVER_DOWN, e:
            print "ldap server down", str(e)
        mod_attrs = [(ldap.MOD_ADD, 'olcRootDN', ['cn=admin,cn=config'])]
        try:
            l.modify_s(dn, mod_attrs)
        except ldap.SERVER_DOWN, e:
            print "ldap server down", str(e)
        else:
            print "Add rootdn successfully"

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
        'olcDbIndex' : ['uid pres,eq','cn,sn pres,eq,approx,sub','uidNumber,gidNumber eq','objectClass eq,pres','entryUUID pres,eq','entryCSN pres,eq'],
        'olcAccess' : ['to attrs=userPassword by self write by anonymous auth by dn.children="ou=admins,dc=example,dc=org" write by * none'],
        'olcAccess' : ['to * by self write by anonymous auth by * read']
        }
    dn = 'olcDatabase=bdb,cn=config'
    ldif = modlist.addModlist(entry)
    try:
        l.add_s(dn, ldif)
    except:
        raise
    else:
        print "BDB database successfully created for suffix dc=example,dc=org"
    l.unbind()
def enable_dit():
    l = ldap.open('localhost', 389)
    try:
        l.bind("cn=Manager,dc=example,dc=org", "redhat")
    except ldap.SERVER_DOWN, e:
        print "ldap server is down"
    dn = 'dc=example,dc=org'
    entry={
            'objectClass': ['top', 'dcObject', 'organization'],
            'dc' : ['example'],
            'o' : ['Example,Inc']
            }
    ldif = modlist.addModlist(entry)
    try:
        l.add_s(dn, ldif)
    except:
        raise
    else:
        print "DIT created for suffix %s" % dn
    
    dn = 'ou=People,dc=example,dc=org'
    entry={
            'objectClass' : ['top', 'organizationalUnit'],
            'ou': ['People']
            }
    ldif = modlist.addModlist(entry)
    try:
        l.add_s(dn, ldif)
    except ldap.TYPE_OR_VALUE_EXISTS, e:
        print("User already exists", e)
    else:
        print "Organizational unit %s successfully created" % dn
    l.unbind()

class MyLDIF(ldif.LDIFParser):

    def __init__(self, input):
        ldif.LDIFParser.__init__(self,input)

    def handle(self,dn,entry):
        ldif = modlist.addModlist(entry)
        l = ldap.open('localhost', 389)
        try:
            l.bind("cn=admin,cn=config", "config")
        except ldap.SERVER_DOWN, e:
            print "ldap server is down"
        else:
            l.add_s(dn, ldif)

def enable_schema(schema_file):
    parser = MyLDIF(open(schema_file, 'rb'))
    parser.parse()

#check_package()
#add_dn()
#setup_bdb()
#enable_dit()
#enable_schema('/etc/openldap/schema/cosine.ldif')
#enable_schema('/etc/openldap/schema/inetorgperson.ldif')
#enable_schema('/etc/openldap/schema/nis.ldif')
enable_schema('/etc/openldap/schema/java.ldif')

