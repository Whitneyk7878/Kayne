echo "installing suricata.."
sudo yum install suricata -y -q
echo "Installing the latest emerging threats rules.."
sudo wget https://rules.emergingthreats.net/open/suricata/emerging.rules.tar.gz -O /tmp/emerging.rules.tar.gz
sudo tar -xvzf /tmp/emerging.rules.tar.gz -C /etc/suricata/
sudo systemctl enable suricata
sudo systemctl start suricata
