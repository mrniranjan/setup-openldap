#!/bin/bash 
## This script does what the setup-ds-admin.pl does, It configures the ldap server, we take the "base suffix" as the input 
### and configure openldap for suffix given
### We use an example slapd.conf first 
###probably we might want to check if the openldap-servers packages is available 
### Check if Openldap packages are installed. 
mylog=/tmp/ldapserver-install-log
slapdconfigdir=/etc/openldap/slapd.d/
workingdir="`pwd`"
sampleconfig="$workingdir/sample-slapd.conf"
slaptest=/usr/sbin/slaptest
slapdinit=/etc/init.d/slapd
RETVAL=0
myldif=/tmp/base.ldif
accesslogdir="/var/lib/ldap-accesslog"
suffixbackend="/var/lib/ldap"
ldapadd=/usr/bin/ldapadd

checkpackage()
{
PACKAGELDAP=`rpm -qa | grep openldap-servers 2>&1`
RETVAL=$?
if test $RETVAL == 0; then 
	echo -e "\n$PACKAGELDAP Packages are installed" >> $mylog
else
	echo -e "\nPackage openldap-servers is not installed. Please install openldap-servers package"
	exit 1
fi
}
basicsetupopenldap()
{
if `test -f $sampleconfig`; then
        echo -e "Using $sampleconfig" >> $mylog
else
	echo $?
        echo -e "file $sampleconfig doesnt exist\n"
	exit 1
fi

#create the slapd.d directory first 
if `test -d $slapdconfigdir`; then
	echo "Directory already exists, backup and remove the directory, we are creating fresh instance" >> $mylog
	exit 1
else
	 echo -e "\nCreating /etc/openldap/slapd.d directory with user and group permissions of ldap" >> $mylog
	`mkdir $slapdconfigdir`
	`chown ldap.ldap $slapdconfigdir`
fi
##run slaptest using the sample slapd.conf 
slaptestout=`$slaptest -f $sampleconfig -F $slapdconfigdir`
RETVAL=$?
if [ $RETVAL == 0 ]; then
	`chown ldap.ldap $slapdconfigdir/* -R `
	## start the slapd process now 
	slapdstart=`$slapdinit start`
	slapdstartcheck=$?
	if [ $slapdstartcheck != 0 ]; then 
		echo "slapd did not start"
		exit
	else 
		echo -e "\nslapd service is started with cn=config and cn=monitor database" >> $mylog
	fi
	
else
	echo "There was some problem converting initial configuration to cn=config format" >> $mylog
	exit 1
fi
}
setupbackend()
{
#### Before we continue check if config database is setup properly, we do ldapsearch to "cn=config" , that would require us to know the binddn 
###and bindpw, currently we use "cn=admin,cn=config" with password as "config".
### To-do we ni]]]eed a method to get this info properly 
configout=`ldapsearch -xLLL -b "cn=config" -D "cn=admin,cn=config" -w "config" -h localhost dn | grep -v ^$`
RETVAL=$?
	if [ $RETVAL != 0 ]; then 
		echo -e "\nThere was some problem config database not properly setup" >> $mylog
		exit 1
	fi
#we need the suffix for which we want to setup berkely database 
#to-do , probably it's better we get the choice of backend from user
echo -n "Specify the suffix(default dc=example,dc=org): "
read suffix
	if [ "$suffix" == "" ]; then
		suffix="dc=example,dc=org"
	fi
echo "$suffix" is configured with berkely database >> $mylog
echo -n "Specify the rootbinddn to use (Default:cn=Manager,$suffix): "
read rootbinddn
        if [ "$rootbinddn" == "" ]; then
                rootbinddn="cn=Manager,$suffix"
                echo -e "\nroot binddn used is:$rootbinddn" >> $mylog
        fi
echo -n "Specify the rootbindpw to use (Default: redhat): "
read rootbindpw
        if [ "$rootbindpw" == "" ];then
                rootbindpw="redhat"
                echo -e "\nroot bind password is :$rootbindpw" >> $mylog
        fi
##By default we use /var/lib/ldap as our default directory 
dirtest=`test -d $suffixbackend`
RETVAL=$?
	if  [ $RETVAL != 0 ]; then
		echo -e "\nDirectory doesn't exist, create /var/lib/ldap with user and group permissions as ldap" >> $mylog
		exit 1
	fi
###setup the backend 
### probably insted of doing below can we output this in an ldif file and then add it, does that look clean ?
addbackend=`$ldapadd -x -D "cn=admin,cn=config" -w "config" -h localhost <<EOF 2>> $mylog
dn: olcDatabase=bdb,cn=config
objectClass: olcDatabaseConfig
objectClass: olcBdbConfig
olcDatabase: {1}bdb
olcSuffix: $suffix
olcDbDirectory: $suffixbackend
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

RETVAL=$?
if [ $RETVAL != 0 ]; then
	echo -n "There seems to be some problem creating database check $mylog file for more details"
	echo $addbackend >> $mylog
	exit 1;
fi
}
enablemodules()
{

### we load ppolicy, accesslog, syncprov
### Load the ppolicy.la
ppolicyadd=`$ldapadd -x -D "cn=admin,cn=config" -w "config" -h localhost <<EOF 2>> $mylog
dn: cn=module,cn=config
objectClass: olcModuleList
cn: module
olcModuleLoad: ppolicy.la
EOF`
RETVAL=$?
	if [ $RETVAL == 0 ];then
		echo -e "ppolicy.la module has been added" >> $mylog
	else
		exit 1
	fi
### Load the syncprov module 
syncprovadd=`$ldapadd -x -D "cn=admin,cn=config" -w "config" -h localhost <<EOF 2>> $mylog
dn: cn=module,cn=config
objectClass: olcModuleList
cn: module
olcModuleLoad: syncprov.la
EOF`
RETVAL=$?
        if [ $RETVAL == 0 ];then
                echo -e "syncprov.la module has been added" >> $mylog
        else
                exit 1
	fi
### Load the accesslog module 
accesslogadd=`$ldapadd -x -D "cn=admin,cn=config" -w "config" -h localhost <<EOF 2>> $mylog
dn: cn=module,cn=config
objectClass: olcModuleList
cn: module
olcModuleLoad: accesslog.la
EOF`
RETVAL=$?
        if [ $RETVAL == 0 ];then
                echo -e "accesslog.la module has been added\n" >> $mylog
        else
                exit 1
	fi
}
enabledit()
{
dcobject=`echo $suffix | awk -F "," '{print $1}' | awk -F "=" '{print $2}'`
echo -e "dn: $suffix" >> $myldif
echo -e "objectClass: top" >> $myldif
echo -e "objectClass: domain" >> $myldif
echo -e "dc: $dcobject" >> $myldif
echo -e '\n' >> $myldif
IFS=" "
for i in `cat $workingdir/create_ou.conf`
do
echo -e "dn: ou=$i,$suffix" >> $myldif
echo -e "objectClass: top" >> $myldif
echo -e "objectClass: organizationalUnit" >> $myldif
echo -e "ou: $i" >> $myldif
echo -e '\n' >> $myldif
done
ditadd=`$ldapadd -x -D "$rootbinddn" -w "$rootbindpw" -f $myldif -h localhost` 2>> $mylog
RETVAL=$?
	if [ $RETVAL == 0 ]; then
		echo -e "\nOpenldap is now configured with $suffix"
	else
		echo -e "\nThere was some problem creating basic Directory Information tree check $mylog for more details" 
		exit 1
	fi
rm -f $myldif 
}
setupaccesslog()
{
## create accesslog directory, We use /var/lib/ldap-accesslog

	if `test -d $accesslogdir`; then
        	echo "Directory already exists, backup and remove the directory, we are creating fresh instance" >> $mylog
	        exit 1
	fi

addaccesslogbackend=`/usr/bin/ldapadd -x -D "cn=admin,cn=config" -w "config" -h localhost <<EOF 2>> $mylog
dn: olcDatabase=bdb,cn=config
objectClass: olcDatabaseConfig
objectClass: olcBdbConfig
olcDatabase: {2}bdb
olcDbDirectory: /var/lib/ldap-accesslog
olcSuffix: cn=accesslog
olcAccess: {0}to * by dn.base="cn=replicator,ou=Admins,dc=example,dc=org" read   by * break
olcLimits: {0}dn.exact="cn=accesslog" time.soft=unlimited time.hard=unlimited size.soft=unlimited size.hard=unlimited
olcLimits: {1}dn.exact="cn=replicator,ou=Admins,dc=example,dc=org" time.soft=unlimited time.hard=unlimited size.soft=unlimited size.hard=unlimited
olcRootDN: cn=accesslog
olcRootPW: redhat
olcDbCacheSize: 1000
olcDbCheckpoint: 1024 10
olcDbIDLcacheSize: 3000
olcDbIndex: default eq
olcDbIndex: reqEnd eq
olcDbIndex: reqResult eq
olcDbIndex: reqStart eq
olcDbIndex: objectClass eq
olcDbIndex: entryCSN pres,eq
EOF`

}
RETVAL=0
## We are called as:

case "$1" in 
	--master)
		checkpackage
		basicsetupopenldap
		setupbackend
		enablemodules
		enabledit
		;;
	usage)
		echo $"Usage: $0 {--master}"
                RETVAL=0
                ;;
	*)	
		echo $"Usage: $0 {--master}"
		RETVAL=2
esac
