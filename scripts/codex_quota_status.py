#!/usr/bin/env python3
"""Read Codex account rate-limit status from the local app-server protocol."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import select
import shutil
import subprocess
import sys
import time
from typing import Any


def _now() -> dt.datetime:
    return dt.datetime.now().astimezone()


def _format_reset(epoch_seconds: Any) -> str | None:
    if not isinstance(epoch_seconds, (int, float)):
        return None
    reset_at = dt.datetime.fromtimestamp(epoch_seconds).astimezone()
    now = _now()
    if reset_at.date() == now.date():
        return reset_at.strftime("%H:%M")
    if reset_at.year == now.year:
        return reset_at.strftime("%m-%d %H:%M")
    return reset_at.strftime("%Y-%m-%d %H:%M")


def _format_window(minutes: Any) -> str | None:
    if not isinstance(minutes, int):
        return None
    if minutes % 10080 == 0:
        weeks = minutes // 10080
        return f"{weeks}w"
    if minutes % 1440 == 0:
        days = minutes // 1440
        return f"{days}d"
    if minutes % 60 == 0:
        hours = minutes // 60
        return f"{hours}h"
    return f"{minutes}m"


def _normalize_window(window: Any) -> dict[str, Any] | None:
    if not isinstance(window, dict):
        return None
    used = window.get("usedPercent")
    remaining = None
    if isinstance(used, int):
        remaining = max(0, min(100, 100 - used))
    return {
        "usedPercent": used,
        "remainingPercent": remaining,
        "windowDurationMins": window.get("windowDurationMins"),
        "windowLabel": _format_window(window.get("windowDurationMins")),
        "resetsAt": window.get("resetsAt"),
        "resetsAtText": _format_reset(window.get("resetsAt")),
    }


def _normalize_snapshot(snapshot: Any) -> dict[str, Any] | None:
    if not isinstance(snapshot, dict):
        return None
    individual = snapshot.get("individualLimit")
    credits = snapshot.get("credits")
    return {
        "limitId": snapshot.get("limitId"),
        "limitName": snapshot.get("limitName"),
        "displayName": snapshot.get("limitName") or snapshot.get("limitId") or "Codex",
        "planType": snapshot.get("planType"),
        "primary": _normalize_window(snapshot.get("primary")),
        "secondary": _normalize_window(snapshot.get("secondary")),
        "credits": credits if isinstance(credits, dict) else None,
        "individualLimit": individual if isinstance(individual, dict) else None,
        "rateLimitReachedType": snapshot.get("rateLimitReachedType"),
    }


def _send(proc: subprocess.Popen[str], message: dict[str, Any]) -> None:
    assert proc.stdin is not None
    proc.stdin.write(json.dumps(message, separators=(",", ":")) + "\n")
    proc.stdin.flush()


def _read_app_server(codex_bin: str, timeout_seconds: float) -> dict[str, Any]:
    proc = subprocess.Popen(
        [codex_bin, "app-server", "--listen", "stdio://"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
        env={**os.environ, "TERM": os.environ.get("TERM") or "xterm-256color"},
    )
    responses: dict[int, Any] = {}
    notifications: list[dict[str, Any]] = []
    stderr_lines: list[str] = []
    started = time.time()

    try:
        _send(
            proc,
            {
                "id": 1,
                "method": "initialize",
                "params": {
                    "clientInfo": {
                        "name": "codex-quota-float",
                        "title": "Codex Quota Float",
                        "version": "0.1.0",
                    },
                    "capabilities": {
                        "experimentalApi": True,
                        "requestAttestation": False,
                        "optOutNotificationMethods": [],
                    },
                },
            },
        )
        _send(proc, {"method": "initialized"})
        _send(proc, {"id": 2, "method": "account/read", "params": {}})
        _send(proc, {"id": 3, "method": "account/rateLimits/read"})

        streams = [stream for stream in (proc.stdout, proc.stderr) if stream is not None]
        while time.time() - started < timeout_seconds:
            if proc.poll() is not None and not streams:
                break
            readable, _, _ = select.select(streams, [], [], 0.2)
            for stream in readable:
                line = stream.readline()
                if not line:
                    streams.remove(stream)
                    continue
                line = line.rstrip("\n")
                if stream is proc.stderr:
                    stderr_lines.append(line)
                    continue
                try:
                    payload = json.loads(line)
                except json.JSONDecodeError:
                    notifications.append({"raw": line})
                    continue
                if "id" in payload:
                    responses[int(payload["id"])] = payload
                else:
                    notifications.append(payload)
            if 2 in responses and 3 in responses:
                break
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                proc.kill()

    if 3 not in responses:
        raise RuntimeError("account/rateLimits/read did not return before timeout")

    account_result = responses.get(2, {}).get("result") if isinstance(responses.get(2), dict) else None
    limits_result = responses.get(3, {}).get("result") if isinstance(responses.get(3), dict) else None
    return {
        "accountResult": account_result,
        "rateLimitsResult": limits_result,
        "notifications": notifications,
        "stderr": stderr_lines,
    }


def collect_status(timeout_seconds: float) -> dict[str, Any]:
    captured = _now()
    codex_bin = shutil.which("codex") or "/Applications/Codex.app/Contents/Resources/codex"
    result: dict[str, Any] = {
        "status": "ok",
        "capturedAt": captured.isoformat(timespec="seconds"),
        "capturedAtText": captured.strftime("%H:%M:%S"),
        "codexBin": codex_bin,
        "account": None,
        "buckets": [],
        "primaryBucket": None,
        "raw": {},
        "errors": [],
    }

    try:
        app_server = None
        for attempt in range(2):
            app_server = _read_app_server(codex_bin, timeout_seconds)
            rate_result = app_server.get("rateLimitsResult")
            if isinstance(rate_result, dict) and (rate_result.get("rateLimits") or rate_result.get("rateLimitsByLimitId")):
                break
            if attempt == 0:
                time.sleep(0.5)
    except Exception as exc:  # noqa: BLE001 - this script should return a readable status object.
        result["status"] = "error"
        result["errors"].append(str(exc))
        return result
    if app_server is None:
        result["status"] = "error"
        result["errors"].append("app-server did not return a rate-limit response")
        return result

    account_result = app_server.get("accountResult") or {}
    if isinstance(account_result, dict):
        result["account"] = account_result.get("account")
        result["requiresOpenaiAuth"] = account_result.get("requiresOpenaiAuth")

    limits_result = app_server.get("rateLimitsResult") or {}
    if isinstance(limits_result, dict):
        by_limit = limits_result.get("rateLimitsByLimitId")
        snapshots: list[tuple[str, Any]] = []
        if isinstance(by_limit, dict) and by_limit:
            snapshots.extend((str(key), value) for key, value in by_limit.items())
        elif "rateLimits" in limits_result:
            snapshots.append(("codex", limits_result.get("rateLimits")))

        def sort_key(item: tuple[str, Any]) -> tuple[int, str]:
            limit_id = item[0]
            return (0 if limit_id == "codex" else 1, limit_id)

        buckets = []
        for _, snapshot in sorted(snapshots, key=sort_key):
            normalized = _normalize_snapshot(snapshot)
            if normalized:
                buckets.append(normalized)
        result["buckets"] = buckets
        result["primaryBucket"] = buckets[0] if buckets else None

    result["raw"] = {
        "rateLimits": limits_result,
        "notifications": app_server.get("notifications", []),
    }
    if app_server.get("stderr"):
        result["warnings"] = app_server["stderr"][-5:]
    return result


def render_text(status: dict[str, Any]) -> str:
    if status.get("status") != "ok":
        return "Codex quota: unavailable\n" + "\n".join(status.get("errors") or [])
    account = status.get("account") or {}
    buckets = status.get("buckets") or []
    primary_bucket = buckets[0] if buckets else {}
    account_plan = account.get("planType", "unknown")
    quota_plan = primary_bucket.get("planType", "unknown")
    lines = [
        f"Codex quota at {status.get('capturedAtText')}",
        f"account: {account.get('email', 'unknown')}; Codex quota plan: {quota_plan}; account field: {account_plan}",
    ]
    for bucket in buckets:
        primary = bucket.get("primary") or {}
        secondary = bucket.get("secondary") or {}
        lines.append(
            f"{bucket.get('displayName')}: "
            f"{primary.get('windowLabel', '?')} left {primary.get('remainingPercent', '?')}% "
            f"(resets {primary.get('resetsAtText', '?')}), "
            f"{secondary.get('windowLabel', '?')} left {secondary.get('remainingPercent', '?')}% "
            f"(resets {secondary.get('resetsAtText', '?')})"
        )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Read Codex account quota status.")
    parser.add_argument("--json", action="store_true", help="emit compact JSON")
    parser.add_argument("--pretty", action="store_true", help="emit formatted JSON")
    parser.add_argument("--timeout", type=float, default=30.0, help="app-server timeout in seconds")
    args = parser.parse_args()

    status = collect_status(args.timeout)
    if args.json:
        print(json.dumps(status, ensure_ascii=False, separators=(",", ":")))
    elif args.pretty:
        print(json.dumps(status, ensure_ascii=False, indent=2))
    else:
        print(render_text(status))
    return 0 if status.get("status") == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main())
