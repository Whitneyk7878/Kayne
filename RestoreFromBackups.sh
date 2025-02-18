#!/bin/bash

mkdir -p /root/restore_tmp
tar -xzf mailserver_backup_20250217_123000.tar.gz -C /root/restore_tmp

# Un-comment the ones you need
#cp -R /root/restore_tmp/etc/postfix /etc/
#cp -R /root/restore_tmp/etc/dovecot /etc/
#cp -R /root/restore_tmp/etc/roundcubemail /etc/
#cp -R /root/restore_tmp/var/mail /var/
#cp /root/restore_tmp/etc/aliases /etc/
#cp /root/restore_tmp/etc/aliases.db /etc/
#cp -R /root/restore_tmp/etc/httpd/conf /etc/httpd/
#cp -R /root/restore_tmp/etc/httpd/conf.d /etc/httpd/
#cp -R /root/restore_tmp/etc/pki/tls /etc/pki/
