#!/bin/bash

#FIREWALL

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
#Remove Stuff I Dont like
yum remove xinetd telnet-server rsh-server telnet rsh ypbind ypserv tftp-server cronie-anacron bind vsftpd squid net-snmpd -y
systemctl disable xinetd
systemctl disable rexec
systemctl disable rsh
systemctl disable rlogin
systemctl disable ypbind
systemctl disable tftp
systemctl disable certmonger
systemctl disable cgconfig
systemctl disable cgred
systemctl disable cpuspeed
systemctl enable irqbalance
systemctl disable kdump
systemctl disable mdmonitor
systemctl disable messagebus
systemctl disable netconsole
systemctl disable ntpdate
systemctl disable oddjobd
systemctl disable portreserve
systemctl enable psacct
systemctl disable qpidd
systemctl disable quota_nld
systemctl disable rdisc
systemctl disable rhnsd
systemctl disable rhsmcertd
systemctl disable saslauthd
systemctl disable smartd
systemctl disable sysstat
systemctl enable crond
systemctl disable atd
systemctl disable nfslock
systemctl disable named
systemctl disable dovecot
systemctl disable squid
systemctl disable snmpd
systemctl disable postfix

# Disable rpc
systemctl disable rpcgssd
systemctl disable rpcsvcgssd
systemctl disable rpcidmapd

# Disable Network File Systems (netfs)
systemctl disable netfs

# Disable Network File System (nfs)
systemctl disable nfs

# Disable core dumps for users
echo -e "\e[33mDisabling core dumps for users\e[0m"
echo "* hard core 0" >> /etc/security/limits.conf
sleep 5
# Secure sysctl.conf
echo -e "\e[33mSecuring sysctl.conf\e[0m"
cat <<-EOF >> /etc/sysctl.conf
fs.suid_dumpable = 0
kernel.exec_shield = 1
kernel.randomize_va_space = 2
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.tcp_max_syn_backlog = 1280
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_timestamps = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.default.log_martians = 1
net.core.bpf_jit_harden = 2
kernel.sysrq = 0
kernel.perf_event_paranoid = 3
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.yama.ptrace_scope = 3
EOF
sleep 5




####################################################################
# Update system
echo "Updating and upgrading system packages..."
#yum update -y && yum upgrade -y
# Enable and start Dovecot and Postfix
echo "Enabling and starting Dovecot and Postfix..."
systemctl enable dovecot
systemctl enable postfix
systemctl start dovecot
systemctl start postfix
#############
#DOVECOT WORK
#############
sed -i 's|#disable_plaintext_auth = yes|disable_plaintext_auth = yes|' /etc/dovecot/conf.d/10-auth.conf
sed -i 's|#auth_verbose = no|auth_verbose = yes|' /etc/dovecot/conf.d/10-logging.conf
sudo systemctl restart dovecot


# Install fail2ban
echo "Installing fail2ban..."
yum install -y fail2ban
# Create fail2ban log file
echo "Creating fail2ban log file..."
touch /var/log/fail2banlog
# Backup and configure fail2ban
echo "Configuring fail2ban..."
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
# Putting in the contents to the jail file
sed -i '/\[dovecot\]/a enabled = true\nmaxretry = 5\nbantime = 3600' /etc/fail2ban/jail.local
sed -i 's|logpath = %(dovecot_log)s|logpath = /var/log/fail2banlog|g' /etc/fail2ban/jail.local
# Restart fail2ban service
echo "Restarting fail2ban service..."
systemctl enable fail2ban
systemctl restart fail2ban
#THIS IS THE SECOND HALF FOR MONITORING
# Update and install necessary packages
echo "Installing required packages..."
sudo yum install -y aide rkhunter clamav clamd clamav-update
# Download and set up monitoring script
echo "Downloading monitoring script..."
sudo wget https://raw.githubusercontent.com/UWStout-CCDC/kronos/master/Linux/General/monitor.sh
# Enable and start auditd
echo "Configuring auditd..."
sudo systemctl enable auditd
sudo systemctl start auditd
# Download audit rules and apply them
echo "Setting up audit rules..."
sudo wget https://raw.githubusercontent.com/Neo23x0/auditd/refs/heads/master/audit.rules
sudo rm /etc/audit/rules.d/audit.rules
sudo mv audit.rules /etc/audit/rules.d/
sudo auditctl -R /etc/audit/rules.d/audit.rules
# Configure ClamAV
echo "Configuring ClamAV..."
sudo sed -i '8s/^/#/' /etc/freshclam.conf
sudo freshclam
# Create DIFFING directory
echo "Creating DIFFING directory..."
sudo mkdir DIFFING
# Generate baseline system information
echo "Generating baseline data..."
sudo lsof -i -n | grep "LISTEN" > DIFFING/portdiffingBASELINE.txt
sudo ss -t state established > DIFFING/connectiondiffingBASELINE.txt
sudo cat /root/.bashrc > DIFFING/alias_diffingBASELINE.txt
sudo find / -type f -executable 2>/dev/null > DIFFING/executables_diffingBASELINE.txt
for user in $(cut -f1 -d: /etc/passwd); do crontab -u $user -l 2>/dev/null; done > DIFFING/cron_diffingBASELINE.txt
sudo cat /etc/shadow > DIFFING/users_diffingBASELINE.txt
# Create hidden directory for compressed files
echo "Creating hidden directory..."
sudo mkdir /lib/.tarkov
# Archive and store system files
echo "Compressing and storing system files individually..."
sudo tar -czf /lib/.tarkov/shadow_backup.tar.gz /etc/shadow
sudo tar -czf /lib/.tarkov/passwd_backup.tar.gz /etc/passwd
sudo tar -czf /lib/.tarkov/fail2ban_backup.tar.gz /etc/fail2ban/
sudo tar -czf /lib/.tarkov/hosts_backup.tar.gz /etc/hosts
sudo tar -czf /lib/.tarkov/log_backup.tar.gz /var/log
sudo tar -czf /lib/.tarkov/mail_backup.tar.gz /var/mail
sudo tar -czf /lib/.tarkov/postfix_spool_backup.tar.gz /var/spool/postfix/
sudo tar -czf /lib/.tarkov/postfix_backup.tar.gz /etc/postfix/
sudo tar -czf /lib/.tarkov/dovecot_backup.tar.gz /etc/dovecot
#Remove Compilers
sudo yum remove libgcc -y
if grep -q "udp6" /etc/netconfig
then
    echo "Support for RPC IPv6 already disabled"
else
    echo "Disabling Support for RPC IPv6..."
    sed -i 's/udp6       tpi_clts      v     inet6    udp     -       -/#udp6       tpi_clts      v     inet6    udp     -       -/g' /etc/netconfig
    sed -i 's/tcp6       tpi_cots_ord  v     inet6    tcp     -       -/#tcp6       tpi_cots_ord  v     inet6    tcp     -       -/g' /etc/netconfig
fi
# Only allow root login from console
echo "tty1" > /etc/securetty
chmod 700 /root
echo "DONE"
# Secure cron
echo "Locking down Cron"
touch /etc/cron.allow
chmod 600 /etc/cron.allow
awk -F: '{print $1}' /etc/passwd | grep -v root > /etc/cron.deny
echo "Locking down AT"
touch /etc/at.allow
chmod 600 /etc/at.allow
awk -F: '{print $1}' /etc/passwd | grep -v root > /etc/at.deny
chmod 600 /etc/cron.deny
chmod 600 /etc/at.deny
chmod 600 /etc/crontab
# DENY ALL TCP WRAPPERS
echo "ALL:ALL" > /etc/hosts.deny
#BULK REMOVE SERVICES
yum remove xinetd telnet-server rsh-server telnet rsh ypbind ypserv tftp-server cronie-anacron bind vsftpd squid net-snmpd vim httpd-manual -y
# Disable rpc
systemctl disable rpcgssd
systemctl disable rpcsvcgssd
systemctl disable rpcidmapd
# Disable Network File Systems (netfs)
systemctl disable netfs
# Disable Network File System (nfs)
systemctl disable nfs
sudo yum install lynis -y
sudo auditctl -R /etc/audit/rules.d/audit.rules
sudo yum install ntpdate -y
ntpdate pool.ntp.org
sudo auditctl -R /etc/audit/rules.d/audit.rules
#EXPIREMENTAL/////////////////////////////////////////////////////////////////////////////
echo "FINISHED MAKE SURE YOU REBOOT"
