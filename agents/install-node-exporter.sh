#!/usr/bin/env bash
# ============================================================
#  InfraGuardian360 — Node Exporter Installer
#  Deep Linux host metrics — CPU, memory, disk, network, services
#  Usage: curl -sSL https://raw.githubusercontent.com/Gsingh3001/infraguardian360/main/agents/install-node-exporter.sh | bash
# ============================================================

set -euo pipefail

TEAL='\033[0;36m'; GREEN='\033[0;32m'; AMBER='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'; BOLD='\033[1m'

log()     { echo -e "${TEAL}[node-exp]${NC} $1"; }
success() { echo -e "${GREEN}[  OK   ]${NC} $1"; }
warn()    { echo -e "${AMBER}[ WARN  ]${NC} $1"; }
error()   { echo -e "${RED}[ FAIL  ]${NC} $1"; exit 1; }

# Configurable — point this at your IG360 server
IG360_SERVER="${IG360_SERVER:-}"
NODE_EXPORTER_VERSION="1.8.2"
INSTALL_DIR="/opt/node_exporter"
ARCH=$(uname -m)

echo -e "${BOLD}${TEAL}"
echo "  InfraGuardian360 — Node Exporter Agent"
echo "  Deep Linux host metrics for Prometheus"
echo -e "${NC}"

# ── MAP ARCH ─────────────────────────────────────────────────
map_arch() {
  case "$ARCH" in
    x86_64)  ARCH_SUFFIX="amd64" ;;
    aarch64) ARCH_SUFFIX="arm64" ;;
    armv7l)  ARCH_SUFFIX="armv7" ;;
    *)       error "Unsupported architecture: $ARCH" ;;
  esac
  log "Architecture: $ARCH ($ARCH_SUFFIX)"
}

# ── DOWNLOAD & INSTALL ───────────────────────────────────────
install_node_exporter() {
  log "Downloading Node Exporter v$NODE_EXPORTER_VERSION..."

  DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH_SUFFIX}.tar.gz"

  cd /tmp
  curl -sSL "$DOWNLOAD_URL" -o node_exporter.tar.gz
  tar -xzf node_exporter.tar.gz
  sudo mkdir -p "$INSTALL_DIR"
  sudo cp "node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH_SUFFIX}/node_exporter" "$INSTALL_DIR/"
  sudo chmod +x "$INSTALL_DIR/node_exporter"
  rm -rf node_exporter.tar.gz "node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH_SUFFIX}"

  success "Node Exporter installed to $INSTALL_DIR"
}

# ── CREATE SYSTEMD SERVICE ───────────────────────────────────
create_service() {
  log "Creating systemd service..."

  # Create dedicated user
  sudo useradd --no-create-home --shell /bin/false node_exporter 2>/dev/null || true
  sudo chown node_exporter:node_exporter "$INSTALL_DIR/node_exporter"

  sudo tee /etc/systemd/system/node_exporter.service > /dev/null << EOF
[Unit]
Description=InfraGuardian360 Node Exporter
Documentation=https://github.com/Gsingh3001/infraguardian360
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=$INSTALL_DIR/node_exporter \\
  --collector.systemd \\
  --collector.processes \\
  --collector.tcpstat \\
  --collector.interrupts \\
  --web.listen-address=:9100
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable node_exporter
  sudo systemctl start node_exporter
  sleep 2

  if sudo systemctl is-active --quiet node_exporter; then
    success "Node Exporter service running on :9100"
  else
    error "Node Exporter failed to start"
  fi
}

# ── VERIFY ───────────────────────────────────────────────────
verify() {
  log "Verifying metrics endpoint..."
  sleep 2

  if curl -s http://localhost:9100/metrics | grep -q "node_cpu_seconds_total"; then
    success "Metrics endpoint responding — CPU metrics confirmed"
    METRIC_COUNT=$(curl -s http://localhost:9100/metrics | grep -c "^node_" || echo "0")
    log "Total node_ metrics available: $METRIC_COUNT"
  else
    warn "Metrics endpoint not responding yet — may need a few seconds"
  fi
}

# ── SHOW PROMETHEUS CONFIG ───────────────────────────────────
show_prometheus_config() {
  HOST_IP=$(hostname -I | awk '{print $1}')

  echo ""
  echo -e "${TEAL}  Add this to your Prometheus scrape config:${NC}"
  echo ""
  echo "  - job_name: node-exporter"
  echo "    static_configs:"
  echo "      - targets: ['${HOST_IP}:9100']"
  echo "        labels:"
  echo "          hostname: '$(hostname)'"
  echo "          environment: 'production'"
  echo ""

  if [[ -n "$IG360_SERVER" ]]; then
    log "Auto-registering with IG360 server at $IG360_SERVER..."
    # Future: POST to NetBox API to register this host
    warn "Auto-registration not yet implemented — add manually to Prometheus config"
  fi
}

# ── SUMMARY ──────────────────────────────────────────────────
summary() {
  echo -e "${GREEN}${BOLD}  Node Exporter installed successfully!${NC}"
  echo ""
  echo -e "  ${TEAL}Metrics available at:${NC} http://$(hostname -I | awk '{print $1}'):9100/metrics"
  echo ""
  echo -e "  ${TEAL}Collecting:${NC}"
  echo "  → CPU per-core usage and idle time"
  echo "  → Memory — used, free, cached, buffers"
  echo "  → Disk — per-partition usage, I/O rates"
  echo "  → Network — per-NIC bytes, errors, drops"
  echo "  → Systemd service states"
  echo "  → Running processes"
  echo "  → TCP connection stats"
  echo ""
}

map_arch
install_node_exporter
create_service
verify
show_prometheus_config
summary