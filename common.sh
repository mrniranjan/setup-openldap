welcome="\nThis program will set up the OpenLDAP Server\nThis program should be run as "root" user to setup the software\n\nThis script set's up the following:\n* Create a bdb backend for a given suffix\n* Configure SSL/TLS\n* Configure accesslog overlay for Delta Sync Replication\n* Adds sample entries in ldap\n* Adds ppolicy.la, syncprov.la\nTo accept the default shown in brackets, press the Enter key."

breakline="\n============================================================================================================================"

configdb="\nWe first setup Config database, where all the configuration information is stored\n"

configdbadmin="\nConfig Database admin user, who will have all the rights will be referred to as Configuration manager\nand has a Distinguished Name (DN) of "cn=admin,cn=config"\n"

confsuffix="\nThe suffix is the main root of your Directory Information Tree. Suffix must be a valid DN.\nRecommended values are "dc=example,dc=com","o=example".This script uses "dc=example,dc=org" as the default suffix.\nThis suffix will be configured using berkely db (bdb) backend"
suffixadmin="\nThe suffix configured earlier requires Administrator referred to as rootdn, This user is the root user of your DIT and has all the privileges.\nThis user should have a Distinguished Name(DN). Example:cn=Manager,dc=example,dc=com\n"
accesslogdb="\nWe configure berkely db backend for Accesslog. This database records all the changes on the master \nand make them available for Consumer(slave) to access the changes using delta sync replication.\nRootDN for accesslog database is "cn=accesslog".Directory where bdb files for accesslog is /var/lib/ldap-accesslog"
tlssetup="\nOpenLDAP is configured with TLS/SSL to provide integrity and confidentiality protections.\nProvide the Path where CA certificate, Server Cert and Private Key file are stored"
successprovider="\nOpenLDAP has successfully configured as Provider\n.Exiting . . .\n.Log file is '/tmp/ldap-server-install.log'"

