#!/usr/bin/env bash
# Read-only smoke tests; never run the mutating configuration path.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
command -v shellcheck >/dev/null || { echo 'Missing test dependency: shellcheck' >&2; exit 1; }
command -v jq >/dev/null || { echo 'Missing test dependency: jq' >&2; exit 1; }
files=(vivobook_optimize.sh tools/cleanup-v16.0-drift.sh tests/smoke.sh tests/regression.sh)
for file in "${files[@]}"; do bash -n "$file"; done
echo 'PASS bash -n (all project shell scripts)'
shellcheck "${files[@]}"
echo 'PASS shellcheck'
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
bash vivobook_optimize.sh --help > "$tmp/help"
grep -q -- '--restore-defaults' "$tmp/help"
echo 'PASS --help'
bash vivobook_optimize.sh --version | tee "$tmp/version"
grep -q 'version 16.1 (JSON schema 3)' "$tmp/version"
bash vivobook_optimize.sh --status > "$tmp/status"
grep -q 'Status mode is read-only' "$tmp/status"
echo 'PASS --status'
bash vivobook_optimize.sh --status-json > "$tmp/status.json"
jq . "$tmp/status.json" > /dev/null
jq -e '.script.version == "16.1" and .script.schema == 3
  and (.thermal | has("choices")) and (.vaapi | has("driver_version"))
  and (.keyboard_backlight | has("brightness") and has("stop_time"))
  and (.sleep_hooks | has("vivobook-power-switch"))' "$tmp/status.json" > /dev/null
echo 'PASS --status-json | jq . and schema-3 additive keys'
bash tests/regression.sh
bash tools/cleanup-v16.0-drift.sh --help > /dev/null
bash tools/cleanup-v16.0-drift.sh --dry-run > "$tmp/cleanup"
echo 'PASS cleanup --help / --dry-run'
echo 'PASS smoke tests (hardware mutation intentionally not tested)'
