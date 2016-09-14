#!/usr/bin/python
# macgen.py script to generate a MAC address for guests on Xen
#
import random
import os
#
def randomMAC():
	mac = [ 0x00, 0x16, 0x3e,
		random.randint(0x00, 0x7f),
		random.randint(0x00, 0xff),
		random.randint(0x00, 0xff) ]
	return ':'.join(map(lambda x: "%02x" % x, mac))
#
for i in range(3):
	mac = randomMAC()
	print mac
	os.system("sed -i '0,/fe:ff:ff:ff:ff:ff/s//%s/' /var/lib/xcp/state.db.bak" % (mac))
