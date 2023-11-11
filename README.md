> :warning: **Work in progress**

# openwrt-presence (WrtPresence)

OpenWrt device presence detection bash script. Runs on multiple APs. Listens "passively" for events from the OpenWrt logread via syslog-ng on a master AP. Can "actively" resynchronise by running "wrtwifistareport" on slave APs every 5 minutes in the event of missed events. Events are transmitted to node-red. Node-red takes care of creating or updating your device_tracker. This is then transmitted to Homeassistant via MQTT.
There is no link with knows_device. You find your device in a WrtPresence MQTT device. You can view the attributes of each device, if your device changes access point it will update.
To delete a device, I recommend using MQTT Explorer.

OpenWrt -> node-red -> mqtt -> homeassitant

Exemple : device_tracker discovery:

topic = `homeassistant/device_tracker/ab12cd23ab12/config` (unique_id = Address mac)

```json
{
  "unique_id": "ab12cd23ab12", (Address mac)
  "name": "Computer HP", (hostname in openwrt if available in dhcp.leases otherwise mac address)
  "device": {
    "manufacturer": "Openwrt", (Can be modified in the MQTT Config node)
    "model": "Xiaomi Ax3600", (Can be modified in the MQTT Config node)
    "name": "WrtPresence", (Can be modified in the MQTT Config node)
    "identifiers": [
      "WrtPresence" (Can be modified in the MQTT Config node)
    ]
  },
  "state_topic": "openwrt/ab12cd23ab12/state", (unique_id = Address mac)
  "payload_home": "home",
  "payload_not_home": "not_home",
  "entity_category": "diagnostic",
  "json_attributes_topic": "openwrt/ab12cd23ab12/attributes" (unique_id = Address mac)
}
```

state = `openwrt/ab12cd23ab12/state` (unique_id = Address mac)

```json
home (or not_home)
```

attributes = `wrtpresence/ab12cd23ab12/attributes` (unique_id = Address mac)

```json
{
  "mac": "ab:12:cd:23:ab:12",
  "source_type": "WifiAP-02", (Device name Openwrt WifiAP-01 or WifiAP-02...)
  "source_ssid": "2.4ghz", (Names can be changed. See the two extract nodes (to make searching easier, write "table" in info))
  "ip": "192.x.x.x", (IP assigned in dhcp.leases)
  "host_name": "Computer HP", (hostname in openwrt if available in dhcp.leases otherwise mac address)
  "disconnected_idx": "0" (0 = connected, 1 à 10 = disconnected)
}
```

## Installation Openwrt

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

Setting syslog-ng.conf line to etc / syslog-ng.conf (example: view in the directory File MASTER ROUTER)

```text
line 55 change "IP node-red" to "192.XXX.XX.X"
line 56 port of your choice. Be careful if you change it, you will have to put the same one back in the syslog-input node.
line 68 By default, the line is commented out. You must uncomment it if you have slave access point.
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

## Configuration MQTT

You need a mosquitto server. Normally you don't need to change anything in this section. This is in node-red.

## Configuration Node-Red

Search the palette and install `node-red-contrib-syslog-input2`

Import the flow below

```json
[{"id":"c935ca7d01c176f7","type":"tab","label":"WrtPresence","disabled":false,"info":"","env":[]},{"id":"338bd89a0c3ccbdc","type":"syslog-input2","z":"c935ca7d01c176f7","name":"syslog","socktype":"udp","address":"","port":"21500","topic":"","x":330,"y":20,"wires":[["1d026c40d87342da","bb856d3cd8739cfd"]]},{"id":"34ce5b55c8510422","type":"mqtt out","z":"c935ca7d01c176f7","name":"SERVER","topic":"","qos":"","retain":"true","respTopic":"","contentType":"","userProps":"","correl":"","expiry":"","broker":"8739c3164bbbc25d","x":560,"y":540,"wires":[]},{"id":"b294334543a55806","type":"function","z":"c935ca7d01c176f7","name":"MQTT State","func":"msg.topic = `wrtpresence/${msg.payload.dev_id}/state`\nmsg.payload = msg.payload.location_name\nreturn msg;","outputs":1,"timeout":0,"noerr":0,"initialize":"","finalize":"","libs":[],"x":330,"y":540,"wires":[["34ce5b55c8510422"]]},{"id":"835251192a393877","type":"function","z":"c935ca7d01c176f7","name":"MQTT State attributes","func":"var a = msg.payload.hostname;\nvar b = \"*\";\nif (a == b) {\n    msg.payload.hostname = msg.payload.dev_id\n}else{\n    msg.payload.hostname = msg.payload.hostname\n}//Update host_name (*)\n\nmsg.topic = `wrtpresence/${msg.payload.dev_id}/attributes`\nmsg.payload = {\n    \"mac\": `${msg.payload.mac}`,\n    \"source_type\": `${msg.payload.source_type}`,\n    \"source_ssid\": `${msg.payload.source_ssid}`,\n    \"ip\": `${msg.payload.ip}`,\n    \"host_name\": `${msg.payload.hostname}`,\n    \"disconnected_idx\": `${msg.payload.disconnected_idx}`,\n    }\nreturn msg;","outputs":1,"timeout":0,"noerr":0,"initialize":"","finalize":"","libs":[],"x":360,"y":580,"wires":[["34ce5b55c8510422"]]},{"id":"a6c375948a0f77d2","type":"delay","z":"c935ca7d01c176f7","name":"","pauseType":"delay","timeout":"4","timeoutUnits":"seconds","rate":"1","nbRateUnits":"1","rateUnits":"second","randomFirst":"1","randomLast":"5","randomUnits":"seconds","drop":false,"allowrate":false,"outputs":1,"x":100,"y":580,"wires":[["835251192a393877"]]},{"id":"2449acd9a58aecd5","type":"delay","z":"c935ca7d01c176f7","name":"","pauseType":"delay","timeout":"2","timeoutUnits":"seconds","rate":"1","nbRateUnits":"1","rateUnits":"second","randomFirst":"1","randomLast":"5","randomUnits":"seconds","drop":false,"outputs":1,"x":100,"y":540,"wires":[["b294334543a55806"]]},{"id":"927338cfb9f3ab23","type":"function","z":"c935ca7d01c176f7","name":"MQTT Config","func":"var a = msg.payload.hostname;\nvar b = \"*\";\nif (a == b) {\n    msg.payload.hostname = msg.payload.dev_id\n}else{\n    msg.payload.hostname = msg.payload.hostname\n}//Update host_name (*)\n\nmsg.topic = `homeassistant/device_tracker/${msg.payload.dev_id}/config`\nmsg.payload = {\n    \"unique_id\": `${msg.payload.dev_id}`,\n    \"name\": `${msg.payload.hostname}`,\n    \"device\": {\n        \"manufacturer\": \"Openwrt\",\n        \"model\": \"Xiaomi Ax3600\",\n        \"name\": \"WrtPresence\",\n        \"identifiers\": [\n            \"wrtpresence\"\n        ]\n    },\n    \"state_topic\": `wrtpresence/${msg.payload.dev_id}/state`,\n    \"payload_home\": \"home\",\n    \"payload_payload_not_home\": \"not_home\",\n    \"entity_category\": \"diagnostic\",\n    \"json_attributes_topic\": `wrtpresence/${msg.payload.dev_id}/attributes`\n}\nreturn msg;","outputs":1,"timeout":0,"noerr":0,"initialize":"","finalize":"","libs":[],"x":340,"y":500,"wires":[["34ce5b55c8510422"]]},{"id":"1d026c40d87342da","type":"switch","z":"c935ca7d01c176f7","name":"WRTASSOCIATIONSREPORT","property":"payload.tag","propertyType":"msg","rules":[{"t":"eq","v":"wrtassociationreport","vt":"str"}],"checkall":"true","repair":false,"outputs":1,"x":170,"y":80,"wires":[["6e2691b580178010"]]},{"id":"6e2691b580178010","type":"change","z":"c935ca7d01c176f7","name":"Replace","rules":[{"t":"set","p":"payload","pt":"msg","to":"$replace(payload.msg, \"|\", \"\\n\")","tot":"jsonata"}],"action":"","property":"","from":"","to":"","reg":false,"x":100,"y":120,"wires":[["f256e5d1abb29460"]]},{"id":"f256e5d1abb29460","type":"split","z":"c935ca7d01c176f7","name":"","splt":"\\n","spltType":"str","arraySplt":"1","arraySpltType":"len","stream":false,"addname":"","x":90,"y":160,"wires":[["bc6aafeaff0d6d29"]]},{"id":"bc6aafeaff0d6d29","type":"switch","z":"c935ca7d01c176f7","name":"Check value \"null\"","property":"payload","propertyType":"msg","rules":[{"t":"nempty"}],"checkall":"true","repair":false,"outputs":1,"x":130,"y":200,"wires":[["5e6122fa66de7550"]]},{"id":"5e6122fa66de7550","type":"change","z":"c935ca7d01c176f7","name":"Extract","rules":[{"t":"set","p":"payload","pt":"msg","to":"(\t  $table:={\t    \"phy0-ap0\" : \"IOT\",\t    \"phy2-ap0\" : \"2.4ghz\",\t    \"phy1-ap0\" : \"5ghz\"\t    };\t\t    payload#$i.(\t        $data:=$split($, \"=\");\t        $source:=$substring($data[0], 0, 9);\t        $ssid:=$substringAfter($data[0], \"_\");\t        $dev_id:=$split($data[1],(\":\"))~> $join('');\t        $counter:=$data[2]~>$substringBefore(\" \")~>$number();\t        $ishome:=$counter < 1 ? \"home\" : \"not_home\";\t\t        {\t          \"dev_id\": $dev_id,\t          \"source_type\": $source,\t          \"source_ssid\": $lookup($table,$ssid),\t          \"mac\": $data[1],\t          \"location_name\": $ishome,\t          \"disconnected_idx\": $counter\t        }\t    )\t)","tot":"jsonata"},{"t":"set","p":"topic","pt":"msg","to":"$substring(payload.dev_id, 0, 12)","tot":"jsonata"},{"t":"move","p":"payload","pt":"msg","to":"associations","tot":"msg"}],"action":"","property":"","from":"","to":"","reg":false,"x":100,"y":240,"wires":[["8418b58cef1dff5e"]]},{"id":"bb856d3cd8739cfd","type":"switch","z":"c935ca7d01c176f7","name":"WRTDHCPLEASESREPORT","property":"payload.tag","propertyType":"msg","rules":[{"t":"eq","v":"wrtdhcpleasesreport","vt":"str"}],"checkall":"true","repair":false,"outputs":1,"x":510,"y":80,"wires":[["cdd1e6c51560411c"]]},{"id":"cdd1e6c51560411c","type":"change","z":"c935ca7d01c176f7","name":"Replace","rules":[{"t":"set","p":"payload","pt":"msg","to":"$replace(payload.msg, \"|\", \"\\n\")","tot":"jsonata"}],"action":"","property":"","from":"","to":"","reg":false,"x":440,"y":120,"wires":[["5d898e83cec6988d"]]},{"id":"5d898e83cec6988d","type":"split","z":"c935ca7d01c176f7","name":"","splt":"\\n","spltType":"str","arraySplt":"1","arraySpltType":"len","stream":false,"addname":"","x":430,"y":160,"wires":[["7087d289ed6a9e9b"]]},{"id":"7087d289ed6a9e9b","type":"switch","z":"c935ca7d01c176f7","name":"Check value \"null\"","property":"payload","propertyType":"msg","rules":[{"t":"nempty"}],"checkall":"true","repair":false,"outputs":1,"x":470,"y":200,"wires":[["2f593bb6b72265f8"]]},{"id":"2f593bb6b72265f8","type":"change","z":"c935ca7d01c176f7","name":"Extract","rules":[{"t":"set","p":"payload","pt":"msg","to":"(\t  payload#$i.( \t    $data:=$split($, \";\");\t    $dev_id:=$split($data[0],(\":\"))~> $join('');\t\t    {\t        \"dev_id\": $dev_id,\t        \"mac\": $data[0],\t        \"ip\":   $data[1],\t        \"host\": $data[2]\t    }\t  )\t)","tot":"jsonata"},{"t":"set","p":"topic","pt":"msg","to":"$substring(payload.dev_id, 0, 12)","tot":"jsonata"},{"t":"move","p":"payload","pt":"msg","to":"dhcp_leases","tot":"msg"}],"action":"","property":"","from":"","to":"","reg":false,"x":440,"y":240,"wires":[["c72cb9dcbca2aa5a"]]},{"id":"478a797fdbaa54ba","type":"function","z":"c935ca7d01c176f7","name":"Fetch Associations","func":"if (typeof context.counter === 'undefined')\n{\n    context.counter =0;\n}\ncontext.counter ++;\nmsg.payload = context.counter;\nmsg.parts = {};\nmsg.parts.id = msg.topic;\nmsg.parts.index = 0;\nmsg.parts.count = 2;\nreturn msg;","outputs":1,"timeout":"","noerr":0,"initialize":"","finalize":"","libs":[],"x":130,"y":360,"wires":[["44a16e18d4f145d4"]]},{"id":"c72cb9dcbca2aa5a","type":"function","z":"c935ca7d01c176f7","name":"Fetch Dhcp_Leases","func":"if (typeof context.counter === 'undefined')\n{\n    context.counter=0;\n}\ncontext.counter++;\nmsg.payload = context.counter;\nmsg.parts = {};\nmsg.parts.id = msg.topic;\nmsg.parts.index = 1;\nmsg.parts.count = 2;\nreturn msg;","outputs":1,"timeout":"","noerr":0,"initialize":"","finalize":"","libs":[],"x":480,"y":280,"wires":[["58f673a3ed994b05"]]},{"id":"44a16e18d4f145d4","type":"join","z":"c935ca7d01c176f7","name":"Connected devices join details with dhcp leases","mode":"auto","build":"object","property":"","propertyType":"full","key":"topic","joiner":"\\n","joinerType":"str","accumulate":false,"timeout":"","count":"","reduceRight":false,"reduceExp":"","reduceInit":"","reduceInitType":"","reduceFixup":"","x":320,"y":420,"wires":[["e6f5fa0bf3acfeab"]]},{"id":"e6f5fa0bf3acfeab","type":"change","z":"c935ca7d01c176f7","name":"Checks every 5 min","rules":[{"t":"move","p":"associations","pt":"msg","to":"payload","tot":"msg"},{"t":"move","p":"dhcp_leases.ip","pt":"msg","to":"payload.ip","tot":"msg"},{"t":"move","p":"dhcp_leases.host","pt":"msg","to":"payload.hostname","tot":"msg"},{"t":"delete","p":"dhcp_leases","pt":"msg"}],"action":"","property":"","from":"","to":"","reg":false,"x":330,"y":460,"wires":[["2449acd9a58aecd5","a6c375948a0f77d2","927338cfb9f3ab23"]]},{"id":"58f673a3ed994b05","type":"delay","z":"c935ca7d01c176f7","name":"","pauseType":"delay","timeout":"2","timeoutUnits":"seconds","rate":"1","nbRateUnits":"1","rateUnits":"second","randomFirst":"1","randomLast":"5","randomUnits":"seconds","drop":false,"outputs":1,"x":440,"y":320,"wires":[["44a16e18d4f145d4"]]},{"id":"7f1f9f4164a7007a","type":"rbe","z":"c935ca7d01c176f7","name":"Remove Mac 2 STA ","func":"rbe","gap":"2","start":"","inout":"in","septopics":false,"property":"associations.disconnected_idx","topi":"topic","x":140,"y":320,"wires":[["478a797fdbaa54ba"]]},{"id":"8418b58cef1dff5e","type":"switch","z":"c935ca7d01c176f7","name":"Check disconnect_idx","property":"associations.disconnected_idx","propertyType":"msg","rules":[{"t":"eq","v":"0","vt":"num"},{"t":"neq","v":"0","vt":"num"}],"checkall":"true","repair":false,"outputs":2,"x":140,"y":280,"wires":[["478a797fdbaa54ba"],["7f1f9f4164a7007a"]]},{"id":"8739c3164bbbc25d","type":"mqtt-broker","name":"Mosquitto broker","broker":"192.168.2.9","port":"1883","clientid":"node-red","autoConnect":true,"usetls":false,"protocolVersion":"4","keepalive":"60","cleansession":true,"autoUnsubscribe":true,"birthTopic":"","birthQos":"0","birthRetain":"false","birthPayload":"","birthMsg":{},"closeTopic":"","closeQos":"0","closeRetain":"false","closePayload":"","closeMsg":{},"willTopic":"","willQos":"0","willRetain":"false","willPayload":"","willMsg":{},"userProps":"","sessionExpiry":""}]
```

In the syslog node, match the port defined in syslog-ng.conf.
In the mqtt out nodes, set or select your mqtt server.

## Special Thanks

A special thanks you to everyone who helped me with this project in one way or another.

* **Catfriend1** (The author of the bash code) [Github][github]
* **Biscuit** (Help with Node-red) [Community Home Assistant][community-home-assistant]
* **Ed Morton** and **jhnc** (Help with bash code) [Stackoverflow][stackoverflow]

<!-- References -->

[github]: https://github.com/
[community-home-assistant]: https://community.home-assistant.io/
[stackoverflow]: https://stackoverflow.com/
