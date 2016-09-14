#!/bin/bash

set -x

set -e

. config.sh

if [ ! -f /root/.ssh/id_rsa ]; then
    ssh-keygen -f /root/.ssh/id_rsa -t rsa -N ''
fi
#echo $controller_pub_key >> /root/.ssh/authorized_keys

#Install openvswitch
cd $TEMP
wget $WEBSITE/openvswitch-2.3.0.tar.gz
tar xzf openvswitch-2.3.0.tar.gz
cd openvswitch-2.3.0
if [ "$platform" = xen ]; then
  ./configure --prefix=/usr --with-linux=$TEMP/BUILD/kernel
elif [ "$platform" = kvm ]; then
  ./configure --prefix=/usr --with-linux=$TEMP/BUILD/kernel-3.4.46/linux-3.4.46-8.el6.x86_64
elif [ "$platform" = hyperv ]; then
  ./configure --prefix=/usr --with-linux=$TEMP/BUILD/kernel-3.4.46/linux-3.4.46-8.el6.x86_64
fi

make
make modules_install
make install
cp rhel/etc_init.d_openvswitch /etc/init.d/openvswitch
modprobe openvswitch
#echo "openvswitch" > /etc/modprobe.d/openvswitch.conf
service openvswitch start
chkconfig openvswitch on
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

cp $BASE/vif-openvswitch /etc/xen/scripts
sed -c -i "s/vif-bridge/vif-openvswitch/" /etc/xen/xl.conf
sed -c -i "s/#vifscript/vifscript/" /etc/xen/xl.conf

yum install nfs-utils -y

echo "ALL FINISHED."
