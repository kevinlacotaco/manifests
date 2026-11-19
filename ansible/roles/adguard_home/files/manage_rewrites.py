#!/usr/bin/env python3
"""Idempotently ensure the desired DNS rewrites exist in AdGuardHome.yaml."""
import json
import os
import shutil
import subprocess
import sys
import tempfile

import yaml

CONFIG = sys.argv[1]
DESIRED = json.loads(sys.argv[2])
ADGUARD = "/opt/AdGuardHome/AdGuardHome"

with open(CONFIG, encoding="utf-8") as config_file:
    config = yaml.safe_load(config_file) or {}

filtering = config.setdefault("filtering", {})
rewrites = filtering.setdefault("rewrites", [])
changed = False

for wanted in DESIRED:
    match = next((item for item in rewrites if item.get("domain") == wanted["domain"]), None)
    if match is None:
        rewrites.append(
            {
                "domain": wanted["domain"],
                "answer": wanted["answer"],
                "enabled": True,
            }
        )
        changed = True
        continue

    if match.get("answer") != wanted["answer"] or not match.get("enabled"):
        match["answer"] = wanted["answer"]
        match["enabled"] = True
        changed = True

if not changed:
    print("unchanged")
    sys.exit(0)

backup = CONFIG + ".bak-rewrites"
shutil.copy2(CONFIG, backup)

fd, tmp_path = tempfile.mkstemp(prefix="AdGuardHome.", suffix=".yaml", dir=os.path.dirname(CONFIG))
os.close(fd)
try:
    with open(tmp_path, "w", encoding="utf-8") as output:
        yaml.safe_dump(config, output, sort_keys=False)
    shutil.copymode(CONFIG, tmp_path)

    check = subprocess.run(
        [ADGUARD, "--check-config", "-c", tmp_path],
        capture_output=True,
        text=True,
    )
    if check.returncode != 0:
        sys.stderr.write(check.stdout)
        sys.stderr.write(check.stderr)
        raise SystemExit("AdGuard Home rejected the generated config; original left untouched")

    os.replace(tmp_path, CONFIG)
    print("changed")
finally:
    if os.path.exists(tmp_path):
        os.unlink(tmp_path)
