#!/bin/bash
yum install -y fail2ban
touch /root/Downloads/fail2ban.log
sed -i '/^\s*\[dovecot\]/,/^\[/{/logpath\s*=/d;/enabled\s*=/d;/bantime\s*=/d;/maxretry\s*=/d}' /etc/fail2ban/jail.conf
sed -i '/\[dovecot\]/a enabled = true\nbantime = 1800\nmaxretry = 5\nlogpath = /root/Downloads/fail2ban.log' /etc/fail2ban/jail.conf
sed -i '/^\s*\[postfix\]/,/^\[/{/logpath\s*=/d;/enabled\s*=/d;/bantime\s*=/d;/maxretry\s*=/d}' /etc/fail2ban/jail.conf
sed -i '/\[postfix\]/a enabled = true\nbantime = 1800\nmaxretry = 5\nlogpath = /root/Downloads/fail2ban.log' /etc/fail2ban/jail.conf
sed -i '/^\s*\[apache-auth\]/,/^\[/{/logpath\s*=/d;/enabled\s*=/d;/bantime\s*=/d;/maxretry\s*=/d}' /etc/fail2ban/jail.conf
sed -i '/\[apache-auth\]/a enabled = true\nbantime = 1800\nmaxretry = 5\nlogpath = /root/Downloads/fail2ban.log' /etc/fail2ban/jail.conf
sed -i '/^\s*\[roundcube-auth\]/,/^\[/{/logpath\s*=/d;/enabled\s*=/d;/bantime\s*=/d;/maxretry\s*=/d}' /etc/fail2ban/jail.conf
sed -i '/\[roundcube-auth\]/a enabled = true\nbantime = 1800\nmaxretry = 5\nlogpath = /root/Downloads/fail2ban.log' /etc/fail2ban/jail.conf
systemctl enable fail2ban
systemctl start fail2ban
