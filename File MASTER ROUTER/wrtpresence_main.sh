#/bin/bash
trap "" SIGHUP
#
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT
#
# set +m
#
# Filename:			wrtpresence_main.sh
# Usage:			Instanced by service wrapper.
# Purpose:			Tracks STA client associations across a WiFi backed by multiple APs.
# 
# Installation:
# 
# 	Generic advice:
# 		LUCI / System / System / Hostname
# 			Set hostname to "WifiAP-[01|02|03|..]" or adjust the variable to match your hostname convention.
# 				LOGREAD_SOURCE_PREFIX="WifiAP-.."
# 
# 	=========================
# 	== MASTER ACCESS POINT ==
# 	=========================
# 		... where this script is executed.
# 	opkg update
# 	opkg install bash
# 	opkg remove logd
# 	opkg install syslog-ng
# 	chmod +x "/root/wrtpresence"
# 	chmod +x "/root/wrtpresence_main.sh"
# 
# 	LUCI / System / Startup / Local Startup
# 		# sh /root/wrtpresence start
# 
# 	LUCI / System / System / Logging
# 		External system log server
# 			127.0.0.1
# 		Cron Log Level
# 			Warning
# 
# 	chmod +x "/root/wrtwifistareport.sh"
# 	LUCI: System / Scheduled Tasks / Add new row
# 		*/5 * * * * /bin/sh "/root/wrtwifistareport.sh" >/dev/null 2>&1
# 	Restart Cron:
# 		/etc/init.d/cron restart
#
# 	chmod +x "/root/wrtbtdevreport.sh"
# 	LUCI: System / Scheduled Tasks / Add new row
# 		*/1 * * * * /bin/sh "/root/wrtbtdevreport.sh" >/dev/null 2>&1
# 	Restart Cron:
# 		/etc/init.d/cron restart
# 
# 	========================
# 	== SLAVE ACCESS POINT ==
# 	========================
# 		... where WiFi STA clients may roam to/from.
# 	LUCI / System / System / Logging
# 		External system log server
# 			[IP_ADDRESS_OF_MASTER_ACCESS_POINT]
# 		Cron Log Level
# 			Warning
# 
# 	chmod +x "/root/wrtwifistareport.sh"
# 	LUCI: System / Scheduled Tasks / Add new row
# 		*/5 * * * * /bin/sh "/root/wrtwifistareport.sh" >/dev/null 2>&1
# 	Restart Cron:
# 		/etc/init.d/cron restart	
#
# Diagnostics:
#	Cleanup, Reset:
#		sh /root/wrtpresence clean
#	Logging and Monitoring:
#		sh /root/wrtpresence debug	
#		sh /root/wrtpresence showlog
#		sh /root/wrtpresence livelog
# 		sh /root/wrtpresence livestate
# 		sh /root/wrtpresence showstate
#
# Prerequisites:
# 	Configuration
#		LUCI / System /System / Logging
# 			External system log server
# 				127.0.0.1
# 		/etc/config/system
# 			option log_ip '127.0.0.1'
#	Files 
# 		wrtpresence								main service wrapper
# 		wrtpresence_main.sh						main service program
# 		wrtwifistareport.sh						cron job script for sync in case events got lost during reboot
# 		wrtbtdevreport.sh						cron job script for bluetooth scans
# 	Packages
# 		bash									required for arrays
# 		syslog-ng								required for log collection from other APs
# 
#
# For testing purposes only:
# 	killall logread; killall tail; sh wrtpresence stop; bash wrtpresence_main.sh debug
# 	kill -INT "$(cat "/tmp/wrtpresence_main.sh.pid")"
# 
#
# ====================
# Script Configuration
# ====================
PATH=/usr/bin:/usr/sbin:/sbin:/bin
# CURRENT_SCRIPT_PATH="$(cd "$(dirname "$0")"; pwd)"
EVENT_FIFO=/tmp/"$(basename "$0")".event_fifo
PID_FILE=/tmp/"$(basename "$0")".pid
LOGFILE="/tmp/wrtpresence.log"
LOG_MAX_LINES="1000"
DEBUG_MODE="0"
# -----------------------
# --- Function Import ---
# -----------------------
# 
# -----------------------------------------------------
# -------------- START OF FUNCTION BLOCK --------------
# -----------------------------------------------------
logAdd ()
{
	TMP_DATETIME="$(date '+%Y-%m-%d [%H-%M-%S]')"
	TMP_LOGSTREAM="$(tail -n ${LOG_MAX_LINES} ${LOGFILE} 2>/dev/null)"
	echo "${TMP_LOGSTREAM}" > "$LOGFILE"
	if [ "${1}" = "-q" ]; then
		# Quiet mode.
		echo "${TMP_DATETIME} ${@:2}" >> "${LOGFILE}"
	else
		# Loud mode.
		echo "${TMP_DATETIME} $*" | tee -a "${LOGFILE}"
	fi
	return
}

dumpDhcpLeases ()
{
    cat /tmp/dhcp.leases | awk '{print $2";"$3";"$4}' | tr '\n' '|'
	return
}

logreader() {
	#
	# Called by:	MAIN
	#
	# Send DHCP LEASES
	# 
	logAdd -q "[INFO] BEGIN logreader"
	#
	LOGREAD_BIN="$(which logread)"
	if ( opkg list "syslog-ng" | grep -q "syslog-ng" ); then
		# logread is provided by package "syslog-ng"
		LOGREAD_SOURCE_PREFIX="WifiAP-.."
	else
		# logread is provided by default package "logd"
		LOGREAD_SOURCE_PREFIX="daemon\.notice"
	fi
	#
	if [ ! -f "/var/log/messages" ]; then
		logAdd -q "[INFO] logreader: Waiting for /var/log/messages"
	fi
	while [ ! -f "/var/log/messages" ]; do
		sleep 2
	done
	logAdd -q "[INFO] BEGIN logreader_loop"
	${LOGREAD_BIN} -f | while read line; do
		if $(echo -n "${line}" | grep -q "${LOGREAD_SOURCE_PREFIX}.*hostapd.*\(AP-STA-CONNECTED\)"); then
			if $(echo -n "${line}" | grep -q "AP-STA-CONNECTED"); then
				sh /root/wrtwifistareport.sh restart
			fi
		fi
	done
}
# ---------------------------------------------------
# -------------- END OF FUNCTION BLOCK --------------
# ---------------------------------------------------





















































#
# Check prerequisites.
if [ -f "/usr/sbin/syslog-ng" ]; then
	# syslog-ng is installed.
	# Check if 'external log server ip' is set correctly to forward the local logread to syslog-ng.
	if ( ! grep -q "option log_ip '127\.0\.0\.1'$" "/etc/config/system" ); then
		logAdd "[ERROR] You are using syslog-ng without forwarding the local syslog output to it. Set \"option log_ip '127.0.0.1'\". Stop."
		exit 99
	fi
	#
else
	logAdd "[WARN] syslog-ng is not installed. Only this AP will be monitored. Run \"opkg install syslog-ng\" if you need to monitor multiple APs."
fi
# 
if ( ! grep -q "network(ip(\"0\.0\.0\.0\") port(514)" "/etc/syslog-ng.conf" ); then
	logAdd "[WARN] syslog-ng is NOT configured to listen for incoming syslog messages from slave access points. Trying to fix ..."
	sed -i -e "s/network(ip(\".*[\"]/network(ip(\"0.0.0.0\"/g" "/etc/syslog-ng.conf"
	sed -i -e "s/network_localhost(/network(ip(\"0.0.0.0\") port(514) transport(udp) ip-protocol(6)/g" "/etc/syslog-ng.conf"
	#
	# Recheck.
	if ( ! grep -q "network(ip(\"0\.0\.0\.0\") port(514)" "/etc/syslog-ng.conf" ); then
		logAdd "[ERROR] syslog-ng is NOT configured to listen for incoming syslog messages from slave access points. Stop."
		exit 99
	fi
	/etc/init.d/syslog-ng restart
	logAdd "[INFO] Successfully reconfigured syslog-ng."
fi
# 
if ( ! grep -q "option cronloglevel '9'$" "/etc/config/system" ); then
	logAdd "[WARN] Cron log level is not reduced to \"warning\" in \"/etc/config/system\". Set \"option cronloglevel '9'\"."
fi
#
# Check commmand line parameters.
case "$1" in 
'debug')
	# Turn DEBUG_MODE on.
	DEBUG_MODE="1"
	# Continue script execution.
	;;
esac
#
# Service Startup.
#
if [ "${DEBUG_MODE}" = "0" ]; then
	logAdd "[INFO] Service was restarted."
	sleep 10
else
	# Log message.
	logAdd "*************"
	logAdd "[INFO] Service was restarted in DEBUG_MODE."
	# 
fi
# Store script PID.
echo "$$" > "${PID_FILE}"
#
# Fork two permanently running background processes.
logreader &
#
# Wait for kill -INT from service stub.
wait
#
# We should never reach here.
#
logAdd "[INFO] End of script reached."
exit 0
