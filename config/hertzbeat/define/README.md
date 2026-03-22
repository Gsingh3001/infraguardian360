# InfraGuardian360 — HertzBeat Device Templates

21 production-ready monitoring templates.
Copy YAML files to HertzBeat's define/ directory and restart.

## Network — Switches

| File | Device | Key metrics |
|---|---|---|
| cisco-catalyst-switch.yml | Cisco Catalyst 2960/3650/3850/9200/9300 | CPU · ports · PoE · temperature |
| hp-aruba-switch.yml | HP/Aruba 2530/2540/2930/5400 | CPU · ports · PoE |
| arista-switch.yml | Arista EOS 7000/7500 series | CPU · ports · BGP · MLAG · environment |

## Network — Wireless

| File | Device | Key metrics |
|---|---|---|
| ubiquiti-unifi-ap.yml | Ubiquiti UniFi all models (UAP, U6) | Per-radio · clients · RSSI · channel |
| ruckus-ap.yml | Ruckus/CommScope R300–R850 + T-series outdoor | Per-radio · clients · noise floor · retries |
| cisco-meraki-ap.yml | Cisco Meraki MR/MS/MX (cloud-managed) | API-based · device status · clients · uplinks |

## Network — Firewalls & Security

| File | Device | Key metrics |
|---|---|---|
| fortinet-fortigate.yml | Fortinet FortiGate all models | CPU · VPN · sessions · interfaces |
| paloalto-firewall.yml | Palo Alto PA-Series, VM-Series | CPU · sessions · VPN · threats · HA |
| cisco-asa-firewall.yml | Cisco ASA 5505–5585, Firepower | CPU · connections · VPN · failover |
| juniper-srx-firewall.yml | Juniper SRX300–SRX4100+ | CPU · BGP · VPN · temperature · HA |

## Virtualisation & SDN

| File | Device | Key metrics |
|---|---|---|
| vmware-nsx-manager.yml | VMware NSX-T / NSX-V Manager | Cluster · transport nodes · edges |
| vmware-vsphere-esxi.yml | VMware ESXi 6.5/6.7/7.0/8.0 | CPU · memory · VMs · datastores · NICs |
| microsoft-hyperv.yml | Microsoft Hyper-V (Server 2016/2019/2022) | VMs · vCPU · memory balloon · vSwitch |

## Servers

| File | Device | Key metrics |
|---|---|---|
| dell-idrac.yml | Dell PowerEdge R/T/C series (iDRAC 7/8/9) | CPU · memory · disks · PSU · temperature · fans |
| hpe-ilo-server.yml | HPE ProLiant DL/ML series (iLO 4/5/6) | CPU · memory · disks · PSU · temperature · fans |

## Printers & MFPs

| File | Device | Key metrics |
|---|---|---|
| hp-laserjet-printer.yml | HP LaserJet/OfficeJet + Canon/Kyocera | Toner CMYK% · pages · trays · errors |
| samsung-printer.yml | Samsung Xpress/ProXpress + HP-Samsung | Toner · drum · fuser · scan jobs |
| ricoh-mfp-printer.yml | Ricoh IM/MP + Konica Minolta bizhub | Toner · drum · fuser · transfer belt · A3 |
| xerox-mfp-printer.yml | Xerox AltaLink/VersaLink/WorkCentre | Toner · drum · fuser · waste toner |

## VoIP

| File | Device | Key metrics |
|---|---|---|
| cisco-ip-phone.yml | Cisco 7800/8800/8900 series | Registration · MOS · jitter · packet loss |
| yealink-ip-phone.yml | Yealink T2x/T4x/T5x/T6x series | SIP registration · MOS · jitter · LLDP info |

## How to load in HertzBeat
```bash
cp config/hertzbeat/define/*.yml /opt/hertzbeat/define/
docker restart ig360-hertzbeat
```

Templates appear under: Monitoring → Add Monitor

## SNMPv3 for all network devices
```
Auth protocol:  SHA
Auth password:  strong_auth_password
Priv protocol:  AES-128
Priv password:  strong_priv_password
```

## Special notes

**Cisco Meraki** — uses REST API only (no SNMP). Requires API key from
dashboard.meraki.com → Organization → API & Webhooks.

**VMware ESXi** — enable SNMP via:
`esxcli system snmp set --enable true --communities public`

**Hyper-V** — requires windows_exporter with Hyper-V collector:
Add `--collectors.enabled=cpu,cs,hyperv,logical_disk,memory,net,os,service`
to windows_exporter service arguments.

**HPE iLO** — enable SNMP in iLO web UI:
Administration → Management → SNMP Settings → Enable SNMP

## Roadmap — v1.3

- Check Point firewall
- Cisco Meraki MX (security appliance)
- Nutanix AHV cluster
- Pure Storage FlashArray
- NetApp ONTAP
- Avaya/Poly IP phones
- Brother printers
- Kyocera TASKalfa MFPs