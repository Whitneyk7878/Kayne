#!/bin/bash

sed -i '/\[apache-auth\]/,/^\[/{/enabled\s*=/d;/bantime\s*=/d;/maxretry\s*=/d};/\[apache-auth\]/a enabled = true\nbantime = 3600\nmaxretry = 5' /etc/fail2ban/jail.local

sed -i '/\[roundcube-auth\]/,/^\[/{/enabled\s*=/d};/\[roundcube-auth\]/a enabled = true' /etc/fail2ban/jail.local

sed -i '/\[dovecot\]/,/^\[/{/enabled\s*=/d;/bantime\s*=/d;/maxretry\s*=/d};/\[dovecot\]/a enabled = true\nbantime = 3600\nmaxretry = 5' /etc/fail2ban/jail.local

sed -i '/\[postfix\]/,/^\[/{/enabled\s*=/d;/bantime\s*=/d;/maxretry\s*=/d};/\[postfix\]/a enabled = true\nbantime = 3600\nmaxretry = 5' /etc/fail2ban/jail.local
