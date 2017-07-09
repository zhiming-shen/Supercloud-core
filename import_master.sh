#!/bin/bash                                                                          

. config.sh


set -x
nameserver=$NAMESERVER
IP_SUFFIX=$IPSUFFIX
STACK_SUFFIX=$((IPSUFFIX+50))

set -e
#MAKE SURE to unmount if script does not run to completion

mkdir -p $TEMP/snapshots
cd $TEMP/snapshots
wget http://fireless.cs.cornell.edu/%7Ezshen/master.xva.tgz
tar xzf master.xva.tgz
cd ..


xe vm-import filename=snapshots/master.xva
xe vm-param-set name-label=$HOSTNAME uuid=`xe vm-list name-label=master-100 --minimal`


STAGING_DIR=$($TEMP/devstack-stable-newton/tools/xen/scripts/manage-vdi open $HOSTNAME 0 1 | grep -o "/tmp/tmp.[[:alnum:]]*")

rm -f $STAGING_DIR/opt/stack/.ssh/known_hosts
cat /root/.ssh/id_rsa.pub >> $STAGING_DIR/opt/stack/.ssh/authorized_keys

cd $STAGING_DIR/etc/nova
#sed -c -i  "s/\(xenapi_connection_url = http:\/\/10\.8\.1\.\).*/\1$IP_SUFFIX/" nova.conf
#sed -i -c "s/\(my_ip = 10\.8\.1\.\).*/\1$STACK_SUFFIX/" nova.conf
#sed -c -i "s/\(verbose = True\)/\1\nsr_matching_filter=default-sr:true/" nova.conf
cd ..
#echo $HOSTNAME > hostname
#sed -c -i "s/master-100/$HOSTNAME/" hosts
#sed -c -i "s/\.151/.$STACK_SUFFIX/" hosts

cd network

#sed -c -i "s/.151/.$STACK_SUFFIX/" interfaces
#sed -c -i "s/.100/.$IP_SUFFIX/" interfaces
sed -c -i "s/\(dns-nameservers\).*/\1 $nameserver/" interfaces
sed -c -i "s:mtu 1400:mtu $guest_mtu:" interfaces

cd ~
$TEMP/devstack-stable-newton/tools/xen/scripts/manage-vdi close $HOSTNAME 0 1



xe vm-start name-label=$HOSTNAME

echo "DONE! log in to stack@10.8.1.$STACK_SUFFIX and start openstack"
#echo "sudo pip uninstall eventlet"
#echo "sudo pip install eventlet==0.15.2"
#echo "then rejoin stack"
