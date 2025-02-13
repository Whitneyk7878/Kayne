#!/bin/bash
sed -i '/\[dovecot\]/a enabled = true\nmaxretry = 5\nbantime = 3600' /etc/fail2ban/jail.local
sed -i 's|logpath = %(dovecot_log)s|logpath = /var/log/fail2banlog|g' /etc/fail2ban/jail.local
#FOR THE COMPETITION
# Apache Stuff
echo "Making an Apache jail..."
sed -i '/\[apache-auth\]/a enabled = true\nmaxretry = 5\nbantime = 3600' /etc/fail2ban/jail.local
sed -i 's|logpath = %(apache_error_log)s|logpath = /var/log/fail2banlog|g' /etc/fail2ban/jail.local

