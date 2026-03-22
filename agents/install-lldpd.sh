#!/usr/bin/env bash
# ============================================================
#  InfraGuardian360 — LLDP Agent Installer
#  Installs lldpd on Linux/macOS — enables network topology
#  Run on: every Linux server, VM, and macOS machine
#  Usage: curl -sSL https://raw.githubusercontent.com/Gsingh3001/infraguardian360/main/agents/install-lldpd.sh | bash
# ============================================================

set -euo pipefail

TEAL='\033[0;36m'; GREEN='\033[0;32m'; AMBER='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'; BOLD='\033[1m'

log()     { echo -e "${TEAL}[lldpd]${NC} $1"; }
success() { echo -e "${GREEN}[  OK  ]${NC} $1"; }
warn()    { echo -e "${AMBER}[ WARN ]${NC} $1"; }
error()   { echo -e "${RED}[ FAIL ]${NC} $1"; exit 1; }

echo -e "${BOLD}${TEAL}"
echo "  InfraGuardian360 — LLDP Topology Agent"
echo "  Enables automatic switch-port discovery"
echo -e "${NC}"

# ── DETECT OS ────────────────────────────────────────────────
detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
  elif [[ -f /etc/os-release ]]; then
    source /etc/os-release
    OS="$ID"
  else
    error "Unsupported OS"
  fi
  log "Detected OS: $OS"
}

# ── INSTALL ──────────────────────────────────────────────────
install_lldpd() {
  case "$OS" in
    ubuntu|debian)
      log "Installing lldpd via apt..."
      sudo apt-get update -qq
      sudo apt-get install -y -qq lldpd
      ;;
    centos|rhel|fedora|rocky|almalinux)
      log "Installing lldpd via yum/dnf..."
      sudo yum install -y lldpd 2>/dev/null || sudo dnf install -y lldpd
      ;;
    macos)
      if ! command -v brew &>/dev/null; then
        error "Homebrew required on macOS. Install from https://brew.sh"
      fi
      log "Installing lldpd via Homebrew..."
      brew install lldpd
      ;;
    *)
      error "Unsupported OS: $OS"
      ;;
  esac
  success "lldpd installed"
}

# ── CONFIGURE ────────────────────────────────────────────────
configure_lldpd() {
  log "Configuring lldpd..."

  if [[ "$OS" != "macos" ]]; then
    # Enable CDP + LLDP + system description
    sudo tee /etc/lldpd.d/ig360.conf > /dev/null << 'EOF'
configure system description "InfraGuardian360 Managed Host"
configure lldp portidsubtype ifname
configure lldp tx-interval 30
configure lldp tx-hold 4
EOF
    success "lldpd configured"
  fi
}

# ── ENABLE & START ───────────────────────────────────────────
start_lldpd() {
  log "Starting lldpd service..."

  case "$OS" in
    ubuntu|debian|centos|rhel|fedora|rocky|almalinux)
      sudo systemctl enable lldpd
      sudo systemctl restart lldpd
      sleep 2
      if sudo systemctl is-active --quiet lldpd; then
        success "lldpd service running"
      else
        error "lldpd failed to start"
      fi
      ;;
    macos)
      sudo brew services start lldpd
      success "lldpd service started"
      ;;
  esac
}

# ── VERIFY ───────────────────────────────────────────────────
verify() {
  log "Verifying LLDP neighbours..."
  sleep 3

  if command -v lldpcli &>/dev/null; then
    NEIGHBOURS=$(sudo lldpcli show neighbors 2>/dev/null | grep -c "Interface" || echo "0")
    if [[ "$NEIGHBOURS" -gt 0 ]]; then
      success "Found $NEIGHBOURS LLDP neighbour(s) — topology working"
      sudo lldpcli show neighbors 2>/dev/null | head -20
    else
      warn "No LLDP neighbours found yet — normal if switch hasn't responded (wait 60s)"
    fi
  fi
}

# ── SUMMARY ──────────────────────────────────────────────────
summary() {
  echo ""
  echo -e "${GREEN}${BOLD}  LLDP agent installed successfully!${NC}"
  echo ""
  echo -e "  ${TEAL}This machine will now appear in:${NC}"
  echo "  → Netdisco topology map"
  echo "  → NetBox switch port assignments"
  echo "  → InfraGuardian360 CMDB"
  echo ""
  echo -e "  ${TEAL}Verify neighbours anytime:${NC}"
  echo "  sudo lldpcli show neighbors"
  echo ""
}

detect_os
install_lldpd
configure_lldpd
start_lldpd
verify
summary