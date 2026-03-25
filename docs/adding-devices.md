\# InfraGuardian360 — Adding Devices



Step-by-step guide for onboarding every supported device type.



\---



\## Before you start



All devices need:

1\. Network reachability from the InfraGuardian360 server (ping test)

2\. SNMP enabled (for network devices)

3\. The device added to NetBox (manually or via auto-discovery)



Test reachability from your server:

```bash

ping DEVICE\_IP

snmpwalk -v2c -c public DEVICE\_IP 1.3.6.1.2.1.1.1.0

```



\---



\## Cisco Catalyst Switch



\### Enable SNMPv3 on the switch

```

snmp-server group ig360group v3 priv

snmp-server user ig360user ig360group v3 auth sha YOUR\_AUTH\_PASS priv aes 128 YOUR\_PRIV\_PASS

snmp-server host YOUR\_SERVER\_IP version 3 priv ig360user

snmp-server location "Server Room A"

snmp-server contact "IT Team"

```



\### Add to HertzBeat

1\. Monitoring → Add Monitor → \*\*Cisco Catalyst Switch\*\*

2\. Host: switch IP address

3\. SNMP Version: v3

4\. Username: ig360user

5\. Auth Password: YOUR\_AUTH\_PASS

6\. Priv Password: YOUR\_PRIV\_PASS

7\. Click Confirm



\*\*What you get:\*\* CPU, memory, per-port traffic, PoE draw, temperature, fan status.



\---



\## HP / Aruba Switch



\### Enable SNMPv3

```

snmpv3 enable

snmpv3 user "ig360user" auth sha "YOUR\_AUTH\_PASS" priv aes "YOUR\_PRIV\_PASS"

snmp-server community "ig360ro" operator unrestricted

```



\### Add to HertzBeat

1\. Monitoring → Add Monitor → \*\*HP/Aruba Switch\*\*

2\. Host: switch IP address

3\. SNMP Version: v2c or v3

4\. Community: ig360ro

5\. Click Confirm



\---



\## Fortinet FortiGate Firewall



\### Enable SNMP

```

config system snmp community

&#x20; edit 1

&#x20;   set name "ig360"

&#x20;   set status enable

&#x20;   config hosts

&#x20;     edit 1

&#x20;       set ip YOUR\_SERVER\_IP/32

&#x20;     end

&#x20;   end

&#x20; next

end

config system snmp sysinfo

&#x20; set status enable

&#x20; set description "InfraGuardian360 Monitored"

end

```



\### Add to HertzBeat

1\. Monitoring → Add Monitor → \*\*Fortinet FortiGate Firewall\*\*

2\. Host: firewall management IP

3\. SNMP Version: v2c, Community: ig360

4\. Click Confirm



\*\*What you get:\*\* CPU, memory, VPN tunnel states, active sessions, interface traffic.



\---



\## Palo Alto Firewall



\### Enable SNMP (via web UI)

1\. Device → Setup → Operations → SNMP Setup

2\. Version: V2c

3\. Community String: ig360

4\. Add server: YOUR\_SERVER\_IP



\### Add to HertzBeat

1\. Monitoring → Add Monitor → \*\*Palo Alto Networks Firewall\*\*

2\. Host: firewall management IP

3\. Community: ig360

4\. Click Confirm



\*\*What you get:\*\* Management + dataplane CPU, session table, VPN tunnels, threat counts.



\---



\## Cisco ASA Firewall



\### Enable SNMP

```

snmp-server community ig360 ro

snmp-server host inside YOUR\_SERVER\_IP community ig360 version 2c

snmp-server enable traps

```



\### Add to HertzBeat

1\. Monitoring → Add Monitor → \*\*Cisco ASA Firewall\*\*

2\. Host: ASA management IP

3\. SNMP Version: v2c, Community: ig360

4\. Click Confirm



\---



\## Ubiquiti UniFi Access Point



\### Enable SNMP on UniFi Controller

1\. UniFi Controller → Settings → Services → SNMP

2\. Enable SNMP

3\. Community: ig360

4\. Apply to all APs



\### Add to HertzBeat

1\. Monitoring → Add Monitor → \*\*Ubiquiti UniFi Access Point\*\*

2\. Host: AP management IP

3\. SNMP Version: v2c, Community: ig360

4\. Click Confirm



\*\*What you get:\*\* Per-radio client count, RSSI, channel utilisation, throughput.



\---



\## HP LaserJet Printer



\### Enable SNMP (most HP printers have it on by default)

1\. Browse to `http://PRINTER\_IP`

2\. Settings → Security → Access Control

3\. Enable SNMP v1/v2 Read — community: public



\### Add to HertzBeat

1\. Monitoring → Add Monitor → \*\*HP LaserJet Printer\*\*

2\. Host: printer IP

3\. SNMP Version: v1, Community: public

4\. Click Confirm



\*\*What you get:\*\* Toner CMYK%, page counts (mono/colour/duplex), paper tray levels, errors.



\---



\## Samsung Printer



\### Enable SNMP

1\. Browse to `http://PRINTER\_IP`

2\. Settings → Network → SNMP

3\. Enable SNMP, Community: public



\### Add to HertzBeat

1\. Monitoring → Add Monitor → \*\*Samsung/HP-Samsung Printer\*\*

2\. Host: printer IP

3\. SNMP Version: v1, Community: public

4\. Click Confirm



\*\*What you get:\*\* Toner CMYK%, drum life%, fuser life%, scan job count, page counts.



\---



\## Ricoh / Konica Minolta MFP



\### Enable SNMP

1\. Browse to `http://PRINTER\_IP` (Web Image Monitor)

2\. Configuration → Network → SNMP

3\. Enable SNMPv1/v2, Read Community: public



\### Add to HertzBeat

1\. Monitoring → Add Monitor → \*\*Ricoh / Konica Minolta MFP\*\*

2\. Host: MFP IP

3\. SNMP Version: v1, Community: public

4\. Click Confirm



\*\*What you get:\*\* Toner CMYK%, drum%, fuser%, transfer belt%, A3 page count.



\---



\## Dell PowerEdge Server (iDRAC)



\### Enable SNMP on iDRAC

1\. iDRAC web UI → Configuration → System Settings

2\. SNMP Configuration → Enable SNMP

3\. Community string: ig360

4\. SNMP port: 161



\### Add to HertzBeat

1\. Monitoring → Add Monitor → \*\*Dell PowerEdge Server (iDRAC)\*\*

2\. Host: \*\*iDRAC IP\*\* (not OS IP)

3\. SNMP Version: v2c, Community: ig360

4\. Click Confirm



\*\*What you get:\*\* CPU health, DIMM status, disk health + predicted failure, PSU output W, temperature sensors, fan RPM.



\---



\## HPE ProLiant Server (iLO)



\### Enable SNMP on iLO

1\. iLO web UI → Administration → Management → SNMP Settings

2\. Enable SNMP

3\. Read Community: ig360



\### Add to HertzBeat

1\. Monitoring → Add Monitor → \*\*HPE ProLiant Server (iLO)\*\*

2\. Host: \*\*iLO IP\*\* (not OS IP)

3\. SNMP Version: v2c, Community: ig360

4\. Click Confirm



\---



\## VMware ESXi Host



\### Enable SNMP on ESXi

```bash

\# Run on ESXi host via SSH

esxcli system snmp set --enable true

esxcli system snmp set --communities ig360

esxcli system snmp set --targets YOUR\_SERVER\_IP@161/ig360

esxcli system snmp set --syscontact "IT Team"

esxcli system snmp set --syslocation "DC Rack A"

```



\### Add to HertzBeat

1\. Monitoring → Add Monitor → \*\*VMware ESXi Host\*\*

2\. Host: ESXi management IP

3\. SNMP Version: v2c, Community: ig360

4\. Click Confirm



\*\*What you get:\*\* Host CPU/memory%, VM inventory + power states, datastore capacity, NIC status.



\---



\## Microsoft Hyper-V Host



\### Prerequisites

The windows\_exporter must be installed with the Hyper-V collector enabled.



Run on each Hyper-V host (PowerShell as Administrator):

```powershell

.\\agents\\install-windows.ps1 -IG360Server "YOUR\_SERVER\_IP" -EnableHyperV

```



Or manually add the flag to windows\_exporter service:

```

\--collectors.enabled=cpu,cs,hyperv,logical\_disk,memory,net,os,service

```



\### Add to HertzBeat

1\. Monitoring → Add Monitor → \*\*Microsoft Hyper-V Host\*\*

2\. Host: Hyper-V host IP

3\. Port: 9182 (windows\_exporter)

4\. Click Confirm



\*\*What you get:\*\* VM inventory, vCPU%, memory balloon, virtual switch throughput.



\---



\## Cisco IP Phone



\### Enable SNMP on the phone

1\. On the phone: Settings → Network Configuration → SNMP Configuration

2\. SNMP: Enabled

3\. Community: public



\### Add to HertzBeat

1\. Monitoring → Add Monitor → \*\*Cisco IP Phone\*\*

2\. Host: phone IP

3\. SNMP Version: v2c, Community: public

4\. Click Confirm



\*\*What you get:\*\* Registration status, SIP server, MOS score, jitter, packet loss, PoE draw.



\---



\## Yealink IP Phone



\### Enable SNMP

1\. Browse to `http://PHONE\_IP`

2\. Features → General Information → SNMP

3\. SNMP: Active, Community: public



\### Add to HertzBeat

1\. Monitoring → Add Monitor → \*\*Yealink IP Phone\*\*

2\. Host: phone IP

3\. SNMP Version: v2c, Community: public

4\. Click Confirm



\---



\## Linux Server (any distribution)



\### Install agents

```bash

\# LLDP topology (shows which switch port this server is on)

curl -sSL https://raw.githubusercontent.com/Gsingh3001/infraguardian360/main/agents/install-lldpd.sh | bash



\# Prometheus metrics (CPU, memory, disk, network per NIC)

curl -sSL https://raw.githubusercontent.com/Gsingh3001/infraguardian360/main/agents/install-node-exporter.sh | bash



\# Log forwarding to OpenSearch

curl -sSL https://raw.githubusercontent.com/Gsingh3001/infraguardian360/main/agents/install-fluent-bit.sh | bash

```



\### Add to Prometheus scrape config

Edit `config/prometheus/prometheus.yml` and add:

```yaml

&#x20; - job\_name: 'linux-servers'

&#x20;   static\_configs:

&#x20;     - targets:

&#x20;         - 'SERVER\_IP:9100'

&#x20;       labels:

&#x20;         hostname: 'server-name'

&#x20;         role: 'web-server'

```



\---



\## Windows Server / Desktop



\### Install agents (PowerShell as Administrator)

```powershell

.\\agents\\install-windows.ps1 -IG360Server "YOUR\_SERVER\_IP"

```



This installs:

\- lldpd-win (LLDP topology)

\- windows\_exporter (CPU, memory, disk, NIC, services, Event Log)

\- Fluent Bit (Windows Event Log → OpenSearch)



\### Add to Prometheus scrape config

```yaml

&#x20; - job\_name: 'windows-servers'

&#x20;   static\_configs:

&#x20;     - targets:

&#x20;         - 'SERVER\_IP:9182'

&#x20;       labels:

&#x20;         hostname: 'server-name'

```



\---



\## Cisco Meraki (API-based)



\### Get API key

1\. Meraki Dashboard → Organization → API \& Webhooks

2\. Generate API key

3\. Note your Organization ID and Network ID



\### Add to HertzBeat

1\. Monitoring → Add Monitor → \*\*Cisco Meraki Cloud Network\*\*

2\. Host: api.meraki.com

3\. API Key: your key from dashboard

4\. Organization ID: your org ID

5\. Network ID: your network ID

6\. Click Confirm



\*\*What you get:\*\* Device online/offline, client counts, uplink status, switch port states.



\---



\## Troubleshooting



\*\*SNMP not responding\*\*

```bash

\# Test from server

snmpwalk -v2c -c public DEVICE\_IP 1.3.6.1.2.1.1.1.0

\# If timeout: check firewall allows UDP/161 from server to device

```



\*\*HertzBeat shows no data after adding monitor\*\*

\- Wait 30 seconds — first collection takes time

\- Check HertzBeat logs: `docker logs ig360-hertzbeat`

\- Verify SNMP community string matches exactly



\*\*Device added to NetBox but not showing in HertzBeat\*\*

\- NetBox and HertzBeat are separate — add device to HertzBeat manually

\- Or use the HertzBeat API to auto-import from NetBox (v1.2 roadmap)



\*\*Printer toner shows -1 or 0%\*\*

\- Some printers return -1 when supply level is unknown

\- Try SNMP v1 instead of v2c

\- Check vendor-specific MIB table for your exact model

