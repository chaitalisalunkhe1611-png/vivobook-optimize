#!/usr/bin/env bash
# Opt-in one-time drift cleanup. No tuning/sysfs writes; v16.1 migrates sysctls.
set -euo pipefail
APPLY=false
INCLUDE_UNMANAGED_BBR=false
USER_NAME="${SUDO_USER:-${USER:-}}"
usage() {
  cat <<'HELP'
Usage: cleanup-v16.0-drift.sh [--dry-run | --apply] [--user=NAME] [--include-unmanaged-bbr]
Defaults to --dry-run. --apply needs root and the exact interactive confirmation.
Only disabled/inactive marked static artifacts and stale pure-managed browser
files are eligible. Mixed user flags, enabled units and symlinks are preserved.
The unmanaged duplicate 99-bbr.conf requires --include-unmanaged-bbr AND an exact
BBR-only content match with the managed 98-network-bbr.conf replacement present.
An old v15.3 binary requires the known version header. Every removal is backed up
under a new mode-0700 /var/backups/vivobook-v16.0-drift-TIMESTAMP.XXXXXX directory.
Run v16.1 next: it safely migrates custom sysctls; this tool never rewrites them.
HELP
}
for arg in "$@"; do
  case "$arg" in
    --dry-run) APPLY=false ;;
    --apply) APPLY=true ;;
    --include-unmanaged-bbr) INCLUDE_UNMANAGED_BBR=true ;;
    --user=*) USER_NAME="${arg#*=}" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done
owned() { [[ -f "$1" && ! -L "$1" ]] && grep -q 'Managed by vivobook_optimize' "$1"; }
normalised() { sed -e 's/#.*$//' -e 's/[[:space:]]//g' "$1" | tr -d '\n'; }
PLAN=()
add_owned() {
  if [[ -e "$1" || -L "$1" ]]; then
    if owned "$1"; then PLAN+=("$1"); else printf 'PRESERVE unowned/symlink: %s\n' "$1"; fi
  fi
}
BBR='net.core.default_qdisc=fqnet.ipv4.tcp_congestion_control=bbr'
if [[ "$INCLUDE_UNMANAGED_BBR" == true && -f /etc/sysctl.d/99-bbr.conf && ! -L /etc/sysctl.d/99-bbr.conf ]] &&
   owned /etc/sysctl.d/98-network-bbr.conf &&
   [[ "$(normalised /etc/sysctl.d/98-network-bbr.conf)" == "$BBR" &&
      "$(normalised /etc/sysctl.d/99-bbr.conf)" == "$BBR" ]]; then
  PLAN+=(/etc/sysctl.d/99-bbr.conf)
elif [[ -e /etc/sysctl.d/99-bbr.conf ]]; then
  echo 'PRESERVE 99-bbr.conf: explicit opt-in and exact duplicate/replacement checks required.'
fi
# Do not infer "disabled" from a systemctl failure or from an absent systemd.
for pair in battery:battery-charge-threshold thermal-profile:asus-thermal-profile epp:intel-epp-profile; do
  suffix="${pair%%:*}"; unit="${pair#*:}.service"
  upath="/etc/systemd/system/$unit"
  state="$(systemctl is-enabled "$unit" 2>/dev/null || true)"
  active="$(systemctl is-active "$unit" 2>/dev/null || true)"
  if [[ -e "$upath" || -L "$upath" ]]; then
    if ! owned "$upath" || [[ "$state" != disabled || "$active" != inactive && "$active" != failed ]]; then
      printf 'PRESERVE static group %s: unowned, enabled/active, or state unverified.\n' "$unit"
      continue
    fi
  elif [[ "$state" != not-found && "$state" != disabled ]]; then
    printf 'PRESERVE orphan group %s: systemd state unverified.\n' "$unit"
    continue
  fi
  add_owned "$upath"
  add_owned "/usr/lib/systemd/system-sleep/vivobook-${suffix/epp/intel-epp}"
  add_owned "/etc/default/vivobook-$suffix"
  case "$suffix" in
    battery) helper=set-battery-threshold.sh ;;
    thermal-profile) helper=set-asus-thermal-profile.sh ;;
    epp) helper=set-intel-epp.sh ;;
  esac
  add_owned "/usr/local/bin/$helper"
done
# Read the explicitly selected user's home from passwd, never expand a user path
# or source user configuration as root.
entry="$(getent passwd "$USER_NAME" 2>/dev/null || true)"
if [[ -n "$entry" ]]; then
  IFS=: read -r _ _ uid _ _ home _ <<< "$entry"
  if [[ "$uid" =~ ^[0-9]+$ && "$uid" -ge 1000 && "$home" == /* ]]; then
    for browser in chrome chromium; do
      installed=false
      case "$browser" in
        chrome) if command -v google-chrome >/dev/null || command -v google-chrome-stable >/dev/null; then installed=true; fi ;;
        chromium) if command -v chromium >/dev/null || command -v chromium-browser >/dev/null || [[ -e /snap/bin/chromium ]]; then installed=true; fi ;;
      esac
      [[ "$installed" == false ]] || continue
      targets=("$home/.config/$browser-flags.conf")
      [[ "$browser" != chromium ]] || targets+=("$home/snap/chromium/common/chromium-flags.conf")
      for target in "${targets[@]}"; do
        [[ -e "$target" || -L "$target" ]] || continue
        if owned "$target" && [[ "$(normalised "$target")" == --ozone-platform-hint=auto ]]; then
          PLAN+=("$target")
        else
          printf 'PRESERVE mixed/unowned browser flags: %s (v16.1 can strip only managed tokens).\n' "$target"
        fi
      done
    done
  fi
fi
old=/usr/local/bin/vivobook_optimize_v15.3.sh
if [[ -f "$old" && ! -L "$old" ]] &&
   grep -qE '^# ASUS Vivobook.*Optimization Pass v15\.3([[:space:]]|$)' "$old"; then
  PLAN+=("$old")
fi
printf 'Eligible removal count: %s\n' "${#PLAN[@]}"
for target in "${PLAN[@]}"; do printf '  BACK UP, THEN REMOVE: %s\n' "$target"; done
if [[ "$APPLY" != true ]]; then echo 'DRY RUN: no files or units changed.'; exit 0; fi
(( EUID == 0 )) || { echo '--apply requires root.' >&2; exit 1; }
(( ${#PLAN[@]} > 0 )) || { echo 'Nothing eligible; no backup directory created.'; exit 0; }
[[ -t 0 ]] || { echo '--apply requires an interactive terminal; no changes made.' >&2; exit 1; }
read -r -p 'Review the list. Type CLEANUP-V16.0 to back up and remove exactly these files: ' confirmation
[[ "$confirmation" == CLEANUP-V16.0 ]] || { echo 'Cancelled; nothing changed.'; exit 1; }
install -d -m 0755 /var/backups
backup="$(mktemp -d "/var/backups/vivobook-v16.0-drift-$(date -u +%Y%m%dT%H%M%SZ).XXXXXX")"
chmod 0700 "$backup"
# Complete ALL backups before deleting ANYTHING. cp -a keeps modes/ownership.
for target in "${PLAN[@]}"; do
  [[ -f "$target" && ! -L "$target" ]] || { echo "Path changed: $target; aborting." >&2; exit 1; }
  cp -a --parents -- "$target" "$backup/"
done
printf '%s\n' "${PLAN[@]}" > "$backup/manifest.txt"
for target in "${PLAN[@]}"; do
  # Do not delete a file that changed while the confirmation/backups ran.
  if [[ -L "$target" ]] || ! cmp -s -- "$target" "$backup$target"; then
    echo "Path changed: $target; backups kept at $backup; aborting." >&2; exit 1
  fi
done
for target in "${PLAN[@]}"; do rm -f -- "$target"; done
systemctl daemon-reload
printf 'Cleanup complete. Backups: %s\n' "$backup"
echo 'Restore selected files with cp -a from the matching backup path, then systemctl daemon-reload.'
echo 'No live sysctl reset was performed. Run v16.1, then verify status and hardware.'
