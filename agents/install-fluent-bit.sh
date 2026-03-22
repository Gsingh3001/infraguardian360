#!/usr/bin/env bash
# ============================================================
#  InfraGuardian360 — Fluent Bit Log Forwarder Installer
#  Ships syslog, journald, and app logs to OpenSearch
#  Usage: curl -sSL https://raw.githubusercontent.com/Gsingh3001/infraguardian360/main/agents/install-fluent-bit.sh | bash
# ============================================================

set -euo pipefail

TEAL='\033[0;36m'; GREEN='\033[0;32m'; AMBER='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'; BOLD='\033[1m'

log()     { echo -e "${TEAL}[fluentbit]${NC} $1"; }
success() { echo -e "${GREEN}[  OK    ]${NC} $1"; }
warn()    { echo -e "${AMBER}[ WARN   ]${NC} $1"; }
error()   { echo -e "${RED}[ FAIL   ]${NC} $1"; exit 1; }

# Point this at your IG360 OpenSearch instance
IG360_SERVER="${IG360_SERVER:-localhost}"
OPENSEARCH_PORT="${OPENSEARCH_PORT:-9200}"

echo -e "${BOLD}${TEAL}"
echo "  InfraGuardian360 — Fluent Bit Log Forwarder"
echo "  Ships all logs to OpenSearch"
echo -e "${NC}"

# ── DETECT OS ────────────────────────────────────────────────
detect_os() {
  if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    OS="$ID"
    VERSION="$VERSION_ID"
  else
    error "Cannot detect OS"
  fi
  log "OS: $OS $VERSION"
}

# ── INSTALL FLUENT BIT ───────────────────────────────────────
install_fluent_bit() {
  case "$OS" in
    ubuntu|debian)
      log "Adding Fluent Bit repository..."
      curl -sSL https://packages.fluentbit.io/fluentbit.key | sudo gpg --dearmor -o /usr/share/keyrings/fluentbit-keyring.gpg 2>/dev/null || \
      curl -sSL https://packages.fluentbit.io/fluentbit.key | sudo apt-key add - 2>/dev/null || true

      echo "deb https://packages.fluentbit.io/ubuntu/$(lsb_release -cs) $(lsb_release -cs) main" | \
        sudo tee /etc/apt/sources.list.d/fluent-bit.list > /dev/null

      sudo apt-get update -qq
      sudo apt-get install -y -qq fluent-bit
      ;;
    centos|rhel|rocky|almalinux)
      log "Installing Fluent Bit via script..."
      curl -sSL https://raw.githubusercontent.com/fluent/fluent-bit/master/install.sh | sudo sh
      ;;
    *)
      error "Unsupported OS: $OS. Supported: Ubuntu, Debian, CentOS, RHEL"
      ;;
  esac
  success "Fluent Bit installed"
}

# ── CONFIGURE ────────────────────────────────────────────────
configure_fluent_bit() {
  log "Writing Fluent Bit configuration..."

  HOSTNAME=$(hostname)

  sudo tee /etc/fluent-bit/fluent-bit.conf > /dev/null << EOF
[SERVICE]
    Flush         5
    Daemon        Off
    Log_Level     warn
    Parsers_File  parsers.conf

# ── INPUTS ──────────────────────────────────────────────────

[INPUT]
    Name          systemd
    Tag           host.systemd
    Systemd_Filter _SYSTEMD_UNIT=*.service
    Read_From_Tail On

[INPUT]
    Name          tail
    Tag           host.syslog
    Path          /var/log/syslog
    Path_Key      filename
    DB            /var/log/fluent-bit-syslog.db
    Mem_Buf_Limit 5MB
    Skip_Long_Lines On

[INPUT]
    Name          tail
    Tag           host.auth
    Path          /var/log/auth.log
    DB            /var/log/fluent-bit-auth.db
    Mem_Buf_Limit 5MB

# ── FILTERS ─────────────────────────────────────────────────

[FILTER]
    Name          record_modifier
    Match         host.*
    Record        hostname $HOSTNAME
    Record        platform infraguardian360
    Record        environment production

# ── OUTPUT ──────────────────────────────────────────────────

[OUTPUT]
    Name          opensearch
    Match         host.*
    Host          $IG360_SERVER
    Port          $OPENSEARCH_PORT
    Index         ig360-logs
    Type          _doc
    HTTP_User     admin
    HTTP_Passwd   admin
    tls           Off
    tls.verify    Off
    Suppress_Type_Name On
    Retry_Limit   5
EOF

  success "Fluent Bit configured"
}

# ── START SERVICE ────────────────────────────────────────────
start_service() {
  log "Starting Fluent Bit service..."
  sudo systemctl enable fluent-bit
  sudo systemctl restart fluent-bit
  sleep 3

  if sudo systemctl is-active --quiet fluent-bit; then
    success "Fluent Bit running — logs shipping to $IG360_SERVER:$OPENSEARCH_PORT"
  else
    warn "Fluent Bit may not have started — check: sudo systemctl status fluent-bit"
  fi
}

# ── SUMMARY ──────────────────────────────────────────────────
summary() {
  echo ""
  echo -e "${GREEN}${BOLD}  Fluent Bit installed successfully!${NC}"
  echo ""
  echo -e "  ${TEAL}Shipping to:${NC} $IG360_SERVER:$OPENSEARCH_PORT"
  echo ""
  echo -e "  ${TEAL}Log sources active:${NC}"
  echo "  → systemd service logs (all services)"
  echo "  → /var/log/syslog"
  echo "  → /var/log/auth.log (login/security events)"
  echo ""
  echo -e "  ${TEAL}View logs in:${NC} OpenSearch Dashboards → ig360-logs index"
  echo ""
  echo -e "  ${AMBER}To ship to your IG360 server:${NC}"
  echo "  IG360_SERVER=your-server-ip bash install-fluent-bit.sh"
  echo ""
}

detect_os
install_fluent_bit
configure_fluent_bit
start_service
summary