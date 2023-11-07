#!/bin/bash
#
# Info:			OpenWRT Wifi STA Syslog Reporter
# Filename:		wrtwifistareport.sh
# Usage:		This script gets called by cron every X minutes.
# 				#
#				# Force an immediate report via syslog to the collector server.
#				sh "/root/wrtwifistareport.sh"
#
# Installation:	
# 
# chmod +x "/root/wrtwifistareport.sh"
# LUCI: System / Scheduled Tasks / Add new row
# 	*/5 * * * * /bin/sh "/root/wrtwifistareport.sh" >/dev/null 2>&1
# Restart Cron:
# 	/etc/init.d/cron restart
dhcp_leases='/tmp/dhcp.leases'
# -----------------------------------------------------
# -------------- START OF FUNCTION BLOCK --------------
# -----------------------------------------------------
dumpLocalAssociatedStations ()
{
	#
	# Usage:				dumpLocalAssociatedStations
	# Returns:				iw dev <all wlan devices> station dump
	#						cumulated result.
	# Example Result:		"aa:bb:cc:dd:ee:ff|" (without newline at the end)
	#
	# Called By:			MAIN
	#
	# 
	# Get all wlan interfaces with sub-SSIDs:
	# e.g. wlan0, wlan0-1, wlan0-2, wlan1, wlan1-1, wlan1-2, ...
	iw dev | grep "wlan\|phy" | grep -v "phy#" | cut -d " " -f 2 | while read file;
	do
		#
		# "file" contains one SSID Wifi Interface, e.g. "wlan0-1"
		#
		# Get associated stations of current wlanX interface.
		# 	echo -n "$(iw dev "${file}" station dump 2> /dev/null | grep -Fi "on wlan" | cut -d " " -f 2 | sed "s/^/${file},/" | tr '\n' '|')"
		# 
		# Get authorized stations of current wlanX interface.
		echo -n "$(iw dev "${file}" station dump 2> /dev/null | grep "\(on ${file}\|authorized:*.\)" | grep -B 1 "^.*authorized:.*yes$" | grep -v "^.*authorized:.*$" | cut -d " " -f 2 | sed "s/^/${file},/" | tr '\n' '|')"
		# 
	done
	#
	# Content already returned because iw dev was called loudly.
	return
}

WrtPresenceDhcp() {
	#
	# Usage:				WrtPresenceDhcp
	# Returns:				Recover the mac address, ip address and hostname from dhcp.leases
	#                       Determines the number of devices sent per line to local syslog.
	#						Possibility of increasing or decreasing by changing maxLeases=10
	#
    awk -v maxLeases=10 -v OFS=';' '
        NF {
            lease = $2 OFS $3 OFS $4
            leases = (numLeases++ ? leases "|" : "") lease
            if ( numLeases == maxLeases ) {
                print leases
                numLeases = 0
            }
        }
        END {
            if ( numLeases ) {
                print leases
            }
        }
    ' "$dhcp_leases"
}
dumpWrtPresenceDhcp ()
{
	#
	# Usage:				dumpWrtPresenceDhcp
	# Returns:				Sends the dhcp.leases file to local syslog 1 line per second.
	#                       The number of lines depends on the number of devices per line defined
	#						in WrtPresenceDhcp.
	#
    while IFS= read -r leases; do
        echo "$leases" | logger -t "wrtdhcpleasesreport"
        sleep 1
    done < <(WrtPresenceDhcp)
}
# ---------------------------------------------------
# -------------- END OF FUNCTION BLOCK --------------
# ---------------------------------------------------
#
#
# 
# ---------------------------------------------------
# ----------------- SCRIPT MAIN ---------------------
# ---------------------------------------------------
# 
# Write associated STA client MAC addresses to local syslog.
# If a syslog-ng server is configured in LUCI, the log will be forwarded to it.
logger -t "wrtwifistareport" "$(echo "$(dumpLocalAssociatedStations)")"
dumpWrtPresenceDhcp
#
# For testing purposes only.
# echo "$(dumpLocalAssociatedStations)"
#
exit 0
