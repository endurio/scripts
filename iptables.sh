#!/bin/bash
#

# https://www.digitalocean.com/community/tutorials/how-to-set-up-a-basic-iptables-firewall-on-centos-6

# flush them
iptables -F

# some common attacks
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
iptables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
iptables -A INPUT -i lo -j ACCEPT

# BTCD
iptables -A INPUT -p tcp -m tcp --dport 8333 -j ACCEPT
iptables -A INPUT -p udp -m udp --dport 8333 -j ACCEPT

# SSH
iptables -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT

iptables -I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P INPUT DROP

# save them
#iptables-save | sudo tee /etc/sysconfig/iptables
if ! command -v netfilter-persistent >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get -yq install iptables-persistent
fi
netfilter-persistent save
iptables -S

# restart the service
#service iptables restart
netfilter-persistent reload
