#!/bin/bash
# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No color

echo -e "${YELLOW}WARNING: THIS SCRIPT TAKES A LONG TIME TO RUN!${NC}"
echo -e "${YELLOW}DO NOT RUN IF YOU ARE IN A COMPETITION AND PRESSED FOR TIME.${NC}"
sleep 3

# Install the dependencies
echo -e "${GREEN}Installing Development Tools and Dependencies...${NC}"
sudo yum groupinstall -y "Development Tools"
sudo yum install -y cmake make gcc gcc-c++ flex bison libpcap-devel openssl-devel python-devel swig zlib-devel

# Download the old Bro (Zeek)
echo -e "${GREEN}Downloading Bro (Zeek) 2.6.4...${NC}"
cd /usr/local/src
sudo wget https://old.zeek.org/downloads/bro-2.6.4.tar.gz

# Unzip the tarball
echo -e "${GREEN}Extracting Bro (Zeek) 2.6.4...${NC}"
sudo tar -xvzf bro-2.6.4.tar.gz
cd bro-2.6.4

# Configure the build
echo -e "${GREEN}Configuring Bro (Zeek)...${NC}"
sudo ./configure --prefix=/opt/bro

# Compile and install
echo -e "${GREEN}Compiling Bro (Zeek), this may take a while...${NC}"
sudo make -j$(nproc)
sudo make install

# Set PATH
echo 'export PATH=/opt/bro/bin:$PATH' | sudo tee -a /etc/profile
source /etc/profile

echo -e "${GREEN}Bro (Zeek) installation complete.${NC}"

# ============================
# INSTALL EMERGING THREATS RULES
# ============================
echo -e "${GREEN}Downloading Emerging Threats Rules...${NC}"
ET_RULES_DIR="/opt/bro/share/zeek/site/emerging-threats"
sudo mkdir -p $ET_RULES_DIR
cd $ET_RULES_DIR

# Download the latest Emerging Threats open rules
sudo wget https://rules.emergingthreats.net/open/suricata-5.0/emerging.rules.tar.gz

# Extract the rules
echo -e "${GREEN}Extracting Emerging Threats Rules...${NC}"
sudo tar -xvzf emerging.rules.tar.gz

# Convert Suricata rules to Zeek format
echo -e "${GREEN}Converting Emerging Threats Rules to Zeek Format...${NC}"
sudo find $ET_RULES_DIR -name "*.rules" -exec cat {} + > emerging-threats-all.rules

# ============================
# CONFIGURE ZEEK TO USE ET RULES
# ============================
ZEEK_LOCAL_CONFIG="/opt/bro/share/zeek/site/local.zeek"

echo -e "${GREEN}Configuring Zeek to Load Emerging Threats Rules...${NC}"

if ! grep -q "emerging-threats" $ZEEK_LOCAL_CONFIG; then
    echo 'redef Security::policy_files += "$ET_RULES_DIR/emerging-threats-all.rules";' | sudo tee -a $ZEEK_LOCAL_CONFIG
fi

# Restart Zeek to apply changes
echo -e "${GREEN}Restarting Zeek to Apply Changes...${NC}"
sudo /opt/bro/bin/zeekctl deploy

echo -e "${GREEN}Zeek is now using Emerging Threats rules!${NC}"
