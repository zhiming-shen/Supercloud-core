#!/bin/bash

. /etc/xensource-inventory
iso_name=/opt/xensource/packages/iso/xs-tools-${PRODUCT_VERSION}.iso

skip_vm()
{
    local vm=$1

    #
    # skip if the vm is not started
    #
    local powerstate=`xe vm-param-get uuid=$vm param-name=power-state`
    if [ "$powerstate" != "running" ] ; then
        echo "  skipping since vm is not running."
        return 1
    fi
 
    #
    # Skip if there is a PV boot loader meaning this is not an HVM domain
    #
    local pvbootloader=`xe vm-param-get uuid=$vm param-name=PV-bootloader 2> /dev/null`
    if [ "$pvbootloader" != "" ] ; then
        echo "  skipping since this is a para-virtualized domain (not windows)."
        return 1
    fi

    #
    # Skip if the windows pv tools are already up to date.
    #
    local uptodate=`xe vm-param-get uuid=$vm param-name=PV-drivers-up-to-date`
    if [ "$uptodate" == "true" ] ; then
        echo "  skipping since windows pv tools are already up to date."
        return 1
    fi

    local pvmajor=`xe vm-param-get uuid=$vm param-name=PV-drivers-version param-key=major 2> /dev/null`
    local pvminor=`xe vm-param-get uuid=$vm param-name=PV-drivers-version param-key=minor 2> /dev/null`
    if [[ "$pvmajor" == "" && "$pvminor" == "" ]] ; then
        echo "  skipping since no windows pv tools are installed."
        return 1
    fi    

    if [[ "$pvmajor" < 4 ]] ; then
        echo "  skipping since the windows tools installed are too old to be auto-upgraded."
        return 1
    fi

    return 0
}

main()
{
    local vms=`xe vm-list --minimal`

    mkdir -p /root/xensetup 2> /dev/null
    mount -o loop $iso_name /root/xensetup 2> /dev/null

    for vm in `echo $vms | sed 's/,/ /g'` ; do
        local name=`xe vm-param-get uuid=$vm param-name=name-label`
        echo ""
        echo "Processing $name..."
       
        skip_vm $vm
        if [ $? == 0 ] ; then
            local domid=`xe vm-param-get uuid=$vm param-name=dom-id`
            echo "  updating windows pv tools for $domid"
            /opt/xensource/libexec/rexec_client $domid "xensetup.exe /S" < /root/xensetup/xensetup.exe
        fi

    done

    umount /root/xensetup 2> /dev/null
    rmdir -p /root/xensetup 2> /dev/null
}

if [ "$1" != "-q" ] ; then
    echo "Driver auto-upgrade is experimental and unsupported in this version of XenServer"
fi

main
