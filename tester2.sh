#!/bin/bash
yum install -y fail2ban
touch /root/Downloads/fail2ban.log
for jail in dovecot postfix apache-auth roundcube-auth
do
sed -i "/^\s*\[$jail\]/,/^\[/{/logpath\s*=/d;/enabled\s*=/d;/bantime\s*=/d;/maxretry\s*=/d}" /etc/fail2ban/jail.local
sed -i "/\[$jail\]/a enabled = true\nbantime = 1800\nmaxretry = 5\nlogpath = /root/Downloads/fail2ban.log" /etc/fail2ban/jail.local
done
systemctl enable fail2ban
systemctl start fail2ban
sudo fail2ban-client status
