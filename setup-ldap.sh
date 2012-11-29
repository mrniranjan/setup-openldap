#!/bin/bash 
## This script does what the setup-ds-admin.pl does, It configures the ldap server, we take the "base suffix" as the input 
### and configure openldap for suffix given
### We use an example slapd.conf first 
###probably we might want to check if the openldap-servers packages is available 
### Check if Openldap packages are installed. 
mylog=/tmp/ldapserver-install-log
checkpackage()
{
PACKAGELDAP=`rpm -qa | grep openldap-servers 2>&1`
CHECKPACKAGE=$?
if test $CHECKPACKAGE == 0; then 
	echo -e "Openldap-servers Package is installed\n" >> $mylog
else
	echo -e "Package openldap-servers is not installed. Please install openldap-servers package"
	exit 1
fi
}
basicsetupopenldap()
{

MYPWD=`pwd`
if `test -f $MYPWD/sample-slapd.conf`; then
        echo -e "Using $MYPWD/sample-slapd.conf" >> $mylog
else
	echo $?
        echo -e "file $MYPWD/sample-slapd.conf doesnt exist\n"
	exit 4
fi

#create the slapd.d directory first 
if `test -d /etc/openldap/slapd.d`; then
	echo "Directory already exists, backup and remove the directory, we are creating fresh instance" >> $mylog
	exit 1
else
	 echo -e "\nCreating /etc/openldap/slapd.d directory with user and group permissions of ldap" >> $mylog
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
### To-do we need a method to get this info properly 
configout=`ldapsearch -xLLL -b "cn=config" -D "cn=admin,cn=config" -w "config" -h localhost dn | grep -v ^$`
configresult=$?
	if [ $configresult != 0 ]; then 
		echo -e "\nThere was some problem config database not properly setup" >> $mylog
		exit 1
	fi
#we need the suffix for which we want to setup berkely database 
#to-do , probably it's better we get the choice of backend from user
echo -n "Specify the suffix: "
read suffix 
echo "$suffix" is configured with berkely database >> $mylog
echo -n "Specify the rootbinddn to use (Default:cn=Manager,$suffix): "
read rootbinddn
echo -n "Specify the rootbindpw to use (Default: redhat): "
read rootbindpw
##By default we use /var/lib/ldap as our default directory 
dirtest=`test -d /var/lib/ldap`
dirtestout=$?
	if  [ $dirtestout != 0 ]; then
		echo -e "\nDirectory doesn't exist, create /var/lib/ldap with user and group permissions as ldap" >> $mylog
		exit 1
	fi
###setup the backend 
### probably insted of doing below can we output this in an ldif file and then add it, does that look clean ?
addbackend=`/usr/bin/ldapadd -x -D "cn=admin,cn=config" -w "config" -h localhost <<EOF 2>> $mylog
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
	echo -n "There seems to be some problem creating database check $mylog file for more details"
	echo $addbackend >> $mylog
	exit 1;
fi
}
enablemodules()
{

### we load ppolicy, accesslog, syncprov
### Load the ppolicy.la
ppolicyadd=`/usr/bin/ldapadd -x -D "cn=admin,cn=config" -w "config" -h localhost <<EOF 2>> $mylog
dn: cn=module,cn=config
objectClass: olcModuleList
cn: module
olcModuleLoad: ppolicy.la
EOF`
ppolicyaddtest=$?
	if [ $ppolicyaddtest == 0 ];then
		echo -e "ppolicy.la module has been added" >> $mylog
	else
		exit 1
	fi
### Load the syncprov module 
syncprovadd=`/usr/bin/ldapadd -x -D "cn=admin,cn=config" -w "config" -h localhost <<EOF 2>> $mylog
dn: cn=module,cn=config
objectClass: olcModuleList
cn: module
olcModuleLoad: syncprov.la
EOF`
syncprovaddtest=$?
        if [ $syncprovaddtest == 0 ];then
                echo -e "syncprov.la module has been added" >> $mylog
        else
                exit 1
	fi
### Load the accesslog module 
accesslogadd=`/usr/bin/ldapadd -x -D "cn=admin,cn=config" -w "config" -h localhost <<EOF 2>> $mylog
dn: cn=module,cn=config
objectClass: olcModuleList
cn: module
olcModuleLoad: accesslog.la
EOF`
accesslogaddtest=$?
        if [ $accesslogaddtest == 0 ];then
                echo -e "accesslog.la module has been added\n" >> $mylog
        else
                exit 1
	fi
}
enabledit()
{
myldif=/tmp/base.ldif
dcobject=`echo $suffix | awk -F "," '{print $1}' | awk -F "=" '{print $2}'`
echo -e "dn: $suffix" >> $myldif
echo -e "objectClass: top" >> $myldif
echo -e "objectClass: domain" >> $myldif
echo -e "dc: $dcobject" >> $myldif
echo -e '\n' >> $myldif

IFS=" "
for i in `cat $MYPWD/create_ou.conf`
do
echo -e "dn: ou=$i,$suffix" >> $myldif
echo -e "objectClass: top" >> $myldif
echo -e "objectClass: organizationalUnit" >> $myldif
echo -e "ou: $i" >> $myldif
echo -e '\n' >> $myldif
done
ditadd=`/usr/bin/ldapadd -x -D "$rootbinddn" -w "$rootbindpw" -f $myldif -h localhost` 2>> $mylog
ditaddtest=$?
	if [ $ditaddtest == 0 ]; then
		echo -e "\nOpenldap is now configured with $suffix"
	else
		echo -e "\nThere was some problem creating basic Directory Information tree check $mylog for more details" 
		exit 1
	fi
rm -f $myldif 
}
checkpackage
basicsetupopenldap
setupbackend
enablemodules
enabledit
