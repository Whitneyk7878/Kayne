#!/bin/bash
# Define variables
BASE_DIR="/root/DIFFING"
HIDDEN_DIR="/lib/.tarkov"
AUDIT_RULES_URL="https://raw.githubusercontent.com/Neo23x0/auditd/refs/heads/master/audit.rules"
MONITOR_SCRIPT_URL="https://raw.githubusercontent.com/UWStout-CCDC/kronos/master/Linux/General/monitor.sh"
# Update and install necessary packages
echo "Installing required packages..."
sudo yum install -y aide rkhunter auditd clamav clamd clamav-update
# Download and set up monitoring script
echo "Downloading monitoring script..."
sudo wget -O /usr/local/bin/monitor.sh "$MONITOR_SCRIPT_URL"
sudo chmod +x /usr/local/bin/monitor.sh
# Enable and start auditd
echo "Configuring auditd..."
sudo systemctl enable auditd
sudo systemctl start auditd
# Download audit rules and apply them
echo "Setting up audit rules..."
sudo wget -O audit.rules "$AUDIT_RULES_URL"
sudo rm -f /etc/audit/rules.d/audit.rules
sudo mv audit.rules /etc/audit/rules.d/
sudo auditctl -R /etc/audit/rules.d/audit.rules
# Configure ClamAV
echo "Configuring ClamAV..."
sudo sed -i '8s/^/#/' /etc/freshclam.conf
sudo freshclam
# Create DIFFING directory
echo "Creating DIFFING directory..."
sudo mkdir -p "$BASE_DIR"
# Generate baseline system information
echo "Generating baseline data..."
sudo lsof -i -n | grep "LISTEN" > "$BASE_DIR/portdiffingBASELINE.txt"
sudo ss -t state established > "$BASE_DIR/connectiondiffingBASELINE.txt"
sudo cat /root/.bashrc > "$BASE_DIR/alias_diffingBASELINE.txt"
sudo find / -type f -executable 2>/dev/null > "$BASE_DIR/executables_diffingBASELINE.txt"
for user in $(cut -f1 -d: /etc/passwd); do crontab -u $user -l 2>/dev/null; done > "$BASE_DIR/cron_diffingBASELINE.txt"
sudo cat /etc/shadow > "$BASE_DIR/users_diffingBASELINE.txt"
# Create hidden directory for compressed files
echo "Creating hidden directory..."
sudo mkdir -p "$HIDDEN_DIR"
# Archive and store system files individually
echo "Compressing and storing system files individually..."
sudo tar -czf "$HIDDEN_DIR/shadow_backup.tar.gz" /etc/shadow
sudo tar -czf "$HIDDEN_DIR/passwd_backup.tar.gz" /etc/passwd
sudo tar -czf "$HIDDEN_DIR/fail2ban_backup.tar.gz" /etc/fail2ban/
sudo tar -czf "$HIDDEN_DIR/hosts_backup.tar.gz" /etc/hosts
sudo tar -czf "$HIDDEN_DIR/log_backup.tar.gz" /var/log
sudo tar -czf "$HIDDEN_DIR/mail_backup.tar.gz" /var/mail
sudo tar -czf "$HIDDEN_DIR/postfix_spool_backup.tar.gz" /var/spool/postfix/
sudo tar -czf "$HIDDEN_DIR/postfix_backup.tar.gz" /etc/postfix/
sudo tar -czf "$HIDDEN_DIR/dovecot_backup.tar.gz" /etc/dovecot
echo "Setup complete."
