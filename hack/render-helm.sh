#!/usr/bin/env bash
# Wrapper around render-helm.py so the repository virtualenv is always used.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON="${PYTHON:-$ROOT/.venv/bin/python}"

if [ ! -x "$PYTHON" ]; then
  echo "error: $PYTHON not found. Run 'make tools' first." >&2
  exit 2
fi

exec "$PYTHON" "$ROOT/hack/render-helm.py" "$@"
