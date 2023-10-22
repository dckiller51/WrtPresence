# openwrt-presence

OpenWrt device presence detection bash script. Works accross multiple APs. Listens to events from OpenWrt logread via syslog-ng on a master AP "passively". Can resync "actively" by executing "wrtwifistareport" on slave APs every 5 minutes in case of missed events. Outputs "device A=[present/away]" events to a /tmp/ file and FIFOs. The information can be consumed by home automation or logger software. Presence/Away state is detected representative to the whole extent of a SSID and not limited to a single AP.

## Installation

### MASTER ROUTER or ACCESS POINT

```text

opkg update
opkg install bash
opkg remove logd
opkg install syslog-ng
```
