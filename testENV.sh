#!/bin/bash
sed -i '/\[dovecot\]/a enabled = true\nmaxretry = 5\nbantime = 3600' /etc/fail2ban/jail.local
#FOR THE COMPETITION
# Apache Stuff
echo "Making an Apache jail..."
sed -i '/\[apache-auth\]/a enabled = true\nmaxretry = 5\nbantime = 3600' /etc/fail2ban/jail.local
# Roundcube Stuff
echo "Making an Roundcube jail..."
sed -i '/\[roundcube-auth\]/a enabled = true\nmaxretry = 5\nbantime = 3600' /etc/fail2ban/jail.local

