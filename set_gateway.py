import os
import sys
import time

gateway = sys.argv[1]

#print "setting default gateway: ", gateway

while True:
    eth0_mac = os.popen("ifconfig eth0 | grep HWaddr | awk '{print $5}'").read().strip()
    xenbr0_mac = os.popen("ifconfig xenbr0 | grep HWaddr | awk '{print $5}'").read().strip()
    #print "eth0_mac:", eth0_mac, " xenbr0_mac:", xenbr0_mac
    if eth0_mac != xenbr0_mac:
        print "setting mac to", eth0_mac
        os.system("ifconfig xenbr0 hw ether %s" % (eth0_mac))
        pid  = os.popen("cat /var/run/dhclient-xenbr0.pid").read().strip()
        if pid != '':
            os.system("kill %s" % (pid))
            os.system("/sbin/dhclient -q -pf /var/run/dhclient-xenbr0.pid -lf /var/lib/xcp/dhclient-xenbr0.leases -cf /var/lib/xcp/dhclient-xenbr0.conf xenbr0")
    
    current = os.popen("/sbin/ip route | awk '/default/ { print $3 }'").read().strip()
    if current == '':
        print "need to set the gateway"
        os.system("route add default gw %s" % (gateway))
    else:
        #print "gateway is fine"
        pass
    time.sleep(5)
