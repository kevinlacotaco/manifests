#!/usr/bin/env python3
"""Idempotently ensure an AdGuard Home user exists with the supplied hash."""
import os
import shutil
import subprocess
import sys
import tempfile

import yaml

CONFIG = sys.argv[1]
USERNAME = sys.argv[2]
PASSWORD_HASH = sys.argv[3]
ADGUARD = "/opt/AdGuardHome/AdGuardHome"

with open(CONFIG, encoding="utf-8") as config_file:
    config = yaml.safe_load(config_file) or {}

users = config.setdefault("users", [])
changed = False
entry = next((item for item in users if item.get("name") == USERNAME), None)
if entry is None:
    users.append({"name": USERNAME, "password": PASSWORD_HASH})
    changed = True
elif entry.get("password") != PASSWORD_HASH:
    entry["password"] = PASSWORD_HASH
    changed = True

if not changed:
    print("unchanged")
    sys.exit(0)

backup = CONFIG + ".bak-users"
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
