#!/usr/bin/env python3
"""
InfraGuardian360 — Netdisco to NetBox Sync Script
Reads topology discovered by Netdisco and pushes to NetBox via REST API
Run manually or via cron: 0 * * * * python3 /opt/infraguardian360/scripts/netdisco-to-netbox.py

Usage:
    python3 netdisco-to-netbox.py
    python3 netdisco-to-netbox.py --dry-run
    python3 netdisco-to-netbox.py --device 192.168.1.1
"""

import os
import sys
import json
import logging
import argparse
import requests
import psycopg2
from datetime import datetime
from typing import Optional

# ── CONFIGURATION ────────────────────────────────────────────
NETDISCO_DB_HOST = os.getenv("NETDISCO_DB_HOST", "localhost")
NETDISCO_DB_PORT = os.getenv("NETDISCO_DB_PORT", "5432")
NETDISCO_DB_NAME = os.getenv("NETDISCO_DB_NAME", "netdisco")
NETDISCO_DB_USER = os.getenv("NETDISCO_DB_USER", "netdisco")
NETDISCO_DB_PASS = os.getenv("NETDISCO_DB_PASS", "")

NETBOX_URL = os.getenv("NETBOX_URL", "http://localhost:8080")
NETBOX_TOKEN = os.getenv("NETBOX_TOKEN", "")

DEFAULT_SITE = os.getenv("NETBOX_DEFAULT_SITE", "Auto-Discovered")
DEFAULT_ROLE = os.getenv("NETBOX_DEFAULT_ROLE", "Unknown")

# ── LOGGING ──────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("/var/log/ig360-sync.log") if os.path.exists("/var/log") else logging.NullHandler()
    ]
)
log = logging.getLogger("ig360-sync")


class NetBoxClient:
    """NetBox API client."""

    def __init__(self, url: str, token: str):
        self.base = url.rstrip("/") + "/api"
        self.headers = {
            "Authorization": f"Token {token}",
            "Content-Type": "application/json",
            "Accept": "application/json"
        }

    def get(self, endpoint: str, params: dict = None) -> dict:
        r = requests.get(f"{self.base}{endpoint}", headers=self.headers, params=params, timeout=30)
        r.raise_for_status()
        return r.json()

    def post(self, endpoint: str, data: dict) -> dict:
        r = requests.post(f"{self.base}{endpoint}", headers=self.headers, json=data, timeout=30)
        r.raise_for_status()
        return r.json()

    def patch(self, endpoint: str, obj_id: int, data: dict) -> dict:
        r = requests.patch(f"{self.base}{endpoint}{obj_id}/", headers=self.headers, json=data, timeout=30)
        r.raise_for_status()
        return r.json()

    def get_or_create_site(self, name: str) -> int:
        """Get existing site or create it."""
        result = self.get("/dcim/sites/", {"name": name})
        if result["count"] > 0:
            return result["results"][0]["id"]
        created = self.post("/dcim/sites/", {"name": name, "slug": name.lower().replace(" ", "-"), "status": "active"})
        log.info(f"Created site: {name}")
        return created["id"]

    def get_or_create_role(self, name: str) -> int:
        """Get existing device role or create it."""
        slug = name.lower().replace(" ", "-").replace("/", "-")
        result = self.get("/dcim/device-roles/", {"name": name})
        if result["count"] > 0:
            return result["results"][0]["id"]
        created = self.post("/dcim/device-roles/", {"name": name, "slug": slug, "color": "9e9e9e"})
        log.info(f"Created device role: {name}")
        return created["id"]

    def get_or_create_manufacturer(self, name: str) -> int:
        """Get existing manufacturer or create it."""
        slug = name.lower().replace(" ", "-")
        result = self.get("/dcim/manufacturers/", {"name": name})
        if result["count"] > 0:
            return result["results"][0]["id"]
        created = self.post("/dcim/manufacturers/", {"name": name, "slug": slug})
        log.info(f"Created manufacturer: {name}")
        return created["id"]

    def get_or_create_device_type(self, model: str, manufacturer_id: int) -> int:
        """Get existing device type or create it."""
        slug = model.lower().replace(" ", "-").replace("/", "-")[:50]
        result = self.get("/dcim/device-types/", {"model": model})
        if result["count"] > 0:
            return result["results"][0]["id"]
        created = self.post("/dcim/device-types/", {
            "manufacturer": manufacturer_id,
            "model": model,
            "slug": slug
        })
        log.info(f"Created device type: {model}")
        return created["id"]

    def find_device_by_name(self, name: str) -> Optional[dict]:
        """Find existing device by name."""
        result = self.get("/dcim/devices/", {"name": name})
        if result["count"] > 0:
            return result["results"][0]
        return None

    def find_device_by_ip(self, ip: str) -> Optional[dict]:
        """Find existing device by primary IP."""
        result = self.get("/ipam/ip-addresses/", {"address": ip, "assigned_object_type": "dcim.interface"})
        if result["count"] > 0:
            interface_id = result["results"][0].get("assigned_object_id")
            if interface_id:
                iface = self.get(f"/dcim/interfaces/{interface_id}/")
                return iface.get("device")
        return None


class NetdiscoClient:
    """Netdisco PostgreSQL client."""

    def __init__(self, host: str, port: str, dbname: str, user: str, password: str):
        self.conn = psycopg2.connect(
            host=host, port=port, dbname=dbname,
            user=user, password=password,
            connect_timeout=10
        )
        self.conn.autocommit = True

    def get_all_devices(self) -> list:
        """Get all discovered devices from Netdisco."""
        with self.conn.cursor() as cur:
            cur.execute("""
                SELECT
                    d.ip,
                    d.name,
                    d.description,
                    d.model,
                    d.vendor,
                    d.os,
                    d.os_ver,
                    d.serial,
                    d.layers,
                    d.mac,
                    d.contact,
                    d.location,
                    d.last_discover
                FROM device d
                WHERE d.last_discover IS NOT NULL
                ORDER BY d.last_discover DESC
            """)
            columns = [desc[0] for desc in cur.description]
            return [dict(zip(columns, row)) for row in cur.fetchall()]

    def get_device_ports(self, ip: str) -> list:
        """Get all ports for a device."""
        with self.conn.cursor() as cur:
            cur.execute("""
                SELECT
                    dp.port,
                    dp.descr,
                    dp.type,
                    dp.speed,
                    dp.duplex,
                    dp.up,
                    dp.up_admin,
                    dp.mac,
                    dp.vlan,
                    dp.pvid,
                    dp.lastchange
                FROM device_port dp
                WHERE dp.ip = %s
                ORDER BY dp.port
            """, (ip,))
            columns = [desc[0] for desc in cur.description]
            return [dict(zip(columns, row)) for row in cur.fetchall()]

    def get_device_neighbours(self, ip: str) -> list:
        """Get LLDP/CDP neighbours for a device."""
        with self.conn.cursor() as cur:
            cur.execute("""
                SELECT
                    dn.port,
                    dn.remote_ip,
                    dn.remote_port,
                    dn.remote_type,
                    dn.remote_id,
                    dn.remote_desc
                FROM device_port_log dn
                WHERE dn.ip = %s
                  AND dn.remote_ip IS NOT NULL
            """, (ip,))
            columns = [desc[0] for desc in cur.description]
            return [dict(zip(columns, row)) for row in cur.fetchall()]

    def get_mac_addresses(self, ip: str) -> list:
        """Get MAC address table for a device."""
        with self.conn.cursor() as cur:
            cur.execute("""
                SELECT
                    n.mac,
                    n.port,
                    n.vlan,
                    n.time_first,
                    n.time_last,
                    n.switch,
                    n.oui
                FROM node n
                WHERE n.switch = %s
                  AND n.active = true
                ORDER BY n.time_last DESC
                LIMIT 500
            """, (ip,))
            columns = [desc[0] for desc in cur.description]
            return [dict(zip(columns, row)) for row in cur.fetchall()]

    def close(self):
        self.conn.close()


def map_vendor_to_manufacturer(vendor: str) -> str:
    """Map Netdisco vendor string to clean manufacturer name."""
    if not vendor:
        return "Unknown"
    vendor_lower = vendor.lower()
    mapping = {
        "cisco": "Cisco",
        "juniper": "Juniper Networks",
        "arista": "Arista Networks",
        "hp": "HP",
        "hewlett": "HP",
        "aruba": "Aruba Networks",
        "dell": "Dell",
        "ubiquiti": "Ubiquiti",
        "fortinet": "Fortinet",
        "palo alto": "Palo Alto Networks",
        "ruckus": "Ruckus Networks",
        "extreme": "Extreme Networks",
        "brocade": "Brocade",
        "netgear": "Netgear",
        "d-link": "D-Link",
        "tp-link": "TP-Link",
    }
    for key, name in mapping.items():
        if key in vendor_lower:
            return name
    return vendor.title()


def map_layers_to_role(layers: str, vendor: str, model: str) -> str:
    """Map SNMP layers bitmap to device role."""
    if not layers:
        return "Unknown"
    model_lower = (model or "").lower()
    vendor_lower = (vendor or "").lower()

    if "phone" in model_lower or "ip phone" in model_lower:
        return "IP Phone"
    if "ap" in model_lower or "access point" in model_lower or "unifi" in model_lower:
        return "Wireless AP"
    if "printer" in model_lower or "laserjet" in model_lower or "officejet" in model_lower:
        return "Printer"
    if "firewall" in model_lower or "fortigate" in model_lower or "pfsense" in model_lower:
        return "Firewall"

    # SNMP layers: bit 2 = datalink, bit 3 = network, bit 4 = transport
    try:
        layer_int = int(layers)
        if layer_int & 4:   # Bit 3 — network layer (router)
            return "Router"
        if layer_int & 2:   # Bit 2 — datalink (switch)
            return "Switch"
    except (ValueError, TypeError):
        pass

    return "Unknown"


def sync_device(nb: NetBoxClient, device: dict, dry_run: bool, site_id: int) -> dict:
    """Sync a single Netdisco device to NetBox."""
    ip = device["ip"]
    name = device["name"] or f"device-{ip.replace('.', '-')}"
    vendor = device["vendor"] or "Unknown"
    model = device["model"] or "Unknown"
    serial = device["serial"] or ""

    manufacturer_name = map_vendor_to_manufacturer(vendor)
    role_name = map_layers_to_role(device.get("layers"), vendor, model)

    result = {"ip": ip, "name": name, "action": None, "success": False}

    if dry_run:
        log.info(f"[DRY-RUN] Would sync: {name} ({ip}) — {manufacturer_name} {model} — Role: {role_name}")
        result["action"] = "dry-run"
        result["success"] = True
        return result

    try:
        manufacturer_id = nb.get_or_create_manufacturer(manufacturer_name)
        device_type_id = nb.get_or_create_device_type(model, manufacturer_id)
        role_id = nb.get_or_create_role(role_name)

        existing = nb.find_device_by_name(name)

        device_data = {
            "name": name,
            "device_type": device_type_id,
            "role": role_id,
            "site": site_id,
            "status": "active",
            "serial": serial[:50] if serial else "",
            "comments": f"Auto-discovered by InfraGuardian360 Netdisco sync\n"
                       f"IP: {ip}\n"
                       f"OS: {device.get('os', '')} {device.get('os_ver', '')}\n"
                       f"Last discovered: {device.get('last_discover', '')}\n"
                       f"Description: {device.get('description', '')}\n"
                       f"Contact: {device.get('contact', '')}\n"
                       f"Location: {device.get('location', '')}",
            "custom_fields": {
                "management_ip": ip,
                "snmp_last_seen": str(device.get("last_discover", ""))
            }
        }

        if existing:
            nb.patch("/dcim/devices/", existing["id"], device_data)
            log.info(f"Updated device: {name} ({ip})")
            result["action"] = "updated"
        else:
            nb.post("/dcim/devices/", device_data)
            log.info(f"Created device: {name} ({ip})")
            result["action"] = "created"

        result["success"] = True

    except requests.exceptions.HTTPError as e:
        log.error(f"NetBox API error for {name} ({ip}): {e.response.text}")
        result["action"] = "error"
    except Exception as e:
        log.error(f"Unexpected error for {name} ({ip}): {e}")
        result["action"] = "error"

    return result


def main():
    parser = argparse.ArgumentParser(description="InfraGuardian360 — Netdisco to NetBox Sync")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be synced without making changes")
    parser.add_argument("--device", help="Sync only this device IP")
    parser.add_argument("--verbose", action="store_true", help="Verbose logging")
    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    if not NETBOX_TOKEN:
        log.error("NETBOX_TOKEN environment variable not set")
        sys.exit(1)

    log.info("=" * 60)
    log.info("InfraGuardian360 — Netdisco → NetBox Sync")
    log.info(f"Mode: {'DRY RUN' if args.dry_run else 'LIVE'}")
    log.info(f"Time: {datetime.now().isoformat()}")
    log.info("=" * 60)

    # Connect to Netdisco DB
    try:
        nd = NetdiscoClient(
            NETDISCO_DB_HOST, NETDISCO_DB_PORT,
            NETDISCO_DB_NAME, NETDISCO_DB_USER, NETDISCO_DB_PASS
        )
        log.info("Connected to Netdisco database")
    except Exception as e:
        log.error(f"Cannot connect to Netdisco DB: {e}")
        sys.exit(1)

    # Connect to NetBox API
    try:
        nb = NetBoxClient(NETBOX_URL, NETBOX_TOKEN)
        nb.get("/dcim/sites/", {"limit": 1})
        log.info(f"Connected to NetBox API at {NETBOX_URL}")
    except Exception as e:
        log.error(f"Cannot connect to NetBox API: {e}")
        nd.close()
        sys.exit(1)

    # Get or create default site
    site_id = nb.get_or_create_site(DEFAULT_SITE)

    # Get devices from Netdisco
    devices = nd.get_all_devices()
    if args.device:
        devices = [d for d in devices if d["ip"] == args.device]
        if not devices:
            log.error(f"Device {args.device} not found in Netdisco")
            nd.close()
            sys.exit(1)

    log.info(f"Found {len(devices)} devices in Netdisco")

    # Sync each device
    results = {"created": 0, "updated": 0, "error": 0, "dry-run": 0}
    for device in devices:
        result = sync_device(nb, device, args.dry_run, site_id)
        action = result.get("action", "error")
        if action in results:
            results[action] += 1

    # Summary
    log.info("=" * 60)
    log.info("SYNC COMPLETE")
    log.info(f"  Created:  {results['created']}")
    log.info(f"  Updated:  {results['updated']}")
    log.info(f"  Errors:   {results['error']}")
    if args.dry_run:
        log.info(f"  Dry-run:  {results['dry-run']}")
    log.info("=" * 60)

    nd.close()

    if results["error"] > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()