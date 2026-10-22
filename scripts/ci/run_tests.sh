#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1; then
  if [[ -x /home/ubuntu/bin/godot ]]; then
    GODOT=/home/ubuntu/bin/godot
  fi
fi
cd "$ROOT"
"$GODOT" --headless --path "$ROOT" --import --quit
"$GODOT" --headless --path "$ROOT" --script res://tests/run_tests.gd
