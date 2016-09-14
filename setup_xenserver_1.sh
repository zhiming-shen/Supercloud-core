#!/bin/bash

set -x

. config.sh

yum install -y wget vim screen

if [ ! -d "$TEMP" ]; then
    mkdir -p $TEMP
fi

cd $TEMP
wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
wget http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
sudo rpm -Uvh remi-release-6*.rpm epel-release-6*.rpm

set -e

yum groupinstall -y "Development Tools"
yum install transfig wget texi2html libaio-devel dev86 glibc-devel e2fsprogs-devel gitk mkinitrd iasl xz-devel bzip2-devel pciutils-libs pciutils-devel SDL-devel libX11-devel gtk2-devel bridge-utils PyXML qemu-common qemu-img mercurial libuuid-devel uuid uuid-devel openssl openssl-devel ncurses-devel ncurses python-devel texinfo yajl-devel ipxe-roms seabios glibc-devel.i686 ipxe-roms-qemu libtool libtool-ltdl-devel createrepo ipxe-roms-qemu -y

sed -c -i "s/\(HOSTNAME *= *\).*/\1$HOSTNAME/" /etc/sysconfig/network
sed -c -i "/^127.0.0.1/ s/$/ $HOSTNAME/" /etc/hosts 

touch /etc/sysconfig/iptables

service iptables restart
chkconfig iptables on

#Install openvswitch
cd $TEMP
wget $WEBSITE/openvswitch-2.3.0.tar.gz
tar xzf openvswitch-2.3.0.tar.gz
cd openvswitch-2.3.0
./configure --prefix=/usr
make
make install
cp rhel/etc_init.d_openvswitch /etc/init.d/openvswitch
modprobe openvswitch
#echo "openvswitch" > /etc/modprobe.d/openvswitch.conf
service openvswitch start
chkconfig openvswitch on
iptables -I INPUT -m state --state NEW -p udp --dport 4789 -s 0.0.0.0/0 -j ACCEPT
service iptables save


#Install Xenserver core

yum install -y mock redhat-lsb-core
cd $TEMP
wget $WEBSITE/buildroot-0.10.0-ovs.tgz
tar xzf buildroot-0.10.0-ovs.tgz
cd buildroot-0.10.0
./configure.sh
make
make install

cd $BASE/xenserver-core/xapi
./copy.sh

sed -c -i 's/if use_bkp_footer:/#if use_bkp_footer:/' /usr/lib/xapi/sm/FileSR.py
sed -c -i "s/qopts += 'b'/#qopts += 'b'/" /usr/lib/xapi/sm/FileSR.py

sed -c -i "s:/opt/xensource/sm/:/usr/lib/xapi/sm/:" /usr/lib/xapi/plugins/nfs-on-slave

xenserver-install-wizard

xe pif-scan host-uuid=$(xe host-list minimal=true)

if [ "$use_dhcp" = true ]; then
    xe pif-reconfigure-ip uuid=$(xe pif-list device=eth0 minimal=true) mode=DHCP
else
    xe pif-reconfigure-ip DNS=$staticip_dns gateway=$staticip_gateway IP=$staticip_ip netmask=255.255.255.0 uuid=$(xe pif-list device=eth0 minimal=true) mode=static
fi

sed -c -i "s/\(ONBOOT *= *\).*/\1no/" /etc/sysconfig/network-scripts/ifcfg-eth0 

echo "ifconfig eth0 up" >> /etc/rc.local
echo "sleep 10" >> /etc/rc.local
echo "python $BASE/set_gateway.py $(/sbin/ip route | awk '/default/ { print $3 }') &" >> /etc/rc.local
echo "xe host-set-hostname-live host-uuid=$(xe host-list --minimal) host-name=$HOSTNAME" >> /etc/rc.local
echo "xe host-param-set name-label=$HOSTNAME uuid=$(xe host-list --minimal)" >> /etc/rc.local

sed -c -i 's/TIMEOUTclose = 0/session = 600\nTIMEOUTclose = 600\nTIMEOUTbusy = 600\nTIMEOUTidle = 600/' /etc/xapi/xapissl.conf 
sed -c -i 's/TIMEOUTclose = 0/session = 600\nTIMEOUTclose = 600\nTIMEOUTbusy = 600\nTIMEOUTidle = 600/' /usr/libexec/xapi/xapissl

#Install new version of stunnel
cd $TEMP
wget $WEBSITE/stunnel-5.10.tar.gz
tar xzf stunnel-5.10.tar.gz
cd stunnel-5.10/
./configure --prefix=/usr
make
make install
    
#Install Xen-Blanket
mkdir -p $TEMP/BUILD/
yum install -y ipxe-roms-qemu
XEN_BLANKET_FOLDER=xen-4.2.2
if [ "$platform" = hyperv ]; then
    XEN_BLANKET_FOLDER=xen-4.2.2-hv
fi
wget -P $TEMP/BUILD/ $WEBSITE/$XEN_BLANKET_FOLDER.tgz
cd $TEMP/BUILD/          
tar xzf $XEN_BLANKET_FOLDER.tgz
cd $XEN_BLANKET_FOLDER
./configure --libdir=/usr/lib64
#make clean
make xen
make tools
make install-xen
make install-tools
#make clean
./configure
make tools
make install-tools

/bin/cp -f $TEMP/BUILD/$XEN_BLANKET_FOLDER/dist/install/user/sbin/tap-ctl /usr/sbin/tap-ctl
/bin/cp -f $TEMP/BUILD/$XEN_BLANKET_FOLDER/dist/install/user/sbin/tap-ctl /usr/lib64/blktap/sbin/tap-ctl
/bin/cp -f $TEMP/BUILD/$XEN_BLANKET_FOLDER/dist/install/usr/lib/xen/bin/tapdisk /usr/lib/xen/bin/tapdisk
/bin/cp -f $TEMP/BUILD/$XEN_BLANKET_FOLDER/dist/install/usr/lib/xen/bin/tapdisk /usr/lib64/blktap/libexec/tapdisk


cd $TEMP/BUILD/
if [ "$platform" = xen ]; then
    wget $WEBSITE/kernel.compiled.tgz
    tar xzf kernel.compiled.tgz
    cd kernel
    make -j4 all
    make modules_install install
    ln -s $TEMP/BUILD/kernel /usr/src/kernels/3.4.53-blanket
elif [ "$platform" = kvm ]; then
    #yum install -y kernel-3.4.46-8.el6.centos.alt kernel-devel-3.4.46-8.el6.centos.alt
    mkdir kernel-3.4.46
    cd kernel-3.4.46
    wget $WEBSITE/linux-3.4.46-8.el6.x86_64.tgz
    tar xzf linux-3.4.46-8.el6.x86_64.tgz
    cd linux-3.4.46-8.el6.x86_64
    make -j4 all
    make modules_install install
    ln -s $TEMP/BUILD/kernel-3.4.46/linux-3.4.46-8.el6.x86_64 /usr/src/kernels/3.4.46-blanket
    cd ..
    wget $WEBSITE/kvm_driver.tgz
    tar xzf kvm_driver.tgz
    cd kvm_driver
    make
    make install
elif [ "$platform" = hyperv ]; then
    mkdir kernel-3.4.46
    cd kernel-3.4.46
    wget $WEBSITE/linux-3.4.46-8.el6.x86_64.tgz
    tar xzf linux-3.4.46-8.el6.x86_64.tgz
    cd linux-3.4.46-8.el6.x86_64
    make -j4 all
    make modules_install install
    ln -s $TEMP/BUILD/kernel-3.4.46/linux-3.4.46-8.el6.x86_64 /usr/src/kernels/3.4.46-blanket
    cd ..
    wget $WEBSITE/hyperv_driver.tgz
    tar xzf hyperv_driver.tgz
    cd hyperv_driver
    make
    make install
fi


sed -c -i 's/xen.gz/xen-4.2.2-blanket.gz/' /boot/grub/menu.lst
sed -c -i "/xen-4.2.2-blanket.gz/ s/$/ tgt=0 dom0_mem=1G,max:1G cpuid_mask_ecx=0x80802001 cpuid_mask_edx=0x078bfbfd cpuid_mask_ext_ecx=0x00000001 cpuid_mask_ext_edx=0x2191abfd cpuid_mask_xsave_eax=0 smep=false/" /boot/grub/menu.lst

if [ "$platform" = xen ]; then
    sed -c -i 's/vmlinuz-3.6.11-2.el6.centos.alt.x86_64/vmlinuz-3.4.53-blanket/' /boot/grub/menu.lst
    sed -c -i 's/initramfs-3.6.11-2.el6.centos.alt.x86_64.img/initramfs-3.4.53-blanket.img/' /boot/grub/menu.lst
elif [ "$platform" = kvm ]; then
    sed -c -i 's/vmlinuz-3.6.11-2.el6.centos.alt.x86_64/vmlinuz-3.4.46-blanket/' /boot/grub/menu.lst
    sed -c -i 's/initramfs-3.6.11-2.el6.centos.alt.x86_64.img/initramfs-3.4.46-blanket.img/' /boot/grub/menu.lst
elif [ "$platform" = hyperv ]; then
    sed -c -i 's/vmlinuz-3.6.11-2.el6.centos.alt.x86_64/vmlinuz-3.4.46-blanket/' /boot/grub/menu.lst
    sed -c -i 's/initramfs-3.6.11-2.el6.centos.alt.x86_64.img/initramfs-3.4.46-blanket.img/' /boot/grub/menu.lst
fi
grubby --set-default=/boot/xen-4.2.2-blanket.gz
echo "All completed. Now check grub and rc.local, and then reboot. If your eth0 IP is in the range of 192.168.122.x, remember to do virsh net-edit default."

