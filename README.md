> :warning: **Work in progress**

# openwrt-presence (WrtPresence)

OpenWrt device presence detection bash script. Runs on multiple APs. Listens "passively" for events from the OpenWrt logread via syslog-ng on a master AP. Can "actively" resynchronise by running "wrtwifistareport" on slave APs every 5 minutes in the event of missed events. Events are transmitted to node-red. Node-red takes care of creating or updating your device-tracker. This is then transmitted to Homeassistant via MQTT.

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
  "device_ssid": "2.4ghz", (Names can be changed. See the two extract nodes (to make searching easier, write "table" in info))
  "ip": "192.x.x.x", (IP assigned in dhcp.leases)
  "host_name": "Computer HP" (hostname in openwrt if available in dhcp.leases otherwise mac address)
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
[{"id":"46d1f98bb3df7e02","type":"tab","label":"WrtPresence","disabled":false,"info":"","env":[]},{"id":"94cb066d0f8fce1b","type":"syslog-input2","z":"46d1f98bb3df7e02","name":"syslog","socktype":"udp","address":"","port":"21500","topic":"","x":430,"y":20,"wires":[["a8abc76be880282b","1394a0bb4898a6f3","62c6fc3bf151a6ef"]]},{"id":"a8abc76be880282b","type":"switch","z":"46d1f98bb3df7e02","name":"HOSTAPD","property":"payload.tag","propertyType":"msg","rules":[{"t":"eq","v":"hostapd","vt":"str"}],"checkall":"true","repair":false,"outputs":1,"x":750,"y":80,"wires":[["926abc2502d1b189","11615149a7240221"]]},{"id":"920514881f26d719","type":"switch","z":"46d1f98bb3df7e02","name":"Check","property":"associations.check","propertyType":"msg","rules":[{"t":"eq","v":"AP-STA-CONNECTED","vt":"str"},{"t":"eq","v":"AP-STA-DISCONNECTED","vt":"str"}],"checkall":"true","repair":false,"outputs":2,"x":730,"y":200,"wires":[["749529347003af6a"],["954aee4a17479f85"]]},{"id":"091b58a00e76ef17","type":"change","z":"46d1f98bb3df7e02","name":"Extract","rules":[{"t":"set","p":"associations","pt":"msg","to":"(\t  $table:={\t    \"phy0-ap0\" : \"IOT\",\t    \"phy2-ap0\" : \"2.4ghz\",\t    \"phy1-ap0\" : \"5ghz\"\t    };\t\t    payload.msg#$i.(\t        $data:=$split($, \" \");\t        $dev_id:=$split($data[2],(\":\"))~> $join('');        \t        $dev_ssid:=$substringBefore($data[0], \":\");\t\t        {\t          \"id\": $substring($dev_id, 0, 12),\t          \"device_ssid\": $lookup($table,$dev_ssid),\t          \"mac\": $substring($data[2], 0, 17),\t          \"check\": $data[1]\t        }\t    )\t)","tot":"jsonata"},{"t":"set","p":"associations.device","pt":"msg","to":"payload.hostname","tot":"msg"}],"action":"","property":"","from":"","to":"","reg":false,"x":740,"y":160,"wires":[["920514881f26d719"]]},{"id":"926abc2502d1b189","type":"switch","z":"46d1f98bb3df7e02","name":"AP-STA-CONNECTED","property":"payload.msg","propertyType":"msg","rules":[{"t":"cont","v":"AP-STA-CONNECTED","vt":"str"}],"checkall":"true","repair":false,"outputs":1,"x":780,"y":120,"wires":[["091b58a00e76ef17"]]},{"id":"11615149a7240221","type":"switch","z":"46d1f98bb3df7e02","name":"AP-STA-DISCONNECTED","property":"payload.msg","propertyType":"msg","rules":[{"t":"cont","v":"AP-STA-DISCONNECTED","vt":"str"}],"checkall":"true","repair":false,"outputs":1,"x":1020,"y":120,"wires":[["091b58a00e76ef17"]]},{"id":"e9199bf27336148b","type":"mqtt out","z":"46d1f98bb3df7e02","name":"CONFIG","topic":"","qos":"","retain":"true","respTopic":"","contentType":"","userProps":"","correl":"","expiry":"","broker":"8739c3164bbbc25d","x":760,"y":520,"wires":[]},{"id":"7d3b7b9ec54c1cbd","type":"function","z":"46d1f98bb3df7e02","name":"MQTT State","func":"msg.topic = `wrtpresence/${msg.device.dev_id}/state`\nmsg.payload = msg.device.location_name\nreturn msg;","outputs":1,"timeout":0,"noerr":0,"initialize":"","finalize":"","libs":[],"x":410,"y":580,"wires":[["889ecd6ac4727f4c"]]},{"id":"a96940532c9ee8d4","type":"mqtt out","z":"46d1f98bb3df7e02","name":"STATE ATTRIBUTES","topic":"","qos":"","retain":"true","respTopic":"","contentType":"","userProps":"","correl":"","expiry":"","broker":"8739c3164bbbc25d","x":800,"y":640,"wires":[]},{"id":"8e257fb5af8572fd","type":"function","z":"46d1f98bb3df7e02","name":"MQTT State attributes","func":"var a = msg.device.host_name;\nvar b = \"*\";\nif (a == b) {\n    msg.device.host_name = msg.device.dev_id\n}else{\n    msg.device.host_name = msg.device.host_name\n}//Update host_name (*)\n\nmsg.topic = `wrtpresence/${msg.device.dev_id}/attributes`\nmsg.payload = {\n    \"mac\": `${msg.device.mac}`,\n    \"source_type\": `${msg.device.device}`,\n    \"device_ssid\": `${msg.device.device_ssid}`,\n    \"ip\": `${msg.device.ip}`,\n    \"host_name\": `${msg.device.host_name}`\n    }\nreturn msg;","outputs":1,"timeout":0,"noerr":0,"initialize":"","finalize":"","libs":[],"x":440,"y":640,"wires":[["a96940532c9ee8d4"]]},{"id":"329fe97a34733f3a","type":"delay","z":"46d1f98bb3df7e02","name":"","pauseType":"delay","timeout":"4","timeoutUnits":"seconds","rate":"1","nbRateUnits":"1","rateUnits":"second","randomFirst":"1","randomLast":"5","randomUnits":"seconds","drop":false,"allowrate":false,"outputs":1,"x":120,"y":640,"wires":[["8e257fb5af8572fd"]]},{"id":"00f81abd7786d483","type":"delay","z":"46d1f98bb3df7e02","name":"","pauseType":"delay","timeout":"2","timeoutUnits":"seconds","rate":"1","nbRateUnits":"1","rateUnits":"second","randomFirst":"1","randomLast":"5","randomUnits":"seconds","drop":false,"outputs":1,"x":120,"y":580,"wires":[["7d3b7b9ec54c1cbd"]]},{"id":"889ecd6ac4727f4c","type":"mqtt out","z":"46d1f98bb3df7e02","name":"STATE","topic":"","qos":"","retain":"true","respTopic":"","contentType":"","userProps":"","correl":"","expiry":"","broker":"8739c3164bbbc25d","x":750,"y":580,"wires":[]},{"id":"d3b3908dfdd95213","type":"function","z":"46d1f98bb3df7e02","name":"MQTT Config","func":"var a = msg.device.host_name;\nvar b = \"*\";\nif (a == b) {\n    msg.device.host_name = msg.device.dev_id_device\n}else{\n    msg.device.host_name = msg.device.host_name\n}//Update host_name (*)\n\nmsg.topic = `homeassistant/device_tracker/${msg.device.dev_id}/config`\nmsg.payload = {\n    \"unique_id\": `${msg.device.dev_id}`,\n    \"name\": `${msg.device.host_name}`,\n    \"device\": {\n        \"manufacturer\": \"Openwrt\",\n        \"model\": \"Xiaomi Ax3600\",\n        \"name\": \"WrtPresence\",\n        \"identifiers\": [\n            \"wrtpresence\"\n        ]\n    },\n    \"state_topic\": `wrtpresence/${msg.device.dev_id}/state`,\n    \"payload_home\": \"home\",\n    \"payload_not_home\": \"not_home\",\n    \"entity_category\": \"diagnostic\",\n    \"json_attributes_topic\": `wrtpresence/${msg.device.dev_id}/attributes`\n}\nreturn msg;","outputs":1,"timeout":0,"noerr":0,"initialize":"","finalize":"","libs":[],"x":420,"y":520,"wires":[["e9199bf27336148b"]]},{"id":"1394a0bb4898a6f3","type":"switch","z":"46d1f98bb3df7e02","name":"WRTWIFISTAREPORT","property":"payload.tag","propertyType":"msg","rules":[{"t":"eq","v":"wrtwifistareport","vt":"str"}],"checkall":"true","repair":false,"outputs":1,"x":150,"y":80,"wires":[["512ff5e06ece569f"]]},{"id":"987eb3d20f1e6bc4","type":"change","z":"46d1f98bb3df7e02","name":"Extract","rules":[{"t":"set","p":"device","pt":"msg","to":"(\t  $table:={\t    \"phy0-ap0\" : \"IOT\",\t    \"phy2-ap0\" : \"2.4ghz\",\t    \"phy1-ap0\" : \"5ghz\"\t    };\t\t    payload#$i.(\t        $data:=$substringAfter($,  \",\");\t        $dev_id:=$split($data,(\":\"))~> $join('');        \t        $dev_ssid:=$substringBefore($, \",\");\t\t        {\t          \"dev_id\": $substring($dev_id, 0, 12),\t          \"device_ssid\": $lookup($table,$dev_ssid),\t          \"mac\": $substring($data, 0, 17)\t        }\t    )\t)","tot":"jsonata"},{"t":"move","p":"associations.device","pt":"msg","to":"device.device","tot":"msg"},{"t":"set","p":"device.location_name","pt":"msg","to":"home","tot":"str"},{"t":"delete","p":"associations","pt":"msg"},{"t":"delete","p":"topic","pt":"msg"}],"action":"","property":"","from":"","to":"","reg":false,"x":100,"y":240,"wires":[["a3d923bc06bf077b"]]},{"id":"512ff5e06ece569f","type":"change","z":"46d1f98bb3df7e02","name":"","rules":[{"t":"move","p":"payload.hostname","pt":"msg","to":"associations.device","tot":"msg"},{"t":"set","p":"payload","pt":"msg","to":"payload.msg#$i.(\t    $data:=$replace($, \"|\", \"\\n\");\t    {\t        \"split\": $data\t    }\t)","tot":"jsonata"},{"t":"move","p":"payload.split","pt":"msg","to":"payload","tot":"msg"}],"action":"","property":"","from":"","to":"","reg":false,"x":140,"y":120,"wires":[["2a11ce5c9eb44f14"]]},{"id":"2a11ce5c9eb44f14","type":"split","z":"46d1f98bb3df7e02","name":"","splt":"\\n","spltType":"str","arraySplt":"1","arraySpltType":"len","stream":false,"addname":"","x":90,"y":160,"wires":[["d3e8d75eb7f32026"]]},{"id":"749529347003af6a","type":"change","z":"46d1f98bb3df7e02","name":"Home","rules":[{"t":"set","p":"associations.check","pt":"msg","to":"home","tot":"str"},{"t":"move","p":"associations.check","pt":"msg","to":"associations.location_name","tot":"msg"},{"t":"delete","p":"topic","pt":"msg"}],"action":"","property":"","from":"","to":"","reg":false,"x":850,"y":200,"wires":[["976750b9f9ff74bc"]]},{"id":"954aee4a17479f85","type":"change","z":"46d1f98bb3df7e02","name":"Not_home","rules":[{"t":"set","p":"associations.check","pt":"msg","to":"not_home","tot":"str"},{"t":"move","p":"associations.check","pt":"msg","to":"associations.location_name","tot":"msg"}],"action":"","property":"","from":"","to":"","reg":false,"x":990,"y":200,"wires":[["976750b9f9ff74bc"]]},{"id":"d3e8d75eb7f32026","type":"switch","z":"46d1f98bb3df7e02","name":"Check value \"null\"","property":"payload","propertyType":"msg","rules":[{"t":"nempty"}],"checkall":"true","repair":false,"outputs":1,"x":130,"y":200,"wires":[["987eb3d20f1e6bc4"]]},{"id":"62c6fc3bf151a6ef","type":"switch","z":"46d1f98bb3df7e02","name":"WRTDHCPLEASESREPORT","property":"payload.tag","propertyType":"msg","rules":[{"t":"eq","v":"wrtdhcpleasesreport","vt":"str"}],"checkall":"true","repair":false,"outputs":1,"x":470,"y":80,"wires":[["f481c90df1db7818"]]},{"id":"f481c90df1db7818","type":"change","z":"46d1f98bb3df7e02","name":"","rules":[{"t":"set","p":"payload","pt":"msg","to":"payload.msg#$i.(\t    $data:=$replace($, \"|\", \"\\n\");\t    {\t        \"split\": $data\t    }\t)","tot":"jsonata"},{"t":"move","p":"payload.split","pt":"msg","to":"payload","tot":"msg"}],"action":"","property":"","from":"","to":"","reg":false,"x":440,"y":120,"wires":[["3ebdef9a98da01d1"]]},{"id":"3ebdef9a98da01d1","type":"split","z":"46d1f98bb3df7e02","name":"","splt":"\\n","spltType":"str","arraySplt":"1","arraySpltType":"len","stream":false,"addname":"","x":390,"y":160,"wires":[["017d59034aa121ab"]]},{"id":"74eae9bcf7a6e71f","type":"change","z":"46d1f98bb3df7e02","name":"Extract","rules":[{"t":"set","p":"dhcp_leases","pt":"msg","to":"(\t  payload#$i.( \t    $data:=$split($, \";\");\t    $dev_id:=$split($data[0],(\":\"))~> $join('');\t\t    {\t      \"dev_id\": $dev_id,\t      \"mac\": $data[0],\t      \"ip\":   $data[1],\t      \"host\": $data[2]\t    }\t  )\t)","tot":"jsonata"}],"action":"","property":"","from":"","to":"","reg":false,"x":400,"y":240,"wires":[["dd46722b2ab74c03"]]},{"id":"017d59034aa121ab","type":"switch","z":"46d1f98bb3df7e02","name":"Check value \"null\"","property":"payload","propertyType":"msg","rules":[{"t":"nempty"}],"checkall":"true","repair":false,"outputs":1,"x":430,"y":200,"wires":[["74eae9bcf7a6e71f"]]},{"id":"a3d923bc06bf077b","type":"function","z":"46d1f98bb3df7e02","name":"Fetch Associations","func":"if (typeof context.counter === 'undefined')\n{\n    context.counter =0;\n}\ncontext.counter ++;\nmsg.payload = context.counter;\nmsg.parts = {};\nmsg.parts.id = msg.device.dev_id;\nmsg.parts.index = 0;\nmsg.parts.count = 2;\nreturn msg;","outputs":1,"timeout":"","noerr":0,"initialize":"","finalize":"","libs":[],"x":130,"y":280,"wires":[["e604d5768cd2b5e6"]]},{"id":"dd46722b2ab74c03","type":"function","z":"46d1f98bb3df7e02","name":"Fetch Dhcp_Leases","func":"if (typeof context.counter === 'undefined')\n{\n    context.counter=0;\n}\ncontext.counter++;\nmsg.payload = context.counter;\nmsg.parts = {};\nmsg.parts.id = msg.dhcp_leases.dev_id;\nmsg.parts.index = 1;\nmsg.parts.count = 2;\nreturn msg;","outputs":1,"timeout":"","noerr":0,"initialize":"","finalize":"","libs":[],"x":440,"y":280,"wires":[["2dd5cce52ace2be8"]]},{"id":"e604d5768cd2b5e6","type":"join","z":"46d1f98bb3df7e02","name":"Connected devices join details with dhcp leases","mode":"auto","build":"object","property":"payload","propertyType":"msg","key":"topic","joiner":"\\n","joinerType":"str","accumulate":true,"timeout":"","count":"","reduceRight":false,"reduceExp":"","reduceInit":"","reduceInitType":"","reduceFixup":"","x":280,"y":380,"wires":[["b553335bf930ab4f"]]},{"id":"b553335bf930ab4f","type":"change","z":"46d1f98bb3df7e02","name":"Checks every 5 min","rules":[{"t":"move","p":"dhcp_leases.ip","pt":"msg","to":"device.ip","tot":"msg"},{"t":"move","p":"dhcp_leases.host","pt":"msg","to":"device.host_name","tot":"msg"},{"t":"delete","p":"dhcp_leases","pt":"msg"}],"action":"","property":"","from":"","to":"","reg":false,"x":270,"y":420,"wires":[["d3b3908dfdd95213","00f81abd7786d483","329fe97a34733f3a"]]},{"id":"2dd5cce52ace2be8","type":"delay","z":"46d1f98bb3df7e02","name":"","pauseType":"delay","timeout":"2","timeoutUnits":"seconds","rate":"1","nbRateUnits":"1","rateUnits":"second","randomFirst":"1","randomLast":"5","randomUnits":"seconds","drop":false,"outputs":1,"x":400,"y":320,"wires":[["e604d5768cd2b5e6"]]},{"id":"976750b9f9ff74bc","type":"change","z":"46d1f98bb3df7e02","name":"Update home / not_home","rules":[{"t":"move","p":"associations.id","pt":"msg","to":"device.dev_id","tot":"msg"},{"t":"move","p":"associations.location_name","pt":"msg","to":"device.location_name","tot":"msg"},{"t":"delete","p":"associations","pt":"msg"}],"action":"","property":"","from":"","to":"","reg":false,"x":790,"y":240,"wires":[["63239f6451adf30c"]]},{"id":"63239f6451adf30c","type":"delay","z":"46d1f98bb3df7e02","name":"","pauseType":"delay","timeout":"5","timeoutUnits":"seconds","rate":"1","nbRateUnits":"1","rateUnits":"second","randomFirst":"1","randomLast":"5","randomUnits":"seconds","drop":false,"allowrate":false,"outputs":1,"x":740,"y":280,"wires":[["7d3b7b9ec54c1cbd"]]},{"id":"52b60929a338ae60","type":"debug","z":"46d1f98bb3df7e02","name":"debug 233","active":true,"tosidebar":true,"console":false,"tostatus":false,"complete":"true","targetType":"full","statusVal":"","statusType":"auto","x":550,"y":700,"wires":[]},{"id":"221f8ba34ec7d360","type":"api-render-template","z":"46d1f98bb3df7e02","name":"wireless devices total","server":"631a8a25.74d9f4","version":0,"template":"{{ states.device_tracker|list|count }}\n{{ states.device_tracker|selectattr('attributes.source_type','eq','WifiAP-01')|list|count }}\n{{ states.device_tracker|selectattr('attributes.source_type','eq','WifiAP-02')|list|count }}\n{{ states.device_tracker|selectattr('attributes.device_ssid','eq','5ghz')|list|count }}\n{{ states.device_tracker|selectattr('attributes.device_ssid','eq','2.4ghz')|list|count }}\n{{ states.device_tracker|selectattr('attributes.device_ssid','eq','IOT')|list|count }}","resultsLocation":"payload","resultsLocationType":"msg","templateLocation":"template","templateLocationType":"msg","x":340,"y":700,"wires":[["52b60929a338ae60"]]},{"id":"f244046655e26009","type":"inject","z":"46d1f98bb3df7e02","name":"","props":[{"p":"payload"},{"p":"topic","vt":"str"}],"repeat":"","crontab":"","once":false,"onceDelay":0.1,"topic":"","payload":"","payloadType":"date","x":130,"y":700,"wires":[["221f8ba34ec7d360"]]},{"id":"8739c3164bbbc25d","type":"mqtt-broker","name":"Mosquitto broker","broker":"192.168.2.9","port":"1883","clientid":"node-red","autoConnect":true,"usetls":false,"protocolVersion":"4","keepalive":"60","cleansession":true,"autoUnsubscribe":true,"birthTopic":"","birthQos":"0","birthRetain":"false","birthPayload":"","birthMsg":{},"closeTopic":"","closeQos":"0","closeRetain":"false","closePayload":"","closeMsg":{},"willTopic":"","willQos":"0","willRetain":"false","willPayload":"","willMsg":{},"userProps":"","sessionExpiry":""},{"id":"631a8a25.74d9f4","type":"server","name":"Home Assistant","addon":true}]
```

In the syslog node, match the port defined in syslog-ng.conf.
In the mqtt out nodes, set or select your mqtt server.

## Special Thanks

A special thanks you to everyone who helped me with this project in one way or another.

* **Catfriend1** (The author of the bash code) [Github][github]
* **Biscuit** (Help with Node-red) [Community home-assistant][Community home-assistant]
* **Ed Morton** (Help with bash code) [Stackoverflow][stackoverflow]

<!-- References -->

[github]: https://github.com/
[Community home-assistant]: https://community.home-assistant.io/
[stackoverflow]: https://stackoverflow.com/
