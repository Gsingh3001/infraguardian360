#!/usr/bin/env python3
"""
InfraGuardian360 — Self-Heal Watchdog Daemon
Monitors all 18 Docker services, classifies faults,
auto-remediates known issues, and calls Claude API for unknown faults.

Usage:
    python3 watchdog.py              # Run once
    python3 watchdog.py --daemon     # Run continuously every 30s
    python3 watchdog.py --status     # Show current health
"""

import os
import sys
import json
import time
import logging
import argparse
import subprocess
import shutil
from datetime import datetime
from typing import Optional

# ── Configuration ─────────────────────────────────────────────
CHECK_INTERVAL_SECONDS = int(os.getenv("WATCHDOG_INTERVAL", "30"))
DISK_CRITICAL_PERCENT = int(os.getenv("DISK_CRITICAL_PERCENT", "90"))
MEMORY_CRITICAL_PERCENT = int(os.getenv("MEMORY_CRITICAL_PERCENT", "90"))
LOG_FILE = os.getenv("WATCHDOG_LOG", "/var/log/ig360-watchdog.log")
SLACK_WEBHOOK = os.getenv("SLACK_WEBHOOK_URL", "")
CLAUDE_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")
NOTIFY_EMAIL = os.getenv("NOTIFY_EMAIL", "")

# ── Services to monitor ───────────────────────────────────────
SERVICES = {
    "postgres":           ("ig360-postgres",             True,  []),
    "redis":              ("ig360-redis",                True,  []),
    "netbox":             ("ig360-netbox",               True,  ["postgres", "redis"]),
    "netbox-worker":      ("ig360-netbox-worker",        False, ["postgres", "redis"]),
    "keycloak":           ("ig360-keycloak",             True,  ["postgres"]),
    "traefik":            ("ig360-traefik",              True,  []),
    "hertzbeat":          ("ig360-hertzbeat",            True,  []),
    "prometheus":         ("ig360-prometheus",           True,  []),
    "alertmanager":       ("ig360-alertmanager",         False, []),
    "victoriametrics":    ("ig360-victoria",             True,  []),
    "otel-collector":     ("ig360-otel-collector",       False, []),
    "netdisco":           ("ig360-netdisco",             False, ["postgres"]),
    "clickhouse":         ("ig360-clickhouse",           False, []),
    "signoz-query":       ("ig360-signoz-query",         False, ["clickhouse"]),
    "signoz-frontend":    ("ig360-signoz-frontend",      False, ["signoz-query"]),
    "opensearch":         ("ig360-opensearch",           False, []),
    "opensearch-dashboards": ("ig360-opensearch-dashboards", False, ["opensearch"]),
    "fluent-bit":         ("ig360-fluent-bit",           False, ["opensearch"]),
}

# ── Known faults and auto-fixes ───────────────────────────────
KNOWN_FAULTS = {
    "container_exited": {
        "description": "Container exited unexpectedly",
        "confidence": "high",
        "fix": "restart_container",
    },
    "container_oom": {
        "description": "Container killed by OOM killer",
        "confidence": "high",
        "fix": "restart_container_and_alert",
    },
    "disk_full": {
        "description": "Disk usage above 90%",
        "confidence": "high",
        "fix": "free_disk_space",
    },
    "postgres_not_ready": {
        "description": "PostgreSQL not accepting connections",
        "confidence": "high",
        "fix": "restart_container",
    },
    "netbox_migration_stuck": {
        "description": "NetBox database migration pending",
        "confidence": "medium",
        "fix": "run_netbox_migrations",
    },
    "redis_oom": {
        "description": "Redis out of memory",
        "confidence": "high",
        "fix": "flush_redis_cache",
    },
    "cert_expiring": {
        "description": "SSL certificate expiring within 7 days",
        "confidence": "high",
        "fix": "renew_traefik_cert",
    },
}

# ── Logging ───────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(LOG_FILE) if os.path.exists(os.path.dirname(LOG_FILE)) else logging.NullHandler()
    ]
)
log = logging.getLogger("ig360-watchdog")


# ────────────────────────────────────────────────────────────
# HEALTH CHECK FUNCTIONS
# ────────────────────────────────────────────────────────────

def check_container(container_name: str) -> dict:
    """Check container health via Docker inspect."""
    try:
        result = subprocess.run(
            ["docker", "inspect", "--format",
             "{{.State.Status}}|{{.State.ExitCode}}|{{.State.OOMKilled}}|{{.RestartCount}}",
             container_name],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode != 0:
            return {"status": "not_found", "container": container_name}

        parts = result.stdout.strip().split("|")
        return {
            "container": container_name,
            "status": parts[0],
            "exit_code": int(parts[1]),
            "oom_killed": parts[2].lower() == "true",
            "restart_count": int(parts[3]),
        }
    except Exception as e:
        return {"status": "error", "container": container_name, "error": str(e)}


def check_disk() -> dict:
    """Check disk usage on the server."""
    total, used, free = shutil.disk_usage("/")
    percent = (used / total) * 100
    return {
        "total_gb": round(total / (1024**3), 1),
        "used_gb": round(used / (1024**3), 1),
        "free_gb": round(free / (1024**3), 1),
        "percent": round(percent, 1),
        "critical": percent > DISK_CRITICAL_PERCENT
    }


def check_memory() -> dict:
    """Check system memory usage."""
    try:
        with open("/proc/meminfo") as f:
            lines = f.readlines()
        mem_info = {}
        for line in lines:
            parts = line.split()
            if len(parts) >= 2:
                mem_info[parts[0].rstrip(":")] = int(parts[1])

        total = mem_info.get("MemTotal", 0)
        available = mem_info.get("MemAvailable", 0)
        used = total - available
        percent = (used / total * 100) if total > 0 else 0

        return {
            "total_gb": round(total / (1024**2), 1),
            "used_gb": round(used / (1024**2), 1),
            "available_gb": round(available / (1024**2), 1),
            "percent": round(percent, 1),
            "critical": percent > MEMORY_CRITICAL_PERCENT
        }
    except Exception:
        return {"percent": 0, "critical": False}


def check_postgres() -> dict:
    """Check if PostgreSQL is accepting connections."""
    try:
        result = subprocess.run(
            ["docker", "exec", "ig360-postgres",
             "pg_isready", "-U", "netbox"],
            capture_output=True, text=True, timeout=10
        )
        return {
            "ready": result.returncode == 0,
            "output": result.stdout.strip()
        }
    except Exception as e:
        return {"ready": False, "error": str(e)}


def check_port(host: str, port: int) -> bool:
    """Check if a TCP port is open."""
    import socket
    try:
        with socket.create_connection((host, port), timeout=5):
            return True
    except (socket.timeout, ConnectionRefusedError, OSError):
        return False


# ────────────────────────────────────────────────────────────
# REMEDIATION FUNCTIONS
# ────────────────────────────────────────────────────────────

def restart_container(container_name: str) -> bool:
    """Restart a Docker container."""
    try:
        result = subprocess.run(
            ["docker", "restart", container_name],
            capture_output=True, text=True, timeout=60
        )
        return result.returncode == 0
    except Exception:
        return False


def free_disk_space() -> bool:
    """Free disk space by pruning Docker resources."""
    try:
        # Remove unused images
        subprocess.run(
            ["docker", "image", "prune", "-f"],
            capture_output=True, timeout=120
        )
        # Remove stopped containers
        subprocess.run(
            ["docker", "container", "prune", "-f"],
            capture_output=True, timeout=30
        )
        # Remove unused volumes (careful — skip named volumes)
        subprocess.run(
            ["docker", "volume", "prune", "-f"],
            capture_output=True, timeout=30
        )
        log.info("Disk space freed via Docker prune")
        return True
    except Exception as e:
        log.error(f"Failed to free disk space: {e}")
        return False


def run_netbox_migrations() -> bool:
    """Run pending NetBox database migrations."""
    try:
        result = subprocess.run(
            ["docker", "exec", "ig360-netbox",
             "python", "manage.py", "migrate", "--no-input"],
            capture_output=True, text=True, timeout=120
        )
        return result.returncode == 0
    except Exception:
        return False


def flush_redis_cache() -> bool:
    """Flush Redis cache to free memory."""
    try:
        result = subprocess.run(
            ["docker", "exec", "ig360-redis",
             "redis-cli", "FLUSHDB"],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode == 0:
            subprocess.run(
                ["docker", "restart", "ig360-redis"],
                capture_output=True, timeout=30
            )
            return True
        return False
    except Exception:
        return False


def renew_traefik_cert() -> bool:
    """Force Traefik to renew SSL certificates."""
    try:
        subprocess.run(
            ["docker", "exec", "ig360-traefik",
             "kill", "-USR1", "1"],
            capture_output=True, timeout=10
        )
        return True
    except Exception:
        return False


# ────────────────────────────────────────────────────────────
# AI DIAGNOSIS (Claude API)
# ────────────────────────────────────────────────────────────

def ai_diagnose(fault_info: dict) -> Optional[str]:
    """Call Claude API to diagnose unknown faults."""
    if not CLAUDE_API_KEY:
        return None

    try:
        import urllib.request
        import urllib.error

        prompt = f"""You are an expert DevOps engineer helping to diagnose a fault 
in InfraGuardian360, a self-hosted IT infrastructure monitoring platform built 
from Docker containers.

Fault information:
{json.dumps(fault_info, indent=2)}

Platform services: NetBox (CMDB), HertzBeat (monitoring), Prometheus, 
VictoriaMetrics, SigNoz, ClickHouse, OpenSearch, Fluent Bit, Keycloak (SSO), 
Traefik (reverse proxy), PostgreSQL, Redis, Netdisco.

Please provide:
1. Most likely root cause (2-3 sentences)
2. Exact commands to fix it
3. How to prevent recurrence

Be concise and practical. Focus on the most likely cause first."""

        payload = json.dumps({
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 1000,
            "messages": [{"role": "user", "content": prompt}]
        }).encode()

        req = urllib.request.Request(
            "https://api.anthropic.com/v1/messages",
            data=payload,
            headers={
                "Content-Type": "application/json",
                "x-api-key": CLAUDE_API_KEY,
                "anthropic-version": "2023-06-01"
            }
        )

        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read())
            return data["content"][0]["text"]

    except Exception as e:
        log.error(f"AI diagnosis failed: {e}")
        return None


# ────────────────────────────────────────────────────────────
# NOTIFICATION
# ────────────────────────────────────────────────────────────

def notify_slack(message: str, severity: str = "warning") -> None:
    """Send notification to Slack."""
    if not SLACK_WEBHOOK:
        return

    try:
        import urllib.request
        emoji = {"critical": "🔴", "warning": "🟡",
                 "info": "🟢", "fixed": "✅"}.get(severity, "⚠️")

        payload = json.dumps({
            "text": f"{emoji} *InfraGuardian360*\n{message}",
            "username": "IG360 Watchdog",
            "icon_emoji": ":shield:"
        }).encode()

        req = urllib.request.Request(
            SLACK_WEBHOOK,
            data=payload,
            headers={"Content-Type": "application/json"}
        )
        urllib.request.urlopen(req, timeout=10)
    except Exception as e:
        log.error(f"Slack notification failed: {e}")


# ────────────────────────────────────────────────────────────
# MAIN HEALTH CHECK LOOP
# ────────────────────────────────────────────────────────────

def run_health_checks() -> dict:
    """Run all health checks and return results."""
    results = {
        "timestamp": datetime.utcnow().isoformat(),
        "overall": "healthy",
        "services": {},
        "system": {},
        "faults": [],
        "actions_taken": []
    }

    # ── Check system resources ─────────────────────────────────
    disk = check_disk()
    memory = check_memory()
    results["system"] = {"disk": disk, "memory": memory}

    if disk["critical"]:
        fault = {
            "type": "disk_full",
            "message": f"Disk at {disk['percent']}% — {disk['free_gb']}GB free",
            "severity": "critical"
        }
        results["faults"].append(fault)
        results["overall"] = "critical"

        log.warning(f"Disk critical: {disk['percent']}% used")
        if free_disk_space():
            results["actions_taken"].append("Freed disk space via Docker prune")
            notify_slack(
                f"⚠️ Disk was at {disk['percent']}% — freed space via Docker prune",
                "fixed"
            )
        else:
            notify_slack(
                f"🔴 Disk at {disk['percent']}% — MANUAL ACTION REQUIRED",
                "critical"
            )

    # ── Check each service ────────────────────────────────────
    for service_name, (container_name, is_critical, depends_on) in SERVICES.items():
        container_info = check_container(container_name)
        status = container_info.get("status", "unknown")

        results["services"][service_name] = {
            "container": container_name,
            "status": status,
            "critical": is_critical,
            "restart_count": container_info.get("restart_count", 0)
        }

        # Container not running
        if status in ("exited", "dead", "not_found"):
            fault_type = "container_oom" \
                if container_info.get("oom_killed") \
                else "container_exited"

            fault = {
                "type": fault_type,
                "service": service_name,
                "container": container_name,
                "exit_code": container_info.get("exit_code", -1),
                "severity": "critical" if is_critical else "warning"
            }
            results["faults"].append(fault)

            if is_critical:
                results["overall"] = "critical"

            log.warning(f"Service {service_name} is {status} — attempting restart")

            if restart_container(container_name):
                results["actions_taken"].append(
                    f"Restarted {service_name}"
                )
                notify_slack(
                    f"Container {service_name} was {status} — auto-restarted ✅",
                    "fixed"
                )
                log.info(f"Restarted {service_name} successfully")
            else:
                notify_slack(
                    f"🔴 Container {service_name} failed to restart — manual action needed",
                    "critical"
                )
                log.error(f"Failed to restart {service_name}")

                # Call AI diagnosis for critical failures
                if is_critical and CLAUDE_API_KEY:
                    log.info(f"Requesting AI diagnosis for {service_name}...")
                    diagnosis = ai_diagnose({
                        "service": service_name,
                        "container": container_name,
                        "status": status,
                        "exit_code": container_info.get("exit_code", -1),
                        "oom_killed": container_info.get("oom_killed", False),
                        "restart_count": container_info.get("restart_count", 0),
                        "disk": disk,
                        "memory": memory
                    })
                    if diagnosis:
                        notify_slack(
                            f"🤖 AI Diagnosis for {service_name}:\n```{diagnosis[:800]}```",
                            "critical"
                        )

        # High restart count warning
        elif container_info.get("restart_count", 0) > 5:
            log.warning(
                f"Service {service_name} has restarted "
                f"{container_info['restart_count']} times"
            )
            results["faults"].append({
                "type": "high_restart_count",
                "service": service_name,
                "restart_count": container_info["restart_count"],
                "severity": "warning"
            })

    # ── Deep checks ────────────────────────────────────────────

    # PostgreSQL readiness
    if results["services"].get("postgres", {}).get("status") == "running":
        pg_check = check_postgres()
        if not pg_check.get("ready"):
            results["faults"].append({
                "type": "postgres_not_ready",
                "message": "PostgreSQL not accepting connections",
                "severity": "critical"
            })
            results["overall"] = "critical"
            notify_slack(
                "🔴 PostgreSQL running but not accepting connections",
                "critical"
            )

    # Update overall status
    if results["overall"] == "healthy" and results["faults"]:
        results["overall"] = "degraded"

    return results


def print_status(results: dict) -> None:
    """Print health check results to console."""
    status_emoji = {
        "healthy": "🟢",
        "degraded": "🟡",
        "critical": "🔴"
    }.get(results["overall"], "⚪")

    print(f"\n{'='*60}")
    print(f"  InfraGuardian360 Health Check")
    print(f"  {results['timestamp']}")
    print(f"  Overall: {status_emoji} {results['overall'].upper()}")
    print(f"{'='*60}")

    # System
    disk = results["system"].get("disk", {})
    mem = results["system"].get("memory", {})
    print(f"\nSystem:")
    print(f"  Disk:   {disk.get('percent', 0):.1f}% used "
          f"({disk.get('free_gb', 0):.1f}GB free)")
    print(f"  Memory: {mem.get('percent', 0):.1f}% used "
          f"({mem.get('available_gb', 0):.1f}GB available)")

    # Services
    print(f"\nServices ({len(results['services'])}):")
    for name, info in results["services"].items():
        status = info.get("status", "unknown")
        emoji = "✅" if status == "running" else "❌"
        critical_marker = " [CRITICAL]" if info.get("critical") and status != "running" else ""
        restarts = f" (restarts: {info['restart_count']})" if info.get("restart_count", 0) > 0 else ""
        print(f"  {emoji} {name:<25} {status}{critical_marker}{restarts}")

    # Faults
    if results["faults"]:
        print(f"\nFaults ({len(results['faults'])}):")
        for fault in results["faults"]:
            print(f"  ⚠️  {fault.get('type')}: {fault.get('message', fault.get('service', ''))}")

    # Actions taken
    if results["actions_taken"]:
        print(f"\nActions taken:")
        for action in results["actions_taken"]:
            print(f"  🔧 {action}")

    print(f"\n{'='*60}\n")


def main():
    parser = argparse.ArgumentParser(
        description="InfraGuardian360 Self-Heal Watchdog"
    )
    parser.add_argument(
        "--daemon",
        action="store_true",
        help=f"Run continuously every {CHECK_INTERVAL_SECONDS} seconds"
    )
    parser.add_argument(
        "--status",
        action="store_true",
        help="Show current health status and exit"
    )
    parser.add_argument(
        "--interval",
        type=int,
        default=CHECK_INTERVAL_SECONDS,
        help="Check interval in seconds (daemon mode)"
    )
    args = parser.parse_args()

    if args.status or not args.daemon:
        results = run_health_checks()
        print_status(results)

        # Exit with error code if critical
        if results["overall"] == "critical":
            sys.exit(1)
        return

    # Daemon mode
    log.info(f"InfraGuardian360 watchdog starting — checking every {args.interval}s")
    notify_slack("🟢 InfraGuardian360 watchdog started", "info")

    while True:
        try:
            results = run_health_checks()

            if results["overall"] != "healthy":
                log.warning(
                    f"Health: {results['overall']} — "
                    f"{len(results['faults'])} fault(s)"
                )
            else:
                log.info("Health: HEALTHY ✓")

            # Write status file for external monitoring
            status_file = "/tmp/ig360-health.json"
            with open(status_file, "w") as f:
                json.dump(results, f, indent=2)

        except KeyboardInterrupt:
            log.info("Watchdog stopped")
            notify_slack("🔴 InfraGuardian360 watchdog stopped", "warning")
            break
        except Exception as e:
            log.error(f"Watchdog error: {e}")

        time.sleep(args.interval)


if __name__ == "__main__":
    main()