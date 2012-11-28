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
setupopenldap()
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
checkpackage
setupopenldap
