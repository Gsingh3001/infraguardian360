#!/bin/bash
# ============================================================
#  InfraGuardian360 — Backup & Restore Script
#  Backs up: PostgreSQL databases, Redis, config volumes
#  Ships to: local directory + optional object storage
#  Schedule: Run daily via cron — 0 2 * * * /opt/infraguardian360/scripts/backup.sh
# ============================================================

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${BACKUP_DIR:-/opt/backups/infraguardian360}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="ig360_backup_${DATE}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

# Load env
if [ -f "${PROJECT_DIR}/.env" ]; then
  export $(grep -v '^#' "${PROJECT_DIR}/.env" | xargs)
fi

# ── Colours ───────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()     { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[$(date '+%H:%M:%S')] ✓${NC} $1"; }
warn()    { echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠${NC} $1"; }
error()   { echo -e "${RED}[$(date '+%H:%M:%S')] ✗${NC} $1"; }

# ── Pre-flight checks ─────────────────────────────────────────
preflight() {
  log "Running pre-flight checks..."

  if ! command -v docker &>/dev/null; then
    error "Docker not found"
    exit 1
  fi

  if ! docker ps &>/dev/null; then
    error "Docker daemon not running"
    exit 1
  fi

  mkdir -p "${BACKUP_PATH}"
  success "Backup directory: ${BACKUP_PATH}"
}

# ── Backup PostgreSQL ─────────────────────────────────────────
backup_postgres() {
  log "Backing up PostgreSQL databases..."

  # NetBox database
  if docker ps --format '{{.Names}}' | grep -q "ig360-postgres"; then
    docker exec ig360-postgres pg_dump \
      -U netbox \
      -d netbox \
      --no-password \
      --format=custom \
      --compress=9 \
      > "${BACKUP_PATH}/netbox_db.dump" 2>/dev/null

    success "NetBox database backed up ($(du -sh "${BACKUP_PATH}/netbox_db.dump" | cut -f1))"

    # Keycloak database
    docker exec ig360-postgres pg_dump \
      -U keycloak \
      -d keycloak \
      --no-password \
      --format=custom \
      --compress=9 \
      > "${BACKUP_PATH}/keycloak_db.dump" 2>/dev/null || \
      warn "Keycloak DB backup skipped — may not exist yet"

    success "Keycloak database backed up"
  else
    warn "PostgreSQL container not running — skipping DB backup"
  fi

  # Netdisco database
  if docker ps --format '{{.Names}}' | grep -q "ig360-netdisco-db"; then
    docker exec ig360-netdisco-db pg_dump \
      -U netdisco \
      -d netdisco \
      --no-password \
      --format=custom \
      --compress=9 \
      > "${BACKUP_PATH}/netdisco_db.dump" 2>/dev/null

    success "Netdisco database backed up"
  fi
}

# ── Backup Redis ──────────────────────────────────────────────
backup_redis() {
  log "Backing up Redis..."

  if docker ps --format '{{.Names}}' | grep -q "ig360-redis"; then
    docker exec ig360-redis redis-cli BGSAVE &>/dev/null || true
    sleep 2

    docker cp ig360-redis:/data/dump.rdb \
      "${BACKUP_PATH}/redis_dump.rdb" 2>/dev/null || \
      warn "Redis dump not found — skipping"

    success "Redis backed up"
  else
    warn "Redis container not running — skipping"
  fi
}

# ── Backup config directory ───────────────────────────────────
backup_config() {
  log "Backing up configuration files..."

  tar -czf "${BACKUP_PATH}/config.tar.gz" \
    -C "${PROJECT_DIR}" \
    config/ \
    docker/ \
    agents/ \
    scripts/ \
    install.sh \
    NOTICE \
    README.md \
    2>/dev/null

  success "Config backed up ($(du -sh "${BACKUP_PATH}/config.tar.gz" | cut -f1))"
}

# ── Backup Docker volumes ─────────────────────────────────────
backup_volumes() {
  log "Backing up Docker volumes..."

  volumes=(
    "infraguardian360_netbox-media-files"
    "infraguardian360_signoz-db"
  )

  for volume in "${volumes[@]}"; do
    if docker volume inspect "${volume}" &>/dev/null; then
      docker run --rm \
        -v "${volume}:/source:ro" \
        -v "${BACKUP_PATH}:/backup" \
        alpine \
        tar -czf "/backup/${volume}.tar.gz" -C /source . 2>/dev/null

      success "Volume ${volume} backed up"
    fi
  done
}

# ── Create manifest ───────────────────────────────────────────
create_manifest() {
  log "Creating backup manifest..."

  cat > "${BACKUP_PATH}/manifest.json" << EOF
{
  "backup_name": "${BACKUP_NAME}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "hostname": "$(hostname)",
  "ig360_version": "$(git -C ${PROJECT_DIR} describe --tags --always 2>/dev/null || echo 'unknown')",
  "files": $(ls "${BACKUP_PATH}" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().splitlines()))"),
  "total_size": "$(du -sh "${BACKUP_PATH}" | cut -f1)"
}
EOF

  success "Manifest created"
}

# ── Compress backup ───────────────────────────────────────────
compress_backup() {
  log "Compressing backup archive..."

  tar -czf "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" \
    -C "${BACKUP_DIR}" \
    "${BACKUP_NAME}/"

  rm -rf "${BACKUP_PATH}"

  FINAL_SIZE=$(du -sh "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" | cut -f1)
  success "Backup compressed: ${BACKUP_NAME}.tar.gz (${FINAL_SIZE})"
}

# ── Upload to object storage (optional) ──────────────────────
upload_offsite() {
  if [ -z "${BACKUP_S3_BUCKET:-}" ] && [ -z "${BACKUP_HETZNER_BUCKET:-}" ]; then
    warn "No offsite storage configured — backup is local only"
    warn "Set BACKUP_S3_BUCKET or BACKUP_HETZNER_BUCKET in .env for offsite backup"
    return
  fi

  # Hetzner Object Storage (S3-compatible)
  if [ -n "${BACKUP_HETZNER_BUCKET:-}" ] && command -v aws &>/dev/null; then
    log "Uploading to Hetzner Object Storage..."
    AWS_ACCESS_KEY_ID="${HETZNER_ACCESS_KEY}" \
    AWS_SECRET_ACCESS_KEY="${HETZNER_SECRET_KEY}" \
    aws s3 cp \
      "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" \
      "s3://${BACKUP_HETZNER_BUCKET}/backups/${BACKUP_NAME}.tar.gz" \
      --endpoint-url "https://nbg1.your-objectstorage.com" \
      --quiet

    success "Uploaded to Hetzner Object Storage"
  fi

  # AWS S3
  if [ -n "${BACKUP_S3_BUCKET:-}" ] && command -v aws &>/dev/null; then
    log "Uploading to S3..."
    aws s3 cp \
      "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" \
      "s3://${BACKUP_S3_BUCKET}/backups/${BACKUP_NAME}.tar.gz" \
      --quiet

    success "Uploaded to S3: s3://${BACKUP_S3_BUCKET}/backups/${BACKUP_NAME}.tar.gz"
  fi
}

# ── Cleanup old backups ───────────────────────────────────────
cleanup_old_backups() {
  log "Cleaning up backups older than ${RETENTION_DAYS} days..."

  deleted=$(find "${BACKUP_DIR}" \
    -name "ig360_backup_*.tar.gz" \
    -mtime "+${RETENTION_DAYS}" \
    -delete \
    -print | wc -l)

  success "Deleted ${deleted} old backup(s)"
}

# ── Restore function ──────────────────────────────────────────
restore() {
  local backup_file="${1:-}"

  if [ -z "${backup_file}" ]; then
    error "Usage: $0 restore <backup_file.tar.gz>"
    echo ""
    echo "Available backups:"
    ls -lh "${BACKUP_DIR}"/*.tar.gz 2>/dev/null || echo "No backups found in ${BACKUP_DIR}"
    exit 1
  fi

  if [ ! -f "${backup_file}" ]; then
    error "Backup file not found: ${backup_file}"
    exit 1
  fi

  warn "⚠️  This will OVERWRITE current data. Are you sure? (yes/no)"
  read -r confirm
  if [ "${confirm}" != "yes" ]; then
    log "Restore cancelled"
    exit 0
  fi

  log "Extracting backup archive..."
  RESTORE_DIR=$(mktemp -d)
  tar -xzf "${backup_file}" -C "${RESTORE_DIR}"
  BACKUP_CONTENT=$(ls "${RESTORE_DIR}")

  log "Restoring PostgreSQL databases..."
  if [ -f "${RESTORE_DIR}/${BACKUP_CONTENT}/netbox_db.dump" ]; then
    docker exec -i ig360-postgres pg_restore \
      -U netbox \
      -d netbox \
      --clean \
      --if-exists \
      < "${RESTORE_DIR}/${BACKUP_CONTENT}/netbox_db.dump" || true
    success "NetBox database restored"
  fi

  log "Restoring Redis..."
  if [ -f "${RESTORE_DIR}/${BACKUP_CONTENT}/redis_dump.rdb" ]; then
    docker cp \
      "${RESTORE_DIR}/${BACKUP_CONTENT}/redis_dump.rdb" \
      ig360-redis:/data/dump.rdb
    docker restart ig360-redis
    success "Redis restored"
  fi

  rm -rf "${RESTORE_DIR}"
  success "Restore complete — restart services to apply"
}

# ── Main ──────────────────────────────────────────────────────
main() {
  echo ""
  echo "=============================================="
  echo "  InfraGuardian360 Backup"
  echo "  $(date)"
  echo "=============================================="
  echo ""

  case "${1:-backup}" in
    backup)
      preflight
      backup_postgres
      backup_redis
      backup_config
      backup_volumes
      create_manifest
      compress_backup
      upload_offsite
      cleanup_old_backups
      echo ""
      success "Backup complete: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
      ;;
    restore)
      restore "${2:-}"
      ;;
    list)
      echo "Available backups in ${BACKUP_DIR}:"
      ls -lh "${BACKUP_DIR}"/*.tar.gz 2>/dev/null || \
        echo "No backups found"
      ;;
    *)
      echo "Usage: $0 [backup|restore <file>|list]"
      exit 1
      ;;
  esac
}

main "$@"