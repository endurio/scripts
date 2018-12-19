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

for VAR in "$@"
do
    if [ "${VAR: -3}" = "tcp" ]; then
        PORT=${VAR::-3}
        iptables -A INPUT -p tcp -m tcp --dport $PORT -j ACCEPT
    elif [ "${VAR: -3}" = "udp" ]; then
        PORT=${VAR::-3}
        iptables -A INPUT -p udp -m udp --dport $PORT -j ACCEPT
    else
        PORT=$VAR
        iptables -A INPUT -p tcp -m tcp --dport $PORT -j ACCEPT
        iptables -A INPUT -p udp -m udp --dport $PORT -j ACCEPT
    fi
done

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
