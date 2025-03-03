#!/bin/bash

# Define Paths
BRO_DIR="/opt/bro"
BRO_SITE="$BRO_DIR/share/bro/site"
RULES_DIR="$BRO_SITE/rules"
SIGNATURES_DIR="$BRO_SITE/signatures"
ET_RULES_URL="https://rules.emergingthreats.net/open/suricata-5.0/emerging.rules.tar.gz"
SNORT2BRO_DIR="/usr/local/src/snort2bro"

# Ensure Bro is Installed
if [ ! -d "$BRO_DIR" ]; then
    echo "Error: Bro (Zeek) is not installed in $BRO_DIR. Exiting..."
    exit 1
fi

# Ensure Snort2Bro is Installed
if [ ! -d "$SNORT2BRO_DIR" ]; then
    echo "Installing Snort2Bro..."
    cd /usr/local/src
    git clone https://github.com/J-Gras/snort2bro.git
    cd snort2bro
    chmod +x snort2bro.pl
fi

# Create Required Directories
mkdir -p "$RULES_DIR"
mkdir -p "$SIGNATURES_DIR"

# Download Emerging Threats Rules
echo "[+] Downloading Emerging Threats rules..."
cd "$RULES_DIR"
wget -q -O emerging.rules.tar.gz "$ET_RULES_URL"

# Extract Rules
echo "[+] Extracting rules..."
tar -xzf emerging.rules.tar.gz
cat emerging-*.rules > emerging-threats.rules

# Convert Snort/Suricata Rules to Bro Format
echo "[+] Converting rules using Snort2Bro..."
perl "$SNORT2BRO_DIR/snort2bro.pl" -i emerging-threats.rules -o emerging-threats.sig

# Move Converted Rules to Bro Signatures Directory
echo "[+] Updating Bro signatures..."
mv emerging-threats.sig "$SIGNATURES_DIR/emerging-threats.sig"

# Configure Bro to Load the Rules (if not already configured)
if ! grep -q "emerging-threats.sig" "$BRO_SITE/local.bro"; then
    echo "[+] Configuring Bro to load Emerging Threats rules..."
    echo '@load signatures' >> "$BRO_SITE/local.bro"
    echo 'signature_files += "signatures/emerging-threats.sig";' >> "$BRO_SITE/local.bro"
fi

# Restart Bro (Zeek) to Apply Changes
echo "[+] Restarting Bro..."
$BRO_DIR/bin/broctl deploy

# Cleanup
rm -f emerging.rules.tar.gz

echo "[+] Emerging Threats rules updated successfully!"
exit 0
