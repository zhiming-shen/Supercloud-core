#!/bin/bash


. config.sh

IPSUFFIX=1

set -x
set -e

if [ ! -d "$TEMP" ]; then
    mkdir -p $TEMP
fi

echo "" > tunnels.txt

if [ ! -f /root/.ssh/id_rsa ]; then
    ssh-keygen -f /root/.ssh/id_rsa -t rsa -N ''
fi

yum groupinstall -y "Development Tools"
cd $TEMP
wget $WEBSITE/openvswitch-2.3.0.tar.gz
tar xzf openvswitch-2.3.0.tar.gz
cd openvswitch-2.3.0
#./configure --prefix=/usr --with-linux=/lib/modules/`uname -r`/build
./configure --prefix=/usr
make
#make modules_install
make install
/bin/cp -f rhel/etc_init.d_openvswitch /etc/init.d/openvswitch
modprobe openvswitch
service openvswitch start
chkconfig openvswitch on

touch /etc/sysconfig/iptables
service iptables restart
chkconfig iptables on
iptables -I INPUT -m state --state NEW -p udp --dport 4789 -s 0.0.0.0/0 -j ACCEPT
service iptables save

ovs-vsctl add-br brvif1.4
ovs-vsctl add-br brvif1.5
ovs-vsctl add-br brvif1.6

ifconfig brvif1.4 10.8.1.$IPSUFFIX netmask 255.255.255.0 mtu $guest_mtu up
ifconfig brvif1.5 10.8.8.$IPSUFFIX netmask 255.255.255.0 mtu $guest_mtu up
ifconfig brvif1.6 10.8.9.$IPSUFFIX netmask 255.255.255.0 mtu $guest_mtu up

cd $BASE
python build_bridges.py
if [ "$is_gateway" = true ]; then
    python build_gateway_bridges.py
fi
#python set_tunnels.py $local_ip tunnels.txt

echo "ifconfig brvif1.4 10.8.1.$IPSUFFIX netmask 255.255.255.0 mtu $guest_mtu up" >> /etc/rc.local
echo "ifconfig brvif1.5 10.8.8.$IPSUFFIX netmask 255.255.255.0 mtu $guest_mtu up" >> /etc/rc.local
echo "ifconfig brvif1.6 10.8.9.$IPSUFFIX netmask 255.255.255.0 mtu $guest_mtu up" >> /etc/rc.local

yum install -y nfs-utils nfs-utils-lib
mkdir -p $NFS_ROOT
/bin/cp -f $BASE/controller/exports /etc/exports
sed -c -i "s:/root/nfsroot:$NFS_ROOT:" /etc/exports

#fixing NFS ports. it is not necessary actually because we only allow nfs mount from the VPN
echo "LOCKD_TCPPORT=32803" >> /etc/sysconfig/nfs
echo "LOCKD_UDPPORT=32769" >> /etc/sysconfig/nfs
echo "MOUNTD_PORT=892" >> /etc/sysconfig/nfs
echo "RQUOTAD_PORT=875" >> /etc/sysconfig/nfs
echo "STATD_PORT=662" >> /etc/sysconfig/nfs
echo "STATD_OUTGOING_PORT=2020" >> /etc/sysconfig/nfs

#iptables -I INPUT -m state --state NEW -p tcp -m multiport --dport 111,2049,32803,892,875,662 -s 0.0.0.0/0 -j ACCEPT
#iptables -I INPUT -m state --state NEW -p udp -m multiport --dport 111,2049,32769,892,875,662 -s 0.0.0.0/0 -j ACCEPT
iptables -I INPUT --in-interface brvif1.4 -j ACCEPT
iptables -I INPUT --in-interface brvif1.5 -j ACCEPT
iptables -I INPUT --in-interface brvif1.6 -j ACCEPT
service iptables save

service rpcbind restart
service nfs restart
chkconfig nfs on

iptables --table nat -I POSTROUTING --out-interface eth0 -j MASQUERADE
iptables -I FORWARD --in-interface brvif1.4 -j ACCEPT
iptables -I FORWARD --in-interface brvif1.5 -j ACCEPT
iptables -I FORWARD --in-interface brvif1.6 -j ACCEPT
iptables -I FORWARD -o brvif1.4 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -I FORWARD -o brvif1.5 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -I FORWARD -o brvif1.6 -m state --state RELATED,ESTABLISHED -j ACCEPT
echo 1 > /proc/sys/net/ipv4/ip_forward
echo "echo 1 > /proc/sys/net/ipv4/ip_forward" >> /etc/rc.local
service iptables save




echo "ALL FINISHED." 
