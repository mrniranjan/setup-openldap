#!/bin/bash 
## This script does what the setup-ds-admin.pl does, It configures the ldap server, we take the "base suffix" as the input 
### and configure openldap for suffix given
### We use an example slapd.conf first 
###probably we might want to check if the openldap-servers packages is available 
### Check if Openldap packages are installed. 
checkpackage()
{
PACKAGELDAP=`rpm -qa | grep openldap-servers 2>&1`
CHECKPACKAGE=$?
if test $CHECKPACKAGE == 0; then 
	echo -e "Openldap-servers Package is installed\n"
else
	echo -e "Package Openldap-servers is not installed"
fi
}
basicsetupopenldap()
{

MYPWD=`pwd`
if `test -f $MYPWD/sample-slapd.conf`; then
        echo -e "file exists"
else
	echo $?
        echo -e "file doesnt exist\n"
	exit 4
fi

#create the slapd.d directory first 
if `test -d /etc/openldap/slapd.d`; then
	echo "Directory already exists, backup and remove the directory, we are creating fresh instance"
	exit 1
else
	`mkdir /etc/openldap/slapd.d`
	`chown ldap.ldap /etc/openldap/slapd.d`
fi
##run slaptest using the sample slapd.conf 
slaptestout=`slaptest -f $MYPWD/sample-slapd.conf -F /etc/openldap/slapd.d`
checkslaptestout=$?
if [ $checkslaptestout == 0 ]; then
	`chown ldap.ldap /etc/openldap/slapd.d/* -R `
	## start the slapd process now 
	slapdstart=`/etc/init.d/slapd start`
	slapdstartcheck=$?
	if [ $slapdstartcheck != 0 ]; then 
		echo "slapd did not start"
		exit
	fi
	
else
	echo "There was some problem"
	exit 1
fi
}
setupbackend()
{
#### Before we continue check if config database is setup properly, we do ldapsearch to "cn=config" , that would require us to know the binddn 
###and bindpw, currently we use "cn=admin,cn=config" with password as "config".
### To-do we need a method to get this info properly 
configout=`ldapsearch -xLLL -b "cn=config" -D "cn=admin,cn=config" -w "config" -h localhost dn | grep -v ^$`
configresult=$?
	if [ $configresult != 0 ]; then 
		echo "There was some problem config database not properly setup"
		exit 1
	fi
#we need the suffix for which we want to setup berkely database 
#to-do , probably it's better we get the choice of backend from user
echo -n "Specify the suffix: "
read suffix 
echo $suffix
echo -n "Specify the rootbinddn to use (Default:cn=Manager,$suffix): "
read rootbinddn
echo -n "Specify the rootbindpw to use (Default: redhat): "
read rootbindpw
##By default we use /var/lib/ldap as our default directory 
dirtest=`test -d /var/lib/ldap`
dirtestout=$?
	if  [ $dirtestout != 0 ]; then
		echo -n "Directory doesn't exist, create /var/lib/ldap with user and group permissions as ldap"
		exit 1
	fi
###setup the backend 

addbackend=`/usr/bin/ldapadd -x -D "cn=admin,cn=config" -w "config" -h localhost <<EOF 2>> /tmp/ldapserverlog
dn: olcDatabase=bdb,cn=config
objectClass: olcDatabaseConfig
objectClass: olcBdbConfig
olcDatabase: {1}bdb
olcSuffix: $suffix
olcDbDirectory: /var/lib/ldap
olcRootDN: $rootbinddn
olcRootPW: $rootbindpw
olcDbCacheSize: 1000
olcDbCheckpoint: 1024 10
olcDbIDLcacheSize: 3000
olcDbConfig: set_cachesize 0 10485760 0
olcDbConfig: set_lg_bsize 2097152
olcLimits: dn.exact="$rootbinddn" time.soft=unlimited time.hard=unlimited size.soft=unlimited size.hard=unlimited
olcDbIndex: uid pres,eq
olcDbIndex: cn,sn,displayName pres,eq,approx,sub
olcDbIndex: uidNumber,gidNumber eq
olcDbIndex: memberUid eq
olcDbIndex: objectClass eq
olcDbIndex: entryUUID pres,eq
olcDbIndex: entryCSN pres,eq
olcAccess: to attrs=userPassword by self write by anonymous auth by dn.children="ou=admins,dc=example,dc=com" write  by * none
olcAccess: to * by self write by dn.children="ou=admins,dc=example,dc=com" write by * read
EOF`

ldapout=$?
if [ $ldapout != 0 ]; then
	echo -n "There seems to be some problem"
	echo -n "Check the below errors:\n"
	echo $addbackend
	exit 1;
fi
}
#checkpackage
#basicsetupopenldap
setupbackend
