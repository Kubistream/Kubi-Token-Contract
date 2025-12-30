#!/usr/bin/env python3
from __future__ import annotations

from datetime import datetime, timezone
import re
import sys
from pathlib import Path


TOKEN_ADDRESS_RE = re.compile(r"^\s*Token Address:\s*(0x[a-fA-F0-9]{40})\s*$")
CHAIN_ID_RE = re.compile(r"^\s*Chain\s+(\d+)\s*$")


def _detect_newline(text: str) -> str:
    if "\r\n" in text:
        return "\r\n"
    return "\n"


def _upsert_env_var(env_text: str, key: str, value: str) -> str:
    newline = _detect_newline(env_text)
    lines = env_text.splitlines(True)  # keep ends

    key_re = re.compile(rf"^\s*{re.escape(key)}\s*=")
    replaced = False
    out_lines: list[str] = []
    for line in lines:
        if key_re.match(line):
            out_lines.append(f"{key}={value}{newline}")
            replaced = True
        else:
            out_lines.append(line)

    if not replaced:
        if out_lines and not out_lines[-1].endswith(("\n", "\r\n")):
            out_lines[-1] = out_lines[-1] + newline
        out_lines.append(f"{key}={value}{newline}")

    return "".join(out_lines)


def main(argv: list[str]) -> int:
    if len(argv) not in (4, 5, 6):
        print(
            "Usage: update_env_token_address.py <env_file> <profile> <forge_output_file> [recap_file] [chain_label]",
            file=sys.stderr,
        )
        return 2

    env_file = Path(argv[1])
    profile = argv[2].strip()
    out_file = Path(argv[3])
    recap_file = Path(argv[4]) if len(argv) >= 5 and argv[4].strip() else None
    chain_label = argv[5].strip() if len(argv) >= 6 else ""

    if not profile:
        print("Profile is empty.", file=sys.stderr)
        return 2

    if not out_file.exists():
        print(f"Forge output file not found: {out_file}", file=sys.stderr)
        return 2

    token_address: str | None = None
    chain_id: str | None = None
    for line in out_file.read_text(encoding="utf-8", errors="replace").splitlines():
        match = TOKEN_ADDRESS_RE.match(line)
        if match:
            token_address = match.group(1)
        match = CHAIN_ID_RE.match(line)
        if match:
            chain_id = match.group(1)

    if not token_address:
        # No token address in output; do nothing.
        return 0

    env_text = env_file.read_text(encoding="utf-8", errors="replace") if env_file.exists() else ""
    key = f"TOKEN_ADDRESS_{profile}"
    updated = _upsert_env_var(env_text, key, token_address)
    env_file.write_text(updated, encoding="utf-8", newline="")

    if recap_file is not None:
        recap_file.parent.mkdir(parents=True, exist_ok=True)
        chain = chain_label or (chain_id or "unknown")
        timestamp = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
        _upsert_recap(recap_file, chain, profile, token_address, timestamp)
    return 0


def _upsert_recap(recap_file: Path, chain: str, profile: str, address: str, timestamp: str) -> None:
    # Tab-separated for easy import: timestamp, chain, profile, address
    existing = recap_file.read_text(encoding="utf-8", errors="replace") if recap_file.exists() else ""
    newline = _detect_newline(existing) if existing else "\n"
    lines = [ln for ln in existing.splitlines() if ln.strip()]

    prefix = f"\t{chain}\t{profile}\t"
    new_line = f"{timestamp}\t{chain}\t{profile}\t{address}"
    replaced = False

    out: list[str] = []
    for ln in lines:
        if ln.startswith(prefix) or ln.split("\t")[1:3] == [chain, profile]:
            out.append(new_line)
            replaced = True
        else:
            out.append(ln)

    if not replaced:
        out.append(new_line)

    recap_file.write_text(newline.join(out) + newline, encoding="utf-8", newline="")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
