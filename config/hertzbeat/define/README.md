# InfraGuardian360 — HertzBeat Device Templates

Ready-to-use monitoring templates for enterprise and SME devices.
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

## Servers

| File | Device | Key metrics |
|---|---|---|
| dell-idrac.yml | Dell PowerEdge R/T/C series (iDRAC 7/8/9) | CPU · memory · disks · PSU · temperature · fans |

## Printers & MFPs

| File | Device | Key metrics |
|---|---|---|
| hp-laserjet-printer.yml | HP LaserJet/OfficeJet + Canon/Xerox/Kyocera | Toner CMYK% · pages · trays · errors |
| samsung-printer.yml | Samsung Xpress/ProXpress + HP-Samsung | Toner CMYK% · drum · fuser · scan jobs |
| ricoh-mfp-printer.yml | Ricoh IM/MP/SP + Konica Minolta bizhub | Toner · drum · fuser · transfer belt · A3 pages |

## VoIP

| File | Device | Key metrics |
|---|---|---|
| cisco-ip-phone.yml | Cisco 7800/8800/8900 series | Registration · MOS · jitter · packet loss · PoE |

## How to load in HertzBeat
```bash
# Copy to server
cp config/hertzbeat/define/*.yml /opt/hertzbeat/define/

# Restart HertzBeat
docker restart ig360-hertzbeat
```

Templates appear under: Monitoring → Add Monitor

## SNMPv3 for all network devices (production requirement)
```
Auth protocol:  SHA
Auth password:  strong_auth_password
Priv protocol:  AES-128
Priv password:  strong_priv_password
```

Never use SNMP v1/v2c with default "public" community in production.

## Template roadmap — v1.2

- HPE ProLiant (iLO 4/5)
- Cisco Meraki (API-based)
- Check Point firewall
- Ruckus / CommScope APs
- Xerox AltaLink MFPs
- Yealink IP phones
- Hyper-V cluster nodes
- VMware vSphere ESXi hosts
- AWS CloudWatch integration
- Azure Monitor integration