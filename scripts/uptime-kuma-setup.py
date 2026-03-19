#!/usr/bin/env python3
"""Create/refresh Uptime Kuma monitors, status page, and ntfy notifications.

Requirements:
  - Python 3.10+
  - uptime-kuma-api Python package (installed by wrapper shell script)

Environment variables:
  UPTIME_KUMA_URL=http://localhost:3001
  UPTIME_KUMA_USERNAME=admin
  UPTIME_KUMA_PASSWORD=***
  DOMAIN=example.com
  NTFY_URL=https://ntfy.example.com
  NTFY_TOPIC=homelab-alerts
"""

from __future__ import annotations

import os
import sys
from typing import Any, Dict, List, Optional

try:
    from uptime_kuma_api import MonitorType, NotificationType, UptimeKumaApi
except Exception:
    print("[ERROR] Missing dependency 'uptime-kuma-api'.", file=sys.stderr)
    raise


def env(name: str, default: str | None = None, required: bool = False) -> str:
    value = os.getenv(name, default)
    if required and not value:
        raise RuntimeError(f"Environment variable {name} is required")
    return value or ""


def desired_monitors(domain: str) -> List[Dict[str, str]]:
    services = [
        ("Grafana", f"https://grafana.{domain}/api/health"),
        ("Prometheus", f"https://prometheus.{domain}/-/healthy"),
        ("Alertmanager", f"https://alerts.{domain}/-/healthy"),
        ("Uptime Kuma", f"https://status.{domain}/"),
        ("Traefik", f"https://traefik.{domain}/ping"),
        ("Gitea", f"https://git.{domain}/api/healthz"),
        ("Nextcloud", f"https://nextcloud.{domain}/status.php"),
    ]
    return [{"name": name, "url": url} for name, url in services]


def ensure_ntfy_notification(api: UptimeKumaApi, ntfy_url: str, ntfy_topic: str) -> Optional[int]:
    target_name = "ntfy-homelab"
    existing = api.get_notifications()
    for n in existing:
      if n.get("name") == target_name:
        print(f"[SKIP] Notification exists: {target_name}")
        return n.get("id")

    result = api.add_notification(
        name=target_name,
        type=NotificationType.NTFY,
        isDefault=False,
        applyExisting=False,
        ntfyserverurl=ntfy_url,
        ntfytopic=ntfy_topic,
        ntfyPriority=3,
        ntfyAuthenticationMethod="none",
        ntfyIcon="https://grafana.com/static/assets/img/grafana-net-icon.svg",
    )
    nid = result.get("id")
    print(f"[ADD] Notification {target_name} (id={nid})")
    return nid


def ensure_status_page(api: UptimeKumaApi, domain: str, monitor_ids: List[int]) -> None:
    slug = "status"
    pages = api.get_status_pages()
    if not any(p.get("slug") == slug for p in pages):
        api.add_status_page(slug=slug, title="HomeLab Status")
        print("[ADD] Status page created: /status")
    else:
        print("[SKIP] Status page exists: /status")

    public_group = [{"id": mid} for mid in monitor_ids]
    api.save_status_page(
        slug=slug,
        title="HomeLab Status",
        description="Public uptime status for homelab services",
        domainNameList=[f"status.{domain}"],
        published=True,
        showPoweredBy=False,
        publicGroupList=[
            {
                "name": "Core Services",
                "weight": 1,
                "monitorList": public_group,
            }
        ],
    )
    print("[OK] Status page updated with monitor group and domain")


def main() -> int:
    kuma_url = env("UPTIME_KUMA_URL", "http://localhost:3001")
    username = env("UPTIME_KUMA_USERNAME", required=True)
    password = env("UPTIME_KUMA_PASSWORD", required=True)
    domain = env("DOMAIN", required=True)
    ntfy_url = env("NTFY_URL", f"https://ntfy.{domain}")
    ntfy_topic = env("NTFY_TOPIC", "homelab-alerts")

    monitors = desired_monitors(domain)

    with UptimeKumaApi(kuma_url) as api:
        api.login(username, password)
        notification_id = ensure_ntfy_notification(api, ntfy_url, ntfy_topic)

        existing = {m["name"]: m for m in api.get_monitors()}
        monitor_ids: List[int] = []

        for monitor in monitors:
            name = monitor["name"]
            url = monitor["url"]
            if name in existing:
                mid = existing[name].get("id")
                monitor_ids.append(mid)
                print(f"[SKIP] Monitor exists: {name} (id={mid})")
                if notification_id and isinstance(mid, int):
                    current = existing[name].get("notificationIDList") or []
                    if notification_id not in current:
                        api.edit_monitor(mid, notificationIDList=[*current, notification_id])
                        print(f"[EDIT] Attached ntfy notification to monitor: {name}")
                continue

            payload: Dict[str, Any] = {
                "type": MonitorType.HTTP,
                "name": name,
                "url": url,
                "interval": 60,
                "maxretries": 3,
                "retryInterval": 30,
                "accepted_statuscodes": ["200-299", "301-308"],
                "ignoreTls": False,
            }
            if notification_id:
                payload["notificationIDList"] = [notification_id]

            result = api.add_monitor(**payload)
            monitor_id = result.get("monitorID") or result.get("monitorId")
            if monitor_id:
                monitor_ids.append(monitor_id)
            print(f"[ADD] {name} -> {url} (id={monitor_id})")

        ensure_status_page(api, domain=domain, monitor_ids=[m for m in monitor_ids if isinstance(m, int)])

    print("")
    print(f"Public status page: https://status.{domain}")
    print(f"Downtime notification target: {ntfy_url.rstrip('/')}/{ntfy_topic}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        raise SystemExit(1)
