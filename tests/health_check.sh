#!/usr/bin/env python3
"""
Health‑check utility for the SSO stack.

The script verifies the availability of:
* Authentik (HTTP 200)
* PostgreSQL (TCP connection)
* Redis (TCP connection)
* Traefik (HTTP 200)
* Down‑stream services (HTTP 200)

All checks are performed in parallel and the overall exit status
reflects the health of the stack (0 = healthy, non‑zero = failure).

Usage
-----
    python -m health_check \
        --authentik-url https://auth.example.com/health/ \
        --traefik-url https://traefik.example.com/health/ \
        --service-url https://grafana.example.com/health/ \
        --service-url https://gitea.example.com/health/ \
        --service-url https://nextcloud.example.com/health/ \
        --service-url https://outline.example.com/health/ \
        --service-url https://openwebui.example.com/health/ \
        --service-url https://portainer.example.com/health/ \
        --postgres-host pg \
        --postgres-port 5432 \
        --redis-host redis \
        --redis-port 6379 \
        --timeout 5
"""

import argparse
import asyncio
import logging
import socket
import sys
from pathlib import Path
from typing import List, Tuple

import aiohttp
import psycopg2
import redis

# --------------------------------------------------------------------------- #
# Configuration & Logging
# --------------------------------------------------------------------------- #

DEFAULT_TIMEOUT = 5.0
LOG_FORMAT = "%(asctime)s %(levelname)s %(name)s %(message)s"
logging.basicConfig(level=logging.INFO, format=LOG_FORMAT)
logger = logging.getLogger("health_check")


# --------------------------------------------------------------------------- #
# Helper Functions
# --------------------------------------------------------------------------- #def _tcp_check(host: str, port: int, timeout: float) -> bool:
    """Return ``True`` if a TCP connection to *host*:**port* can be opened."""
    try:
        with socket.create_connection((host, port), timeout=timeout):
            logger.debug("TCP connection succeeded: %s:%s", host, port)
            return True
    except OSError as exc:
        logger.debug("TCP connection failed: %s:%s – %s", host, port, exc)
        return False


def _postgres_check(host: str, port: int, timeout: float) -> bool:
    """Return ``True`` if a PostgreSQL connection can be established."""
    try:
        conn = psycopg2.connect(
            host=host,
            port=port,
            user="postgres",
            password="postgres",
            connect_timeout=int(timeout),
        )
        conn.close()
        logger.debug("PostgreSQL connection succeeded: %s:%s", host, port)
        return True
    except psycopg2.OperationalError as exc:
        logger.debug("PostgreSQL connection failed: %s:%s – %s", host, port, exc)
        return False


def _redis_check(host: str, port: int, timeout: float) -> bool:
    """Return ``True`` if a Redis connection can be established."""
    try:
        client = redis.Redis(host=host, port=port, socket_timeout=timeout)
        client.ping()
        logger.debug("Redis connection succeeded: %s:%s", host, port)
        return True
    except redis.RedisError as exc:
        logger.debug("Redis connection failed: %s:%s – %s", host, port, exc)
        return False


async def _http_check(session: aiohttp.ClientSession, url: str, timeout: float) -> bool:
    """Return ``True`` if an HTTP GET to *url* returns status 200."""
    try:
        async with session.get(url, timeout=timeout) as resp:
            if resp.status == 200:
                logger.debug("HTTP 200 received from %s", url)
                return True
            logger.debug("Unexpected HTTP status %s from %s", resp.status, url)
            return False
    except (aiohttp.ClientError, asyncio.TimeoutError) as exc:
        logger.debug("HTTP request failed for %s – %s", url, exc)
        return False


# --------------------------------------------------------------------------- #
# Main Health‑Check Logic
# --------------------------------------------------------------------------- #

async def run_checks(
    auth_url: str,
    traefik_url: str,
    downstream_urls: List[str],
    pg_host: str,
    pg_port: int,
    redis_host: str,
    redis_port: int,
    timeout: float,
) -> Tuple[int, List[str]]:
    """
    Execute all health checks concurrently.

    Returns
    -------
    exit_code: int
        ``0`` if every check succeeded, otherwise ``1``.
    messages: List[str]
        Human‑readable status messages for each component.
    """
    messages: List[str] = []
    success = True

    # ------------------------------------------------------------------- #
    # Parallel HTTP checks
    # ------------------------------------------------------------------- #
    async with aiohttp.ClientSession() as session:
        http_tasks = {
            "Authentik": _http_check(session, auth_url, timeout),
            "Traefik": _http_check(session, traefik_url, timeout),
        }
        for idx, url in enumerate(downstream_urls, start=1):
            name = f"Downstream-{idx}"
            http_tasks[name] = _http_check(session, url, timeout)

        http_results = await asyncio.gather(*http_tasks.values())
        for name, result in zip(http_tasks.keys(), http_results):
            if result:
                messages.append(f"[OK] {name} reachable")
            else:
                messages.append(f"[FAIL] {name} unreachable")
                success = False

    # ------------------------------------------------------------------- #
    # Blocking TCP checks (PostgreSQL & Redis)
    # ------------------------------------------------------------------- #
    if _postgres_check(pg_host, pg_port, timeout):
        messages.append("[OK] PostgreSQL reachable")
    else:
        messages.append("[FAIL] PostgreSQL unreachable")
        success = False

    if _redis_check(redis_host, redis_port, timeout):
        messages.append("[OK] Redis reachable")
    else:
        messages.append("[FAIL] Redis unreachable")
        success = False

    return (0 if success else 1), messages


def parse_args() -> argparse.Namespace:
    """Parse command‑line arguments."""
    parser = argparse.ArgumentParser(description="Health‑check for the SSO stack")
    parser.add_argument("--authentik-url", required=True, help="Health endpoint of Authentik")
    parser.add_argument("--traefik-url", required=True, help="Health endpoint of Traefik")
    parser.add_argument(
        "--service-url",
        action="append",
        default=[],
        help="Health endpoint of a downstream service (can be repeated)",
    )
    parser.add_argument("--postgres-host", default="localhost", help="PostgreSQL host")
    parser.add_argument("--postgres-port", type=int, default=5432, help="PostgreSQL port")
    parser.add_argument("--redis-host", default="localhost", help="Redis host")
    parser.add_argument("--redis-port", type=int, default=6379, help="Redis port")
    parser.add_argument(
        "--timeout",
        type=float,
        default=DEFAULT_TIMEOUT,
        help="Network timeout in seconds (default %(default)s)",
    )
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"],
        help="Logging verbosity",
    )
    return parser.parse_args()


def main() -> None:
    """Entry point."""
    args = parse_args()
    logger.setLevel(args.log_level)

    try:
        exit_code, msgs = asyncio.run(
            run_checks(
                auth_url=args.authentik_url,
                traefik_url=args.traefik_url,
                downstream_urls=args.service_url,
                pg_host=args.postgres_host,
                pg_port=args.postgres_port,
                redis_host=args.redis_host,
                redis_port=args.redis_port,
                timeout=args.timeout,
            )
        )
    except Exception as exc:  # pragma: no cover – unexpected failure
        logger.exception("Health‑check execution failed")
        sys.exit(1)

    for m in msgs:
        logger.info(m)

    sys.exit(exit_code)


if __name__ == "__main__":
    main()