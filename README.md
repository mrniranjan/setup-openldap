Info 
====
setup-ldap.sh is a shell script which configures OpenLDAP server on Red Hat Enterprise Linux 6.3. 
setup-ldap.sh has 2 options currently to setup as Master (provider) or consumer (slave). 

This script uses a sample slapd.conf (sample-slapd.conf) which is converted to cn=config format. 

Script uses "cn=config" feature provided with OpenLDAP 2.4 to setup an suffix through LDAP operations. It currently 
Configures the following the following

1. Creates a bdb backend for a suffix
2. Configures TLS when certs are provided
3. Enables ppolicy.la,syncprov.la,accesslog.la modules on Master
4. Configures accesslog (cn=accesslog) on Provider to save all the changes that will be replicated on slave
5. When script is run with --slave option it also configures syncreplication agreement with provider server. 


Future Work(Roadmap)
====================
In future versions, I would like to add the following:

1. Configure a samba PDC 
2. Congigure a Samba BDC 
3. Provide scripts to add dhcp,dns,kerberos schema to OpenLDAP, and provide command line utilities to Configure zones which will be saved in 
OpenLDAP 
4. Provide scripts to Integrate kerberos,dns,dhcp to act as an Identity Server. 

Steps to run the script 
========================
1. Get the latest code from github
git clone git@github.com/mrniranjan/setup-openldap.git

2. The following files will be copied 

common.sh  
create_ou.conf  
defines.sh  
README  
sample-slapd.conf  
setup-ldap.sh  
TODO

3.Make sure openldap-servers package  is installed on RHEL

4.Run the script as:
./setup-ldap.sh --master (To configure provider)
./setup-ldap.sh --slave (To configure consumer)

5. when run as ./setup-ldap.sh --master configure cn=config database, suffix (as provided by user) with bdb 
backend . This backend uses /var/lib/ldap , and also sets up cn=accesslog suffix which uses /var/lib/ldap-accesslog directory 

6.When run as ./setup-ldap.sh --slave configures cn=config database, suffix (as provided by user) with bdb
backend . This backend uses /var/lib/ldap , and also sets up syncreplication agreement with provider. 

7. This script also configure TLS/SSL for slapd when certificate paths are provided


