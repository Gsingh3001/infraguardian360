\# InfraGuardian360 — Architecture



Full technical architecture reference for the platform.



\---



\## Overview



InfraGuardian360 is a 6-tier observability platform built entirely from

Apache 2.0 / MIT / ISC licensed components. Every tier is independently

replaceable. No proprietary lock-in anywhere in the stack.

```

┌─────────────────────────────────────────────────────────────────┐

│  TIER 6 — UI / Dashboards                                       │

│  HertzBeat UI · SigNoz UI · OpenSearch Dashboards               │

│  NetBox UI · Keycloak Admin · Traefik Dashboard                 │

│  InfraGuardian360 Portal (branded landing page)                 │

└────────────────────────┬────────────────────────────────────────┘

&#x20;                        │ HTTPS via Traefik

┌────────────────────────▼────────────────────────────────────────┐

│  TIER 5 — Observability Backends                                │

│  VictoriaMetrics — long-term metrics storage                    │

│  SigNoz + ClickHouse — APM, traces, exceptions                  │

│  OpenSearch — log storage and full-text search                  │

│  Jaeger — deep distributed trace viewer                         │

└────────────────────────┬────────────────────────────────────────┘

&#x20;                        │ OpenTelemetry Protocol (OTLP)

┌────────────────────────▼────────────────────────────────────────┐

│  TIER 4 — Telemetry Pipeline                                    │

│  OpenTelemetry Collector — universal signal router              │

│  Fluent Bit — log collection and forwarding                     │

│  Prometheus — pull-based metrics scraping                       │

│  Alertmanager — alert routing and deduplication                 │

└────────────────────────┬────────────────────────────────────────┘

&#x20;                        │ SNMP / SSH / HTTP / JDBC / eBPF

┌────────────────────────▼────────────────────────────────────────┐

│  TIER 3 — Monitoring \& Discovery Agents                         │

│  HertzBeat collectors — agentless SNMP/SSH/JDBC/HTTP/JMX        │

│  lldpd — LLDP/CDP topology daemon on every Linux host           │

│  Netdisco — CDP/LLDP network crawler                            │

│  Grafana Beyla — eBPF zero-code instrumentation                 │

│  Node Exporter — Linux host OS metrics                          │

│  windows\_exporter — Windows host OS metrics                     │

│  Prometheus SNMP Exporter — SNMP → Prometheus bridge            │

└────────────────────────┬────────────────────────────────────────┘

&#x20;                        │ REST API / PostgreSQL queries

┌────────────────────────▼────────────────────────────────────────┐

│  TIER 2 — CMDB / IPAM / Source of Truth                        │

│  NetBox — DCIM + IPAM + CMDB + rack diagrams                   │

│  NetBox Discovery (Diode) — auto-discovery agent                │

│  Netdisco — L2 topology database                                │

│  PostgreSQL 16 — primary data store                             │

│  Redis 7 — cache and job queue                                  │

└────────────────────────┬────────────────────────────────────────┘

&#x20;                        │ SNMP / LLDP / CDP / ARP / agent

┌────────────────────────▼────────────────────────────────────────┐

│  TIER 1 — Monitored Infrastructure                              │

│  Switches · Routers · Firewalls · Access Points                 │

│  Servers · Desktops · Laptops · Printers · IP Phones            │

│  Virtual Machines · Containers · Kubernetes clusters            │

│  AWS · Azure · GCP · Databases · Middleware                     │

└─────────────────────────────────────────────────────────────────┘

```



\---



\## Key Design Principles



\### 1. NetBox is the single source of truth

Nothing is added to dashboards manually. All device inventory flows

from NetBox — either entered manually or auto-populated by Netdisco

and NetBox Discovery. If it's not in NetBox, it's not being monitored.



\### 2. OpenTelemetry is the universal pipe

Every signal — metrics, logs, and traces — from every source routes

through the OpenTelemetry Collector before reaching a storage backend.

This decouples collection from storage. Swap VictoriaMetrics for

Cortex tomorrow without touching a single agent.



\### 3. Signal-type separation

Each signal type has its own purpose-built backend:

\- \*\*Metrics\*\* → VictoriaMetrics (10x more efficient than Prometheus at scale)

\- \*\*Traces\*\* → SigNoz + ClickHouse (columnar storage, fast trace queries)

\- \*\*Logs\*\* → OpenSearch (full-text search, RBAC, compliance)



\### 4. No proprietary lock-in

Every component exposes standard APIs — Prometheus remote write,

OpenTelemetry Protocol, REST. Replace any tier without changing

the others.



\### 5. eBPF fills the SNMP gaps

Grafana Beyla attaches at the kernel level via eBPF — zero code

changes, zero restarts. Captures per-request HTTP/gRPC traces,

JVM internals, TLS-decrypted flows. Sees what SNMP cannot.



\---



\## Data Flow



\### Metrics flow

```

Device (SNMP) → HertzBeat → OTel Collector → VictoriaMetrics

Linux host    → Node Exporter → Prometheus → OTel Collector → VictoriaMetrics

Windows host  → windows\_exporter → Prometheus → OTel Collector → VictoriaMetrics

Application   → Beyla (eBPF) → OTel Collector → VictoriaMetrics + SigNoz

```



\### Logs flow

```

Docker containers → Fluent Bit → OpenSearch

Linux syslog      → Fluent Bit → OpenSearch

Windows Events    → Fluent Bit → OpenSearch

Application logs  → OTel Collector → OpenSearch

AWS CloudTrail    → OTel Collector → OpenSearch

```



\### Traces flow

```

Application (SDK) → OTel Collector → SigNoz + ClickHouse

Application (eBPF via Beyla) → OTel Collector → SigNoz + ClickHouse

```



\### Discovery flow

```

Network (SNMP/LLDP/CDP) → Netdisco → NetBox API → NetBox CMDB

Network (SNMP range scan) → NetBox Discovery → NetBox CMDB

Linux host (lldpd) → Switch LLDP table → Netdisco → NetBox CMDB

```



\---



\## Port Reference



| Service | Internal port | External (Traefik) |

|---|---|---|

| NetBox | 8080 | netbox.your-domain.com |

| HertzBeat | 1157, 1158 | monitor.your-domain.com |

| Prometheus | 9090 | prometheus.your-domain.com |

| Alertmanager | 9093 | alerts.your-domain.com |

| VictoriaMetrics | 8428 | — (internal only) |

| SigNoz Frontend | 3301 | apm.your-domain.com |

| ClickHouse | 8123, 9000 | — (internal only) |

| OpenSearch | 9200 | — (internal only) |

| OpenSearch Dashboards | 5601 | logs.your-domain.com |

| Keycloak | 8443 | sso.your-domain.com |

| Traefik | 80, 443 | your-domain.com |

| Netdisco | 5000 | topology.your-domain.com |

| OTel Collector | 4317 (gRPC), 4318 (HTTP) | — (internal + agents) |

| Fluent Bit metrics | 2020 | — (internal only) |

| Node Exporter | 9100 | — (server-side agent) |

| windows\_exporter | 9182 | — (Windows agent) |

| Portal | 80 | your-domain.com |



\---



\## Component Decisions



| Component | Alternative considered | Why this choice |

|---|---|---|

| NetBox | LibreNMS | Apache 2.0 vs GPL — rebrandable |

| HertzBeat | Zabbix | Apache 2.0 vs GPL — rebrandable |

| VictoriaMetrics | InfluxDB | InfluxDB switched to BSL 2022 |

| OpenSearch | Elasticsearch | Elasticsearch switched to SSPL 2021 |

| SigNoz | Grafana Tempo | Native OTel, better UI for APM |

| Traefik | Nginx | Automatic TLS, Docker-native |

| Keycloak | Authentik | Most mature, best LDAP/AD support |

| lldpd | custom | Only mature cross-platform LLDP daemon |



\---



\## Minimum Server Requirements



| Tier | CPU | RAM | Disk | Use case |

|---|---|---|---|---|

| Development | 4 vCPU | 8 GB | 80 GB | Phases 1-3 only |

| \*\*Production\*\* | \*\*8 vCPU\*\* | \*\*16 GB\*\* | \*\*160 GB\*\* | \*\*All 5 phases\*\* |

| MSP (10 clients) | 16 vCPU | 32 GB | 500 GB | Multi-tenant |

| Enterprise | 16 vCPU dedicated | 64 GB | 2 TB | NHS/large enterprise |



\*\*Recommended:\*\* Hetzner CAX31 — 8 ARM vCPU, 16 GB, 160 GB NVMe — £10.80/month



\---



\## Security Architecture

```

Internet

&#x20;   │

&#x20;   ▼

Traefik (443 only — automatic TLS)

&#x20;   │

&#x20;   ▼

Keycloak (SSO — all UIs behind single login)

&#x20;   │

&#x20;   ├── NetBox (RBAC — object-level permissions)

&#x20;   ├── HertzBeat (role-based access)

&#x20;   ├── SigNoz (team-based access)

&#x20;   └── OpenSearch (index-level RBAC)



Server firewall rules:

&#x20;   ALLOW  22   (SSH — key-only, fail2ban)

&#x20;   ALLOW  80   (HTTP — Traefik redirect to HTTPS)

&#x20;   ALLOW  443  (HTTPS — all traffic)

&#x20;   ALLOW  4317 (OTel gRPC — agents only, restrict by IP)

&#x20;   ALLOW  4318 (OTel HTTP — agents only, restrict by IP)

&#x20;   DENY   all other inbound

```



\---



\## Licence Summary



| Component | Licence | Fork + rebrand | Sell commercially |

|---|---|---|---|

| All Apache 2.0 components | Apache 2.0 | ✅ Yes | ✅ Yes |

| Traefik | MIT | ✅ Yes | ✅ Yes |

| lldpd | ISC | ✅ Yes | ✅ Yes |

| PostgreSQL | PostgreSQL (permissive) | ✅ Yes | ✅ Yes |

| Redis | BSD 3-Clause | ✅ Yes | ✅ Yes |



\*\*One obligation:\*\* Include the NOTICE file listing all upstream components.

Already included in the repository root.

