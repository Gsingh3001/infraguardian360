# InfraGuardian360 — HertzBeat Device Templates

Ready-to-use monitoring templates for enterprise and SME devices.
Drop YAML files into HertzBeat's define/ directory and restart.

## Network — Switches

| File | Device | Key metrics |
|---|---|---|
| cisco-catalyst-switch.yml | Cisco Catalyst 2960/3650/3850/9200/9300 | CPU, memory, per-port traffic, PoE, temperature |
| hp-aruba-switch.yml | HP/Aruba 2530/2540/2930/5400 | CPU, memory, per-port traffic, PoE |

## Network — Wireless

| File | Device | Key metrics |
|---|---|---|
| ubiquiti-unifi-ap.yml | Ubiquiti UniFi all models (UAP, U6) | Per-radio stats, client count, RSSI, channel utilisation |

## Network — Firewalls & Security

| File | Device | Key metrics |
|---|---|---|
| fortinet-fortigate.yml | Fortinet FortiGate all models | CPU, memory, VPN tunnels, sessions, interfaces |
| paloalto-firewall.yml | Palo Alto PA-Series, VM-Series | CPU, sessions, VPN tunnels, threats, HA state |
| cisco-asa-firewall.yml | Cisco ASA 5505–5585, Firepower | CPU, connections, VPN sessions, failover state |

## Virtualisation & SDN

| File | Device | Key metrics |
|---|---|---|
| vmware-nsx-manager.yml | VMware NSX-T / NSX-V Manager | Cluster status, transport nodes, edges, logical switches |

## Printers & MFPs

| File | Device | Key metrics |
|---|---|---|
| hp-laserjet-printer.yml | HP LaserJet/OfficeJet + Canon/Ricoh/Xerox/Kyocera | Toner CMYK%, page counts, trays, errors |
| samsung-printer.yml | Samsung Xpress/ProXpress/MultiXpress + HP-Samsung | Toner CMYK%, drum life, fuser life, scan jobs, page counts |

## How to load in HertzBeat

Copy YAML files to your server and restart:
```bash
cp config/hertzbeat/define/*.yml /path/to/hertzbeat/define/
docker restart ig360-hertzbeat
```

Templates appear under: Monitoring → Add Monitor → select device type

## SNMPv3 recommended for all network devices
```
Auth protocol:  SHA
Auth password:  your_auth_password
Priv protocol:  AES-128
Priv password:  your_priv_password
```

Never use SNMP v1/v2c "public" community string in production.

## Template coverage roadmap

Coming in v1.2:
- Cisco IP Phones (7800/8800 series)
- Ricoh/Konica Minolta MFPs
- VMware vSphere ESXi hosts
- Dell/HPE servers (iDRAC/iLO)
- Juniper SRX firewall
- Check Point firewall
- Arista switch
- Ruckus/CommScope APs