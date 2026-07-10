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


def _resolve_codex_bin() -> tuple[str | None, list[str]]:
    candidates = [
        os.environ.get("CODEX_QUOTA_CODEX_BIN"),
        os.environ.get("CODEX_BIN"),
        shutil.which("codex"),
        "/Applications/ChatGPT.app/Contents/Resources/codex",
        "/Applications/Codex.app/Contents/Resources/codex",
        "~/Applications/ChatGPT.app/Contents/Resources/codex",
        "~/Applications/Codex.app/Contents/Resources/codex",
        "/opt/homebrew/bin/codex",
        "/usr/local/bin/codex",
    ]
    searched: list[str] = []
    for candidate in candidates:
        if not candidate:
            continue
        path = os.path.expanduser(candidate)
        if path in searched:
            continue
        searched.append(path)
        if os.path.isfile(path) and os.access(path, os.X_OK):
            return path, searched
    return None, searched


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


def _remaining_percent(window: Any) -> float | None:
    if not isinstance(window, dict):
        return None
    used = window.get("usedPercent")
    if not isinstance(used, (int, float)):
        return None
    return max(0, min(100, 100 - used))


def _snapshot_risk(snapshot: Any) -> tuple[float, float, float]:
    if not isinstance(snapshot, dict):
        return (101, 101, 101)
    primary_remaining = _remaining_percent(snapshot.get("primary"))
    secondary_remaining = _remaining_percent(snapshot.get("secondary"))
    values = [value for value in (primary_remaining, secondary_remaining) if value is not None]
    if not values:
        return (101, 101, 101)
    primary_score = primary_remaining if primary_remaining is not None else 101
    secondary_score = secondary_remaining if secondary_remaining is not None else 101
    return (min(values), primary_score, secondary_score)


def _rate_limits_risk(rate_limits_result: Any) -> tuple[float, float, float]:
    if not isinstance(rate_limits_result, dict):
        return (101, 101, 101)
    by_limit = rate_limits_result.get("rateLimitsByLimitId")
    if isinstance(by_limit, dict) and isinstance(by_limit.get("codex"), dict):
        return _snapshot_risk(by_limit["codex"])
    if isinstance(rate_limits_result.get("rateLimits"), dict):
        return _snapshot_risk(rate_limits_result["rateLimits"])
    if isinstance(by_limit, dict):
        risks = [_snapshot_risk(snapshot) for snapshot in by_limit.values()]
        if risks:
            return min(risks)
    return (101, 101, 101)


def _has_rate_limits(app_server: Any) -> bool:
    if not isinstance(app_server, dict):
        return False
    rate_result = app_server.get("rateLimitsResult")
    return isinstance(rate_result, dict) and bool(rate_result.get("rateLimits") or rate_result.get("rateLimitsByLimitId"))


def _choose_conservative_sample(samples: list[dict[str, Any]]) -> dict[str, Any] | None:
    if not samples:
        return None
    return min(samples, key=lambda sample: _rate_limits_risk(sample.get("rateLimitsResult")))


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


def collect_status(timeout_seconds: float, sample_count: int = 3, sample_delay_seconds: float = 0.4) -> dict[str, Any]:
    captured = _now()
    codex_bin, searched_codex_bins = _resolve_codex_bin()
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
    if codex_bin is None:
        result["status"] = "error"
        result["errors"].append("codex executable not found; checked: " + ", ".join(searched_codex_bins))
        return result

    sample_count = max(1, sample_count)
    samples: list[dict[str, Any]] = []
    sample_errors: list[str] = []

    try:
        for attempt in range(sample_count):
            attempt_timeout = timeout_seconds if attempt == 0 else min(timeout_seconds, 10.0)
            try:
                app_server_sample = _read_app_server(codex_bin, attempt_timeout)
            except Exception as exc:  # noqa: BLE001 - keep later samples available.
                sample_errors.append(str(exc))
                continue
            if _has_rate_limits(app_server_sample):
                samples.append(app_server_sample)
            if attempt < sample_count - 1:
                time.sleep(sample_delay_seconds)
    except Exception as exc:  # noqa: BLE001 - this script should return a readable status object.
        result["status"] = "error"
        result["errors"].append(str(exc))
        return result
    app_server = _choose_conservative_sample(samples)
    if app_server is None:
        result["status"] = "error"
        result["errors"].append(sample_errors[-1] if sample_errors else "app-server did not return a rate-limit response")
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
        "sampleCount": len(samples),
        "sampleRisks": [_rate_limits_risk(sample.get("rateLimitsResult")) for sample in samples],
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
    parser.add_argument("--samples", type=int, default=3, help="number of rate-limit samples to read")
    parser.add_argument("--sample-delay", type=float, default=0.4, help="delay between samples in seconds")
    args = parser.parse_args()

    status = collect_status(args.timeout, args.samples, args.sample_delay)
    if args.json:
        print(json.dumps(status, ensure_ascii=False, separators=(",", ":")))
    elif args.pretty:
        print(json.dumps(status, ensure_ascii=False, indent=2))
    else:
        print(render_text(status))
    return 0 if status.get("status") == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main())
