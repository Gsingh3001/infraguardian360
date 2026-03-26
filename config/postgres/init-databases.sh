#!/bin/bash
# ============================================================
#  InfraGuardian360 — PostgreSQL Database Initialisation
#  Creates all required databases on first boot
#  Runs automatically via docker-entrypoint-initdb.d
# ============================================================

set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL

  -- ── NetBox database (already created by POSTGRES_DB) ─────
  -- Already exists, just ensure permissions
  GRANT ALL PRIVILEGES ON DATABASE netbox TO netbox;

  -- ── Keycloak database ─────────────────────────────────────
  CREATE USER keycloak WITH PASSWORD '${KEYCLOAK_DB_PASSWORD}';
  CREATE DATABASE keycloak OWNER keycloak;
  GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;

  -- ── Netdisco database ─────────────────────────────────────
  CREATE USER netdisco WITH PASSWORD '${NETDISCO_DB_PASSWORD}';
  CREATE DATABASE netdisco OWNER netdisco;
  GRANT ALL PRIVILEGES ON DATABASE netdisco TO netdisco;

EOSQL

echo "InfraGuardian360 — All databases created successfully"