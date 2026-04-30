#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_FILE="${1:-${ROOT_DIR}/fishtools.sh}"

PARTS=(
  "src/00_globals.sh"
  "src/core/10_package.sh"
  "src/core/20_cli.sh"
  "src/core/30_common.sh"
  "src/ui/10_draw.sh"
  "src/modules/10_status.sh"
  "src/modules/20_docker.sh"
  "src/modules/30_web_proxy.sh"
  "src/modules/40_install_tools.sh"
  "src/modules/50_tests_dd.sh"
  "src/modules/60_optimization.sh"
  "src/modules/70_deploy.sh"
  "src/modules/80_system_tools.sh"
  "src/modules/90_gost.sh"
  "src/modules/95_openclaw.sh"
  "src/99_main.sh"
)

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

: > "$tmp_file"
for part in "${PARTS[@]}"; do
  part_path="${ROOT_DIR}/${part}"
  if [[ ! -f "$part_path" ]]; then
    echo "Missing source part: ${part}" >&2
    exit 1
  fi
  cat "$part_path" >> "$tmp_file"
  printf '\n' >> "$tmp_file"
done

bash -n "$tmp_file"
chmod +x "$tmp_file"
mv "$tmp_file" "$OUT_FILE"
trap - EXIT

echo "Built ${OUT_FILE}"
