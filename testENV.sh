sudo systemctl enable firewalld
sudo systemctl start firewalld

#!/bin/bash

# Reset all Firewalld rules
sudo firewall-cmd --permanent --reset
sudo firewall-cmd --reload

# Set default policy to block all incoming and forwarded packets
sudo firewall-cmd --set-default-zone=drop

# Drop all outgoing packets by default (if needed)
sudo firewall-cmd --direct --add-rule ipv4 filter OUTPUT 0 -j DROP

# Allow already established and related connections
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" connection state="RELATED,ESTABLISHED" accept'

# Allow all loopback traffic
sudo firewall-cmd --permanent --add-interface=lo
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="127.0.0.1" accept'

# Allow ICMP (Ping)
sudo firewall-cmd --permanent --add-icmp-block-inversion
sudo firewall-cmd --permanent --add-icmp-block=echo-reply

# Allow DNS (Required for updates and curl - TCP & UDP on port 53)
sudo firewall-cmd --permanent --add-port=53/tcp
sudo firewall-cmd --permanent --add-port=53/udp

# Allow HTTP and HTTPS traffic
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https

# Allow NTP (Network Time Protocol - Syncs server time)
sudo firewall-cmd --permanent --add-service=ntp

# Allow Splunk traffic (Ports 8000, 8089, 9997)
sudo firewall-cmd --permanent --add-port=8000/tcp
sudo firewall-cmd --permanent --add-port=8089/tcp
sudo firewall-cmd --permanent --add-port=9997/tcp

# Allow SMTP (Mail - Port 25)
sudo firewall-cmd --permanent --add-service=smtp

# Allow POP3 (Mail retrieval - Port 110)
sudo firewall-cmd --permanent --add-service=pop3

# Allow IMAP (Mail retrieval - Port 143)
sudo firewall-cmd --permanent --add-service=imap

# Reload Firewalld to apply all changes
sudo firewall-cmd --reload

# Restart service
sudo systemctl restart firewalld

# Display the active Firewalld configuration
sudo firewall-cmd --list-all


