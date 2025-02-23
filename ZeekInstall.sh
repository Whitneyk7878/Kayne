#!/bin/bash

sudo yum groupinstall -y "Development Tools"
sudo yum install -y cmake make gcc gcc-c++ flex bison libpcap-devel openssl-devel python-devel swig zlib-devel

cd /usr/local/src
sudo wget https://old.zeek.org/downloads/bro-2.6.4.tar.gz

sudo tar -xvzf bro-2.6.4.tar.gz
cd bro-2.6.4

sudo ./configure --prefix=/opt/bro
sudo make -j$(nproc)
sudo make install

echo 'export PATH=/opt/bro/bin:$PATH' | sudo tee -a /etc/profile
source /etc/profile

# NEXT
# CHANGE NETWORK INTERFACE IN /opt/bro/etc/broctl.cfg

# sudo /opt/bro/bin/broctl deploy
# sudo /opt/bro/bin/broctl status

#VIEW LOGS
# ls /opt/bro/logs/current/
# cat /opt/bro/logs/current/conn.log



