# InfraGuardian360 — HertzBeat Device Templates

26 production-ready monitoring templates.
Copy YAML files to HertzBeat's define/ directory and restart.

## Switches (3)
| File | Device |
|---|---|
| cisco-catalyst-switch.yml | Cisco Catalyst 2960/3650/3850/9200/9300 |
| hp-aruba-switch.yml | HP/Aruba 2530/2540/2930/5400 |
| arista-switch.yml | Arista EOS 7000/7500 series |

## Wireless (3)
| File | Device |
|---|---|
| ubiquiti-unifi-ap.yml | Ubiquiti UniFi all models |
| ruckus-ap.yml | Ruckus/CommScope R300–R850 |
| cisco-meraki-ap.yml | Cisco Meraki MR/MS/MX (API) |

## Firewalls (5)
| File | Device |
|---|---|
| fortinet-fortigate.yml | Fortinet FortiGate all models |
| paloalto-firewall.yml | Palo Alto PA-Series, VM-Series |
| cisco-asa-firewall.yml | Cisco ASA 5505–5585, Firepower |
| juniper-srx-firewall.yml | Juniper SRX300–SRX4100+ |
| checkpoint-firewall.yml | Check Point R80.x/R81.x |

## Virtualisation (4)
| File | Device |
|---|---|
| vmware-nsx-manager.yml | VMware NSX-T / NSX-V |
| vmware-vsphere-esxi.yml | VMware ESXi 6.5–8.0 |
| microsoft-hyperv.yml | Hyper-V Server 2016/2019/2022 |
| nutanix-ahv-cluster.yml | Nutanix AHV (API-based) |

## Servers (2)
| File | Device |
|---|---|
| dell-idrac.yml | Dell PowerEdge (iDRAC 7/8/9) |
| hpe-ilo-server.yml | HPE ProLiant (iLO 4/5/6) |

## Printers & MFPs (5)
| File | Device |
|---|---|
| hp-laserjet-printer.yml | HP LaserJet/OfficeJet + Canon/Kyocera |
| samsung-printer.yml | Samsung Xpress/ProXpress |
| ricoh-mfp-printer.yml | Ricoh IM/MP + Konica Minolta bizhub |
| xerox-mfp-printer.yml | Xerox AltaLink/VersaLink/WorkCentre |
| brother-printer.yml | Brother HL/DCP/MFC series |

## VoIP (3)
| File | Device |
|---|---|
| cisco-ip-phone.yml | Cisco 7800/8800/8900 series |
| yealink-ip-phone.yml | Yealink T2x/T4x/T5x/T6x series |
| avaya-ip-phone.yml | Avaya J100/9600 + Poly VVX series |

## How to load
```bash
cp config/hertzbeat/define/*.yml /opt/hertzbeat/define/
docker restart ig360-hertzbeat
```

Templates appear under: Monitoring → Add Monitor

## SNMPv3 for all network devices
```
Auth: SHA  |  Auth password: strong_password
Priv: AES  |  Priv password: strong_password
```