#!/bin/bash

sed -i -e '/\[apache-auth\]/,/^\[/{/enabled\s*=/d;/bantime\s*=/d;/maxretry\s*=/d}' \
       -e '/\[apache-auth\]/a enabled = true\nbantime = 3600\nmaxretry = 5' \
       /etc/fail2ban/jail.local

sed -i -e '/\[roundcube-auth\]/,/^\[/{/enabled\s*=/d;/bantime\s*=/d;/maxretry\s*=/d}' \
       -e '/\[roundcube-auth\]/a enabled = true\nbantime = 3600\nmaxretry = 5' \
       /etc/fail2ban/jail.local

sed -i -e '/\[dovecot\]/,/^\[/{/enabled\s*=/d;/bantime\s*=/d;/maxretry\s*=/d}' \
       -e '/\[dovecot\]/a enabled = true\nbantime = 3600\nmaxretry = 5' \
       /etc/fail2ban/jail.local

sed -i -e '/\[postfix\]/,/^\[/{/enabled\s*=/d;/bantime\s*=/d;/maxretry\s*=/d}' \
       -e '/\[postfix\]/a enabled = true\nbantime = 3600\nmaxretry = 5' \
       /etc/fail2ban/jail.local

