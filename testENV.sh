#!/bin/bash
sed -i '/^\[apache-auth\]/,/^$/s/^bantime.*/bantime = 3600/' /etc/fail2ban/jail.local
sed -i '/^\[apache-auth\]/,/^$/s/^maxretry.*/maxretry = 5/' /etc/fail2ban/jail.local
sed -i '/^\[apache-auth\]/,/^$/s|^logpath.*|logpath = /var/log/fail2banlog|' /etc/fail2ban/jail.local

