import os
import sys

local_pub_ip = sys.argv[1]
file_name = sys.argv[2]

bridge_prefix = "brvif"
bridges = ["1.4", "1.5", "1.6"]
tunnel_prefix = "gateway"
port_numbers = [1655, 1665, 1675]

tunnels = {}
fd = open(file_name)
for line in fd:
    vals = line.split()
    if len(vals) != 2: 
        continue
    tunnels[vals[0]] = vals[1]
    


    
    
for index, bridge in enumerate(bridges):
    bridge_name = bridge_prefix + bridge
    tunnel_name = tunnel_prefix + bridge
    port_number = port_numbers[index]
    
    for key, ip in tunnels.items():
        tunnel_key = "%s-%s" % (tunnel_name, key)
        if ip == local_pub_ip:
            print "skipping self ip"
            continue
        
        cur_setup = os.popen("ovs-vsctl show | grep -C 3 'Port \"%s\"' | tail -n 3" % (tunnel_key)).read()
        if len(cur_setup) == 0:
            print "adding a new tunnel:", tunnel_key
            os.system("ovs-vsctl add-port %s %s -- set interface %s type=vxlan options:remote_ip=%s options:key=flow options:dst_port=%s" % (tunnel_name, tunnel_key, tunnel_key, ip, port_number))
        elif cur_setup.find("remote_ip=\"%s\"" % (ip)) == -1:
            print "deleting a conflict setup for tunnel:", tunnel_key
            os.system("ovs-vsctl del-port %s %s" % (tunnel_name, tunnel_key))
            os.system("ovs-vsctl add-port %s %s -- set interface %s type=vxlan options:remote_ip=%s options:key=flow options:dst_port=%s" % (tunnel_name, tunnel_key, tunnel_key, ip, port_number))
        else:
            print "skipping existing tunnel key ", tunnel_key
        
        
print "all finished"
