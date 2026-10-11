#!/usr/bin/env bash
# verify_v16.sh — checks for vivobook_optimize_v16.sh that do not need the
# target hardware.
#
#   bash verify_v16.sh            # run everything that is possible here
#
# Sections
#   A. static   bash -n, shellcheck baseline vs v15.3, version/schema, anchors,
#               no new flags, JSON key superset, patches rebuild v16
#   B. sandbox  read-only modes of v16 on THIS machine (--status, --status-json,
#               --safe-mode-check, --dry-run, --help, --version). Never an apply
#               pass and never root-only paths.
#   C. fixtures individual v16 functions/blocks, extracted from the script with
#               every absolute /sys /proc /boot /etc /run /usr/lib/systemd ...
#               path rewritten into a temporary fixture tree, with systemctl,
#               journalctl, dmesg, sbverify, uname, lsmod, ... mocked.
#
# Nothing here verifies behaviour on the real Vivobook X1605VA: fixture inputs
# model the documented facts (kernel 7.2.6, xe bound, SOF + 10/N audio file,
# energy_* battery, 99-bbr.conf, USB 1-9/1-10 on auto). Exit 1 if any check fails.
set -uo pipefail

cd "$(dirname "$0")" || exit 1
V15=vivobook_optimize_v15.3.sh
V16=vivobook_optimize_v16.sh
PASS=0
FAIL=0
SKIP=0

ok()   { PASS=$((PASS + 1)); printf 'PASS  %s\n' "$*"; }
bad()  { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$*"; }
skip() { SKIP=$((SKIP + 1)); printf 'SKIP  %s\n' "$*"; }
check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }
section() { printf '\n== %s ==\n' "$*"; }

FX="$(mktemp -d)"
export FX
WORK="$(mktemp -d)"
trap 'rm -rf "$FX" "$WORK"' EXIT

[[ -f "$V15" && -f "$V16" ]] || { echo "run from the repository root ($V15 and $V16 required)"; exit 1; }

# ---------------------------------------------------------------------------
section "A. static checks"

check "bash -n $V16" bash -n "$V16"

SC="$(command -v shellcheck || true)"
if [[ -n "$SC" ]]; then
  norm_sc() { "$SC" -f gcc "$1" 2>/dev/null | sed -E 's/^[^:]+:[0-9]+:[0-9]+: //' | sort | uniq -c; }
  if diff <(norm_sc "$V15") <(norm_sc "$V16") > "$WORK/sc.diff"; then
    ok "shellcheck: no findings beyond the v15.3 baseline ($("$SC" --version | sed -n 's/^version: //p'))"
  else
    bad "shellcheck: new findings vs v15.3:"; sed 's/^/      /' "$WORK/sc.diff"
  fi
else
  skip "shellcheck not installed"
fi

check "SCRIPT_VERSION=16.0" grep -q '^SCRIPT_VERSION="16.0"$' "$V16"
check "SCRIPT_SCHEMA=3" grep -q '^SCRIPT_SCHEMA=3$' "$V16"
check "no generated header still says v15.3" bash -c "! grep -q 'Managed by vivobook_optimize.sh v15.3' '$V16'"
check "marker substring kept in generated files" grep -q 'Managed by vivobook_optimize.sh v16' "$V16"
check "anchor '# ASUS Vivobook' kept" grep -q '^# ASUS Vivobook' "$V16"
check "anchor '# END-USAGE' kept" grep -q '^# END-USAGE' "$V16"
check "v15.3 file untouched by the build (still v15.3)" grep -q '^SCRIPT_VERSION="15.3"$' "$V15"

flags_of() { sed -n '/^for arg in/,/^done/p; /^while (( \$# ))/,/^done/p' "$1" | grep -oE '^[[:space:]]+--[a-z0-9-]+(=\*)?(\|--[a-z0-9-]+(=\*)?)*\)' | tr -d ' )' | tr '|' '\n' | sort -u; }
if [[ -n "$(flags_of "$V15")" ]] && diff <(flags_of "$V15") <(flags_of "$V16") > "$WORK/flags.diff"; then
  ok "no new/removed command-line flags ($(flags_of "$V16" | wc -l) parser patterns)"
else
  bad "flag set differs (or parser not found):"; sed 's/^/      /' "$WORK/flags.diff" 2>/dev/null
fi

json_keys_of() { grep -oE '\\"[a-z0-9_]+\\": ' "$1" | sed -E 's/\\"([a-z0-9_]+)\\": /\1/' | sort -u; }
missing="$(comm -23 <(json_keys_of "$V15") <(json_keys_of "$V16"))"
if [[ -z "$missing" ]]; then
  ok "static JSON key literals: every v15.3 key still emitted by v16"
else
  bad "static JSON keys missing in v16: $missing"
fi

if [[ -d patches ]]; then
  t="$WORK/patchcheck"; mkdir -p "$t"; cp "$V15" "$t/$V16"
  pfail=0
  for p in "$PWD"/patches/[0-9][0-9]-*.patch; do
    (cd "$t" && patch -s -p1 < "$p" >/dev/null 2>&1) || { pfail=1; echo "      cannot apply $p"; }
  done
  if (( pfail == 0 )) && cmp -s "$t/$V16" "$V16"; then
    ok "patches/01..15 applied in order to v15.3 reproduce v16 byte-for-byte"
  else
    bad "per-change patches do not reproduce v16"
  fi
  t2="$WORK/fullcheck"; mkdir -p "$t2"; cp "$V15" "$t2/"
  if (cd "$t2" && patch -s -o "$V16" "$V15" < "$OLDPWD/patches/v15.3-to-v16.full.diff" >/dev/null 2>&1) &&
     cmp -s "$t2/$V16" "$V16"; then
    ok "patches/v15.3-to-v16.full.diff reproduces v16"
  else
    bad "full diff does not reproduce v16"
  fi
else
  skip "patches/ directory not found"
fi

# Function-body helper (also used by section C).
fn_body() { awk -v n="$1" '$0 ~ "^"n"\\(\\) \\{" {p=1} p {print} p && /^}/ {exit}' "$V16"; }

check "status dashboard never calls the RAPL write probe" bash -c "! awk '/^show_status\\(\\) \\{/,/^}/' '$V16' | grep -q rapl_probe_lock_state"
check "status JSON never calls the RAPL write probe" bash -c "! awk '/^show_status_json\\(\\) \\{/,/^}/' '$V16' | grep -q rapl_probe_lock_state"
check "RAPL probe still used by --pl1/--pl2 step 20" bash -c "grep -q 'RAPL_PL1_STATE=\"\$(rapl_probe_lock_state' '$V16'"
check "all four sleep hooks are written from sleep_hook_body" test "$(grep -c 'atomic_write /usr/lib/systemd/system-sleep/vivobook-[a-z-]* 0755 <<< "$(sleep_hook_body' "$V16")" -eq 4
check "restore_defaults has no unconditional rm of units/helpers/hooks/defaults/udev" \
  bash -c "! fn() { awk '/^restore_defaults\\(\\) \\{/,/^}/' '$V16'; }; ! fn | grep -E '^[[:space:]]*rm -f (\"?/etc/systemd/system|/usr/local/bin|/usr/lib/systemd/system-sleep|/etc/default/vivobook-(battery|thermal|epp|rapl|ppd)|/etc/udev/rules.d)'"
check "safe-mode mt7921e item never adds to SAFE_FAILS" \
  bash -c "! awk '/\\[5\\/5\\]/,/RESULT: OK/' '$V16' | grep -q 'SAFE_FAILS+='"
check "usage marks --with-mt7921e-aspm as OPTIONAL fallback" grep -q 'OPTIONAL fallback: stage the MediaTek' "$V16"
check "IPv6 TODO comment present (needs user confirmation)" grep -q 'TODO(v16, needs user confirmation' "$V16"

# ---------------------------------------------------------------------------
section "B. read-only runs on this machine (not the target hardware)"

if [[ $EUID -eq 0 ]]; then
  skip "section B is meant to run unprivileged; skipped as root"
else
  for mode in --status --safe-mode-check --help --version; do
    bash "$V16" "$mode" > "$WORK/out" 2> "$WORK/err"
    rc=$?
    if [[ ! -s "$WORK/err" ]] && { [[ $rc -eq 0 ]] || [[ "$mode" == --safe-mode-check && $rc -eq 1 ]]; }; then
      ok "$mode runs (rc=$rc, no stderr)"
    else
      bad "$mode rc=$rc stderr: $(head -3 "$WORK/err")"
    fi
  done
  check "--help shows the informational safe-mode text" bash -c "bash '$V16' --help | grep -q 'mt7921e Wi-Fi item is INFORMATIONAL'"
  check "--version reports 16.0 / schema 3" bash -c "bash '$V16' --version | grep -q 'version 16.0 (JSON schema 3)'"
  if command -v jq >/dev/null 2>&1; then
    if bash "$V16" --status-json > "$WORK/j16" 2>/dev/null && jq -e . "$WORK/j16" >/dev/null 2>&1; then
      ok "--status-json is valid JSON"
      check "JSON script.version=16.0, schema=3" jq -e '.script.version == "16.0" and .script.schema == 3' "$WORK/j16"
      if bash "$V15" --status-json > "$WORK/j15" 2>/dev/null; then
        miss="$(jq -r '[paths(scalars, arrays, objects) | map(tostring) | join(".")] | .[]' "$WORK/j15" |
                grep -vE '\.[0-9]+(\.|$)|^(rapl|wifi\.interfaces|zram\.devices|nvme|timers|cpu\.epp)\.' | sort -u |
                comm -23 - <(jq -r '[paths(scalars, arrays, objects) | map(tostring) | join(".")] | .[]' "$WORK/j16" | sort -u))"
        if [[ -z "$miss" ]]; then ok "runtime JSON: every v15.3 key path is still present"; else bad "runtime JSON paths missing: $miss"; fi
      else
        skip "v15.3 --status-json failed here; runtime key comparison skipped"
      fi
      check "JSON new keys present" jq -e '
        (.suspend | has("aspm_workaround_live") and has("pc6_residency") and has("package_cstates") and has("s0i3_residency_usec") and has("s0ix_substate_source"))
        and (.wifi.mt7921e | has("aspm_workaround_live"))
        and (.audio | has("power_save_live") and has("staged_options") and has("staged_vs_live"))
        and (.battery | has("service_state")) and (.thermal | has("service_state")) and (.cpu | has("epp_service_state"))
        and (.battery_health | has("unit") and has("full") and has("full_design"))
        and (.boot_integrity | has("newest_kernel_image") and has("newest_kernel_signature"))
        and (.rapl.lock_state_probed == false)
        and has("sleep_hooks") and has("sysctl_overrides") and (.bbr | has("unmanaged_override_files"))
        and (.usb_autosuspend | has("exempt_class_devices") and has("mismatch_applicable"))
        and (.i915 | keys | length == 5)' "$WORK/j16"
    else
      bad "--status-json is not valid JSON"
    fi
  else
    skip "jq not installed; JSON checks skipped"
  fi
  bash "$V16" --dry-run > "$WORK/dry" 2>&1; rc=$?
  check "--dry-run exits 0" test "$rc" -eq 0
  check "--dry-run echoes mt7921e-aspm in both flag blocks" test "$(grep -c 'mt7921e-aspm=' "$WORK/dry")" -eq 2
  check "--dry-run shows step 15d" grep -q '== 15d\.' "$WORK/dry"
  check "--dry-run ends with the dry-run banner" bash -c "tail -1 '$WORK/dry' | grep -q 'END DRY RUN'"
  bash "$V16" --restore-defaults --dry-run > "$WORK/rdry" 2>&1; rc=$?
  check "--restore-defaults --dry-run exits 0" test "$rc" -eq 0
fi

# ---------------------------------------------------------------------------
section "C. fixture tests (functions extracted from v16, paths redirected to a temp tree)"

if ! command -v perl >/dev/null 2>&1; then
  skip "perl not installed; fixture tests need it for path rewriting"
else

# Rewrite absolute system paths (only at a path start) into $FX.
rewrite() {
  perl -pe 's{(?<![\w.\-/\$\{])(/(?:sys|proc|boot|etc|run)/|/usr/lib/systemd/|/lib/systemd/|/usr/lib/sysctl\.d|/lib/sysctl\.d|/usr/local/lib/sysctl\.d|/usr/local/bin/)}{$ENV{FX}$1}g'
}
# All functions defined in v16, and the transitive closure of a function's deps.
ALL_FNS="$(grep -oE '^[a-z_][a-z0-9_]*\(\) \{' "$V16" | sed 's/() {//' | sort -u)"
closure() {
  local -A seen=()
  local -a todo=("$@")
  local f w
  while (( ${#todo[@]} )); do
    f="${todo[0]}"; todo=("${todo[@]:1}")
    [[ -n "${seen[$f]:-}" ]] && continue
    seen[$f]=1
    for w in $(fn_body "$f" | grep -oE '\b[a-z_][a-z0-9_]*\b' | sort -u); do
      [[ -z "${seen[$w]:-}" ]] && grep -qx "$w" <<< "$ALL_FNS" && todo+=("$w")
    done
  done
  printf '%s\n' "${!seen[@]}"
}
extract() { local f; for f in $(closure "$@"); do fn_body "$f"; done | rewrite; }
# Global variable definitions the helpers rely on (single-line or multi-line arrays).
globals() {
  local v
  for v in MT7921E_CONF AUDIO_CONF AUDIO_PARAM_DIR PMC_CORE_DIR SLEEP_HOOK_DIR SLEEP_HOOK_PAIRS \
           SYSCTL_MANAGED_KEYS SYSCTL_SCAN_DIRS SYSCTL_CONF_FILE USB_EXEMPT_CLASSES \
           SIGNING_HOOK STOCK_KERNEL_PREF MOK_SUBJECT_MATCH I915_CONF I915_CONF_REMOVED; do
    awk -v n="$v" '
      !p && $0 ~ "^"n"=" { p = 1; if ($0 !~ /=\($/) { print; exit } }
      p { print } p && /^\)$/ { exit }' "$V16"
  done | rewrite
}
# Extract a top-level block between two literal start/end lines (end excluded).
block() { awk -v s="$1" -v e="$2" 'index($0, s) == 1 { p = 1 } p && index($0, e) == 1 { exit } p { print }' "$V16" | rewrite; }

LIB="$WORK/lib.sh"
{
  echo 'DRY_RUN=false; TMP_REGISTRY=(); SCRIPT_NAME=vivobook_optimize_v16.sh; SCRIPT_PATH=/x/vivobook_optimize_v16.sh'
  globals
  extract safe_mode_check aspm_workaround_live aspm_workaround_active restore_defaults \
          restore_remove_owned restore_unit_owned ppd_state_file_owned ppd_state_value \
          audio_conf_is_legacy_content audio_staged_verdict audio_sof_loaded audio_staged_options \
          sleep_hook_body unit_install_state sleep_hook_guard_state persistent_service_line \
          kernel_image_signature_state newest_installed_kernel_image detect_active_drm_driver \
          pmc_pkg_cstate pmc_pkg_cstate_rows pmc_substate_rows pmc_substate_sum battery_health_rows \
          sysctl_unmanaged_overrides battery_limit_off_reset usb_exempt_class_rows atomic_write \
          is_managed_file remove_managed_config json_string mt7921e_error_count
} > "$LIB"
check "fixture library extracts and parses" bash -n "$LIB"

# Mocks: each test sets MOCK_* variables; calls are logged to $FX/calls.
MOCKS="$WORK/mocks.sh"
cat > "$MOCKS" << 'MOCK'
systemctl() {
  echo "systemctl $*" >> "$FX/calls"
  case "$1" in
    is-enabled) local u; for u in "$@"; do :; done; [[ " ${MOCK_ENABLED:-} " == *" $u "* ]]; return ;;
    is-active) return 1 ;;
    *) return 0 ;;
  esac
}
journalctl() { printf '%s' "${MOCK_JOURNAL:-}"; }
dmesg() { printf '%s' "${MOCK_DMESG:-}"; }
uname() { [[ "${1:-}" == -r ]] && echo "${MOCK_UNAME:-7.2.6-070206-generic}" || command uname "$@"; }
sbverify() { local f; for f in "$@"; do :; done; case "$(cat "$f" 2>/dev/null)" in vivobook) echo "signature 1"; echo " subject: /CN=Vivobook Kernel Key";; other) echo " subject: /CN=Canonical";; *) return 1;; esac; }
udevadm() { echo "udevadm $*" >> "$FX/calls"; }
sysctl() { echo "sysctl $*" >> "$FX/calls"; }
swapoff() { echo "swapoff $*" >> "$FX/calls"; }
update-initramfs() { echo "update-initramfs $*" >> "$FX/calls"; }
modprobe() { echo "modprobe $*" >> "$FX/calls"; }
runuser() { echo "runuser $*" >> "$FX/calls"; }
lsmod() { printf '%s\n' "${MOCK_LSMOD:-}"; }
tlp_gate() { return 0; }
mt7921e_loaded() { [[ -n "${MOCK_MT_LOADED:-}" ]]; }
MOCK
# Run a snippet in a fresh shell with the library + mocks loaded.
run() { FX="$FX" bash -c "set -uo pipefail; . '$LIB'; . '$MOCKS'; $1" 2>&1; }
reset_fx() { rm -rf "${FX:?}"/*; mkdir -p "$FX"; : > "$FX/calls"; }
mk() { mkdir -p "$(dirname "$FX$1")"; printf '%s\n' "$2" > "$FX$1"; }

if [[ $EUID -eq 0 ]]; then
  skip "fixture tests skipped as root (they are designed to run unprivileged)"
else

# --- change 1: safe-mode mt7921e informational -----------------------------
reset_fx
SAFE_OK_SETUP='signing_hook_state() { echo present-executable; }; stock_kernel_pin_blocks() { return 0; };
  secure_boot_state() { echo enabled; }; newest_installed_kernel_image() { echo /boot/vmlinuz-$(uname -r); };
  kernel_image_signature_state() { echo signed-by-vivobook-key; };'
mkdir -p "$FX/sys/module/mt7921e/parameters"; echo N > "$FX/sys/module/mt7921e/parameters/disable_aspm"
out="$(MOCK_MT_LOADED=1 MOCK_JOURNAL=$'k: mt7921e 0000:01:00.0: ready\n' run "$SAFE_OK_SETUP safe_mode_check; echo rc=\$?")"
if grep -q 'rc=0' <<< "$out" && grep -q 'OK    0 mt7921e error lines' <<< "$out" && grep -q 'config: .* absent' <<< "$out"; then
  ok "safe-mode: workaround absent + no errors -> exit 0, config 'absent', live value shown"
else bad "safe-mode absent/no-errors case"; echo "$out" | sed 's/^/      /' | tail -15; fi
out="$(MOCK_MT_LOADED=1 MOCK_JOURNAL=$'mt7921e 0000:01:00.0: Message 00020007 (seq 3) timeout\nmt7921e: chip reset failed\n' run "$SAFE_OK_SETUP safe_mode_check; echo rc=\$?")"
if grep -q 'rc=0' <<< "$out" && grep -q 'WARN  2 mt7921e error line' <<< "$out" && grep -q 'Informational warning' <<< "$out"; then
  ok "safe-mode: 2 mt7921e errors in this boot's log -> WARN, exit still 0"
else bad "safe-mode errors case"; echo "$out" | tail -12 | sed 's/^/      /'; fi
out="$(MOCK_MT_LOADED=1 run "$SAFE_OK_SETUP safe_mode_check; echo rc=\$?")"
check "safe-mode: unreadable kernel log -> 'unknown', exit 0" bash -c "grep -q 'rc=0' <<< '$out' && grep -q 'errors this boot: unknown' <<< '$out'"
out="$(MOCK_MT_LOADED=1 run "$SAFE_OK_SETUP signing_hook_state() { echo absent; }; safe_mode_check; echo rc=\$?")"
check "safe-mode: missing signing hook still FAILS (exit 1)" grep -q 'rc=1' <<< "$out"

# --- change 2: live vs staged ---------------------------------------------
reset_fx
mkdir -p "$FX/sys/module/mt7921e/parameters"; echo Y > "$FX/sys/module/mt7921e/parameters/disable_aspm"
check "aspm_workaround_live true when parameter is Y" bash -c "$(declare -f run); FX='$FX' LIB='$LIB' MOCKS='$MOCKS'; run 'aspm_workaround_live' >/dev/null"
echo N > "$FX/sys/module/mt7921e/parameters/disable_aspm"
mk /etc/modprobe.d/mt7921e.conf $'# Managed by vivobook_optimize.sh v16\noptions mt7921e disable_aspm=1'
out="$(run 'aspm_workaround_live && echo live || echo notlive; aspm_workaround_active && echo active || echo inactive')"
check "staged-only: active but not live" bash -c "grep -q notlive <<< '$out' && grep -q '^active' <<< '$out'"

# --- change 5: ownership-aware restore -------------------------------------
reset_fx
M='# Managed by vivobook_optimize.sh v15.3'
mk /etc/systemd/system/asus-thermal-profile.service "$M"
mk /etc/systemd/system/battery-charge-threshold.service '[Unit]
Description=admin-written, no marker'
mk /usr/local/bin/set-asus-thermal-profile.sh "$M"
mk /usr/local/bin/set-battery-threshold.sh '#!/bin/sh
# hand-written'
mk /usr/lib/systemd/system-sleep/vivobook-thermal-profile "$M"
mk /etc/default/vivobook-epp "$M"
mk /etc/default/vivobook-battery 'BATTERY_CHARGE_END_THRESHOLD=80'
mk /etc/udev/rules.d/99-usb-autosuspend.rules "$M"
mk /etc/udev/rules.d/99-vivobook-power.rules '# admin rule'
mk /etc/sysctl.d/99-bbr.conf $'net.core.default_qdisc = fq\nnet.ipv4.tcp_congestion_control = bbr'
mk /etc/default/vivobook-ppd-state $'PPD_WAS_PRESENT=true\nPPD_WAS_ACTIVE=true\nPPD_WAS_ENABLED=true\nPPD_WAS_MASKED=false'
mk /etc/modprobe.d/audio-powersave.conf $'# Managed by vivobook_optimize.sh v15.3\noptions snd_hda_intel power_save=10 power_save_controller=N'
: > "$FX/etc/passwd"
out="$(run 'restore_defaults; echo rc=$?')"
gone()  { [[ ! -e "$FX$1" ]]; }
there() { [[ -e "$FX$1" ]]; }
check "restore: marked unit removed"                 gone /etc/systemd/system/asus-thermal-profile.service
check "restore: unmarked unit preserved"             there /etc/systemd/system/battery-charge-threshold.service
check "restore: unmarked unit was NOT disabled"      bash -c "! grep -q 'disable --now battery-charge-threshold' '$FX/calls'"
check "restore: marked unit was disabled"            grep -q 'disable --now asus-thermal-profile.service' "$FX/calls"
check "restore: marked helper removed"               gone /usr/local/bin/set-asus-thermal-profile.sh
check "restore: unmarked helper preserved"           there /usr/local/bin/set-battery-threshold.sh
check "restore: marked sleep hook removed"           gone /usr/lib/systemd/system-sleep/vivobook-thermal-profile
check "restore: marked /etc/default file removed"    gone /etc/default/vivobook-epp
check "restore: unmarked /etc/default file preserved" there /etc/default/vivobook-battery
check "restore: marked udev rule removed"            gone /etc/udev/rules.d/99-usb-autosuspend.rules
check "restore: unmarked udev rule preserved"        there /etc/udev/rules.d/99-vivobook-power.rules
check "restore: pre-marker PPD state recognised, PPD unmasked+enabled+started" \
  bash -c "grep -q 'unmask power-profiles-daemon' '$FX/calls' && grep -q 'enable power-profiles-daemon' '$FX/calls' && grep -q 'start power-profiles-daemon' '$FX/calls' && [[ ! -e '$FX/etc/default/vivobook-ppd-state' ]]"
check "restore: skipped paths listed" bash -c "grep -q 'Preserved 4 path(s)' <<< \"\$1\"" _ "$out"
check "restore: 99-bbr.conf reported, not edited" bash -c "grep -q '99-bbr.conf (not script-managed, left untouched) sets net.ipv4.tcp_congestion_control' <<< \"\$1\" && [[ -e '$FX/etc/sysctl.d/99-bbr.conf' ]]" _ "$out"
check "restore: hand-edited marked audio conf removed WITH a NOTE" bash -c "grep -q 'carries edited options' <<< \"\$1\" && [[ ! -e '$FX/etc/modprobe.d/audio-powersave.conf' ]]" _ "$out"
check "restore: zram not touched without a managed zram config" bash -c "! grep -q 'zramswap\\|zram-setup' '$FX/calls'"
check "restore: exit 0 when nothing failed" grep -q 'rc=0' <<< "$out"
reset_fx
mk /etc/sysctl.d/98-network-bbr.conf $'# pre-marker copy\nnet.core.default_qdisc = fq\nnet.ipv4.tcp_congestion_control = bbr'
mk /etc/modules-load.d/bbr.conf 'tcp_bbr'
mk /proc/sys/net/ipv4/tcp_congestion_control 'bbr'
mk /etc/sysctl.d/99-vivobook.conf $'vm.swappiness = 5\n# admin copy without marker'
: > "$FX/etc/passwd"
run 'restore_defaults' >/dev/null
check "restore: unmarked legacy-content BBR files removed (v15.3 adoption rule)" \
  bash -c "[[ ! -e '$FX/etc/sysctl.d/98-network-bbr.conf' && ! -e '$FX/etc/modules-load.d/bbr.conf' ]]"
check "restore: tcp_congestion_control reset to cubic for the adopted BBR file" \
  bash -c "[[ \$(cat '$FX/proc/sys/net/ipv4/tcp_congestion_control') == cubic ]]"
check "restore: unmarked non-legacy sysctl file preserved" there /etc/sysctl.d/99-vivobook.conf
reset_fx
mk /etc/default/vivobook-ppd-state $'PPD_WAS_PRESENT=true\nrm -rf /'
: > "$FX/etc/passwd"
out="$(run 'restore_defaults >/dev/null; echo rc=$?')"
check "restore: foreign ppd-state file preserved, PPD not touched" \
  bash -c "[[ -e '$FX/etc/default/vivobook-ppd-state' ]] && ! grep -q power-profiles-daemon '$FX/calls'"
reset_fx
mk /etc/systemd/system/asus-thermal-profile.service "$M"
: > "$FX/etc/passwd"
out="$(run 'DRY_RUN=true; restore_defaults')"
check "restore --dry-run: managed unit reported, not removed, not disabled" \
  bash -c "grep -q 'Would disable --now asus-thermal-profile.service' <<< \"\$1\" && [[ -e '$FX/etc/systemd/system/asus-thermal-profile.service' ]] && ! grep -q 'systemctl disable' '$FX/calls'" _ "$out"

# --- change 6: audio --------------------------------------------------------
reset_fx
mk /etc/modprobe.d/audio-powersave.conf $'# Managed by vivobook_optimize.sh v16\noptions snd_hda_intel power_save=10 power_save_controller=N'
mkdir -p "$FX/sys/module/snd_hda_intel/parameters"
echo 0 > "$FX/sys/module/snd_hda_intel/parameters/power_save"; echo N > "$FX/sys/module/snd_hda_intel/parameters/power_save_controller"
check "audio: 10/N is not script content" bash -c "! (. '$LIB'; audio_conf_is_legacy_content '$FX/etc/modprobe.d/audio-powersave.conf')"
check "audio: staged 10 vs live 0 -> staged-differs-from-live" bash -c "[[ \"\$(FX='$FX' bash -c '. $LIB; audio_staged_verdict')\" == staged-differs-from-live ]]"
mk /proc/modules 'snd_sof_pci_intel_tgl 16384 0 - Live 0x0'
check "audio: SOF detected from /proc/modules" bash -c ". '$LIB'; audio_sof_loaded"
STEP12="$WORK/step12.sh"
{ echo 'WITH_AUDIO_POWERSAVE=true'; block 'echo "== 12. Intel HD Audio power saving =="' 'echo "== 12b.'; } > "$STEP12"
out="$(MOCK_LSMOD='snd_sof_pci_intel_tgl 16384 0' run ". '$STEP12'")"
check "step 12 SOF: marked 10/N file PRESERVED with NOTE" bash -c "[[ -e '$FX/etc/modprobe.d/audio-powersave.conf' ]] && grep -q 'treated as hand-edited' <<< \"\$1\"" _ "$out"
mk /etc/modprobe.d/audio-powersave.conf $'# Managed by vivobook_optimize.sh v15.3\n# comment\noptions snd_hda_intel power_save=1 power_save_controller=Y'
MOCK_LSMOD='snd_sof_pci_intel_tgl 16384 0' run ". '$STEP12'" >/dev/null
check "step 12 SOF: marked 1/Y file (script content) still removed" gone /etc/modprobe.d/audio-powersave.conf
mk /etc/modprobe.d/audio-powersave.conf 'options snd_hda_intel power_save=10'
MOCK_LSMOD='snd_sof_pci_intel_tgl 16384 0' run ". '$STEP12'" >/dev/null
check "step 12 SOF: unmarked file preserved" there /etc/modprobe.d/audio-powersave.conf

# --- change 7: sleep hooks ---------------------------------------------------
reset_fx
body="$(run 'sleep_hook_body intel-epp-profile.service')"
printf '%s\n' "$body" > "$WORK/hook"
check "hook body: bash -n" bash -n "$WORK/hook"
if [[ -n "$SC" ]]; then check "hook body: shellcheck clean" "$SC" "$WORK/hook"; fi
check "hook body: carries the marker" grep -q 'Managed by vivobook_optimize' "$WORK/hook"
hook_calls() { : > "$FX/calls"; FX="$FX" MOCK_ENABLED="$1" bash -c ". '$MOCKS'; . '$WORK/hook'" "$WORK/hook" "$2"; cat "$FX/calls"; }
check "hook: disabled unit is NOT restarted on post" bash -c "! grep -q restart <<< \"\$1\"" _ "$(hook_calls '' post)"
check "hook: enabled unit IS restarted on post" bash -c "grep -q 'restart intel-epp-profile.service' <<< \"\$1\"" _ "$(hook_calls intel-epp-profile.service post)"
check "hook: nothing happens on pre" bash -c "! grep -q restart <<< \"\$1\"" _ "$(hook_calls intel-epp-profile.service pre)"
STEP15D="$WORK/step15d.sh"
block 'echo "== 15d.' 'echo "== 16.' > "$STEP15D"
mkdir -p "$FX/usr/lib/systemd/system-sleep"
printf '%s\n' '#!/usr/bin/env bash' '# Managed by vivobook_optimize.sh v15.3' 'if [[ "${1:-}" == post ]]; then' '  systemctl restart asus-thermal-profile.service >/dev/null 2>&1 || true' 'fi' > "$FX/usr/lib/systemd/system-sleep/vivobook-thermal-profile"
printf '%s\n' '#!/bin/sh' '# admin hook' > "$FX/usr/lib/systemd/system-sleep/vivobook-intel-epp"
check "status: v15.3 hook flagged unguarded" bash -c "[[ \"\$(FX='$FX' bash -c '. $LIB; sleep_hook_guard_state $FX/usr/lib/systemd/system-sleep/vivobook-thermal-profile')\" == unguarded ]]"
out1="$(run ". '$STEP15D'")"
check "15d: managed unguarded hook refreshed" bash -c "grep -q 'vivobook-thermal-profile refreshed' <<< \"\$1\" && grep -q is-enabled '$FX/usr/lib/systemd/system-sleep/vivobook-thermal-profile'" _ "$out1"
check "15d: unmanaged hook untouched" grep -q '# admin hook' "$FX/usr/lib/systemd/system-sleep/vivobook-intel-epp"
check "15d: absent hooks are not created" bash -c "[[ ! -e '$FX/usr/lib/systemd/system-sleep/vivobook-battery' && ! -e '$FX/usr/lib/systemd/system-sleep/vivobook-kbd-timeout' ]]"
check "15d: no enable/start/restart issued" bash -c "! grep -qE 'systemctl (enable|start|restart|reenable)' '$FX/calls'"
out2="$(run ". '$STEP15D'")"
check "15d: second run is a no-op ('up to date')" bash -c "grep -q 'vivobook-thermal-profile up to date' <<< \"\$1\" && ! grep -q refreshed <<< \"\$1\"" _ "$out2"
out3="$(run "DRY_RUN=true; atomic_write() { echo '[DRY-RUN] -> Write file:' \"\$1\"; cat >/dev/null; }; chmod() { :; }; . '$STEP15D'")"
check "15d --dry-run: no simulated write when content already matches" bash -c "! grep -q 'DRY-RUN' <<< \"\$1\"" _ "$out3"
mkdir -p "$FX/etc/systemd/system"; : > "$FX/etc/systemd/system/asus-thermal-profile.service"
check "unit_install_state: installed-disabled" bash -c "[[ \"\$(FX='$FX' bash -c '. $LIB; . $MOCKS; unit_install_state asus-thermal-profile.service')\" == installed-disabled ]]"
check "unit_install_state: enabled" bash -c "[[ \"\$(FX='$FX' MOCK_ENABLED=asus-thermal-profile.service bash -c '. $LIB; . $MOCKS; unit_install_state asus-thermal-profile.service')\" == enabled ]]"
check "unit_install_state: not-installed" bash -c "[[ \"\$(FX='$FX' bash -c '. $LIB; . $MOCKS; unit_install_state intel-epp-profile.service')\" == not-installed ]]"

# --- change 8: newest kernel ---------------------------------------------------
reset_fx
mkdir -p "$FX/boot"
echo vivobook > "$FX/boot/vmlinuz-7.2.6-070206-generic"
echo unsigned > "$FX/boot/vmlinuz-7.10.1-071001-generic"
echo vivobook > "$FX/boot/vmlinuz-7.10.1-071001-generic.old"
check "newest image by sort -V (7.10.1 > 7.2.6, .old ignored)" bash -c "[[ \"\$(FX='$FX' bash -c '. $LIB; newest_installed_kernel_image')\" == '$FX/boot/vmlinuz-7.10.1-071001-generic' ]]"
SAFE_K='signing_hook_state() { echo present-executable; }; stock_kernel_pin_blocks() { return 0; }; secure_boot_state() { echo enabled; };'
out="$(run "$SAFE_K safe_mode_check; echo rc=\$?")"
check "safe-mode: unsigned newest image -> FAIL, exit 1" bash -c "grep -q 'rc=1' <<< \"\$1\" && grep -q 'newest image has no readable signature' <<< \"\$1\"" _ "$out"
echo vivobook > "$FX/boot/vmlinuz-7.10.1-071001-generic"
out="$(run "$SAFE_K safe_mode_check; echo rc=\$?")"
check "safe-mode: signed newest image -> OK, exit 0" bash -c "grep -q 'rc=0' <<< \"\$1\" && grep -q 'newest image signed by CN=Vivobook Kernel Key' <<< \"\$1\"" _ "$out"
out="$(run "$SAFE_K sbverify() { return 127; }; kernel_image_signature_state() { echo sbverify-missing; }; safe_mode_check; echo rc=\$?")"
check "safe-mode: no sbverify -> UNVERIFIED counts as failure" bash -c "grep -q 'rc=1' <<< \"\$1\" && grep -q 'newest image cannot be checked' <<< \"\$1\"" _ "$out"

# --- change 9: bound DRM driver ---------------------------------------------------
reset_fx
mkdir -p "$FX/sys/bus/pci/drivers/xe" "$FX/sys/class/drm/card1/device"
ln -s "$FX/sys/bus/pci/drivers/xe" "$FX/sys/class/drm/card1/device/driver"
mkdir -p "$FX/sys/module/i915"
check "bound DRM driver reported as xe even with i915 loaded" bash -c "[[ \"\$(FX='$FX' bash -c '. $LIB; detect_active_drm_driver')\" == xe ]]"

# --- change 10: pmc_core ----------------------------------------------------------
reset_fx
mkdir -p "$FX/sys/kernel/debug/pmc_core"
printf '%s\n' 'Package C2 : 15380284' 'Package C3 : 0' 'Package C6 : 2210000' 'Package C7 : 0' 'Package C8 : 51000' 'Package C9 : 0' 'Package C10 : 0' > "$FX/sys/kernel/debug/pmc_core/package_cstate_show"
printf '%s\n' 'pmc0   Substate       Residency' '         S0i2.0               0' '         S0i3.0         2231014' > "$FX/sys/kernel/debug/pmc_core/substate_residencies"
check "PC6 exact read" bash -c "[[ \"\$(FX='$FX' bash -c '. $LIB; pmc_pkg_cstate 6')\" == 2210000 ]]"
check "PC1 does not match PC10 (exact label)" bash -c "[[ -z \"\$(FX='$FX' bash -c '. $LIB; pmc_pkg_cstate 1')\" ]]"
check "S0i3 sum from validated substate_residencies (upstream pmcN header)" bash -c "[[ \"\$(FX='$FX' bash -c '. $LIB; pmc_substate_sum 3')\" == 2231014 ]]"
printf '%s\n' 'Substate   Residency' 'S0i2.0     10' 'S0i3.0     20' 'S0i3.1     5' > "$FX/sys/kernel/debug/pmc_core/substate_residencies"
check "S0i3 sum, older header format, multiple S0i3 rows" bash -c "[[ \"\$(FX='$FX' bash -c '. $LIB; pmc_substate_sum 3')\" == 25 ]]"
printf '%s\n' 'pmc0 Substate Residency' 'S0i2.0 1' 'pmc1 Substate Residency' 'S0i2.0 999' > "$FX/sys/kernel/debug/pmc_core/substate_residencies"
check "only the first PMC block is used" bash -c "[[ \"\$(FX='$FX' bash -c '. $LIB; pmc_substate_sum 2')\" == 1 ]]"
printf '%s\n' 'something unexpected' 'S0i3: 12' > "$FX/sys/kernel/debug/pmc_core/substate_residencies"
check "unrecognised format -> unavailable (no guess)" bash -c "! FX='$FX' bash -c '. $LIB; pmc_substate_rows' >/dev/null"
rm "$FX/sys/kernel/debug/pmc_core/substate_residencies"; echo 49338142 > "$FX/sys/kernel/debug/pmc_core/slp_s0_residency_usec"
check "no substate file -> unavailable even with SLP_S0 present (no inference)" bash -c "! FX='$FX' bash -c '. $LIB; pmc_substate_rows' >/dev/null"

# --- change 11: battery health -------------------------------------------------------
reset_fx
mkdir -p "$FX/sys/class/power_supply/BAT0"
echo 37548000 > "$FX/sys/class/power_supply/BAT0/energy_full"
echo 42000000 > "$FX/sys/class/power_supply/BAT0/energy_full_design"
echo 64 > "$FX/sys/class/power_supply/BAT0/cycle_count"
status_value_def='status_value() { if [[ -r "$1" ]]; then cat "$1" 2>/dev/null || echo unknown; else echo unavailable; fi; }'
row="$(FX="$FX" bash -c ". '$LIB'; $status_value_def; battery_health_rows")"
check "battery energy_* fallback: 89.4 %, unit uWh, 6 columns" bash -c "[[ \"\$1\" == \$'BAT0\t37548000\t42000000\t64\t89.4\tuWh' ]]" _ "$row"
rm "$FX/sys/class/power_supply/BAT0/energy_full"*; echo 4000000 > "$FX/sys/class/power_supply/BAT0/charge_full"; echo 5000000 > "$FX/sys/class/power_supply/BAT0/charge_full_design"
row="$(FX="$FX" bash -c ". '$LIB'; $status_value_def; battery_health_rows")"
check "battery charge_* path: unit uAh" bash -c "[[ \"\$1\" == \$'BAT0\t4000000\t5000000\t64\t80.0\tuAh' ]]" _ "$row"
rm "$FX/sys/class/power_supply/BAT0/charge_full"*
row="$(FX="$FX" bash -c ". '$LIB'; $status_value_def; battery_health_rows")"
check "battery neither pair: unit unavailable, no empty fields" bash -c "[[ \"\$1\" == \$'BAT0\tunavailable\tunavailable\t64\tunavailable\tunavailable' ]]" _ "$row"

# --- change 12: sysctl overrides --------------------------------------------------
reset_fx
mk /etc/sysctl.d/98-network-bbr.conf $'# Managed by vivobook_optimize.sh v16 --with-bbr\nnet.core.default_qdisc = fq\nnet.ipv4.tcp_congestion_control = bbr'
mk /etc/sysctl.d/99-vivobook.conf $'# Managed by vivobook_optimize.sh v16\nvm.swappiness = 100'
mk /etc/sysctl.d/99-bbr.conf $'net.core.default_qdisc=fq\nnet/ipv4/tcp_congestion_control = bbr'
mk /usr/lib/sysctl.d/99-bbr.conf 'net.ipv4.tcp_congestion_control = reno'
mk /usr/lib/sysctl.d/10-swap.conf '-vm.swappiness = 30 ; comment'
mk /usr/lib/sysctl.d/50-masked.conf 'kernel.nmi_watchdog = 1'
mkdir -p "$FX/etc/sysctl.d"; ln -s /dev/null "$FX/etc/sysctl.d/50-masked.conf"
mk /etc/sysctl.conf 'fs.inotify.max_user_watches = 8192'
rows="$(FX="$FX" bash -c ". '$LIB'; sysctl_unmanaged_overrides" | sed "s#$FX##g")"
check "sysctl: 99-bbr.conf qdisc reported as applied after managed file" grep -qx $'/etc/sysctl.d/99-bbr.conf\tnet.core.default_qdisc\tfq\tafter\t/etc/sysctl.d/98-network-bbr.conf' <<< "$rows"
check "sysctl: slash keys normalised" grep -q $'^/etc/sysctl.d/99-bbr.conf\tnet.ipv4.tcp_congestion_control\tbbr' <<< "$rows"
check "sysctl: /usr/lib copy shadowed by /etc basename" bash -c "! grep -q '/usr/lib/sysctl.d/99-bbr.conf' <<< \"\$1\"" _ "$rows"
check "sysctl: earlier file reported as 'before', '-' prefix and ';' comment handled" grep -qx $'/usr/lib/sysctl.d/10-swap.conf\tvm.swappiness\t30\tbefore\t/etc/sysctl.d/99-vivobook.conf' <<< "$rows"
check "sysctl: /dev/null mask honoured" bash -c "! grep -q 50-masked <<< \"\$1\"" _ "$rows"
check "sysctl: /etc/sysctl.conf applies after" grep -q $'^/etc/sysctl.conf\tfs.inotify.max_user_watches\t8192\tafter' <<< "$rows"
check "sysctl: managed files themselves not reported" bash -c "! grep -qE '98-network-bbr.conf\\s|99-vivobook.conf\\s' <<< \"\$(cut -f1 <<< \"\$1\")\"" _ "$rows"

# --- change 13: --battery-limit=off counting ------------------------------------
reset_fx
mkdir -p "$FX/sys/class/power_supply/BAT0"; echo 80 > "$FX/sys/class/power_supply/BAT0/charge_control_end_threshold"
out="$(run 'battery_limit_off_reset; echo rc=$?')"
check "battery off: 'set to 100% on 1 of 1' and value written" bash -c "grep -q 'set to 100% on 1 of 1' <<< \"\$1\" && [[ \$(cat '$FX/sys/class/power_supply/BAT0/charge_control_end_threshold') == 100 ]]" _ "$out"
out="$(run 'battery_limit_off_reset; echo rc=$?')"
check "battery off: already 100% reported" grep -q 'already 100% on all 1' <<< "$out"
echo 80 > "$FX/sys/class/power_supply/BAT0/charge_control_end_threshold"; chmod 444 "$FX/sys/class/power_supply/BAT0/charge_control_end_threshold"
out="$(run 'battery_limit_off_reset; echo rc=$?')"
check "battery off: unwritable -> WARNING, rc 1" bash -c "grep -q 'WARNING: could not reset' <<< \"\$1\" && grep -q 'rc=1' <<< \"\$1\"" _ "$out"
rm -rf "$FX/sys/class/power_supply"
out="$(run 'battery_limit_off_reset')"
check "battery off: none found" grep -q 'No charge_control_end_threshold attribute found' <<< "$out"

# --- change 15: USB exempt-class diagnostic ------------------------------------------
reset_fx
for d in 1-9 1-10 1-3; do mkdir -p "$FX/sys/bus/usb/devices/$d/power"; done
echo auto > "$FX/sys/bus/usb/devices/1-9/power/control"; echo "USB2.0 HD UVC WebCam" > "$FX/sys/bus/usb/devices/1-9/product"
echo auto > "$FX/sys/bus/usb/devices/1-10/power/control"
echo auto > "$FX/sys/bus/usb/devices/1-3/power/control"
mkdir -p "$FX/sys/bus/usb/devices/1-9:1.0" "$FX/sys/bus/usb/devices/1-9:1.1" "$FX/sys/bus/usb/devices/1-10:1.0" "$FX/sys/bus/usb/devices/1-3:1.0"
echo 0e > "$FX/sys/bus/usb/devices/1-9:1.0/bInterfaceClass"; echo 0e > "$FX/sys/bus/usb/devices/1-9:1.1/bInterfaceClass"
echo e0 > "$FX/sys/bus/usb/devices/1-10:1.0/bInterfaceClass"; echo 08 > "$FX/sys/bus/usb/devices/1-3:1.0/bInterfaceClass"
rows="$(FX="$FX" bash -c ". '$LIB'; usb_exempt_class_rows")"
check "usb: webcam 1-9 (0e) and BT 1-10 (e0) listed on auto, storage 1-3 not" \
  bash -c "[[ \"\$1\" == \$'1-9\t0e\tauto\tUSB2.0 HD UVC WebCam\n1-10\te0\tauto\tunknown' ]]" _ "$rows"

fi  # not root
fi  # perl

# ---------------------------------------------------------------------------
printf '\n== summary: %d passed, %d failed, %d skipped ==\n' "$PASS" "$FAIL" "$SKIP"
echo "Not verified here: anything requiring the X1605VA hardware, root, debugfs,"
echo "a real suspend/resume cycle, Secure Boot/MOK state or an apply pass."
(( FAIL == 0 ))
