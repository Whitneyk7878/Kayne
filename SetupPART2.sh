#!/bin/bash
# Update system
echo "Updating and upgrading system packages..."
yum update -y && yum upgrade -y
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
# Restart fail2ban service
echo "Restarting fail2ban service..."
systemctl enable fail2ban
systemctl start fail2ban
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
echo "DONE"
