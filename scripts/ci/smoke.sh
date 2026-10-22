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

run_logged() {
  local log
  log="$(mktemp)"
  if ! "$GODOT" --headless --path "$ROOT" "$@" >"$log" 2>&1; then
    cat "$log"
    rm -f "$log"
    return 1
  fi
  if grep -E "SCRIPT ERROR|Parse Error|SMOKE FAIL" "$log"; then
    cat "$log"
    rm -f "$log"
    return 1
  fi
  cat "$log"
  rm -f "$log"
}

run_logged --scene res://tests/smoke_menu.tscn -- --seconds=2
for mode in survive gather escape endless; do
  run_logged --scene res://tests/smoke_arena.tscn -- --mode="$mode" --seconds=3
done
