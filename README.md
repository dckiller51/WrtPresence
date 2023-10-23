# openwrt-presence

OpenWrt device presence detection bash script. Works accross multiple APs. Listens to events from OpenWrt logread via syslog-ng on a master AP "passively". Can resync "actively" by executing "wrtwifistareport" on slave APs every 5 minutes in case of missed events. Outputs "device A=[present/away]" events to a /tmp/ file and FIFOs. The information can be consumed by home automation or logger software. Presence/Away state is detected representative to the whole extent of a SSID and not limited to a single AP.

## Installation

The hostname is important. Apply a simple logic.

```text

WifiAP-01
WifiAP-02
WifiAP-XX
```

### MASTER ROUTER or ACCESS POINT

Copy the 3 files in folder ROOT.

```text
wrtpresence
wrtpresence_main.sh
wrtwifistareport.sh
```

Change file permissions

```text
chmod +x "/root/wrtpresence"
chmod +x "/root/wrtpresence_main.sh"
chmod +x "/root/wrtwifistareport.sh"
```

Install or remove the following packages

```text
opkg update
opkg install bash
opkg remove logd
opkg install syslog-ng
```

Add this command line to LUCI / System / Startup / Local Startup

```text
# sh /root/wrtpresence start
```

Setting logging parameters to LUCI / System / System / Logging

```text
External system log server 127.0.0.1
Cron Log Level Warning
```

Add a scheduled task to LUCI / System / Scheduled Tasks

```text
*/5 * * * * /bin/sh "/root/wrtwifistareport.sh" >/dev/null 2>&1
```

Restart Cron:

```text
/etc/init.d/cron restart
```

### SLAVE ACCESS POINT

Copy the files in folder ROOT.

```text
wrtwifistareport.sh
```

Change file permissions

```text
chmod +x "/root/wrtwifistareport.sh"
```

Setting logging parameters to LUCI / System / System / Logging

```text
External system log server [IP ADDRESS OF MASTER ROUTER or ACCESS POINT]
Cron Log Level Warning
```

Add a scheduled task to LUCI / System / Scheduled Tasks

```text
*/5 * * * * /bin/sh "/root/wrtwifistareport.sh" >/dev/null 2>&1
```

Restart Cron:

```text
/etc/init.d/cron restart
```
