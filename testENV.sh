#!/bin/bash
sudo yum install iptables-services -y
sudo systemctl stop firewalld
sudo systemctl disable firewalld
sudo systemctl enable iptables
sudo systemctl start iptables
# Empty all rules
iptables -t filter -F
iptables -t filter -X
# Block everything by default
iptables -t filter -P INPUT DROP
iptables -t filter -P FORWARD DROP
iptables -t filter -P OUTPUT DROP
# Authorize already established connections
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -t filter -A INPUT -i lo -j ACCEPT
iptables -t filter -A OUTPUT -o lo -j ACCEPT
# ICMP (Ping)
iptables -t filter -A INPUT -p icmp -j ACCEPT
iptables -t filter -A OUTPUT -p icmp -j ACCEPT
# DNS (Needed for curl, and updates)
iptables -t filter -A OUTPUT -p tcp --dport 53 -j ACCEPT
iptables -t filter -A OUTPUT -p udp --dport 53 -j ACCEPT
# HTTP/HTTPS
iptables -t filter -A OUTPUT -p tcp --dport 80 -j ACCEPT
iptables -t filter -A OUTPUT -p tcp --dport 443 -j ACCEPT
# NTP (server time)
iptables -t filter -A OUTPUT -p udp --dport 123 -j ACCEPT
# Splunk
iptables -t filter -A OUTPUT -p tcp --dport 8000 -j ACCEPT
iptables -t filter -A OUTPUT -p tcp --dport 8089 -j ACCEPT
iptables -t filter -A OUTPUT -p tcp --dport 9997 -j ACCEPT
# SMTP
iptables -t filter -A OUTPUT -p tcp --dport 25 -j ACCEPT
iptables -t filter -A INPUT -p tcp --dport 25 -j ACCEPT
# POP3
iptables -t filter -A OUTPUT -p tcp --dport 110 -j ACCEPT
iptables -t filter -A INPUT -p tcp --dport 110 -j ACCEPT
# IMAP
iptables -t filter -A OUTPUT -p tcp --dport 143 -j ACCEPT
iptables -t filter -A INPUT -p tcp --dport 143 -j ACCEPT
