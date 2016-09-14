#!/bin/bash

. config.sh

set -x
set -e


if [ ! -f /root/.ssh/id_rsa ]; then
    ssh-keygen -f /root/.ssh/id_rsa -t rsa -N ''
fi
#echo $controller_pub_key >> /root/.ssh/authorized_keys

xe network-param-set uuid=$(xe network-list bridge=xenbr0 --minimal) MTU=$host_mtu
ifconfig eth0 mtu $host_mtu
ifconfig xenbr0 mtu $host_mtu

xe pif-reconfigure-ip mode=static uuid=$(xe pif-list device=vif1.4 --minimal) IP=10.8.1.$IPSUFFIX netmask=255.255.255.0
xe network-param-set uuid=$(xe network-list bridge=brvif1.4 --minimal) MTU=$guest_mtu
xe pif-unplug uuid=$(xe pif-list device=vif1.4 --minimal)
xe pif-plug uuid=$(xe pif-list device=vif1.4 --minimal)

xe pif-reconfigure-ip mode=static uuid=$(xe pif-list device=vif1.5 --minimal) IP=10.8.8.$IPSUFFIX netmask=255.255.255.0
xe network-param-set uuid=$(xe network-list bridge=brvif1.5 --minimal) MTU=$guest_mtu
xe pif-unplug uuid=$(xe pif-list device=vif1.5 --minimal)
xe pif-plug uuid=$(xe pif-list device=vif1.5 --minimal)

xe pif-reconfigure-ip mode=static uuid=$(xe pif-list device=vif1.6 --minimal) IP=10.8.9.$IPSUFFIX netmask=255.255.255.0
xe network-param-set uuid=$(xe network-list bridge=brvif1.6 --minimal) MTU=$guest_mtu
xe pif-unplug uuid=$(xe pif-list device=vif1.6 --minimal)
xe pif-plug uuid=$(xe pif-list device=vif1.6 --minimal)

xe host-management-reconfigure pif-uuid=$(xe pif-list device=vif1.4 --minimal)
xe vm-destroy uuid=$(xe vm-list name-label=dummy --minimal)



iptables -t nat -I POSTROUTING -o xenbr0 -j MASQUERADE
iptables -I FORWARD -i xenbr0 -o brvif1.4 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -I FORWARD -i brvif1.4 -j ACCEPT
iptables -I FORWARD -i xenbr0 -o brvif1.5 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -I FORWARD -i brvif1.5 -j ACCEPT
iptables -I FORWARD -i xenbr0 -o brvif1.6 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -I FORWARD -i brvif1.6 -j ACCEPT
service iptables save

#setup tunnels
cd $BASE
python build_bridges.py
if [ "$is_gateway" = true ]; then
    python build_gateway_bridges.py
fi
#python set_tunnels.py $local_ip tunnels.txt

echo -e "$host_passwd\n$host_passwd" | (passwd --stdin root)

cd $TEMP
git clone --depth=1 $GIT_OPENSTACK
cd devstack
git apply $BASE/supercloud.patch

sed -c -i "s/10.8.1.100/10.8.1.$IPSUFFIX/" local.conf
sed -c -i "s/OPENSTACK_PASSWD/$openstack_passwd/" local.conf
sed -c -i "s/GUEST_PASSWD/$guest_passwd/" local.conf
sed -c -i "s/HOST_PASSWD/$host_passwd/" local.conf

if [ "$is_compute" = true ]; then
    sed -c -i 's/#DATABASE_TYPE=mysql/DATABASE_TYPE=mysql/' local.conf
    sed -c -i 's/#SERVICE_HOST=10.8.1.150/SERVICE_HOST=10.8.1.150/' local.conf
    sed -c -i 's/#MYSQL_HOST=10.8.1.150/MYSQL_HOST=10.8.1.150/' local.conf
    sed -c -i 's/#RABBIT_HOST=10.8.1.150/RABBIT_HOST=10.8.1.150/' local.conf
    sed -c -i 's/#GLANCE_HOSTPORT=10.8.1.150:9292/GLANCE_HOSTPORT=10.8.1.150:9292/' local.conf
    sed -c -i 's/#ENABLED_SERVICES/ENABLED_SERVICES/' local.conf
    sed -c -i 's/#NOVA_VNC_ENABLED=True/NOVA_VNC_ENABLED=True/' local.conf
    sed -c -i 's/#NOVNCPROXY_URL/NOVNCPROXY_URL/' local.conf
    sed -c -i 's/#VNCSERVER_LISTEN/VNCSERVER_LISTEN/' local.conf
fi

sed -c -i "s/DevStack-master/$GUEST_NAME/" tools/xen/xenrc

if [ "$is_compute" = true ]; then
    sed -c -i "s/OSDOMU_MEM_MB=6144/OSDOMU_MEM_MB=2048/" tools/xen/xenrc
    sed -c -i "s/OSDOMU_VDI_GB=15/OSDOMU_VDI_GB=8/" tools/xen/xenrc
#else
#    sed -c -i "s/OSDOMU_VDI_GB=15/OSDOMU_VDI_GB=20/" tools/xen/xenrc
fi

sed -c -i "s/.150/.$GUEST_IPSUFFIX/" tools/xen/xenrc
sed -c -i "s/128.253.180.2/$NAMESERVER/" tools/xen/xenrc
sed -c -i "s/\"GATEWAY\"/\"10.8.1.$IPSUFFIX\"/" tools/xen/xenrc
sed -c -i "s/\"GUEST_MTU\"/\"$guest_mtu\"/" tools/xen/xenrc

sed -c -i "s/GATEWAY/10.8.1.$IPSUFFIX/" tools/xen/build_xva.sh
sed -c -i "s/128.253.180.2/$NAMESERVER/" tools/xen/build_xva.sh
sed -c -i "s/mtu 1400/mtu $guest_mtu/" tools/xen/build_xva.sh

#cd tools/xen/
#./install_os_domU.sh
#cp -np plugins/* /usr/lib/xapi/plugins/
echo "Check default gateway, mtu and nameserver in xenrc and build_xva.sh. You may want to adjust the disk size of the VM. Then run cd $TEMP/devstack/tools/xen/; ./install_os_domU.sh"
echo "Stage 3 finished."
