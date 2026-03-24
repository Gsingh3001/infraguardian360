# InfraGuardian360 — Quickstart Guide

Zero to live in 15 minutes on a fresh Ubuntu 24.04 server.

---

## What you need before starting

- A server running Ubuntu 22.04 or 24.04 LTS (recommended: Hetzner CAX31 — 8 vCPU, 16GB RAM)
- A domain name pointed at your server IP (or use the server IP directly for testing)
- SSH access to the server
- 15 minutes

---

## Step 1 — One-command install (2 minutes)

SSH into your server then run:
```bash
curl -sSL https://raw.githubusercontent.com/Gsingh3001/infraguardian360/main/install.sh | sudo bash
```

This automatically:
- Installs Docker and Docker Compose
- Clones the InfraGuardian360 repository
- Prompts you for passwords and domain name
- Starts Phases 1, 2, and 3

When complete you will see:
```
✓ InfraGuardian360 is live
  NetBox:      https://your-domain.com:8080
  HertzBeat:   https://your-domain.com:1157
  Prometheus:  https://your-domain.com:9090
  Keycloak:    https://your-domain.com:8443
```

---

## Step 2 — First login to NetBox (2 minutes)

1. Open `https://your-domain.com:8080`
2. Login: `admin` / the password you set during install
3. Go to **Organisation → Sites → Add**
4. Create your first site — name it your client or office name
5. Go to **Devices → Add** — add your first switch manually

NetBox is your source of truth. Everything else auto-populates from here.

---

## Step 3 — Configure SNMP on your first switch (3 minutes)

On your switch, enable SNMPv3:

**Cisco IOS:**
```
snmp-server group ig360group v3 priv
snmp-server user ig360user ig360group v3 auth sha YOUR_AUTH_PASS priv aes 128 YOUR_PRIV_PASS
snmp-server host YOUR_SERVER_IP version 3 priv ig360user
```

**HP/Aruba ProCurve:**
```
snmp-server community "public" operator unrestricted
snmpv3 user "ig360user" auth sha "YOUR_AUTH_PASS" priv aes "YOUR_PRIV_PASS"
```

**Fortinet FortiGate:**
```
config system snmp community
  edit 1
    set name "ig360"
    config hosts
      edit 1
        set ip YOUR_SERVER_IP/32
      end
    end
  next
end
```

---

## Step 4 — Start network discovery (1 minute)

Edit your Netdisco seed config:
```bash
cd /opt/infraguardian360
nano config/netdisco/netdisco.conf
```

Change these two lines:
```yaml
discover_nodes:
  - 192.168.1.1    # Your first switch or router IP

discover_subnets:
  - 192.168.1.0/24  # Your network subnet
```

Then restart Netdisco:
```bash
docker compose -f docker/docker-compose.discovery.yml restart
```

Open `https://your-domain.com:5000` — within 5 minutes your entire network topology will be visible.

---

## Step 5 — Add your first monitor in HertzBeat (2 minutes)

1. Open `https://your-domain.com:1157`
2. Login: `admin` / `hertzbeat` (change this immediately)
3. Click **Monitoring → Add Monitor**
4. Select your device type — e.g. **Cisco Catalyst Switch**
5. Enter IP address and SNMP credentials
6. Click **Confirm**

Within 30 seconds you'll see CPU, memory, port traffic, and PoE data.

---

## Step 6 — Deploy agents on Linux servers (1 minute per server)

On each Linux server you want to monitor:
```bash
# LLDP topology agent
curl -sSL https://raw.githubusercontent.com/Gsingh3001/infraguardian360/main/agents/install-lldpd.sh | bash

# Prometheus metrics agent
curl -sSL https://raw.githubusercontent.com/Gsingh3001/infraguardian360/main/agents/install-node-exporter.sh | bash

# Log forwarding agent
curl -sSL https://raw.githubusercontent.com/Gsingh3001/infraguardian360/main/agents/install-fluent-bit.sh | bash
```

On Windows servers (PowerShell as Administrator):
```powershell
.\agents\install-windows.ps1 -IG360Server "YOUR_SERVER_IP"
```

---

## Step 7 — Add APM and Log Analytics (optional)

Start the APM stack for distributed tracing:
```bash
docker compose -f docker/docker-compose.apm.yml up -d
```

Access SigNoz at `https://apm.your-domain.com`

Start the logging stack for centralised log analytics:
```bash
docker compose -f docker/docker-compose.logging.yml up -d
```

Access OpenSearch Dashboards at `https://logs.your-domain.com`

---

## Set up daily backups
```bash
# Add to crontab
echo "0 2 * * * /opt/infraguardian360/scripts/backup.sh" | sudo crontab -
```

Backups are saved to `/opt/backups/infraguardian360/` and retained for 30 days.

---

## Verify everything is running
```bash
cd /opt/infraguardian360
docker compose -f docker/docker-compose.core.yml ps
docker compose -f docker/docker-compose.monitoring.yml ps
docker compose -f docker/docker-compose.discovery.yml ps
```

All services should show `running (healthy)`.

---

## Common issues

**NetBox won't start**
```bash
docker logs ig360-netbox
# Usually a DB_PASSWORD mismatch — check .env
```

**HertzBeat can't reach a device**
- Check firewall allows UDP/161 from server to device
- Verify SNMP community string matches
- Test manually: `snmpwalk -v2c -c public DEVICE_IP 1.3.6.1.2.1.1.1.0`

**Traefik SSL cert not issuing**
- Ensure ports 80 and 443 are open on server firewall
- Ensure domain A record points to server IP
- Check: `docker logs ig360-traefik`

**Out of memory**
- Run on Phase 1-3 only first: skip APM and logging stacks
- Minimum 16GB RAM for full stack
- Check: `free -h` and `docker stats`

---

## What's running where

| Service | URL | Default login |
|---|---|---|
| InfraGuardian360 Portal | https://your-domain.com | — |
| NetBox (CMDB/IPAM) | https://netbox.your-domain.com | admin / set in .env |
| HertzBeat (Monitoring) | https://monitor.your-domain.com | admin / hertzbeat |
| Prometheus | https://prometheus.your-domain.com | BasicAuth from .env |
| Keycloak (SSO) | https://sso.your-domain.com | admin / set in .env |
| SigNoz (APM) | https://apm.your-domain.com | admin@example.com |
| OpenSearch Dashboards | https://logs.your-domain.com | admin / set in .env |
| Netdisco (Topology) | https://topology.your-domain.com | admin / set in .env |

---

## Next steps

- [Adding device templates](adding-devices.md)
- [Configuring cloud monitoring (AWS/Azure/GCP)](cloud-setup.md)
- [Setting up multi-tenant MSP mode](msp-setup.md)
- [Configuring alerting (email/Slack/Teams)](alerting.md)