#/bin/bash
# Disable prelinking altogether for aide

if grep -q ^PRELINKING /etc/sysconfig/prelink
then
  sed -i 's/PRELINKING.*/PRELINKING=no/g' /etc/sysconfig/prelink
else
  echo -e "\n# Set PRELINKING=no per security requirements" >> /etc/sysconfig/prelink
  echo "PRELINKING=no" >> /etc/sysconfig/prelink
fi
sleep 5
# Enable SHA512 password hashing
authconfig --passalgo=sha512 —update

# Set Last Login/Access Notification
# Edit /etc/pam.d/system-auth, and add following line imeediatley after session required pam_limits.so: session       required     pam_lastlog.so showfailed

if grep -q pam_lastlog.so /etc/pam.d/system-auth
then
    echo "pam_lastlog.so already in system-auth"
else
    echo "Adding pam_lastlog.so to system-auth..."
    sed -i '/pam_limits.so/a session required pam_lastlog.so showfailed' /etc/pam.d/system-auth
fi
sleep 5
# Disable Ctrl-Alt-Del Reboot Activation
# change 'exec /sbin/shutdown -r now "Control-Alt-Delete pressed"' to 'exec /usr/bin/logger -p security.info "Control-Alt-Delete pressed"' in /etc/init/control-alt-delete.conf

if grep -q "exec /usr/bin/logger -p security.info" /etc/init/control-alt-delete.conf
then
    echo "Control-Alt-Delete already disabled"
else
    echo "Disabling Control-Alt-Delete..."
    sed -i 's/exec \/sbin\/shutdown -r now "Control-Alt-Delete pressed"/exec \/usr\/bin\/logger -p security.info "Control-Alt-Delete pressed"/g' /etc/init/control-alt-delete.conf
fi
sleep 5
# secure grub by ensuring the permissions are set to 600
chmod 600 /boot/grub2/grub.cfg
sleep 5
# Ensure SELinux is enabled and enforcing
# Check if SELINUX is already set to enforcing
if grep -q SELINUX=enforcing /etc/selinux/config
then
    echo "SELINUX already set to enforcing"
else
    echo "Setting SELINUX to enforcing..."
    sed -i 's/SELINUX=disabled/SELINUX=enforcing/g' /etc/selinux/config
fi
sleep 5
# REMOVE ALLL COMPILERS
yum remove libgcc -y

# Disable Support for RPC IPv6
# comment the following lines in /etc/netconfig
# udp6       tpi_clts      v     inet6    udp     -       -
# tcp6       tpi_cots_ord  v     inet6    tcp     -       -
sleep 5
if grep -q "udp6" /etc/netconfig
then
    echo "Support for RPC IPv6 already disabled"
else
    echo "Disabling Support for RPC IPv6..."
    sed -i 's/udp6       tpi_clts      v     inet6    udp     -       -/#udp6       tpi_clts      v     inet6    udp     -       -/g' /etc/netconfig
    sed -i 's/tcp6       tpi_cots_ord  v     inet6    tcp     -       -/#tcp6       tpi_cots_ord  v     inet6    tcp     -       -/g' /etc/netconfig
fi
sleep 5
# Only allow root login from console
echo "tty1" > /etc/securetty
chmod 700 /root
sleep 5
# Enable UMASK 077
perl -npe 's/umask\s+0\d2/umask 077/g' -i /etc/bashrc
perl -npe 's/umask\s+0\d2/umask 077/g' -i /etc/csh.cshrc
sleep 5
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
sleep 5
# Sysctl Security 
cat <<-EOF > /etc/sysctl.conf
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
kernel.exec_shield = 1
kernel.randomize_va_space = 2
fs.suid_dumpable = 0
EOF
sleep 5
#kernel.modules_disabled = 1

# kernel.yama.ptrace_scope = 2

# DENY ALL TCP WRAPPERS
echo "ALL:ALL" > /etc/hosts.deny
sleep 5
# Disable Uncommon Protocols
echo "install dccp /bin/false" > /etc/modprobe.d/dccp.conf
echo "install sctp /bin/false" > /etc/modprobe.d/sctp.conf
echo "install rds /bin/false" > /etc/modprobe.d/rds.conf
echo "install tipc /bin/false" > /etc/modprobe.d/tipc.conf
