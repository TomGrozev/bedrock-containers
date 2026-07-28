#!/usr/bin/env python3
"""Regenerate <app-dir>/SECURITY.md from <app-dir>/.grype.yaml.

Usage: python3 scripts/gen-security-md.py <app-dir>

The static narrative lives in <app-dir>/SECURITY.md.tmpl; the "Accepted
findings" table is generated from the `ignore:` entries in .grype.yaml (the
single source of truth for what is accepted). Idempotent: re-running produces
no change when in sync.
"""
import os
import re
import sys
from datetime import date


def parse_ignore(path):
    items = []
    cur = None
    with open(path, encoding="utf-8") as f:
        for line in f:
            m = re.match(r"\s*-\s*vulnerability:\s*(.+?)\s*$", line)
            if m:
                cur = {"vuln": m.group(1).strip().strip('"').strip("'")}
                items.append(cur)
                continue
            if cur is not None:
                rm = re.match(r'\s*reason:\s*"?([^"]*)"?\s*$', line)
                if rm:
                    cur["reason"] = rm.group(1).strip()
                    cur = None
    for it in items:
        it.setdefault("reason", "")
    return items


def render(items):
    items = sorted(items, key=lambda x: x["vuln"])
    lines = []
    lines.append(
        f"_Generated from `.grype.yaml` on {date.today().isoformat()} — "
        f"{len(items)} accepted vulnerability ID(s). Edit `.grype.yaml`, not this file._"
    )
    lines.append("")
    lines.append("| Vulnerability ID | Reason |")
    lines.append("| --- | --- |")
    for it in items:
        vid = it["vuln"]
        reason = it["reason"].replace("|", "\\|")
        lines.append(f"| `{vid}` | {reason} |")
    lines.append("")
    return "\n".join(lines)


def main():
    if len(sys.argv) < 2:
        print("usage: gen-security-md.py <app-dir>", file=sys.stderr)
        sys.exit(2)
    app_dir = os.path.abspath(sys.argv[1])
    grype_yaml = os.path.join(app_dir, ".grype.yaml")
    tmpl = os.path.join(app_dir, "SECURITY.md.tmpl")
    out = os.path.join(app_dir, "SECURITY.md")
    if not os.path.exists(grype_yaml) or not os.path.exists(tmpl):
        print(f"Skipping {app_dir}: missing .grype.yaml or SECURITY.md.tmpl", file=sys.stderr)
        sys.exit(0)
    items = parse_ignore(grype_yaml)
    gen = render(items)
    with open(tmpl, encoding="utf-8") as f:
        content = f.read()
    new = content.replace("{{ACCEPTED}}", gen)
    old = open(out, encoding="utf-8").read() if os.path.exists(out) else ""
    if new != old:
        with open(out, "w", encoding="utf-8") as f:
            f.write(new)
        print(f"Updated {out} ({len(items)} entries).")
    else:
        print("SECURITY.md up to date.")


if __name__ == "__main__":
    main()
