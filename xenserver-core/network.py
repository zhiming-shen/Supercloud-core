#!/usr/bin/env python

import sys, subprocess, os, os.path, platform
import xapi, interfaces, networkscripts

# Common, distribution-agnostic network interface configuration code.
# This is mostly code to interact with xapi and the user.

def list_devices(tui):
	"""Use xapi to query the PIFs on the local host"""
	x = xapi.open()	
	x.login_with_password("root", "")
	no_configuration = {
		"devices": [], # none will be managed by xapi
		"device_to_pif": {}
	}
	try:
		hosts = x.xenapi.host.get_all()
		if len(hosts) <> 1:
			print >>sys.stderr, "WARNING: cannot configuring networking if already pooled"
			return no_configuration
		pifs = x.xenapi.PIF.get_all_records()
		for pif in pifs:
			if pifs[pif]["management"]:
				print >>sys.stderr, "OK: found a configured management interface"
				return no_configuration
		if not(tui.yesno("Would you like me to set up host networking for XenServer?", False)):
			print >>sys.stderr, "WARNING: host networking is not set up"
			return no_configuration
		print "PIF scan %s" % hosts[0]
		x.xenapi.PIF.scan(hosts[0])
		print "PIF.get_all_records"
		pifs = x.xenapi.PIF.get_all_records()
		device_to_pif = {}
		devices = []
		for pif in pifs:
			pif_r = pifs[pif]
			devices.append(pif_r["device"])
			device_to_pif[pif_r["device"]] = pif
		devices.sort()
		return {
			"devices": devices,
			"device_to_pif": device_to_pif
		}
	finally:
		x.logout()

def choose_management(tui, config):
	"""Ask the user which PIF should be used for management traffic"""
	options = []
	for d in config["devices"]:
		options.append((d, "<insert description>",))
	if options == []:
		return config
	mgmt = tui.choose("Please select a management interface", options, options[0][0])
	config["management"] = mgmt
	return config

def configure(config, new_interfaces):
	"""Configure [new_interfaces] through the XenAPI"""
        x = xapi.open() 
        x.login_with_password("root", "")
        try:
		for device in new_interfaces:
			mode, address, netmask, gateway, dns = new_interfaces[device]
			if mode == "DHCP":
				print >> sys.stderr, "Configuring %s with DHCP" % device
			else:
				print >> sys.stderr, "Configuring %s with static IP %s netmask %s gateway %s DNS %s" % (device, mode, address, netmask, gateway, dns)
			x.xenapi.PIF.reconfigure_ip(config["device_to_pif"][device], mode, address, netmask, gateway, dns)
		if "management" in config:
			print >> sys.stderr, "Configuring %s as the management interface" % config["management"]
			x.xenapi.host.management_reconfigure(config["device_to_pif"][config["management"]])
        finally:
                x.logout()

debian_like = [ "ubuntu", "debian" ]
rhel_like = [ "fedora", "redhat", "centos" ]

def analyse(tui):
	config = list_devices(tui)
	config = choose_management(tui, config)
	result = None
	distribution = platform.linux_distribution()[0].lower()
	if distribution in debian_like:
		result = interfaces.analyse(tui, config)
	elif distribution in rhel_like:
		result = networkscripts.analyse(tui, config)
	if not result:
		return None
	file_changes, new_interfaces = result
	configure(config, new_interfaces)
	return file_changes

# Maybe time to start ... using OO?
def restart():
	distribution = platform.linux_distribution()[0].lower()
	if distribution in debian_like:
		interfaces.restart()
	elif distribution in rhel_like:
		networkscripts.restart()
