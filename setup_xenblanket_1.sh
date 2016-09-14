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
yum install transfig wget texi2html libaio-devel dev86 glibc-devel e2fsprogs-devel gitk mkinitrd iasl xz-devel bzip2-devel pciutils-libs pciutils-devel SDL-devel libX11-devel gtk2-devel bridge-utils PyXML qemu-common qemu-img mercurial libuuid-devel uuid uuid-devel openssl openssl-devel ncurses-devel ncurses python-devel texinfo yajl-devel ipxe-roms seabios glibc-devel.i686 ipxe-roms-qemu libtool libtool-ltdl-devel createrepo -y 

wget -P $TEMP/ $WEBSITE/ipxe-roms-qemu-20120328-3.gitaac9718.el6.centos.alt.noarch.rpm

rpm -ivh $TEMP/ipxe-roms-qemu-20120328-3.gitaac9718.el6.centos.alt.noarch.rpm

sed -c -i "s/\(HOSTNAME *= *\).*/\1$HOSTNAME/" /etc/sysconfig/network
sed -c -i "/^127.0.0.1/ s/$/ $HOSTNAME/" /etc/hosts 

touch /etc/sysconfig/iptables

service iptables restart
chkconfig iptables on



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

chkconfig xencommons on

set +x
echo "All completed. Edit grub to add xen-blanket. It should look like this:"
echo "title xen-blanket"
echo "	root (hd0,0)"
echo "	kernel /xen-4.2.2-blanket.gz tgt=0 dom0_mem=1G,max:1G cpuid_mask_ecx=0x80802001 cpuid_mask_edx=0x078bfbfd cpuid_mask_ext_ecx=0x00000001 cpuid_mask_ext_edx=0x2191abfd cpuid_mask_xsave_eax=0 smep=false"
echo "	module /vmlinuz-xxxxxxxxxx yyyyyyyyyyyyyyyyyyy console=hvc0 earlyprintk=xen"
echo "	module /initramfs-xxxxxxxxxxxxxxxxx"

