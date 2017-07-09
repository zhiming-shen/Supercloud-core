#!/bin/bash


. config.sh


set -x
set -e

#reinstall openvswitch kernel moduel
cd $TEMP/openvswitch-2.3.0
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


xe vm-install new-name-label="dummy" template=$(xe template-list name-label="CentOS 6 (64-bit)" --minimal)

xe network-create name-label=dummy_network
xe vif-create device=4 network-uuid=$(xe network-list name-label=dummy_network --minimal) vm-uuid=$(xe vm-list name-label=dummy --minimal)
xe vif-create device=5 network-uuid=$(xe network-list name-label=dummy_network --minimal) vm-uuid=$(xe vm-list name-label=dummy --minimal)
xe vif-create device=6 network-uuid=$(xe network-list name-label=dummy_network --minimal) vm-uuid=$(xe vm-list name-label=dummy --minimal)

xe vm-param-set uuid=$(xe vm-list name-label=dummy --minimal) other-config:install-repository="http://mirror.es.its.nyu.edu/centos/6/os/x86_64/"
xe vm-start vm=$(xe vm-list name-label=dummy --minimal)

xe pif-scan host-uuid=$(xe host-list minimal=true)
sleep 15
xe vm-shutdown uuid=$(xe vm-list name-label=dummy --minimal) force=true

set +x
echo "Waiting for the database to be flushed. It could take a while..."
while ! grep -q fe:ff:ff:ff:ff:ff /var/lib/xcp/state.db; do sleep 1; done
set -x

/bin/cp -f /var/lib/xcp/state.db /var/lib/xcp/state.db.bak


#/bin/cp -f /etc/rc.d/rc3.d/S05cgconfig /root/S05cgconfig.bak
/bin/cp -f /etc/rc.d/init.d/openvswitch /root/openvswitch.bak

$BASE/xenserver-core/macgen.py   

#A dirty trick to hack the xenserver database
sed -c -i 's:### END INIT INFO:### END INIT INFO\n/bin/cp -f /var/lib/xcp/state.db.bak /var/lib/xcp/state.db\n/bin/cp -f /root/openvswitch.bak /etc/rc.d/init.d/openvswitch:' /etc/rc.d/init.d/openvswitch

echo "Stage 2 finished. Waiting for 10 seconds before rebooting..."
sleep 10
reboot
