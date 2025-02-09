#!/bin/bash
#
# init.sh
# Copyright (C) 2021 chibashr
#
# Distributed under terms of the MIT license.
# 
# Script to use during init of linux machine

if [[ $EUID -ne 0 ]]
then
  printf 'Must be run as root, exiting!\n'
  exit 1
fi

# Definitions
CCDC_DIR="/ccdc"
CCDC_ETC="$CCDC_DIR/etc"
SCRIPT_DIR="$CCDC_DIR/scripts"

# make directories and set current directory
mkdir -p $CCDC_DIR
mkdir -p $CCDC_ETC
mkdir -p $SCRIPT_DIR
cd $CCDC_DIR

# if prompt <prompt> n; then; <cmds>; fi
# Defaults to NO
# if prompt <prompt> y; then; <cmds>; fi
# Defaults to YES
prompt() {
  case "$2" in 
    y) def="[Y/n]" ;;
    n) def="[y/N]" ;;
    *) echo "INVALID PARAMETER!!!!"; exit ;;
  esac
  read -p "$1 $def" ans
  case $ans in
    y|Y) true ;;
    n|N) false ;;
    *) [[ "$def" != "[y/N]" ]] ;;
  esac
}

# get <file>
# prints the name of the file downloaded
get() {
  # only download if the file doesn't exist
  if [[ ! -f "$SCRIPT_DIR/$1" ]]
  then
    mkdir -p $(dirname "$SCRIPT_DIR/$1") 1>&2
    BASE_URL="https://raw.githubusercontent.com/UWStout-CCDC/CCDC-scripts/master"
    wget --no-check-certificate "$BASE_URL/$1" -O "$SCRIPT_DIR/$1" 1>&2
  fi
  echo "$SCRIPT_DIR/$1"
}

# replace <dir> <file> <new file>
replace() {
  mkdir -p $CCDC_ETC/$(dirname $2)
  cp $1/$2 $CCDC_ETC/$2.old
  mkdir -p $(dirname $1/$2)
  cp $(get $3) $1/$2
}

# Grab script so it's guarnteed to be in /ccdc/scripts/linux
get linux/init.sh

# Grabs monitor.sh script for monitoring log, process, connections, etc
get linux/monitor.sh
get linux/monitor2.sh

bash $(get linux/log_state.sh)
SPLUNK_SCRIPT=$(get linux/splunk-forward.sh)

#gets wanted username
echo "What would you like the admin account to be named?"
read username

PASSWD_SH=$SCRIPT_DIR/linux/passwd.sh
cat <<EOF > $PASSWD_SH
if [[ \$EUID -ne 0 ]]
then
  printf 'Must be run as root, exiting!\n'
  exit 1
fi
EOF

groupadd wheel
groupadd sudo
cp /etc/sudoers $CCDC_ETC/sudoers
cat <<-EOF > /etc/sudoers
# This file MUST be edited with the 'visudo' command as root.
#
# Please consider adding local content in /etc/sudoers.d/ instead of
# directly modifying this file.
#
# See the man page for details on how to write a sudoers file.
Defaults        env_reset
Defaults        mail_badpass
Defaults        secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"

# User privilege specification
root    ALL=(ALL:ALL) ALL
$username ALL=(ALL:ALL) ALL

# Allow members of group sudo to execute any command
%sudo   ALL=(ALL:ALL) ALL
%wheel   ALL=(ALL:ALL) ALL

# See sudoers(5) for more information on "@include" directives:
#@includedir /etc/sudoers.d
EOF

useradd -G wheel,sudo -m -s /bin/bash -U $username

echo "Set $username's password"
passwd $username
echo "Set root password"
passwd root

bash $PASSWD_SH

# Current IP address. We should assume this to be correct
IP_ADDR=$(ip addr show dev eth0 | grep -Po "inet \K172\.\d+\.\d+\.\d+")

if prompt "Is $IP_ADDR the correct IP address?" y
then
  echo "Configuring network interfaces"
else
  read -p "Enter the correct IP address: " IP_ADDR
fi

# Iptables
IPTABLES_SCRIPT="$SCRIPT_DIR/linux/iptables.sh"
cat <<EOF > $IPTABLES_SCRIPT
if [[ \$EUID -ne 0 ]]
then
  printf 'Must be run as root, exiting!\n'
  exit 1
fi

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

# SSH outbound
iptables -A OUTPUT -p tcp --sport 22 -m conntrack --ctstate ESTABLISHED -j ACCEPT

######## OUTBOUND SERVICES ###############

EOF

chmod +x $IPTABLES_SCRIPT

if prompt "HTTP(S) Server?" n
then
  IS_HTTP_SERVER="y"
  cat <<-EOF >> $IPTABLES_SCRIPT
  # HTTP/HTTPS (apache)
  iptables -t filter -A INPUT -p tcp --dport 80 -j ACCEPT
  iptables -t filter -A INPUT -p tcp --dport 443 -j ACCEPT

EOF
  # TODO: add mod_sec and secure apache
fi

if prompt "DNS/NTP Server?" n
then
  IS_DNS_SERVER="y"
  IS_NTP_SERVER="y"
  cat <<-EOF >> $IPTABLES_SCRIPT
  # DNS (bind)
  iptables -t filter -A INPUT -p tcp --dport 53 -j ACCEPT
  iptables -t filter -A INPUT -p udp --dport 53 -j ACCEPT

  # NTP
  iptables -t filter -A INPUT -p tcp --dport 123 -j ACCEPT
  iptables -t filter -A INPUT -p udp --dport 123 -j ACCEPT

EOF
  # TODO: secure bind / named
fi

if prompt "MAIL Server?" n
then
  IS_MAIL_SERVER="y"
  cat <<-EOF >> $IPTABLES_SCRIPT
  # SMTP
  iptables -t filter -A OUTPUT -p tcp --dport 25 -j ACCEPT
  iptables -t filter -A INPUT -p tcp --dport 25 -j ACCEPT

  # POP3
  iptables -t filter -A OUTPUT -p tcp --dport 110 -j ACCEPT
  iptables -t filter -A INPUT -p tcp --dport 110 -j ACCEPT

  # IMAP
  iptables -t filter -A OUTPUT -p tcp --dport 143 -j ACCEPT
  iptables -t filter -A INPUT -p tcp --dport 143 -j ACCEPT

EOF
  # TODO: secure ?
fi

if prompt "Splunk Server?" n
then
  IS_SPLUNK_SERVER="y"
  cat <<-EOF >> $IPTABLES_SCRIPT
  # Splunk Web UI
  iptables -t filter -A INPUT -p tcp --dport 8000 -j ACCEPT
  # Splunk Forwarder
  iptables -t filter -A INPUT -p tcp --dport 8089 -j ACCEPT
  iptables -t filter -A INPUT -p tcp --dport 9997 -j ACCEPT
  # Syslog (PA)
  iptables -t filter -A INPUT -p tcp --dport 514 -j ACCEPT
EOF
fi

bash $IPTABLES_SCRIPT

# Create systemd unit for the firewall
mkdir -p /etc/systemd/system/
cat <<-EOF > /etc/systemd/system/ccdc_firewall.service
[Unit]
Description=ZDSFirewall
After=syslog.target network.target

[Service]
Type=oneshot
ExecStart=$IPTABLES_SCRIPT
ExecStop=/sbin/iptables -F
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Set Legal banners
replace /etc motd general/legal_banner.txt
replace /etc issue general/legal_banner.txt
replace /etc issue.net general/legal_banner.txt

# Set permissions
chown -hR $username:$username $CCDC_DIR
# Fix permissions (just in case)
chown root:root /etc/group
chmod a=r,u=rw /etc/group
chown root:root /etc/sudoers
chmod a=,ug=r /etc/sudoers
chown root:root /etc/passwd
chmod a=r,u=rw /etc/passwd
if [ $(getent group shadow) ]; then
  chown root:shadow /etc/shadow
else
  chown root:root /etc/shadow
fi
chmod a=,u=rw,g=r /etc/shadow


# We might be able to get away with installing systemd on centos 6 to make every server the same

# !! DO LAST !! These will take a while

if type yum
then
  echo 'yum selected, upgrading'
  yum update && yum upgrade -y
  yum install -y ntp ntpdate screen openssh-client netcat aide
elif type apt-get
then
  echo 'apt selected, upgrading'
  apt-get update && apt-get upgrade -y
  apt-get install -y ntp ntpdate screen openssh-client netcat aide
else
Outbound firewall rules
  echo 'No package manager found'
fi

# SSH Server config
replace /etc ssh/sshd_config linux/sshd_config
# Disable all keys - sshd_config will set the server to check this file
mkdir -p /ccdc/ssh/
touch /ccdc/ssh/authorized_keys

if [[ ! -z "$IS_NTP_SERVER" ]] && type systemctl && type apt-get
then
  # TODO: There are multiple ways to do NTP. We need to check what each server uses.
  #server 172.20.240.20
  # timedatectl status
  apt-get install ntp-server
  replace /etc ntp.conf linux/ntp.conf
elif [[ ! -z "$IS_NTP_SERVER" ]]
then
  echo "NTP Servers are only supported on Debian"
else
  cp /etc/ntp.conf $CCDC_ETC/ntp.conf
  echo "
driftfile /var/lib/ntp/npt.drift
logfile /var/log/ntp.log

server 172.20.240.20 iburst

# Set hw clock as low priority
server 127.127.1.0
fudge 127.127.1.0 stratum 10
restrict -4 default kob notrap nomodify nopeer limited noquery noserve
restrict -6 default kob notrap nomodify nopeer limited noquery noserve

restrict 127.0.0.1
restrict ::1

tinker panic 0
tos maxdist 30
" > /etc/ntp.conf
fi

# Restart services
if type systemctl
then
  systemctl restart sshd
  systemctl restart iptables
  # TODO: Verify service name
  systemctl restart ntp
  systemctl enable ntp

  # Disable other firewalls
  # (--now also runs a start/stop with the enable/disable)
  systemctl disable firewalld
  systemctl disable ufw

  # Automatically apply IPTABLES_SCRIPT on boot
  systemctl enable ccdc_firewall.service
  systemctl start ccdc_firewall.service

  # We want to use ntpd?
  systemctl disable systemd-timesyncd.service
  systemctl disable chronyd
else
  echo "!! non systemd systems are not supported !!"
  #exit
  #service sshd restart
  #service iptables restart
  # On non-systemd systems, the firewall will need to be reapplied in another way
fi

# Splunk forwarder
# We need to check to make sure this actually applies... the get sometimes fails
if [[ $IS_SPLUNK_SERVER != "y" ]]
then
  if prompt "Install Splunk Forwarder?" y
  then
    bash $SPLUNK_SCRIPT 172.20.241.20 
  fi
fi

echo "Now restart the machine to guarntee all changes apply"

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
sudo systemctl status fail2ban
sudo systemctl status auditd.service
sudo systemctl status postfix
sudo systemctl status dovecot
echo "FINISHED MAKE SURE YOU REBOOT"
