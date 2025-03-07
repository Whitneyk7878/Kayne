#!/bin/bash
# ============================================================
#   Fancy Progress Bar (Constantly at the Bottom)
# ============================================================
# Total number of major steps in the script.
total_steps=26
# Global progress counter (updated in each section).
current_step=0

# Function that continuously draws the progress bar at the bottom.
display_progress_bar() {
  while true; do
    # Save current cursor position.
    tput sc
    # Move cursor to the bottom line (last row, column 0).
    tput cup $(($(tput lines) - 1)) 0
    # Calculate progress values.
    bar_length=40
    percent=$(( current_step * 100 / total_steps ))
    filled=$(( current_step * bar_length / total_steps ))
    unfilled=$(( bar_length - filled ))
    filled_bar=$(printf "%0.s█" $(seq 1 $filled))
    unfilled_bar=$(printf "%0.s░" $(seq 1 $unfilled))
    # Clear the line and print the progress bar.
    printf "\033[2K\033[1;36mProgress: [\033[1;32m%s\033[0m\033[1;31m%s\033[0m\033[1;36m] %3d%%\033[0m" "$filled_bar" "$unfilled_bar" "$percent"
    # Restore original cursor position.
    tput rc
    sleep 0.1
  done
}

# Start the progress bar in the background.
display_progress_bar &
progress_pid=$!

# ============================================================
#  (Your Script Starts Below)
# ============================================================

echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo -e "\e[38;5;46m             General Security Measures                \e[0m"
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
sleep 1
# Only allow root login from console
echo "tty1" > /etc/securetty
chmod 700 /root
echo "DONE"

# DENY ALL TCP WRAPPERS
echo "ALL:ALL" > /etc/hosts.deny

echo "Removing all users from the wheel group except root..."
wheel_users=$(grep '^wheel:' /etc/group | cut -d: -f4 | tr ',' '\n')
for user in $wheel_users; do
    if [[ "$user" != "root" ]]; then
        echo "Removing $user from wheel group..."
        gpasswd -d "$user" wheel
    fi
done

echo "Cleanup complete. Only root has sudo permissions now."
current_step=$(( current_step + 1 ))

# ------------------------------------------------------------
# Restricting permissions: Only root will have full privileges.
# ------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    kill $progress_pid
    exit 1
fi

echo "Restricting permissions: Only root will have full privileges."
for user in $(getent passwd | awk -F: '$3 >= 1000 {print $1}'); do
    if [[ "$user" != "root" ]]; then
        echo "Modifying permissions for user: $user"
        chmod -R 755 /home/"$user"
        gpasswd -d "$user" wheel 2>/dev/null
        gpasswd -d "$user" sudo 2>/dev/null
        usermod -s /bin/false "$user"
    fi
done
current_step=$(( current_step + 1 ))

# ------------------------------------------------------------
# Implementing Fail2Ban.
# ------------------------------------------------------------
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo -e "\e[38;5;46m                Implementing Fail2Ban                 \e[0m"
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
sleep 1
echo "Installing fail2ban..."
sudo yum install -y -q fail2ban
echo "Creating fail2ban log file..."
sudo touch /var/log/fail2ban.log
echo "Configuring fail2ban..."
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.BACKUP
sed -i '/^\s*\[dovecot\]/,/^\[/{/logpath\s*=/d;/enabled\s*=/d;/bantime\s*=/d;/maxretry\s*=/d}' /etc/fail2ban/jail.conf
sed -i '/\[dovecot\]/a enabled = true\nbantime = 1800\nmaxretry = 5\nlogpath = /var/log/fail2ban.log' /etc/fail2ban/jail.conf
sed -i '/^\s*\[postfix\]/,/^\[/{/logpath\s*=/d;/enabled\s*=/d;/bantime\s*=/d;/maxretry\s*=/d}' /etc/fail2ban/jail.conf
sed -i '/\[postfix\]/a enabled = true\nbantime = 1800\nmaxretry = 5\nlogpath = /var/log/fail2ban.log' /etc/fail2ban/jail.conf
sed -i '/^\s*\[apache-auth\]/,/^\[/{/logpath\s*=/d;/enabled\s*=/d;/bantime\s*=/d;/maxretry\s*=/d}' /etc/fail2ban/jail.conf
sed -i '/\[apache-auth\]/a enabled = true\nbantime = 1800\nmaxretry = 5\nlogpath = /var/log/fail2ban.log' /etc/fail2ban/jail.conf
sed -i '/^\s*\[roundcube-auth\]/,/^\[/{/logpath\s*=/d;/enabled\s*=/d;/bantime\s*=/d;/maxretry\s*=/d}' /etc/fail2ban/jail.conf
sed -i '/\[roundcube-auth\]/a enabled = true\nbantime = 1800\nmaxretry = 5\nlogpath = /var/log/fail2ban.log' /etc/fail2ban/jail.conf
echo "Restarting fail2ban service..."
systemctl enable fail2ban
systemctl restart fail2ban
current_step=$(( current_step + 1 ))

# ------------------------------------------------------------
# Installing Comp Tools from Github.
# ------------------------------------------------------------
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo -e "\e[38;5;46m         Installing Comp Tools from Github            \e[0m"
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
sleep 1
mkdir -p COMPtools
base_url="https://raw.githubusercontent.com/Whitneyk7878/Kayne/refs/heads/main/"
files=(
    "COMPMailBoxClear.sh"
    "COMPInstallBroZEEK.sh"
    "COMPBackupFIREWALL.sh"
    "COMPcreatebackups.sh"
    "COMPrestorefrombackup.sh"
    "COMPautodiffer.sh"
    "COMPaddimmute.sh"
    "COMPremoveimmute.sh"
)
for file in "${files[@]}"; do
    echo "Downloading ${file}..."
    wget -P COMPtools "${base_url}${file}"
done
echo "All files have been downloaded to the COMPtools directory."
current_step=$(( current_step + 1 ))

# ------------------------------------------------------------
# Firewall Setup.
# ------------------------------------------------------------
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo -e "\e[38;5;46m                     Firewall                         \e[0m"
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
sleep 1
sudo yum install iptables-services -y -q
echo "stopping alternate firewall services.."
sudo systemctl stop firewalld && sudo systemctl disable firewalld && sudo systemctl mask firewalld
sudo dnf remove firewalld -y -q
sudo systemctl stop nftables && sudo systemctl disable nftables && sudo systemctl mask nftables
sudo systemctl mask nftables -y -q
echo "Starting IPTABLES..."
sudo yum install iptables iptables-services -y -q
sudo systemctl enable iptables && sudo systemctl start iptables
sudo iptables -t filter -F
sudo iptables -t filter -X
sudo iptables -t filter -P INPUT DROP
sudo iptables -t filter -P FORWARD DROP
sudo iptables -t filter -P OUTPUT DROP
sudo iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -t filter -A INPUT -i lo -j ACCEPT
sudo iptables -t filter -A OUTPUT -o lo -j ACCEPT
sudo iptables -t filter -A INPUT -p icmp -j ACCEPT
sudo iptables -t filter -A OUTPUT -p icmp -j ACCEPT
sudo iptables -t filter -A OUTPUT -p tcp --dport 53 -j ACCEPT
sudo iptables -t filter -A OUTPUT -p udp --dport 53 -j ACCEPT
sudo iptables -t filter -A OUTPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -t filter -A OUTPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -t filter -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -t filter -A INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -t filter -A OUTPUT -p udp --dport 123 -j ACCEPT
sudo iptables -t filter -A OUTPUT -p tcp --dport 8000 -j ACCEPT
sudo iptables -t filter -A OUTPUT -p tcp --dport 8089 -j ACCEPT
sudo iptables -t filter -A OUTPUT -p tcp --dport 9997 -j ACCEPT
sudo iptables -t filter -A OUTPUT -p tcp --dport 25 -j ACCEPT
sudo iptables -t filter -A INPUT -p tcp --dport 25 -j ACCEPT
sudo iptables -t filter -A OUTPUT -p tcp --dport 587 -j ACCEPT
sudo iptables -t filter -A OUPUT -p tcp --dport 465 -j ACCEPT
sudo iptables -t filter -A INPUT -p tcp --dport 587 -j ACCEPT
sudo iptables -t filter -A INPUT -p tcp --dport 465 -j ACCEPT
sudo iptables -t filter -A OUTPUT -p tcp --dport 110 -j ACCEPT
sudo iptables -t filter -A INPUT -p tcp --dport 110 -j ACCEPT
sudo iptables -t filter -A OUTPUT -p udp --dport 110 -j ACCEPT
sudo iptables -t filter -A INPUT -p udp --dport 110 -j ACCEPT
sudo iptables -t filter -A OUTPUT -p tcp --dport 143 -j ACCEPT
sudo iptables -t filter -A INPUT -p tcp --dport 143 -j ACCEPT
sudo iptables -t filter -A OUTPUT -p udp --dport 143 -j ACCEPT
sudo iptables -t filter -A INPUT -p udp --dport 143 -j ACCEPT
sudo iptables -t filter -A INPUT -p tcp --dport 389 -j ACCEPT
sudo iptables -t filter -A INPUT -p tcp --dport 636 -j ACCEPT
sudo iptables -t filter -A OUTPUT -p tcp --dport 389 -j ACCEPT
sudo iptables -t filter -A OUTPUT -p tcp --dport 636 -j ACCEPT
sudo iptables-save | sudo tee /etc/sysconfig/iptables
current_step=$(( current_step + 1 ))

# ------------------------------------------------------------
# Stuff Removal.
# ------------------------------------------------------------
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo -e "\e[38;5;46m                Stuff Removal                         \e[0m"
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
sleep 1
sudo yum remove sshd xinetd telnet-server rsh-server telnet rsh ypbind ypserv tftp-server cronie-anacron bind vsftpd squid net-snmpd -y -q
sudo systemctl stop xinetd && sudo systemctl disable xinetd
sudo systemctl stop rexec && sudo systemctl disable rexec
sudo systemctl stop rsh && sudo systemctl disable rsh
sudo systemctl stop rlogin && sudo systemctl disable rlogin
sudo systemctl stop ypbind && sudo systemctl disable ypbind
sudo systemctl stop tftp && sudo systemctl disable tftp
sudo systemctl stop certmonger && sudo systemctl disable certmonger
sudo systemctl stop cgconfig && sudo systemctl disable cgconfig
sudo systemctl stop cgred && sudo systemctl disable cgred
sudo systemctl stop kdump && sudo systemctl disable kdump
sudo systemctl stop mdmonitor && sudo systemctl disable mdmonitor
sudo systemctl stop netconsole && sudo systemctl disable netconsole
sudo systemctl stop oddjobd && sudo systemctl disable oddjobd
sudo systemctl stop portreserve && sudo systemctl disable portreserve
sudo systemctl stop qpidd && sudo systemctl disable qpidd
sudo systemctl stop quota_nld && sudo systemctl disable quota_nld
sudo systemctl stop rdisc && sudo systemctl disable rdisc
sudo systemctl stop rhnsd && sudo systemctl disable rhnsd
sudo systemctl stop rhsmcertd && sudo systemctl disable rhsmcertd
sudo systemctl stop saslauthd && sudo systemctl disable saslauthd
sudo systemctl stop smartd && sudo systemctl disable smartd
sudo systemctl stop sysstat && sudo systemctl disable sysstat
sudo systemctl stop atd && sudo systemctl disable atd
sudo systemctl stop nfslock && sudo systemctl disable nfslock
sudo systemctl stop named && sudo systemctl disable named
sudo systemctl stop squid && sudo systemctl disable squid
sudo systemctl stop snmpd && sudo systemctl disable snmpd
sudo systemctl stop postgresql && sudo systemctl disable postgresql
sudo systemctl stop nginx && sudo systemctl disable nginx
sudo systemctl stop cockpit.s && sudo systemctl disable cockpit.s
sudo systemctl stop rpcgssd && sudo systemctl disable rpcgssd
sudo systemctl stop rpcsvcgssd && sudo systemctl disable rpcsvcgssd
sudo systemctl stop rpcidmapd && sudo systemctl disable rpcidmapd
systemctl disable netfs
systemctl disable nfs
sudo yum remove -q -y ruby* java* perl* python* nodejs*
current_step=$(( current_step + 1 ))

# ------------------------------------------------------------
# Kernel Hardening.
# ------------------------------------------------------------
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo -e "\e[38;5;46m               Kernel Hardening                       \e[0m"
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
sleep 1
echo -e "Disabling core dumps for users"
echo "* hard core 0" >> /etc/security/limits.conf
echo -e "Securing sysctl.conf"
cat <<-EOF >> /etc/sysctl.conf
fs.suid_dumpable = 0
kernel.exec_shield = 1
kernel.randomize_va_space = 2
net.ipv4.ip_forward = 1
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
kernel.kptr_restrict = 1
kernel.dmesg_restrict = 1
kernel.yama.ptrace_scope = 3
EOF
sudo sysctl -p
current_step=$(( current_step + 1 ))

# ------------------------------------------------------------
# Update + Upgrade.
# ------------------------------------------------------------
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo -e "\e[38;5;46m               Update + Upgrade                       \e[0m"
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
sleep 1
echo "Updating and upgrading system packages. This may take a while..."
#sudo yum update -y -q && yum upgrade -y -q
current_step=$(( current_step + 1 ))

# ------------------------------------------------------------
# Securing APACHE.
# ------------------------------------------------------------
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo -e "\e[38;5;46m               Securing APACHE                        \e[0m"
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
sleep 1
echo "Hardening Apache HTTPD..."
sed -i 's/ServerTokens OS/ServerTokens Prod/' /etc/httpd/conf/httpd.conf
sed -i 's/ServerSignature On/ServerSignature Off/' /etc/httpd/conf/httpd.conf
systemctl restart httpd
echo "Apache HTTPD secured."
echo "Securing Apache against remote command execution..."
sed -i '/Options/d' /etc/httpd/conf/httpd.conf
sed -i 's/AllowOverride All/AllowOverride None/' /etc/httpd/conf/httpd.conf
sed -i 's/Require all granted/Require all denied/' /etc/httpd/conf/httpd.conf
systemctl restart httpd
current_step=$(( current_step + 1 ))

# ------------------------------------------------------------
# Securing Roundcube.
# ------------------------------------------------------------
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo -e "\e[38;5;46m               Securing Roundcube                      \e[0m"
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
sleep 1
sudo systemctl start httpd
sudo systemctl enable httpd
echo "Hardening RoundcubeMail..."
sed -i "s/\$config\['enable_installer'\] = true;/\$config['enable_installer'] = false;/" /etc/roundcubemail/config.inc.php
sed -i "s/\$config\['default_host'\] = '';/\$config['default_host'] = 'ssl:\/\/localhost';/" /etc/roundcubemail/config.inc.php
echo "RoundcubeMail secured."
systemctl restart httpd
current_step=$(( current_step + 1 ))

# ------------------------------------------------------------
# Securing PHP.
# ------------------------------------------------------------
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo -e "\e[38;5;46m                     Securing PHP                     \e[0m"
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
sleep 1
echo "Disabling dangerous PHP functions..."
sed -i 's/^disable_functions =.*/disable_functions = exec,system,shell_exec,passthru,popen,proc_open/' /etc/php.ini
echo "Turning off expose_php.."
sudo sed -i 's/^expose_php\s*=\s*On/expose_php = Off/' /etc/php.ini
sudo sed -i '/^\s*disable_functions\s*=/d' /etc/php.ini && sudo sh -c 'echo "disable_functions = exec,shell_exec,system,passthru,popen,proc_open,phpinfo,eval" >> /etc/php.ini'
sed -i -e '/^[;\s]*allow_url_fopen\s*=/d' -e '/^[;\s]*allow_url_include\s*=/d' -e '$ a allow_url_fopen = Off\nallow_url_include = Off' /etc/php.ini
systemctl restart httpd
current_step=$(( current_step + 1 ))

# ------------------------------------------------------------
# Securing Dovecot.
# ------------------------------------------------------------
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo -e "\e[38;5;46m                  Securing Dovecot                    \e[0m"
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
sleep 1
echo "Enabling and starting Dovecot and Postfix..."
systemctl enable dovecot
systemctl enable postfix
systemctl start dovecot
systemctl start postfix
sudo systemctl restart dovecot
current_step=$(( current_step + 1 ))

# ------------------------------------------------------------
# Securing Postfix.
# ------------------------------------------------------------
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo -e "\e[38;5;46m                  Securing Postfix                    \e[0m"
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo "Configuring Postfix..."
POSTFIX_CONFIG="/etc/postfix/main.cf"
declare -A POSTFIX_SETTINGS=(
    ["smtpd_client_connection_count_limit"]="10"
    ["smtpd_client_connection_rate_limit"]="60"
    ["smtpd_error_sleep_time"]="5s"
    ["smtpd_soft_error_limit"]="10"
    ["smtpd_hard_error_limit"]="20"
    ["message_size_limit"]="10485760"
    ["smtpd_recipient_restrictions"]="reject_unauth_destination"
)
for key in "${!POSTFIX_SETTINGS[@]}"; do
    if ! grep -q "^$key" "$POSTFIX_CONFIG"; then
        echo "$key = ${POSTFIX_SETTINGS[$key]}" >> "$POSTFIX_CONFIG"
    fi
done
sudo systemctl restart postfix
current_step=$(( current_step + 1 ))

# ------------------------------------------------------------
# Downloading Security Tools.
# ------------------------------------------------------------
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo -e "\e[38;5;46m              Downloading Security Tools              \e[0m"
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
sleep 1
echo "Installing required packages..."
sudo yum install -y -q chkrootkit aide rkhunter clamav clamd clamav-update
echo "Downloading monitoring script..."
# (download command commented out)
echo "Insalling Lynis..."
sudo yum install lynis -y -q
current_step=$(( current_step + 1 ))

# ------------------------------------------------------------
# AuditD.
# ------------------------------------------------------------
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo -e "\e[38;5;46m                     AuditD                         \e[0m"
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
sleep 1
echo "Configuring auditd..."
sudo systemctl enable auditd
sudo systemctl start auditd
echo "Setting up audit rules..."
sudo wget https://raw.githubusercontent.com/Whitneyk7878/Kayne/refs/heads/main/COMPCustomAudit.rules
sudo rm /etc/audit/rules.d/audit.rules
sudo mv COMPCustomAudit.rules /etc/audit/rules.d/
sudo dos2unix /etc/audit/rules.d/COMPCustomAudit.rules
current_step=$(( current_step + 1 ))

# ------------------------------------------------------------
# CLAMAV.
# ------------------------------------------------------------
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo -e "\e[38;5;46m                     CLAMAV                           \e[0m"
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
sleep 1
echo "Configuring ClamAV..."
# (ClamAV configuration commands commented out)
current_step=$(( current_step + 1 ))

# ------------------------------------------------------------
# SE LINUX.
# ------------------------------------------------------------
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo -e "\e[38;5;46m                     SE LINUX                           \e[0m"
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo "Setting SE to enforce mode and turning off permissive..."
sudo sed -i 's/^SELINUX=permissive/SELINUX=enforcing/' /etc/selinux/config
sudo setsebool -P allow_postfix_local_write_mail_spool on
sudo setsebool -P httpd_can_sendmail on
sudo setsebool -P allow_postfix_local_write_mail_spool=1
sudo systemctl restart postfix
current_step=$(( current_step + 1 ))

# ------------------------------------------------------------
# I HATE THE ANTICHRIST (compilers).
# ------------------------------------------------------------
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo -e "\e[38;5;46m            I HATE THE ANTICHRIST (compilers)         \e[0m"
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
sleep 1
sudo yum remove libgcc clang make cmake automake autoconf -y -q
current_step=$(( current_step + 1 ))

# ------------------------------------------------------------
# IPv6 is for Microsoft Engineers not me.
# ------------------------------------------------------------
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo -e "\e[38;5;46m        IPv6 is for Microsoft Engineers not me        \e[0m"
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
sleep 1
if grep -q "udp6" /etc/netconfig; then
    echo "Support for RPC IPv6 already disabled"
else
    echo "Disabling Support for RPC IPv6..."
    sed -i 's/udp6       tpi_clts      v     inet6    udp     -       -/#udp6       tpi_clts      v     inet6    udp     -       -/g' /etc/netconfig
    sed -i 's/tcp6       tpi_cots_ord  v     inet6    tcp     -       -/#tcp6       tpi_cots_ord  v     inet6    tcp     -       -/g' /etc/netconfig
fi
current_step=$(( current_step + 1 ))

# ------------------------------------------------------------
# Cron Lockdown.
# ------------------------------------------------------------
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo -e "\e[38;5;46m                   Cron Lockdown                      \e[0m"
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
sleep 1
echo "Locking down Cron"
sudo systemctl start crond && sudo systemctl enable crond
touch /etc/cron.allow
chmod 600 /etc/cron.allow
awk -F: '{print $1}' /etc/passwd | grep -v root > /etc/cron.deny
echo "Locking down AT"
touch /etc/at.allow
chmod 600 /etc/at.allow
awk -F: '{print $1}' /etc/passwd | grep -v root > /etc/at.deny
chmod 600 /etc/cron.deny /etc/at.deny /etc/crontab
current_step=$(( current_step + 1 ))

# ------------------------------------------------------------
# NTP.
# ------------------------------------------------------------
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo -e "\e[38;5;46m                     NTP                         \e[0m"
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
sleep 1
sudo yum install ntpdate -y -q
ntpdate pool.ntp.org
current_step=$(( current_step + 1 ))

# ------------------------------------------------------------
# Diffing for Baselines.
# ------------------------------------------------------------
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo -e "\e[38;5;46m             Diffing for Baselines                    \e[0m"
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
sleep 1
echo "Creating DIFFING directory..."
sudo mkdir -p /root/DIFFING/CHANGES
echo "Running auto-differ.."
sudo bash /root/COMPtools/COMPautodiffer.sh
current_step=$(( current_step + 1 ))

# ------------------------------------------------------------
# Install XFCE.
# ------------------------------------------------------------
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo -e "\e[38;5;46m                  Install XFCE                        \e[0m"
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
sudo yum groupinstall "Xfce Desktop" -y -q
current_step=$(( current_step + 1 ))

# ------------------------------------------------------------
# Carpet Bombing Binaries.
# ------------------------------------------------------------
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo -e "\e[38;5;46m              Carpet Bombing Binaries                 \e[0m"
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo "Making the secret location.."
sudo mkdir -p /etc/stb
sudo mv /usr/bin/curl /etc/stb/1
sudo mv /usr/bin/wget /etc/stb/2
sudo mv /usr/bin/ftp  /etc/stb/3
sudo mv /usr/bin/sftp /etc/stb/4
sudo mv /usr/bin/aria2c /etc/stb/5
sudo mv /usr/bin/nc /etc/stb/6
sudo mv /usr/bin/socat /etc/stb/7
sudo mv /usr/bin/telnet /etc/stb/8
sudo mv /usr/bin/tftp /etc/stb/9
sudo mv /usr/bin/ncat /etc/stb/10
sudo mv /usr/bin/gdb /etc/stb/11  
sudo mv /usr/bin/strace /etc/stb/12 
sudo mv /usr/bin/ltrace /etc/stb/13
current_step=$(( current_step + 1 ))

# ------------------------------------------------------------
# Locking Down Critical Files.
# ------------------------------------------------------------
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
echo -e "\e[38;5;46m              Locking Down Critical Files             \e[0m"
echo -e "\e[38;5;46m//////////////////////////////////////////////////////\e[0m"
sleep 1
FILES=( /etc/passwd /etc/shadow /etc/group /etc/gshadow /etc/sudoers /etc/ssh/sshd_config /etc/ssh/ssh_config /etc/crontab /etc/fstab /etc/hosts /etc/resolv.conf /etc/sysctl.conf /etc/selinux/config )
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        chattr +i "$file"
        echo "Set immutable on $file"
    else
        echo "File not found: $file"
    fi
done

# Helper function to secure directories.
set_permissions_and_immutable() {
  local dir="$1"
  echo "Applying ownership root:root to $dir ..."
  sudo chown -R root:root "$dir"
  echo "Setting directory permissions to 755 in $dir ..."
  sudo find "$dir" -type d -exec chmod 755 {} \;
  echo "Setting file permissions to 644 in $dir ..."
  sudo find "$dir" -type f -exec chmod 644 {} \;
  echo "Applying immutable attribute (+i) to $dir ..."
  sudo chattr -R +i "$dir"
  echo "Finished securing $dir."
  echo
}
CONFIG_DIRS=( "/etc/roundcubemail" "/etc/httpd" "/etc/dovecot" "/etc/postfix" )
for dir in "${CONFIG_DIRS[@]}"; do
  echo "Directory: $dir"
  read -r -p "Is this the correct directory to secure? (y/n): " answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    if [[ -d "$dir" ]]; then
      set_permissions_and_immutable "$dir"
    else
      echo "Warning: $dir does not exist on this system. Skipping."
      echo
    fi
  else
    echo "Skipping $dir."
    echo
  fi
done
current_step=$(( current_step + 1 ))

# Final Step: Clean up and reboot.
echo " "
echo -e "\e[45mSCRIPT HAS FINISHED RUNNING... REBOOTING..\e[0m"
sleep 3

# Kill the background progress bar process.
kill $progress_pid
sudo reboot
