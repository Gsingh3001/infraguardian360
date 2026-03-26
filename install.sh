#!/usr/bin/env bash
# ============================================================
#  InfraGuardian360 — One-Command Installer
#  Usage: curl -sSL https://raw.githubusercontent.com/Gsingh3001/infraguardian360/main/install.sh | bash
#  Supports: Ubuntu 22.04 / 24.04 (AMD64 + ARM64)
# ============================================================

set -euo pipefail

# ── COLOURS ─────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
AMBER='\033[0;33m'
BLUE='\033[0;34m'
TEAL='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── BANNER ──────────────────────────────────────────────────
banner() {
cat << 'EOF'

  ██╗███╗   ██╗███████╗██████╗  █████╗  ██████╗ ██╗   ██╗ █████╗ ██████╗ ██████╗ ██╗ █████╗ ███╗   ██╗
  ██║████╗  ██║██╔════╝██╔══██╗██╔══██╗██╔════╝ ██║   ██║██╔══██╗██╔══██╗██╔══██╗██║██╔══██╗████╗  ██║
  ██║██╔██╗ ██║█████╗  ██████╔╝███████║██║  ███╗██║   ██║███████║██████╔╝██║  ██║██║███████║██╔██╗ ██║
  ██║██║╚██╗██║██╔══╝  ██╔══██╗██╔══██║██║   ██║██║   ██║██╔══██║██╔══██╗██║  ██║██║██╔══██║██║╚██╗██║
  ██║██║ ╚████║██║     ██║  ██║██║  ██║╚██████╔╝╚██████╔╝██║  ██║██║  ██║██████╔╝██║██║  ██║██║ ╚████║
  ╚═╝╚═╝  ╚═══╝╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝
                                              360
  Full 360° IT Infrastructure Monitoring — Self-Hosted · Docker-Native · Zero Licence Cost
  github.com/Gsingh3001/infraguardian360

EOF
}

# ── LOGGING ─────────────────────────────────────────────────
log()     { echo -e "${TEAL}[IG360]${NC} $1"; }
success() { echo -e "${GREEN}[  OK  ]${NC} $1"; }
warn()    { echo -e "${AMBER}[ WARN ]${NC} $1"; }
error()   { echo -e "${RED}[ FAIL ]${NC} $1"; exit 1; }
section() { echo -e "\n${BOLD}${BLUE}══════════════════════════════════════════${NC}"; echo -e "${BOLD}${BLUE}  $1${NC}"; echo -e "${BOLD}${BLUE}══════════════════════════════════════════${NC}\n"; }

# ── PREFLIGHT CHECKS ────────────────────────────────────────
preflight() {
  section "PREFLIGHT CHECKS"

  # OS check
  if [[ ! -f /etc/os-release ]]; then
    error "Cannot detect OS. Ubuntu 22.04/24.04 required."
  fi
  source /etc/os-release
  if [[ "$ID" != "ubuntu" ]]; then
    error "Ubuntu required. Detected: $ID"
  fi
  log "OS: Ubuntu $VERSION_ID detected"

  # Architecture
  ARCH=$(uname -m)
  log "Architecture: $ARCH"
  if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" ]]; then
    warn "Untested architecture: $ARCH. Proceeding anyway."
  fi

  # RAM check
  TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
  if [[ "$TOTAL_RAM" -lt 8 ]]; then
    warn "Only ${TOTAL_RAM}GB RAM detected. 16GB recommended. Stack may be unstable."
  else
    success "RAM: ${TOTAL_RAM}GB available"
  fi

  # Disk check
  FREE_DISK=$(df -BG / | awk 'NR==2{print $4}' | tr -d G)
  if [[ "$FREE_DISK" -lt 20 ]]; then
    error "Only ${FREE_DISK}GB disk free. 50GB minimum required."
  fi
  success "Disk: ${FREE_DISK}GB free"

  # Root check
  if [[ "$EUID" -ne 0 ]]; then
    error "Please run with sudo: sudo bash install.sh"
  fi
  success "Running as root"
}

# ── INSTALL DEPENDENCIES ─────────────────────────────────────
install_deps() {
  section "INSTALLING DEPENDENCIES"

  log "Updating package lists..."
  apt-get update -qq

  log "Installing required packages..."
  apt-get install -y -qq \
    curl \
    git \
    wget \
    ca-certificates \
    gnupg \
    lsb-release \
    openssl \
    iptables \
    netfilter-persistent \
    iptables-persistent

  success "Base packages installed"
}

# ── INSTALL DOCKER ───────────────────────────────────────────
install_docker() {
  section "INSTALLING DOCKER"

  if command -v docker &>/dev/null; then
    DOCKER_VER=$(docker --version | awk '{print $3}' | tr -d ',')
    success "Docker already installed: $DOCKER_VER"
    return
  fi

  log "Installing Docker Engine..."
  curl -fsSL https://get.docker.com | sh

  log "Installing Docker Compose plugin..."
  apt-get install -y -qq docker-compose-plugin

  log "Adding current user to docker group..."
  SUDO_USER_NAME="${SUDO_USER:-ubuntu}"
  usermod -aG docker "$SUDO_USER_NAME" 2>/dev/null || true

  # Enable and start Docker
  systemctl enable docker
  systemctl start docker

  DOCKER_VER=$(docker --version | awk '{print $3}' | tr -d ',')
  success "Docker installed: $DOCKER_VER"

  COMPOSE_VER=$(docker compose version | awk '{print $4}')
  success "Docker Compose installed: $COMPOSE_VER"
}

# ── OPEN FIREWALL PORTS ──────────────────────────────────────
configure_firewall() {
  section "CONFIGURING FIREWALL"

  log "Opening port 80 (HTTP)..."
  iptables -I INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null || true

  log "Opening port 443 (HTTPS)..."
  iptables -I INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null || true

  log "Saving firewall rules..."
  netfilter-persistent save 2>/dev/null || true

  success "Firewall configured — ports 80 and 443 open"

# ── Block OTel ports from external access ─────────────────
  # Agents must use WireGuard tunnel or server-side proxy
  ufw deny 4317/tcp comment "OTel gRPC - internal only"
  ufw deny 4318/tcp comment "OTel HTTP - internal only"
  success "OTel ports blocked from external access"

}

# ── CLONE REPO ───────────────────────────────────────────────
clone_repo() {
  section "CLONING INFRAGUARDIAN360"

  INSTALL_DIR="${INSTALL_DIR:-/opt/infraguardian360}"

  if [[ -d "$INSTALL_DIR" ]]; then
    warn "Directory $INSTALL_DIR already exists."
    read -rp "  Overwrite? (y/N): " OVERWRITE
    if [[ "$OVERWRITE" =~ ^[Yy]$ ]]; then
      rm -rf "$INSTALL_DIR"
    else
      log "Using existing installation at $INSTALL_DIR"
      cd "$INSTALL_DIR"
      return
    fi
  fi

  log "Cloning to $INSTALL_DIR..."
  git clone https://github.com/Gsingh3001/infraguardian360.git "$INSTALL_DIR"
  cd "$INSTALL_DIR"

  success "Repository cloned to $INSTALL_DIR"
}

# ── CONFIGURE ENVIRONMENT ────────────────────────────────────
configure_env() {
  section "CONFIGURING ENVIRONMENT"

  if [[ -f .env ]]; then
    warn ".env file already exists — skipping generation"
    return
  fi

  cp config/.env.example .env

  # Generate secret key
  SECRET_KEY=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 50)

  # Generate strong passwords
  PG_PASS=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)
  REDIS_PASS=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)
  ADMIN_PASS=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)
  KC_PASS=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)

  # Get server IP
  SERVER_IP=$(curl -s https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')

  # Prompt for domain
  echo ""
  log "Server public IP detected: ${AMBER}$SERVER_IP${NC}"
  read -rp "  Enter your domain or DuckDNS hostname (or press Enter to use IP): " USER_DOMAIN
  DOMAIN="${USER_DOMAIN:-$SERVER_IP}"

  # Prompt for email
  read -rp "  Enter your email address (for SSL cert + alerts): " USER_EMAIL
  USER_EMAIL="${USER_EMAIL:-admin@infraguardian360.local}"

  # Write .env
  sed -i "s|changeme_strong_password|$PG_PASS|g" .env
  sed -i "s|changeme_50_char_random_string|$SECRET_KEY|g" .env
  sed -i "s|changeme_admin_password|$ADMIN_PASS|g" .env
  sed -i "s|changeme_redis_password|$REDIS_PASS|g" .env
  sed -i "s|changeme_keycloak_password|$KC_PASS|g" .env
  sed -i "s|your-server-ip-or-domain|$DOMAIN|g" .env
  sed -i "s|your@email.com|$USER_EMAIL|g" .env
  sed -i "s|admin@infraguardian360.local|$USER_EMAIL|g" .env

  success "Environment configured"

  # Save credentials
  cat > /root/ig360-credentials.txt << CREDS
InfraGuardian360 — Installation Credentials
============================================
Generated: $(date)
Server IP: $SERVER_IP
Domain:    $DOMAIN

NetBox Admin Password:    $ADMIN_PASS
Keycloak Admin Password:  $KC_PASS
Postgres Password:        $PG_PASS
Redis Password:           $REDIS_PASS

NetBox URL:     https://netbox.$DOMAIN
Keycloak URL:   https://keycloak.$DOMAIN

KEEP THIS FILE SAFE — DELETE AFTER NOTING PASSWORDS
CREDS

  chmod 600 /root/ig360-credentials.txt
  success "Credentials saved to /root/ig360-credentials.txt"
}

# ── LAUNCH STACK ─────────────────────────────────────────────
launch_stack() {
  section "LAUNCHING INFRAGUARDIAN360"

  log "Pulling Docker images (this takes 3-5 minutes)..."
  docker compose -f docker/docker-compose.core.yml pull

  log "Starting all services..."
  docker compose -f docker/docker-compose.core.yml up -d

  # Wait for NetBox to be healthy
  log "Waiting for NetBox to initialise (up to 3 minutes)..."
  TIMEOUT=180
  ELAPSED=0
  until docker exec ig360-netbox python3 /opt/netbox/netbox/manage.py check --deploy &>/dev/null; do
    if [[ $ELAPSED -ge $TIMEOUT ]]; then
      warn "NetBox health check timed out — it may still be starting up"
      break
    fi
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    echo -n "."
  done
  echo ""

  success "Stack launched"
  log "To start the FULL stack (all phases) in one command:"
  echo ""
  echo "  docker compose -f docker/docker-compose.full.yml up -d"
  echo ""

}

# ── SERVICE STATUS ───────────────────────────────────────────
show_status() {
  section "SERVICE STATUS"

  docker compose -f docker/docker-compose.core.yml ps --format \
    "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || \
    docker compose -f docker/docker-compose.core.yml ps
}

# ── SUMMARY ─────────────────────────────────────────────────
show_summary() {
  section "INSTALLATION COMPLETE"

  DOMAIN=$(grep "^DOMAIN=" .env | cut -d= -f2)

  echo -e "${GREEN}${BOLD}"
  echo "  InfraGuardian360 is now live!"
  echo ""
  echo -e "${NC}${TEAL}  Access your platform:${NC}"
  echo ""
  echo -e "  ${BOLD}NetBox CMDB:${NC}       https://netbox.$DOMAIN"
  echo -e "  ${BOLD}Keycloak SSO:${NC}      https://keycloak.$DOMAIN"
  echo -e "  ${BOLD}Traefik Dashboard:${NC} https://traefik.$DOMAIN"
  echo ""
  echo -e "${TEAL}  Credentials:${NC}       /root/ig360-credentials.txt"
  echo ""
  echo -e "${TEAL}  Add monitoring stack (Phase 3):${NC}"
  echo -e "  cd /opt/infraguardian360"
  echo -e "  docker compose -f docker/docker-compose.monitoring.yml up -d"
  echo ""
  echo -e "${AMBER}  Next steps:${NC}"
  echo "  1. Open NetBox and add your first device"
  echo "  2. Enable SNMP on your switches and routers"
  echo "  3. Run agents/install-lldpd.sh on your Linux servers"
  echo ""
  echo -e "${TEAL}  Docs:${NC} github.com/Gsingh3001/infraguardian360"
  echo ""
}


# ── Substitute Alertmanager config tokens ─────────────────
  log "Configuring Alertmanager..."
  sed -i "s|IG360_ADMIN_EMAIL|${USER_EMAIL}|g" \
    config/alertmanager/alertmanager.yml
  sed -i "s|IG360_SMTP_USER|${USER_EMAIL}|g" \
    config/alertmanager/alertmanager.yml
  sed -i "s|IG360_SMTP_PASSWORD|${SMTP_PASSWORD:-changeme}|g" \
    config/alertmanager/alertmanager.yml
  sed -i "s|IG360_SLACK_WEBHOOK|${SLACK_WEBHOOK:-https://hooks.slack.com/placeholder}|g" \
    config/alertmanager/alertmanager.yml
  success "Alertmanager configured"

# ── MAIN ─────────────────────────────────────────────────────
main() {
  clear
  banner
  echo -e "${TEAL}Starting InfraGuardian360 installation...${NC}"
  echo ""

  preflight
  install_deps
  install_docker
  configure_firewall
  clone_repo
  configure_env
  launch_stack
  show_status
  show_summary
}

main "$@"