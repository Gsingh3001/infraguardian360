\# InfraGuardian360 — Changelog



All notable changes are documented here.

Format follows \[Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

Versioning follows \[Semantic Versioning](https://semver.org/).



\---



\## \[Unreleased] — v1.0.0



\### Added

\- Phase 7 self-heal watchdog daemon with AI diagnosis via Claude API

\- GitHub Actions CI pipeline — 7 automated checks on every push

\- Weekly Trivy CVE scan — all Docker images scanned every Monday

\- Backup and restore script with optional Hetzner/S3 offsite upload

\- docker-compose.full.yml — single command to start all 5 phases

\- PR template and issue templates (bug report, template request)

\- CONTRIBUTING.md — contribution guide

\- CHANGELOG.md — this file



\---



\## \[0.5.0] — 2026-03-22 — Phase 5 Complete



\### Added

\- \*\*Phase 5 — Log Analytics stack\*\*

&#x20; - docker-compose.logging.yml

&#x20; - OpenSearch 2.12.0 with security enabled

&#x20; - OpenSearch Dashboards 2.12.0

&#x20; - Fluent Bit 3.0 — collects Docker, syslog, auth, systemd logs

&#x20; - ISM retention policies — 90-day hot, auto-delete

&#x20; - Index templates for all ig360-\* indices

&#x20; - parsers.conf — Docker, syslog-rfc3164/5424, nginx, JSON parsers



\---



\## \[0.4.0] — 2026-03-22 — Phase 4 Complete



\### Added

\- \*\*Phase 4 — APM stack\*\*

&#x20; - docker-compose.apm.yml

&#x20; - SigNoz 0.43.0 — APM, distributed tracing, service maps

&#x20; - ClickHouse 24.1.2 — trace and metrics backend

&#x20; - Zookeeper 3.7.1 — ClickHouse coordination

&#x20; - Jaeger 1.54 — deep distributed trace UI

&#x20; - SigNoz OTel Collector — dedicated APM telemetry pipeline

&#x20; - ClickHouse tuned for 16GB server — 40% memory cap

&#x20; - 30-day TTL on trace data

&#x20; - Prometheus scrape config for SigNoz internals



\---



\## \[0.3.0] — 2026-03-22 — Device Template Library Complete



\### Added

\- \*\*21 HertzBeat device monitoring templates\*\*



&#x20; Switches:

&#x20; - cisco-catalyst-switch.yml — Catalyst 2960/3650/3850/9200/9300

&#x20; - hp-aruba-switch.yml — HP/Aruba 2530/2540/2930/5400

&#x20; - arista-switch.yml — Arista EOS 7000/7500 series



&#x20; Wireless:

&#x20; - ubiquiti-unifi-ap.yml — UniFi all models (UAP, U6)

&#x20; - ruckus-ap.yml — Ruckus/CommScope R300–R850

&#x20; - cisco-meraki-ap.yml — Meraki MR/MS/MX (API-based)



&#x20; Firewalls:

&#x20; - fortinet-fortigate.yml — FortiGate all models

&#x20; - paloalto-firewall.yml — PA-Series, VM-Series

&#x20; - cisco-asa-firewall.yml — ASA 5505–5585, Firepower

&#x20; - juniper-srx-firewall.yml — SRX300–SRX4100+



&#x20; Virtualisation:

&#x20; - vmware-nsx-manager.yml — NSX-T / NSX-V Manager

&#x20; - vmware-vsphere-esxi.yml — ESXi 6.5/6.7/7.0/8.0

&#x20; - microsoft-hyperv.yml — Hyper-V Server 2016/2019/2022



&#x20; Servers:

&#x20; - dell-idrac.yml — PowerEdge R/T/C (iDRAC 7/8/9)

&#x20; - hpe-ilo-server.yml — ProLiant DL/ML (iLO 4/5/6)



&#x20; Printers:

&#x20; - hp-laserjet-printer.yml — LaserJet/OfficeJet + Canon/Kyocera

&#x20; - samsung-printer.yml — Xpress/ProXpress + HP-Samsung

&#x20; - ricoh-mfp-printer.yml — Ricoh IM/MP + Konica Minolta bizhub

&#x20; - xerox-mfp-printer.yml — AltaLink/VersaLink/WorkCentre



&#x20; VoIP:

&#x20; - cisco-ip-phone.yml — 7800/8800/8900 series

&#x20; - yealink-ip-phone.yml — T2x/T4x/T5x/T6x series



\---



\## \[0.2.0] — 2026-03-22 — Phases 2 \& 3 Complete



\### Added

\- \*\*Phase 2 — Network Discovery stack\*\*

&#x20; - docker-compose.discovery.yml

&#x20; - Netdisco — L2/L3 topology crawler

&#x20; - Netdisco worker and scheduler services

&#x20; - Netdisco dedicated PostgreSQL database

&#x20; - NetBox Discovery (Diode) agent

&#x20; - config/netdisco/netdisco.conf — full configuration

&#x20; - config/discovery/discovery.yml — Diode configuration

&#x20; - scripts/netdisco-to-netbox.py — 350-line Python sync script

&#x20;   - Reads Netdisco topology database

&#x20;   - Maps vendor strings to manufacturers

&#x20;   - Maps SNMP layer bitmaps to device roles

&#x20;   - Pushes to NetBox REST API

&#x20;   - Supports --dry-run mode



\- \*\*Phase 3 — Infrastructure Monitoring stack\*\*

&#x20; - docker-compose.monitoring.yml

&#x20; - Apache HertzBeat — 130+ monitor types

&#x20; - Prometheus with scrape configuration

&#x20; - VictoriaMetrics long-term metrics storage

&#x20; - OpenTelemetry Collector pipeline

&#x20; - Alertmanager with routing configuration

&#x20; - Alert rules — HostDown, HighCPU, HighMemory, DiskFull, NetworkDown

&#x20; - Cloud exporter stubs for AWS/Azure/GCP



\---



\## \[0.1.0] — 2026-03-22 — Initial Release



\### Added

\- \*\*Phase 1 — Foundation stack\*\*

&#x20; - docker-compose.core.yml

&#x20; - NetBox — DCIM + IPAM + CMDB

&#x20; - PostgreSQL 16 — primary database

&#x20; - Redis 7 — cache and job queue

&#x20; - Keycloak — SSO / IAM / LDAP bridge

&#x20; - Traefik — reverse proxy with automatic Let's Encrypt TLS

&#x20; - portal-ui — branded landing page (nginx)



\- \*\*Phase 6 — Agent scripts\*\*

&#x20; - agents/install-lldpd.sh — LLDP topology daemon (Linux/macOS)

&#x20; - agents/install-node-exporter.sh — Prometheus host metrics

&#x20; - agents/install-fluent-bit.sh — log forwarder

&#x20; - agents/install-windows.ps1 — Windows metrics + logs



\- \*\*One-command installer\*\*

&#x20; - install.sh — clones repo, installs Docker, configures .env, starts stack



\- \*\*Project foundation\*\*

&#x20; - NOTICE — Apache 2.0 compliance

&#x20; - LICENSE — Apache 2.0

&#x20; - README.md

&#x20; - .gitignore — secrets protection

&#x20; - config/.env.example — secrets template

&#x20; - GitHub Pages landing page at gsingh3001.github.io/infraguardian360



\---



\## Version History Summary



| Version | Date | Milestone |

|---|---|---|

| v1.0.0 | TBD | First full deployment on production server |

| v0.5.0 | 2026-03-22 | Phase 5 — Log Analytics |

| v0.4.0 | 2026-03-22 | Phase 4 — APM |

| v0.3.0 | 2026-03-22 | 21 device templates |

| v0.2.0 | 2026-03-22 | Phases 2 \& 3 |

| v0.1.0 | 2026-03-22 | Phase 1 — Foundation |

