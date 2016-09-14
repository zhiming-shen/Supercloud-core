import os
import sys

private_key = "/root/.ssh/id_rsa"

if len(sys.argv) == 2:
	private_key = sys.argv[1]


config = []
config_file = open("gateway_network.conf")
for line in config_file:
    vals = line.split()
    if len(vals) != 4 or vals[0][0] == '#':
        continue
        
    config.append(tuple(vals))
    
print "printing network config:"
for c in config:
    print c

os.system("chmod 600 id_rsa")
for id, private_ip, public_ip, data_center in config:
    print "====Configuring: %s====" % (id)
    tunnel_config = ""
    for m_id, m_private_ip, m_public_ip, m_data_center in config:
        if m_data_center == data_center:
            tunnel_config += "%s %s\n" % (m_id, m_private_ip)
        else:
            tunnel_config += "%s %s\n" % (m_id, m_public_ip)
    os.system("source ./config.sh; ssh -i %s %s \"echo '%s' > /$BASE/gateway_tunnels.txt\"" % (private_key, public_ip, tunnel_config))
    os.system("source ./config.sh; ssh -i %s %s \"cd $BASE; python set_gateway_tunnels.py %s gateway_tunnels.txt\"" % (private_key, public_ip, private_ip))
    #break;
