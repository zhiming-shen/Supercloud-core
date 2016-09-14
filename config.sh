
WEBSITE="http://fireless.cs.cornell.edu/supercloud/downloads"
BASE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -P )"

TEMP="/root/workspace_supercloud"   #recommend 10GB free in this directory

IPSUFFIX=103   #controller is fixed to 1
host_mtu=1500
guest_mtu=1360   #typically host_mtu-100

#local_ip=10.2.0.4   #not used anymore

is_gateway=false


######1. required for setting up controller######

NFS_ROOT="/root/nfsroot"


######2. required for setting up xen-blanket######


HOSTNAME=azure-103
platform=hyperv    #xen/kvm/hyperv


######3. xen-server and openstack specific config######
use_dhcp=true
staticip_dns=128.253.180.2
staticip_gateway=192.168.139.1
staticip_ip=192.168.139.41

NAMESERVER=192.168.139.1
is_compute=false
GUEST_NAME=$(hostname)
GUEST_IPSUFFIX=$((IPSUFFIX+50))

#root password of Domain-0
host_passwd=qzpm123098

#password of the openstack VM
guest_passwd=qzpm123098

#password of the openstack services
openstack_passwd=qzpm123098

GIT_OPENSTACK="https://git.openstack.org/openstack-dev/devstack"
