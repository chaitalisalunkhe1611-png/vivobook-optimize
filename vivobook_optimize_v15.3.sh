#!/usr/bin/env bash
#
# ASUS Vivobook 16 (X1605VA) — Optimization Pass v15.3
# i5-13420H (Raptor Lake-H, 4P+4E) / Intel UHD iGPU / 16GB DDR4 / Micron NVMe
#
# v15.3 — correctness/completeness release (new flags: --with-mt7921e-aspm,
# --version, --safe-mode-check). Fixes: I-01 per-constraint RAPL lock probe;
# I-02 live-firmware PL2 check; I-03 MT7902 ASPM workaround; I-04 PPD read-back;
# I-05 PPD thermal/EPP conflict refused; I-06 global ASPM write removed;
# I-07 zram detach on restore; I-08 BBR live reset; I-09 battery restore
# count; I-10/I-11 honest dry-run probes; I-12 banner last; I-13 no-op
# atomic_write; I-14 timer restart only on change; I-15 headers-base purge;
# I-16/I-17 marker enforcement; I-18 unit/hook markers; I-19/I-20 identity +
# integrity status, stable JSON schema, --version; I-21 xe iGPU freq layout;
# I-22 ASPM-aware C-states; I-23 redirect-ordering leak; I-24 here-string
# zram write; I-25 auto-power knob accounting; I-26/I-27 browser flags
# preserved + install detection; I-28 dry-run prompts, /boot note;
# I-29..I-33 doc/dead-code annotations; I-34 --safe-mode-check gate.
#
# Usage:
#   sudo bash __SCRIPT_NAME__                                    safe defaults only
#   sudo bash __SCRIPT_NAME__ --with-guc                         diagnose i915 GuC/HuC state only, no changes
#   sudo bash __SCRIPT_NAME__ --with-auto-upgrade                apply available fwupd firmware updates during the
#                                                                supervised step-2 run (the background timer never
#                                                                upgrades packages, flashes firmware, or prunes kernels)
#   sudo bash __SCRIPT_NAME__ --with-multiverse                  non-interactively enable Ubuntu multiverse if the
#                                                                non-free Intel VA-API driver is unavailable
#   sudo bash __SCRIPT_NAME__ --with-battery-limit               cap battery charge at 80% (asus_wmi)
#   sudo bash __SCRIPT_NAME__ --battery-limit=N                  cap battery charge at N% (20-100)
#   sudo bash __SCRIPT_NAME__ --battery-limit=off                remove the charge cap (restore 100%)
#   sudo bash __SCRIPT_NAME__ --maintenance-schedule=weekly
#   sudo bash __SCRIPT_NAME__ --maintenance-schedule=monthly
#   sudo bash __SCRIPT_NAME__ --fan-profile=quiet
#   sudo bash __SCRIPT_NAME__ --fan-profile=balanced
#   sudo bash __SCRIPT_NAME__ --fan-profile=performance
#   sudo bash __SCRIPT_NAME__ --epp=performance
#   sudo bash __SCRIPT_NAME__ --epp=balance_performance
#   sudo bash __SCRIPT_NAME__ --epp=balance_power
#   sudo bash __SCRIPT_NAME__ --epp=power
#   sudo bash __SCRIPT_NAME__ --with-zram
#   sudo bash __SCRIPT_NAME__ --with-auto-power                  dynamic AC/battery profile switching (udev + service)
#                                                                AC: performance EPP/thermal, Wi-Fi/audio saving off
#                                                                Battery: balance_power/power-saver EPP, balanced
#                                                                thermal, Wi-Fi/audio saving on
#                                                                Profiles apply via power-profiles-daemon when active,
#                                                                else via sysfs; no CPU/iGPU frequency clamps, no RAPL
#                                                                overrides, no backlight or writeback manipulation
#                                                                (HWP/GuC SLPC/kernel defaults retained)
#                                                                Overrides static EPP/thermal when switching; dynamic
#                                                                audio applies even with --no-audio-powersave (that
#                                                                skips the static config only)
#   sudo bash __SCRIPT_NAME__ --pl1=WATTS                        manage Intel RAPL PL1 sustained limit (watts).
#   sudo bash __SCRIPT_NAME__ --pl2=WATTS                        manage Intel RAPL PL2 burst limit (watts).
#                                                                If only one is given, ONLY that constraint is
#                                                                managed; the other stays under firmware control
#                                                                and is never invented. Requests are validated
#                                                                against the live hardware envelope (PL1 <= PL2)
#                                                                and against constraint maxima where exposed.
#   sudo bash __SCRIPT_NAME__ --with-kbd-timeout                 auto-dim keyboard backlight after 30s idle
#   sudo bash __SCRIPT_NAME__ --with-bbr                         enable TCP BBR congestion control + FQ qdisc
#   sudo bash __SCRIPT_NAME__ --with-browser-wayland               configure Ozone platform auto-detection for Wayland browsers
#                                                                (--with-browser-vaapi remains a compatibility alias)
#   sudo bash __SCRIPT_NAME__ --with-mt7921e-aspm                stage the MediaTek MT7902 (mt7921e) ASPM workaround:
#                                                                /etc/modprobe.d/mt7921e.conf with
#                                                                'options mt7921e disable_aspm=1'. Required for Wi-Fi
#                                                                link stability on this platform; needs a reboot (no
#                                                                initramfs rebuild). Unmanaged files are never
#                                                                overwritten. Not gated by TLP.
#   sudo bash __SCRIPT_NAME__ --with-usb-autosuspend             enable USB runtime autosuspend (exempting USB HID,
#                                                                Bluetooth/wireless controllers, USB audio class 01
#                                                                and UVC video class 0e)
#   sudo bash __SCRIPT_NAME__ --disable-ppd                      mask power-profiles-daemon to prevent EPP conflicts
#   sudo bash __SCRIPT_NAME__ --force-tlp-override               allow script-managed power policy steps (audio
#                                                                power_save defaults, ASUS charge threshold,
#                                                                thermal platform profile, CPU EPP, USB
#                                                                autosuspend) even while TLP is active.
#                                                                NOT recommended: two managers then write the
#                                                                same knobs. --with-auto-power ALWAYS refuses
#                                                                to run under TLP regardless of this flag.
#   bash __SCRIPT_NAME__ --dry-run                               parse arguments and print actions without modifying
#                                                                the system (root not required)
#   sudo bash __SCRIPT_NAME__ --restore-defaults                 remove every script-managed service, unit, helper,
#                                                                hook and config file; detach the managed zram swap
#                                                                device; restore battery/max_perf_pct to 100%; reset
#                                                                swappiness/writeback and the live BBR congestion
#                                                                control value, then reapply distro sysctls. Module
#                                                                options and RAPL need a reboot to take effect. It is
#                                                                NOT an undo of the kernel cmdline, BIOS settings or
#                                                                distro packages.
#   bash __SCRIPT_NAME__ --status                                read-only system status dashboard (sudo optional;
#                                                                more detail, e.g. C-state residency, when run as root)
#   bash __SCRIPT_NAME__ --check                                 alias for --status
#   bash __SCRIPT_NAME__ --status-json                           machine-readable system telemetry (sudo optional)
#   bash __SCRIPT_NAME__ --safe-mode-check                       read-only boot/Wi-Fi integrity gate. Runs the checks
#                                                                from I-19/I-34 (kernel signing hook, stock-kernel
#                                                                pin, running-kernel signature, Secure Boot, mt7921e
#                                                                ASPM workaround) and exits 1 listing anything
#                                                                missing — do not reboot until they are resolved
#   bash __SCRIPT_NAME__ --version                               print script name, version and JSON schema; exit 0
#   sudo bash __SCRIPT_NAME__ --skip-update                      skip steps 1-3 (rapid configuration pass)
#   sudo bash __SCRIPT_NAME__ --with-full-upgrade                use apt-get full-upgrade instead of upgrade
#   sudo bash __SCRIPT_NAME__ --no-sysctl                        skip /etc/sysctl.d/99-vivobook.conf tuning
#   sudo bash __SCRIPT_NAME__ --no-audio-powersave               skip snd_hda_intel power_save configuration
#   sudo bash __SCRIPT_NAME__ -h                                 show this usage
#
# Defaults: /etc/vivobook-optimize/defaults.conf is sourced before CLI parsing,
# so command-line arguments take precedence.
#
# Safe to re-run. Flags mostly additive (guc/battery/profile/EPP/zRAM/
# auto-power/kbd/bbr/browser/usb units and files aren't removed by omitting
# the flag later; use --battery-limit=off to undo the charge cap, or
# --restore-defaults to tear down ALL managed configs).
# --maintenance-schedule reflects only the MOST RECENT run, since step 10
# regenerates the maintenance script and timer.
#
# END-USAGE

set -Eeuo pipefail
trap 'rc=$?; echo "ERROR at line $LINENO (exit code $rc)" >&2' ERR

# v15.2: track helper temp files (atomic_write / systemd unit verification) so
# no strays are left behind if the script dies mid-write under set -e. Uses
# 'command rm' so the dry-run rm override cannot affect real cleanup.
TMP_REGISTRY=()
cleanup_tmp_registry() {
  local t
  for t in "${TMP_REGISTRY[@]:-}"; do
    [[ -n "$t" && -f "$t" ]] && command rm -f "$t"
  done
  return 0
}
trap cleanup_tmp_registry EXIT

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]:-$0}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]:-$0}")"
SCRIPT_NAME="$(basename "$SCRIPT_PATH")"
# v15.3 (I-20): the JSON schema is versioned so consumers can detect changes.
SCRIPT_VERSION="15.3"
SCRIPT_SCHEMA=2
DEFAULTS_FILE="/etc/vivobook-optimize/defaults.conf"
I915_CONF="/etc/modprobe.d/vivobook-i915.conf"

# ---- Option defaults -------------------------------------------------------
WITH_GUC=false
WITH_AUTO_UPGRADE=false
WITH_MULTIVERSE=false
BATTERY_LIMIT=""
WITH_SYSCTL=true
WITH_AUDIO_POWERSAVE=true
MAINTENANCE_SCHEDULE=weekly
FAN_PROFILE=""
EPP_PROFILE=""
WITH_ZRAM=false
WITH_AUTO_POWER=false
PL1=""
PL2=""
WITH_KBD_TIMEOUT=false
WITH_BBR=false
WITH_BROWSER_WAYLAND=false
WITH_USB_AUTOSUSPEND=false
DISABLE_PPD=false
DRY_RUN=false
RESTORE_DEFAULTS=false
STATUS_MODE=false
STATUS_JSON=false
HELP_REQUESTED=false
SKIP_UPDATE=false
WITH_FULL_UPGRADE=false
WITH_MT7921E_ASPM=false
VERSION_REQUESTED=false
SAFE_MODE_CHECK=false
# v15.2: even with this set, --with-auto-power still refuses to run under TLP.
FORCE_TLP_OVERRIDE=false

MANAGED_BROWSER_FLAGS=(
  "--ozone-platform-hint=auto"
)

# Obsolete VA-API/GPU flags written by earlier script versions (v12/v13).
# chromium-flags.conf lines they appeared in took two distinct shapes:
#   * tokens embedded in --enable-features=/--disable-features= lists
#     (e.g. --enable-features=Foo,VaapiVideoDecoder,Bar)
#   * standalone whole-line switches (e.g. --ignore-gpu-blocklist)
# v15.1's matcher only caught standalone exact lines and anchored "KEY="
# prefixes, so embedded feature-list tokens survived every purge run — the
# common case. v15.2 splits feature lists token-wise and removes ONLY the
# exact legacy tokens; look-alikes (VaapiVideoDecoderFoo) and all unrelated
# user features are preserved.
LEGACY_FEATURE_TOKENS=(
  "VaapiVideoDecoder"
  "VaapiVideoEncoder"
  "VaapiIgnoreDriverChecks"
)
LEGACY_STANDALONE_FLAGS=(
  "--ignore-gpu-blocklist"
  "--enable-gpu-rasterization"
  "--enable-zero-copy"
)

# Allow unprivileged read-only/help invocations even if defaults.conf is broken.
EARLY_READONLY=false
for arg in "$@"; do
  case "$arg" in
    -h|--help|--status|--check|--status-json|--dry-run|--version|--safe-mode-check) EARLY_READONLY=true ;;
  esac
done

if [[ -r "$DEFAULTS_FILE" ]]; then
  if [[ "$EARLY_READONLY" == true ]]; then
    # shellcheck disable=SC1091
    . "$DEFAULTS_FILE" || true
  else
    # shellcheck disable=SC1091
    . "$DEFAULTS_FILE"
  fi
fi

for arg in "$@"; do
  case "$arg" in
    --with-guc) WITH_GUC=true ;;
    --with-auto-upgrade) WITH_AUTO_UPGRADE=true ;;
    --with-multiverse) WITH_MULTIVERSE=true ;;
    --with-battery-limit) BATTERY_LIMIT=80 ;;
    --battery-limit=*) BATTERY_LIMIT="${arg#*=}" ;;
    --maintenance-schedule=*) MAINTENANCE_SCHEDULE="${arg#*=}" ;;
    --fan-profile=*) FAN_PROFILE="${arg#*=}" ;;
    --epp=*) EPP_PROFILE="${arg#*=}" ;;
    --with-zram) WITH_ZRAM=true ;;
    --with-auto-power) WITH_AUTO_POWER=true ;;
    --pl1=*) PL1="${arg#*=}" ;;
    --pl2=*) PL2="${arg#*=}" ;;
    --with-kbd-timeout) WITH_KBD_TIMEOUT=true ;;
    --with-bbr) WITH_BBR=true ;;
    --with-browser-wayland|--with-browser-vaapi) WITH_BROWSER_WAYLAND=true ;;
    --with-usb-autosuspend) WITH_USB_AUTOSUSPEND=true ;;
    --with-mt7921e-aspm) WITH_MT7921E_ASPM=true ;;
    --version) VERSION_REQUESTED=true ;;
    --safe-mode-check) SAFE_MODE_CHECK=true ;;
    --disable-ppd) DISABLE_PPD=true ;;
    --force-tlp-override) FORCE_TLP_OVERRIDE=true ;;
    --dry-run) DRY_RUN=true ;;
    --restore-defaults) RESTORE_DEFAULTS=true ;;
    --status|--check) STATUS_MODE=true ;;
    --status-json) STATUS_JSON=true ;;
    --skip-update) SKIP_UPDATE=true ;;
    --with-full-upgrade) WITH_FULL_UPGRADE=true ;;
    --no-sysctl) WITH_SYSCTL=false ;;
    --no-audio-powersave) WITH_AUDIO_POWERSAVE=false ;;
    -h|--help) HELP_REQUESTED=true ;;
    *)
      echo "Unknown option: $arg" >&2
      echo "Usage: $0 [--with-guc] [--with-auto-upgrade]" >&2
      echo "          [--with-multiverse] [--with-battery-limit | --battery-limit=N|off]" >&2
      echo "          [--maintenance-schedule=weekly|monthly]" >&2
      echo "          [--fan-profile=quiet|balanced|performance]" >&2
      echo "          [--epp=performance|balance_performance|balance_power|power]" >&2
      echo "          [--with-zram]" >&2
      echo "          [--with-auto-power] [--pl1=WATTS] [--pl2=WATTS]" >&2
      echo "          [--with-kbd-timeout]" >&2
      echo "          [--with-bbr] [--with-browser-wayland]" >&2
      echo "          [--with-usb-autosuspend] [--with-mt7921e-aspm] [--disable-ppd]" >&2
      echo "          [--force-tlp-override]" >&2
      echo "          [--dry-run]" >&2
      echo "          [--restore-defaults] [--status|--check|--status-json]" >&2
      echo "          [--skip-update] [--with-full-upgrade]" >&2
      echo "          [--no-sysctl] [--no-audio-powersave]" >&2
      echo "          [--safe-mode-check] [--version] [-h]" >&2
      exit 2
      ;;
  esac
done

# ---- Helpers ---------------------------------------------------------------

usage() {
  sed -n '/^# ASUS Vivobook/,/^# END-USAGE/p' "$SCRIPT_PATH" |
    sed '/^# END-USAGE/d' |
    sed 's/^# \{0,1\}//' |
    sed "s|__SCRIPT_NAME__|$SCRIPT_NAME|g"
}

atomic_write() {
  local dest="$1" mode="$2" tmp dir want_mode
  dir="$(dirname "$dest")"
  if [[ ! -d "$dir" ]]; then
    install -d -m 0755 "$dir"
  fi
  tmp="$(mktemp "${dir}/.${SCRIPT_NAME}.XXXXXX")"
  TMP_REGISTRY+=("$tmp")
  cat > "$tmp"
  chmod "$mode" "$tmp"
  if [[ -e "$dest" ]]; then
    chown --reference="$dest" "$tmp" 2>/dev/null || true
  fi
  # v15.3 (I-13): semantic no-op. Byte-identical content means there is nothing
  # to install; skip the mv so re-runs do not churn every managed file (and do
  # not re-trigger systemd/udev/browser watchers) for no reason. 'command rm'
  # is used so the dry-run rm override cannot interfere with real cleanup —
  # same reasoning as the TMP_REGISTRY comment above.
  if [[ -e "$dest" ]] && command cmp -s "$tmp" "$dest"; then
    command rm -f "$tmp"
    want_mode="$(printf '%o' "$(( 8#$mode ))")"
    if [[ "$(stat -c '%a' "$dest" 2>/dev/null || true)" != "$want_mode" ]]; then
      chmod "$mode" "$dest"
    fi
    return 0
  fi
  mv -f "$tmp" "$dest"
}

verify_systemd_unit() {
  local unit="$1" errfile
  command -v systemd-analyze >/dev/null 2>&1 || return 0
  errfile="$(mktemp "${TMPDIR:-/tmp}/vivobook-verify.XXXXXX")"
  TMP_REGISTRY+=("$errfile")
  if systemd-analyze verify "$unit" >"$errfile" 2>&1; then
    rm -f "$errfile"
    return 0
  fi
  echo "systemd-analyze verify failed for $unit:" >&2
  cat "$errfile" >&2
  rm -f "$errfile"
  return 1
}

write_unit_file() {
  local dest="$1" mode="$2"
  atomic_write "$dest" "$mode"
  verify_systemd_unit "$dest" || echo "WARNING: systemd-analyze verify failed for $dest, but unit file remains." >&2
}

status_value() {
  local path="$1"
  if [[ -r "$path" ]]; then
    cat "$path" 2>/dev/null || printf '%s\n' unknown
  else
    printf '%s\n' unavailable
  fi
}

find_battery_threshold() {
  local f
  for f in /sys/class/power_supply/BAT*/charge_control_end_threshold; do
    [[ -e "$f" ]] || continue
    printf '%s\n' "$f"
    return 0
  done
  return 0
}

find_intel_drm_card() {
  local card vendor
  for card in /sys/class/drm/card[0-9]*; do
    [[ -d "$card" ]] || continue
    [[ -r "$card/device/vendor" ]] || continue
    vendor="$(cat "$card/device/vendor" 2>/dev/null || true)"
    if [[ "$vendor" == "0x8086" ]]; then
      printf '%s\n' "$card"
      return 0
    fi
  done
  return 1
}

detect_active_drm_driver() {
  local driver_link
  for driver_link in /sys/class/drm/card[0-9]*/device/driver; do
    if [[ -e "$driver_link" ]]; then
      basename "$(readlink -f "$driver_link")"
      return 0
    fi
  done
  echo "unknown"
}

find_igpu_freq_files() {
  local card="$1"
  local max_f="" boost_f="" rp0_f="" rpn_f=""
  
  if [[ -d "$card/gt/gt0" ]]; then
    if [[ -r "$card/gt/gt0/rps_max_freq_mhz" ]]; then
      max_f="$card/gt/gt0/rps_max_freq_mhz"
      boost_f="$card/gt/gt0/rps_boost_freq_mhz"
      rp0_f="$card/gt/gt0/rps_RP0_freq_mhz"
      rpn_f="$card/gt/gt0/rps_RPn_freq_mhz"
    elif [[ -r "$card/gt/gt0/gt_max_freq_mhz" ]]; then
      max_f="$card/gt/gt0/gt_max_freq_mhz"
      boost_f="$card/gt/gt0/gt_boost_freq_mhz"
      rp0_f="$card/gt/gt0/gt_RP0_freq_mhz"
      rpn_f="$card/gt/gt0/gt_RPn_freq_mhz"
    fi
  fi
  
  if [[ -z "$max_f" ]]; then
    if [[ -r "$card/gt_max_freq_mhz" ]]; then
      max_f="$card/gt_max_freq_mhz"
      boost_f="$card/gt_boost_freq_mhz"
      rp0_f="$card/gt_RP0_freq_mhz"
      rpn_f="$card/gt_RPn_freq_mhz"
    fi
  fi

  # v15.3 (I-21): the xe driver (used on this machine) publishes iGPU
  # frequencies under .../device/tile*/gt*/freq0/ instead of the i915
  # gt/gt0/rps_* nodes. Map them onto the SAME four-tuple the callers already
  # expect (max, boost, rp0, rpn): max_freq -> max, rp0_freq -> boost (xe has
  # no separate boost node), rp0_freq -> rp0, min_freq -> rpn. Read-only: no
  # write path is added for xe frequencies.
  if [[ -z "$max_f" ]]; then
    local freq0
    for freq0 in "$card"/device/tile*/gt*/freq0; do
      [[ -d "$freq0" ]] || continue
      [[ -r "$freq0/max_freq" ]] || continue
      max_f="$freq0/max_freq"
      boost_f="$freq0/rp0_freq"
      rp0_f="$freq0/rp0_freq"
      rpn_f="$freq0/min_freq"
      break
    done
  fi
  
  if [[ -n "$max_f" ]]; then
    echo "$max_f $boost_f $rp0_f $rpn_f"
    return 0
  fi
  return 1
}

get_wireplumber_version() {
  if command -v wireplumber &>/dev/null; then
    wireplumber --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || echo "unknown"
  elif command -v wpctl &>/dev/null; then
    wpctl --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || echo "unknown"
  elif dpkg -s wireplumber &>/dev/null; then
    dpkg -s wireplumber 2>/dev/null | awk '/^Version:/ {print $2}' | grep -oE '^[0-9]+\.[0-9]+(\.[0-9]+)?' || echo "unknown"
  else
    echo "not-installed"
  fi
}

json_string() {
  local s="$*"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\n'/\\n}"
  printf '"%s"' "$s"
}

# ---- v15.3 helpers ---------------------------------------------------------

is_managed_file() {
  local f="$1"
  [[ -f "$f" ]] && grep -q "Managed by vivobook_optimize" "$f" 2>/dev/null
}

# PPD holds exactly ONE profile. These two maps are the single source of truth
# for the I-05 conflict check, the status dashboard, and the generated helpers.
ppd_profile_for_thermal() {
  case "${1:-}" in
    quiet)       printf '%s\n' power-saver ;;
    balanced)    printf '%s\n' balanced ;;
    performance) printf '%s\n' performance ;;
    *)           printf '%s\n' none ;;
  esac
}

ppd_profile_for_epp() {
  case "${1:-}" in
    performance)         printf '%s\n' performance ;;
    balance_performance) printf '%s\n' balanced ;;
    balance_power|power) printf '%s\n' power-saver ;;
    *)                   printf '%s\n' none ;;
  esac
}

ppd_current_profile() {
  local v=""
  if command -v powerprofilesctl >/dev/null 2>&1; then
    v="$(powerprofilesctl get 2>/dev/null || true)"
  fi
  printf '%s\n' "${v:-unavailable}"
}

# ---- MediaTek MT7902 / mt7921e ASPM workaround (I-03, I-22) ----------------
MT7921E_CONF=/etc/modprobe.d/mt7921e.conf

mt7921e_loaded() {
  command -v lsmod >/dev/null 2>&1 || return 1
  lsmod 2>/dev/null | awk '$1 == "mt7921e" {found=1} END {exit(found ? 0 : 1)}'
}

# Prints the name of an interface bound to mt7921e, if any.
mt7921e_bound_iface() {
  local link drv
  for link in /sys/class/net/*/device/driver; do
    [[ -e "$link" ]] || continue
    drv="$(basename "$(readlink -f "$link" 2>/dev/null)" 2>/dev/null || true)"
    [[ "$drv" == "mt7921e" ]] || continue
    basename "$(dirname "$(dirname "$link")")"
    return 0
  done
  return 1
}

mt7921e_present() {
  mt7921e_bound_iface >/dev/null 2>&1 || mt7921e_loaded
}

mt7921e_conf_managed() {
  is_managed_file "$MT7921E_CONF"
}

mt7921e_conf_has_disable_aspm() {
  [[ -f "$MT7921E_CONF" ]] &&
    grep -Eq '^[[:space:]]*options[[:space:]]+mt7921e[[:space:]].*disable_aspm=1([[:space:]]|$)' "$MT7921E_CONF" 2>/dev/null
}

mt7921e_disable_aspm_live() {
  local f=/sys/module/mt7921e/parameters/disable_aspm v=""
  if [[ ! -r "$f" ]]; then
    printf '%s\n' unavailable
    return 0
  fi
  v="$(cat "$f" 2>/dev/null || true)"
  printf '%s\n' "${v:-unavailable}"
}

# The mt7921e ASPM workaround is what keeps PC8/PC10 at zero on this platform
# (I-22), whether it comes from the live module parameter or the staged file.
aspm_workaround_active() {
  local live
  live="$(mt7921e_disable_aspm_live)"
  case "$live" in
    Y|y|1) return 0 ;;
  esac
  mt7921e_conf_has_disable_aspm
}

# ---- Intel RAPL constraint enumeration and lock probing (I-01, I-19, I-20) --
# Prints "zone<TAB>canonical-constraint-file<TAB>PL1|PL2" once per constraint.
# Shared by the dashboard and --status-json so the two can never disagree.
rapl_constraint_files() {
  local f canon zone label
  declare -A seen=()
  for f in /sys/class/powercap/intel-rapl*/constraint_0_power_limit_uw \
           /sys/class/powercap/intel-rapl*/*:*/constraint_0_power_limit_uw \
           /sys/class/powercap/intel-rapl*/constraint_1_power_limit_uw \
           /sys/class/powercap/intel-rapl*/*:*/constraint_1_power_limit_uw; do
    [[ -e "$f" ]] || continue
    canon="$(readlink -f "$f" 2>/dev/null || printf '%s' "$f")"
    [[ -n "${seen[$canon]:-}" ]] && continue
    seen["$canon"]=1
    zone="$(basename "$(dirname "$f")")"
    case "$(basename "$f")" in
      constraint_0_*) label=PL1 ;;
      constraint_1_*) label=PL2 ;;
      *) continue ;;
    esac
    printf '%s\t%s\t%s\n' "$zone" "$canon" "$label"
  done
}

# Firmware-lock probe for ONE constraint: writes the current value back, which
# is semantically a no-op but is enough to distinguish a writable register from
# a BIOS/MSR-locked one. Prints writable|locked|unknown|absent. Non-root cannot
# write at all, so the state is reported unknown rather than guessed.
rapl_probe_lock_state() {
  local node="$1" cur=""
  if [[ ! -e "$node" ]]; then
    printf '%s\n' absent
    return 0
  fi
  if (( EUID != 0 )); then
    printf '%s\n' 'unknown (needs root)'
    return 0
  fi
  cur="$(cat "$node" 2>/dev/null || true)"
  if [[ ! "$cur" =~ ^[0-9]+$ ]]; then
    printf '%s\n' unknown
    return 0
  fi
  if { printf '%s\n' "$cur" > "$node"; } 2>/dev/null; then
    printf '%s\n' writable
  else
    printf '%s\n' locked
  fi
}

# ---- Boot-integrity facts (I-19, I-34) -------------------------------------
SIGNING_HOOK=/etc/kernel/postinst.d/zz-sign-kernel
STOCK_KERNEL_PREF=/etc/apt/preferences.d/block-stock-kernel.pref
MOK_SUBJECT_MATCH="Vivobook Kernel Key"

secure_boot_state() {
  local out ef hex
  if command -v mokutil >/dev/null 2>&1; then
    out="$(mokutil --sb-state 2>&1 || true)"
    case "$out" in
      *"SecureBoot enabled"*)  printf '%s\n' enabled ; return 0 ;;
      *"SecureBoot disabled"*) printf '%s\n' disabled; return 0 ;;
    esac
  fi
  # Fallback: efivarfs (6-byte variable; byte 5 is 1 when Secure Boot is on).
  ef=/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c
  if [[ -r "$ef" ]]; then
    hex="$(od -An -t x1 "$ef" 2>/dev/null | tr -d '[:space:]' || true)"
    case "${hex:10:2}" in
      01) printf '%s\n' enabled ; return 0 ;;
      00) printf '%s\n' disabled; return 0 ;;
    esac
  fi
  printf '%s\n' unknown
}

signing_hook_state() {
  if [[ -x "$SIGNING_HOOK" ]]; then
    printf '%s\n' present-executable
  elif [[ -e "$SIGNING_HOOK" ]]; then
    printf '%s\n' present-not-executable
  else
    printf '%s\n' absent
  fi
}

# 0 = the pin file exists AND blocks (negative Pin-Priority for a linux
# package glob); non-zero = absent or not blocking.
stock_kernel_pin_blocks() {
  [[ -f "$STOCK_KERNEL_PREF" ]] || return 1
  grep -Eq '^[[:space:]]*Pin-Priority:[[:space:]]*-[0-9]+' "$STOCK_KERNEL_PREF" 2>/dev/null || return 1
  grep -Eq '^[[:space:]]*Package:[[:space:]].*linux' "$STOCK_KERNEL_PREF" 2>/dev/null || return 1
  return 0
}

# Prints signed-by-vivobook-key | signed-by-other | unsigned | file-missing |
# sbverify-missing. Read-only; never aborts on missing tools or files.
running_kernel_signature_state() {
  local k out
  k="/boot/vmlinuz-$(uname -r)"
  if [[ ! -f "$k" ]]; then
    printf '%s\n' file-missing
    return 0
  fi
  if ! command -v sbverify >/dev/null 2>&1; then
    printf '%s\n' sbverify-missing
    return 0
  fi
  if ! out="$(sbverify --list "$k" 2>&1)"; then
    printf '%s\n' unsigned
    return 0
  fi
  if printf '%s\n' "$out" | grep -q "$MOK_SUBJECT_MATCH"; then
    printf '%s\n' signed-by-vivobook-key
  else
    printf '%s\n' signed-by-other
  fi
}

# Prints "name<TAB>charge_full<TAB>charge_full_design<TAB>cycle_count<TAB>health%".
battery_health_rows() {
  local d name cf cfd cyc health
  for d in /sys/class/power_supply/BAT*; do
    [[ -d "$d" ]] || continue
    name="$(basename "$d")"
    cf="$(status_value "$d/charge_full")"
    cfd="$(status_value "$d/charge_full_design")"
    cyc="$(status_value "$d/cycle_count")"
    health="unavailable"
    if [[ "$cf" =~ ^[0-9]+$ && "$cfd" =~ ^[0-9]+$ ]] && (( 10#$cfd > 0 )); then
      health="$(awk "BEGIN {printf \"%.1f\", 100 * $cf / $cfd}" 2>/dev/null || printf '%s' unavailable)"
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$cf" "$cfd" "$cyc" "$health"
  done
}

# ---- Browser install detection (I-27) --------------------------------------
# 'snap'-based detection is deliberately avoided: snap is overridden to a
# print-only stub in --dry-run, and its echoed output would look like a match.
browser_installed() {
  case "$1" in
    brave)
      command -v brave-browser >/dev/null 2>&1
      ;;
    chrome)
      command -v google-chrome >/dev/null 2>&1 || command -v google-chrome-stable >/dev/null 2>&1
      ;;
    chromium)
      if command -v chromium >/dev/null 2>&1 || command -v chromium-browser >/dev/null 2>&1; then
        return 0
      fi
      compgen -G '/snap/bin/chromium' >/dev/null 2>&1 ||
        compgen -G '/var/lib/snapd/snaps/chromium_*.snap' >/dev/null 2>&1
      ;;
    *)
      return 1
      ;;
  esac
}

# ---- Generic-path adoption policy (I-17) -----------------------------------
# An EXISTING file that is not script-managed may only be adopted when its
# content (comments, blank lines and whitespace stripped) is exactly the
# legacy content written by earlier versions of this script.
managed_or_legacy_adoptable() {
  local path="$1" legacy_norm="$2" norm=""
  [[ -e "$path" ]] || return 0
  is_managed_file "$path" && return 0
  norm="$(sed -e 's/#.*$//' -e 's/[[:space:]]//g' "$path" 2>/dev/null | tr -d '\n' || true)"
  [[ "$norm" == "$legacy_norm" ]]
}

remove_managed_config() {
  local f="$1"
  [[ -e "$f" ]] || return 0
  if grep -q "Managed by vivobook_optimize" "$f" 2>/dev/null; then
    if [[ "$DRY_RUN" == true ]]; then
      echo "[DRY-RUN] Would remove (managed marker found): $f"
    else
      rm -f "$f"
    fi
  fi
}

# Removes /etc/modprobe.d/vivobook-i915.conf when it was staged by an older
# version of this script (managed header, or any of the deprecated i915 module
# parameters enable_guc=3 / enable_dc=2 / enable_fbc=1 / enable_psr=1).
# Sets I915_CONF_REMOVED=true so callers can refresh the initramfs.
# Always returns 0: a missing or unmanaged file is not an error.
I915_CONF_REMOVED=false

remove_i915_conf() {
  [[ -e "$I915_CONF" ]] || return 0
  if grep -q "Managed by vivobook_optimize" "$I915_CONF" 2>/dev/null ||
     grep -Eq '^[[:space:]]*options[[:space:]]+i915[[:space:]]+.*(enable_guc=3|enable_dc=2|enable_fbc=1|enable_psr=1)([[:space:]]|$)' "$I915_CONF" 2>/dev/null; then
    if [[ "$DRY_RUN" == true ]]; then
      # v15.2: report the simulated removal accurately and do NOT mark the
      # file as removed — otherwise dry-run would also fake the initramfs
      # rebuild that follows a real removal.
      echo "[DRY-RUN] Would remove $I915_CONF (deprecated i915 module parameters)."
    else
      rm -f "$I915_CONF"
      I915_CONF_REMOVED=true
    fi
  fi
  return 0
}

restore_iwlwifi_conf() {
  local conf="/etc/modprobe.d/iwlwifi.conf"
  [[ -f "$conf" ]] || return 0
  if ! grep -q "Managed by vivobook_optimize" "$conf" 2>/dev/null; then
    return 0
  fi
  local unmanaged=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*Managed\ by\ vivobook_optimize ]]; then
      continue
    elif [[ "$line" =~ ^[[:space:]]*options[[:space:]]+iwlwifi ]]; then
      local opts
      opts="$(printf '%s\n' "$line" | sed -E 's/^[[:space:]]*options[[:space:]]+iwlwifi[[:space:]]*//; s/(^|[[:space:]])power_save=[^[:space:]]*//g; s/(^|[[:space:]])uapsd_disable=[^[:space:]]*//g; s/(^|[[:space:]])amsdu_size=[^[:space:]]*//g' | tr -s '[:space:]' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      [[ -n "$opts" ]] && unmanaged+=("options iwlwifi $opts")
    elif [[ "$line" =~ ^[[:space:]]*options[[:space:]]+iwlmvm ]]; then
      local opts
      opts="$(printf '%s\n' "$line" | sed -E 's/^[[:space:]]*options[[:space:]]+iwlmvm[[:space:]]*//; s/(^|[[:space:]])power_scheme=[^[:space:]]*//g' | tr -s '[:space:]' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      [[ -n "$opts" ]] && unmanaged+=("options iwlmvm $opts")
    elif [[ -n "$line" ]]; then
      unmanaged+=("$line")
    fi
  done < "$conf"

  if [[ ${#unmanaged[@]} -gt 0 ]]; then
    local out=""
    for ul in "${unmanaged[@]}"; do
      out+="$ul"$'\n'
    done
    atomic_write "$conf" 0644 <<< "$out"
  else
    rm -f "$conf"
  fi
}

# Returns 0 and prints the (possibly rewritten) line to keep it, or returns 1
# to drop the line entirely. Handles:
#   - currently managed flags (always re-appended fresh by the caller)
#   - legacy standalone switches (exact line, optionally with "=value")
#   - --enable-features=/--disable-features= lists: strips only exact legacy
#     tokens; the line is dropped if nothing remains, else rewritten without
#     the legacy tokens and with all unrelated features preserved.
filter_browser_flag_line() {
  local line="$1" mf key lf tok

  for mf in "${MANAGED_BROWSER_FLAGS[@]}"; do
    key="${mf%%=*}"
    if [[ "$line" == "$mf" || "$line" == "$key" || "$line" == "$key="* ]]; then
      return 1
    fi
  done

  for lf in "${LEGACY_STANDALONE_FLAGS[@]}"; do
    if [[ "$line" == "$lf" || "$line" == "$lf="* ]]; then
      return 1
    fi
  done

  if [[ "$line" =~ ^(--enable-features|--disable-features)=(.*)$ ]]; then
    local head="${BASH_REMATCH[1]}" rest="${BASH_REMATCH[2]}"
    local -a toks=() keep=()
    local t legacy
    IFS=',' read -r -a toks <<< "$rest"
    for t in "${toks[@]}"; do
      # Trim surrounding whitespace so "Foo, VaapiVideoDecoder" is handled too.
      t="${t#"${t%%[![:space:]]*}"}"
      t="${t%"${t##*[![:space:]]}"}"
      [[ -z "$t" ]] && continue
      legacy=false
      for tok in "${LEGACY_FEATURE_TOKENS[@]}"; do
        # Exact token match only: VaapiVideoDecoderFoo is NOT purged.
        [[ "$t" == "$tok" ]] && legacy=true && break
      done
      [[ "$legacy" == false ]] && keep+=("$t")
    done
    if (( ${#keep[@]} == 0 )); then
      return 1
    fi
    local joined
    joined="$(IFS=,; printf '%s' "${keep[*]}")"
    printf '%s=%s\n' "$head" "$joined"
    return 0
  fi

  for tok in "${LEGACY_FEATURE_TOKENS[@]}"; do
    [[ "$line" == "$tok" ]] && return 1
  done

  printf '%s\n' "$line"
  return 0
}

# ---- Power-management ownership (v15.2) ------------------------------------
# Explicit ownership model. At runtime we detect the three managers that can
# own overlapping knobs on this machine and report them once per run:
#   * TLP        -> CPU EPP, platform profile, USB autosuspend, audio power
#                   save, ASUS charge thresholds (tlp setcharge) when active.
#   * power-profiles-daemon -> desktop power profile; helpers already delegate
#                   to it via powerprofilesctl when it is active. (Kept.)
#   * thermald   -> thermal policy; left alone deliberately.
# Gated steps consult tlp_gate(); read-only paths never consult it.
TLP_PRESENT=false
TLP_ACTIVE=false
TLP_VERSION=""
PPD_ACTIVE=false
THERMALD_ACTIVE=false

detect_power_managers() {
  TLP_PRESENT=false; TLP_ACTIVE=false; TLP_VERSION=""
  PPD_ACTIVE=false; THERMALD_ACTIVE=false
  if command -v systemctl >/dev/null 2>&1; then
    if command systemctl list-unit-files tlp.service 2>/dev/null | grep -qE '^tlp\.service'; then
      TLP_PRESENT=true
      command systemctl is-active --quiet tlp.service 2>/dev/null && TLP_ACTIVE=true
    fi
    command systemctl is-active --quiet power-profiles-daemon.service 2>/dev/null && PPD_ACTIVE=true
    command systemctl is-active --quiet thermald.service 2>/dev/null && THERMALD_ACTIVE=true
  fi
  # TLP installed but unit missing (e.g. unbooted container): still report it.
  if [[ "$TLP_PRESENT" == false && -r /etc/default/tlp ]]; then
    TLP_PRESENT=true
  fi
  if [[ "$TLP_PRESENT" == true ]]; then
    TLP_VERSION="$(dpkg-query -W -f='${Version}' tlp 2>/dev/null || true)"
  fi
  return 0
}

# Call before any script-initiated write to a TLP-owned domain.
# Returns 0 = proceed, 1 = skip (reason already printed).
tlp_gate() {
  if [[ "$TLP_ACTIVE" == true && "$FORCE_TLP_OVERRIDE" != true ]]; then
    echo "   SKIPPED ($1): TLP is active and owns this domain — not fighting it."
    echo "     Configure via TLP instead, or re-run with --force-tlp-override."
    return 1
  fi
  return 0
}

apply_browser_flags_for_user() {
  local u_name="$1" u_uid="$2" u_gid="$3" u_home="$4"
  local cfg_dir="${u_home}/.config"
  if [[ ! -d "$cfg_dir" ]]; then
    install -d -m 0755 -o "$u_uid" -g "$u_gid" "$cfg_dir"
  fi

  local wrote=0 not_installed=0 preserved=0

  # Helper to write flags to a given file with merge logic.
  # Returns 0 when the file was written, 1 when it was deliberately preserved
  # (an unmanaged file that pins a different value for a managed flag).
  _write_flags_file() {
    local target="$1"
    local existing_lines=()
    if [[ -f "$target" ]]; then
      while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        existing_lines+=("$line")
      done < "$target"
    fi

    # v15.3 (I-26): before the FIRST managed write, respect a user-pinned value
    # for a flag this script manages. When the file is unmanaged and pins a
    # different value (e.g. --ozone-platform-hint=x11 instead of auto), leave
    # the file alone entirely: --restore-defaults could never bring the user's
    # own value back, so the write must not happen in the first place.
    if [[ -f "$target" ]] && ! is_managed_file "$target"; then
      local mf key pinned
      for mf in "${MANAGED_BROWSER_FLAGS[@]}"; do
        key="${mf%%=*}"
        pinned="$(grep -E "^[[:space:]]*${key}=" "$target" 2>/dev/null |
                    grep -v -E "^[[:space:]]*${mf}[[:space:]]*$" | head -1 || true)"
        if [[ -n "$pinned" ]]; then
          echo "   NOTE: $target is not script-managed and pins '${pinned//[[:space:]]/}'."
          echo "   NOTE: it was left untouched — your explicit browser value is preserved."
          return 1
        fi
      done
    fi

    local new_lines=() filtered
    for line in "${existing_lines[@]}"; do
      [[ "$line" =~ ^[[:space:]]*#[[:space:]]*Managed\ by\ vivobook_optimize ]] && continue
      [[ -z "$line" ]] && continue
      # Token-aware purge: drops managed + legacy lines and strips legacy
      # tokens out of --enable-features/--disable-features lists.
      if filtered="$(filter_browser_flag_line "$line")"; then
        new_lines+=("$filtered")
      fi
    done

    local content="# Managed by vivobook_optimize.sh v15.3 --with-browser-wayland"$'\n'
    for nl in "${new_lines[@]}"; do
      content+="$nl"$'\n'
    done
    for mf in "${MANAGED_BROWSER_FLAGS[@]}"; do
      content+="$mf"$'\n'
    done

    atomic_write "$target" 0644 <<< "$content"
    chown "${u_uid}:${u_gid}" "$target"
    return 0
  }

  # v15.3 (I-27): only write a flags file when the matching browser is
  # actually installed; a stale file for an uninstalled browser is noise that
  # --restore-defaults then has to clean up.
  local b_file
  for b_file in brave-flags.conf chrome-flags.conf chromium-flags.conf; do
    local target="${cfg_dir}/${b_file}" browser=""
    case "$b_file" in
      brave-flags.conf)    browser=brave ;;
      chrome-flags.conf)   browser=chrome ;;
      chromium-flags.conf) browser=chromium ;;
    esac
    if ! browser_installed "$browser"; then
      not_installed=$((not_installed + 1))
      continue
    fi
    if _write_flags_file "$target"; then
      wrote=$((wrote + 1))
    else
      preserved=$((preserved + 1))
    fi
  done

  # Chromium Snap path (Ubuntu Snap package)
  local snap_chromium_dir="${u_home}/snap/chromium/common"
  if [[ -d "$snap_chromium_dir" ]] && browser_installed chromium; then
    local snap_target="${snap_chromium_dir}/chromium-flags.conf"
    if _write_flags_file "$snap_target"; then
      wrote=$((wrote + 1))
    else
      preserved=$((preserved + 1))
    fi
  fi

  # v15.3 (I-27): one honest per-user line instead of a blanket "written".
  echo "   $u_name: browser flag files written=$wrote, not-installed=$not_installed, user-pinned-preserved=$preserved"
}

restore_browser_flags_for_user() {
  local u_name="$1" u_uid="$2" u_gid="$3" u_home="$4"
  local cfg_dir="${u_home}/.config"
  [[ -d "$cfg_dir" ]] || return 0

  # Helper to restore a flags file (remove managed entries)
  _restore_flags_file() {
    local target="$1"
    [[ -f "$target" ]] || return 0
    grep -q "Managed by vivobook_optimize" "$target" 2>/dev/null || return 0

    local remaining=() filtered
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line%$'\r'}"
      [[ "$line" =~ ^[[:space:]]*#[[:space:]]*Managed\ by\ vivobook_optimize ]] && continue
      [[ -z "$line" ]] && continue
      # Same token-aware purge as the write path: legacy tokens are stripped
      # out of feature lists; unrelated user flags and features stay.
      if filtered="$(filter_browser_flag_line "$line")"; then
        remaining+=("$filtered")
      fi
    done < "$target"

    local has_real_content=false
    for rl in "${remaining[@]}"; do
      if [[ -n "$rl" && ! "$rl" =~ ^[[:space:]]*# ]]; then
        has_real_content=true
        break
      fi
    done

    if [[ "$has_real_content" == true ]]; then
      local content=""
      for rl in "${remaining[@]}"; do
        content+="$rl"$'\n'
      done
      atomic_write "$target" 0644 <<< "$content"
      chown "${u_uid}:${u_gid}" "$target"
    else
      rm -f "$target"
    fi
  }

  local b_file
  for b_file in brave-flags.conf chrome-flags.conf chromium-flags.conf; do
    local target="${cfg_dir}/${b_file}"
    _restore_flags_file "$target"
  done

  # Snap Chromium
  local snap_chromium_dir="${u_home}/snap/chromium/common"
  if [[ -d "$snap_chromium_dir" ]]; then
    local snap_target="${snap_chromium_dir}/chromium-flags.conf"
    _restore_flags_file "$snap_target"
  fi
}

restore_defaults() {
  echo "== Restoring ASUS Vivobook v15.3 managed defaults =="
  local unit
  for unit in \
    powertop-autotune.service \
    battery-charge-threshold.service \
    asus-thermal-profile.service \
    intel-epp-profile.service \
    vivobook-power-switch.service \
    rapl-power-limits.service \
    vivobook-kbd-timeout.service \
    system-maintenance.service \
    system-maintenance.timer
  do
    systemctl disable --now "$unit" >/dev/null 2>&1 || true
    rm -f "/etc/systemd/system/$unit"
  done
  systemctl disable --now zramswap.service >/dev/null 2>&1 || true

  # Transient runtime lock files created by the v13/v15.1 helpers. Safe to
  # remove while helpers are stopped; /run is tmpfs anyway. The main
  # /run/vivobook-optimize.lock is deliberately kept: it is actively held by
  # this run to block concurrent instances.
  rm -f /run/vivobook-power-switch.lock
  rm -f /run/system-maintenance.lock

  rm -f /usr/local/bin/system-maintenance.sh
  rm -f /usr/local/bin/set-battery-threshold.sh
  rm -f /usr/local/bin/set-asus-thermal-profile.sh
  rm -f /usr/local/bin/set-intel-epp.sh
  rm -f /usr/local/bin/vivobook-power-switch.sh
  rm -f /usr/local/bin/set-rapl-limits.sh
  rm -f /usr/local/bin/vivobook-kbd-timeout.sh
  rm -f /usr/lib/systemd/system-sleep/vivobook-battery
  rm -f /usr/lib/systemd/system-sleep/vivobook-thermal-profile
  rm -f /usr/lib/systemd/system-sleep/vivobook-intel-epp
  rm -f /usr/lib/systemd/system-sleep/vivobook-kbd-timeout

  rm -f /etc/default/vivobook-battery
  rm -f /etc/default/vivobook-thermal-profile
  rm -f /etc/default/vivobook-epp
  rm -f /etc/default/vivobook-rapl
  remove_managed_config /etc/default/zramswap
  remove_managed_config /etc/systemd/zram-generator.conf

  # v15.3 (I-07): removing the generator config does not detach an already
  # live /dev/zram0 swap device, and step 16 already knows this matters. Do it
  # here too, so 'swapon --show' does not keep listing a stale zram device
  # after a restore. The detach is guarded and reports failure instead of
  # swallowing it.
  if [[ -e /dev/zram0 ]] || systemctl is-active --quiet systemd-zram-setup@zram0.service 2>/dev/null; then
    systemctl stop systemd-zram-setup@zram0.service >/dev/null 2>&1 || true
    if [[ -e /dev/zram0 ]]; then
      if ! swapoff /dev/zram0 2>/dev/null; then
        echo "   WARNING: could not detach /dev/zram0 — it may still be active swap." >&2
        echo "   WARNING: check 'swapon --show' and detach it manually when it is free." >&2
      fi
    fi
  fi

  # v15.3 (I-08): remember whether this script installed the BBR sysctl.
  # Removing a sysctl.d file does not reset the live value, and the BBR
  # default_qdisc/tcp_congestion_control pair is exactly that case.
  BBR_CONF_WAS_MANAGED=false
  if is_managed_file /etc/sysctl.d/98-network-bbr.conf; then
    BBR_CONF_WAS_MANAGED=true
  fi

  remove_managed_config /etc/sysctl.d/99-vivobook.conf
  remove_managed_config /etc/sysctl.d/98-network-bbr.conf
  remove_managed_config /etc/modules-load.d/bbr.conf
  remove_managed_config /etc/modprobe.d/audio-powersave.conf

  # v15.3 (I-03): the MediaTek MT7902 needs 'options mt7921e disable_aspm=1'
  # for link stability on this platform. Removing it is the documented
  # rollback, but it re-exposes Wi-Fi to the disconnects/packet loss the
  # workaround exists to prevent — so say so loudly.
  if is_managed_file "$MT7921E_CONF"; then
    echo "   WARNING: removing $MT7921E_CONF (mt7921e disable_aspm=1)." >&2
    echo "   WARNING: Wi-Fi link stability on the MT7902 REQUIRES this workaround on this" >&2
    echo "   WARNING: platform. Expect disconnects and packet loss until it is restored with" >&2
    echo "   WARNING:   sudo bash $SCRIPT_PATH --with-mt7921e-aspm" >&2
  fi
  remove_managed_config "$MT7921E_CONF"

  restore_iwlwifi_conf
  remove_i915_conf
  # Rollback integrity: if a stale i915 conf was still present, purge its
  # deprecated parameters from the boot images as well.
  if [[ "$I915_CONF_REMOVED" == true ]]; then
    if command -v update-initramfs >/dev/null 2>&1; then
      echo "   Rebuilding initramfs images to purge deprecated i915 parameters..."
      update-initramfs -u -k all ||
        echo "   WARNING: update-initramfs -u -k all failed." >&2
    else
      echo "   NOTE: deprecated i915 parameters may remain staged in existing"
      echo "   initramfs images; rebuild the initramfs with your distro tool."
    fi
  elif [[ "$DRY_RUN" == true && -e "$I915_CONF" ]]; then
    echo "[DRY-RUN] Would rebuild initramfs images after removing the deprecated"
    echo "[DRY-RUN] i915 parameters above (update-initramfs -u -k all)."
  fi

  remove_managed_config /etc/wireplumber/wireplumber.conf.d/50-alsa-powersave.conf
  remove_managed_config /etc/wireplumber/main.lua.d/50-alsa-powersave.lua

  # Remove udev rules
  rm -f /etc/udev/rules.d/99-vivobook-power.rules
  rm -f /etc/udev/rules.d/99-vivobook-nvme.rules
  rm -f /etc/udev/rules.d/99-usb-autosuspend.rules

  # Remove environment.d snippet
  remove_managed_config /etc/environment.d/99-vivobook-vaapi.conf

  # Restore power-profiles-daemon if masked by this script
  if [[ -f /etc/default/vivobook-ppd-state ]]; then
    local PPD_WAS_PRESENT="false" PPD_WAS_ACTIVE="false" PPD_WAS_ENABLED="false" PPD_WAS_MASKED="false"
    # shellcheck disable=SC1091
    . /etc/default/vivobook-ppd-state 2>/dev/null || true
    if [[ "$PPD_WAS_PRESENT" == "true" ]]; then
      if [[ "$PPD_WAS_MASKED" == "false" ]]; then
        systemctl unmask power-profiles-daemon.service >/dev/null 2>&1 || true
        if [[ "$PPD_WAS_ENABLED" == "true" ]]; then
          systemctl enable power-profiles-daemon.service >/dev/null 2>&1 || true
        fi
        if [[ "$PPD_WAS_ACTIVE" == "true" ]]; then
          systemctl start power-profiles-daemon.service >/dev/null 2>&1 || true
        fi
      fi
    fi
    rm -f /etc/default/vivobook-ppd-state
  fi

  # Restore user browser flags
  while IFS=: read -r U_NAME _ U_UID U_GID _ U_HOME U_SHELL; do
    [[ "$U_UID" =~ ^[0-9]+$ ]] || continue
    (( U_UID >= 1000 && U_UID < 65000 )) || continue
    case "$U_SHELL" in
      */nologin|*/false|"") continue ;;
    esac
    [[ -n "$U_HOME" && -d "$U_HOME" ]] || continue
    restore_browser_flags_for_user "$U_NAME" "$U_UID" "$U_GID" "$U_HOME"
  done < /etc/passwd

  # Restore original CPU turbo state.
  # LEGACY (pre-v15 installs only, I-32): no v15.x code path writes
  # /etc/default/vivobook-pstate-defaults. The branch is kept so a machine
  # still carrying the file from an older release can restore no_turbo.
  if [[ -f /etc/default/vivobook-pstate-defaults ]]; then
    local ORIG_NO_TURBO=""
    # shellcheck disable=SC1091
    . /etc/default/vivobook-pstate-defaults 2>/dev/null || true
    if [[ -n "$ORIG_NO_TURBO" && -w /sys/devices/system/cpu/intel_pstate/no_turbo ]]; then
      if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] Restore intel_pstate/no_turbo to $ORIG_NO_TURBO"
      else
        { printf '%s\n' "$ORIG_NO_TURBO" > /sys/devices/system/cpu/intel_pstate/no_turbo; } 2>/dev/null || true
      fi
    fi
    rm -f /etc/default/vivobook-pstate-defaults
  fi

  # Remove the dynamic battery frequency ceiling independently of the saved
  # no_turbo baseline (also covers upgrades from earlier installs). This part
  # is deliberately NOT tied to a save file: 100% is a fixed baseline, so it
  # is applied unconditionally where the node is writable.
  if [[ -e /sys/devices/system/cpu/intel_pstate/max_perf_pct &&
        -w /sys/devices/system/cpu/intel_pstate/max_perf_pct ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      echo "[DRY-RUN] Restore intel_pstate/max_perf_pct to 100"
    else
      { printf '%s\n' 100 > /sys/devices/system/cpu/intel_pstate/max_perf_pct; } 2>/dev/null || true
    fi
  fi

  # Restore iGPU frequencies to hardware baseline.
  # LEGACY (pre-v15 installs only, I-32): no v15.x code path writes
  # /etc/default/vivobook-igpu-defaults. Kept so a machine still carrying the
  # file from an older release can roll back those frequency writes. On the
  # reference X1605VA the iGPU is driven by xe + GuC SLPC, and the xe freq0
  # nodes are read-only, so this branch cannot write there anyway.
  if [[ -f /etc/default/vivobook-igpu-defaults ]]; then
    local IGPU_CARD="" IGPU_DEFAULT_MAX_MHZ="" IGPU_DEFAULT_BOOST_MHZ=""
    # shellcheck disable=SC1091
    . /etc/default/vivobook-igpu-defaults 2>/dev/null || true
    if [[ -n "$IGPU_CARD" && -d "$IGPU_CARD" ]]; then
      local freq_info
      freq_info="$(find_igpu_freq_files "$IGPU_CARD" || true)"
      if [[ -n "$freq_info" ]]; then
        local max_f boost_f rp0_f rpn_f
        read -r max_f boost_f rp0_f rpn_f <<< "$freq_info"
        if [[ -n "$max_f" && -w "$max_f" && -n "$IGPU_DEFAULT_MAX_MHZ" ]]; then
          if [[ "$DRY_RUN" == true ]]; then
            echo "[DRY-RUN] Restore $max_f to $IGPU_DEFAULT_MAX_MHZ"
          else
            { printf '%s\n' "$IGPU_DEFAULT_MAX_MHZ" > "$max_f"; } 2>/dev/null || true
          fi
        fi
        if [[ -n "$boost_f" && -w "$boost_f" && -n "$IGPU_DEFAULT_BOOST_MHZ" ]]; then
          if [[ "$DRY_RUN" == true ]]; then
            echo "[DRY-RUN] Restore $boost_f to $IGPU_DEFAULT_BOOST_MHZ"
          else
            { printf '%s\n' "$IGPU_DEFAULT_BOOST_MHZ" > "$boost_f"; } 2>/dev/null || true
          fi
        fi
      fi
    fi
    rm -f /etc/default/vivobook-igpu-defaults
  fi

  # Reload udev after removing rules
  if command -v udevadm &>/dev/null; then
    udevadm control --reload-rules 2>/dev/null || true
  fi

  # v15.3 (I-09): count what actually happened. The old unconditional success
  # message printed even when the glob matched nothing or every write failed.
  local BAT_RESTORE_TOTAL=0 BAT_RESTORE_OK=0
  for f in /sys/class/power_supply/BAT*/charge_control_end_threshold; do
    [[ -e "$f" ]] || continue
    BAT_RESTORE_TOTAL=$((BAT_RESTORE_TOTAL + 1))
    [[ -w "$f" ]] || continue
    if [[ "$DRY_RUN" == true ]]; then
      echo "[DRY-RUN] Restore $f to 100"
      BAT_RESTORE_OK=$((BAT_RESTORE_OK + 1))
    elif { printf '%s\n' 100 > "$f"; } 2>/dev/null; then
      BAT_RESTORE_OK=$((BAT_RESTORE_OK + 1))
    fi
  done

  systemctl daemon-reload
  # Removing a sysctl.d file does not reset a live value that the remaining
  # configuration does not mention. Reset to Linux's 500-centisecond baseline
  # FIRST, then let the remaining distro/admin sysctl configuration override it.
  # No new /etc/default state file is needed: never save a tuned 1500/6000 value
  # as a supposed distro default when upgrading an existing installation.
  if [[ -e /proc/sys/vm/dirty_writeback_centisecs &&
        -w /proc/sys/vm/dirty_writeback_centisecs ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      echo "[DRY-RUN] Restore vm.dirty_writeback_centisecs baseline to 500 before distro sysctls"
    else
      { printf '%s\n' 500 > /proc/sys/vm/dirty_writeback_centisecs; } 2>/dev/null || true
    fi
  fi
  # Removing a sysctl.d file does not reset a live value; zram-tools previously
  # pushed vm.swappiness to 100. Reset to the Linux default of 60 as well.
  if [[ -e /proc/sys/vm/swappiness && -w /proc/sys/vm/swappiness ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      echo "[DRY-RUN] Restore vm.swappiness baseline to 60 before distro sysctls"
    else
      { echo 60 > /proc/sys/vm/swappiness; } 2>/dev/null || true
    fi
  fi
  # v15.3 (I-08): the same reasoning as writeback/swappiness above applies to
  # the BBR pair. Put tcp_congestion_control back to the kernel's cubic default
  # when this script installed it. default_qdisc is deliberately NOT forced —
  # its baseline varies between distros and kernels.
  if [[ "$BBR_CONF_WAS_MANAGED" == true ]]; then
    if [[ -e /proc/sys/net/ipv4/tcp_congestion_control &&
          -w /proc/sys/net/ipv4/tcp_congestion_control ]]; then
      if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] Restore net.ipv4.tcp_congestion_control baseline to cubic before distro sysctls"
      else
        { printf '%s\n' cubic > /proc/sys/net/ipv4/tcp_congestion_control; } 2>/dev/null || true
      fi
    fi
  fi
  command -v sysctl >/dev/null 2>&1 && sysctl --system >/dev/null 2>&1 || true
  echo "Managed configuration removed."
  if (( BAT_RESTORE_OK > 0 )); then
    echo "Battery charge limit: restored to 100% on ${BAT_RESTORE_OK} of ${BAT_RESTORE_TOTAL} batteries."
  elif (( BAT_RESTORE_TOTAL == 0 )); then
    echo "Battery charge limit: no charge_control_end_threshold attribute found; nothing to restore."
  else
    echo "WARNING: battery charge limit could not be restored on any of the ${BAT_RESTORE_TOTAL} battery attribute(s) found." >&2
  fi
  echo "CPU max_perf_pct reset to 100 where writable; swappiness, writeback and (when BBR was managed) tcp_congestion_control reset, then distro sysctls reapplied."
  echo "Reboot to reset remaining live module, RAPL, and other hardware settings."
  echo "No apt packages were removed."
}

log_summary() {
  if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY-RUN] Append v15.3 run summary to /var/log/vivobook-optimize.log"
    return 0
  fi
  local reboot=no
  [[ -e /var/run/reboot-required ]] && reboot=yes
  printf '%s flags="%s" reboot_required=%s\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" "$*" "$reboot" \
    >> /var/log/vivobook-optimize.log
}

package_has_candidate() {
  local candidate
  candidate="$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print $2; exit}')"
  [[ -n "$candidate" && "$candidate" != "(none)" ]]
}

show_status_dashboard() {
  local found=false f value driver timer_state timer_next
  local guc_lines va_output va_driver card wp_ver

  echo "===================================================="
  echo "ASUS Vivobook Optimization v15.3 — System Status"
  echo "Generated: $(date)"
  echo "Script: $SCRIPT_NAME version $SCRIPT_VERSION (JSON schema $SCRIPT_SCHEMA)"
  echo "===================================================="

  # ---- Machine identity and boot integrity (v15.3, I-19) -------------------
  echo
  echo "[Firmware]"
  printf '  %-22s %s\n' "Product:" "$(status_value /sys/class/dmi/id/product_name)"
  printf '  %-22s %s\n' "Board:" "$(status_value /sys/class/dmi/id/board_name)"
  printf '  %-22s %s\n' "BIOS version:" "$(status_value /sys/class/dmi/id/bios_version)"
  printf '  %-22s %s\n' "BIOS date:" "$(status_value /sys/class/dmi/id/bios_date)"

  echo
  echo "[Boot integrity]"
  case "$(secure_boot_state)" in
    enabled)  echo "  Secure Boot:            enabled (mokutil/efivarfs)" ;;
    disabled) echo "  Secure Boot:            disabled (mokutil/efivarfs)" ;;
    *)        echo "  Secure Boot:            unavailable (install mokutil for a definitive answer)" ;;
  esac
  case "$(signing_hook_state)" in
    present-executable)
      echo "  Kernel signing hook:    present and executable ($SIGNING_HOOK)"
      ;;
    present-not-executable)
      echo "  Kernel signing hook:    PRESENT BUT NOT EXECUTABLE ($SIGNING_HOOK)"
      ;;
    *)
      echo "  Kernel signing hook:    absent ($SIGNING_HOOK)"
      ;;
  esac
  case "$(running_kernel_signature_state)" in
    signed-by-vivobook-key)
      echo "  Running kernel:         signed by CN=Vivobook Kernel Key (/boot/vmlinuz-$(uname -r))"
      ;;
    signed-by-other)
      echo "  Running kernel:         signed, but NOT by CN=Vivobook Kernel Key"
      ;;
    unsigned)
      echo "  Running kernel:         has no readable signature (sbverify --list failed)"
      ;;
    file-missing)
      echo "  Running kernel:         /boot/vmlinuz-$(uname -r) not found"
      ;;
    *)
      echo "  Running kernel:         sbverify not installed; skipping signature check"
      ;;
  esac

  echo
  echo "[Kernel source pin]"
  if [[ -f "$STOCK_KERNEL_PREF" ]]; then
    if stock_kernel_pin_blocks; then
      echo "  $STOCK_KERNEL_PREF: present and blocking the stock kernel meta-packages"
    else
      echo "  $STOCK_KERNEL_PREF: present, but no negative Pin-Priority for a linux package was found"
    fi
  else
    echo "  $STOCK_KERNEL_PREF: absent (stock kernels are not pinned)"
  fi

  echo
  echo "[Kernel cmdline]"
  printf '  %-22s %s\n' "Active DRM driver:" "$(detect_active_drm_driver)"
  found=false
  for token in $(cat /proc/cmdline 2>/dev/null || true); do
    case "$token" in
      i915.force_probe=*|xe.force_probe=*|i915.enable_guc=*|pcie_aspm.policy=*)
        printf '  %-22s %s\n' "cmdline token:" "$token"
        found=true
        ;;
    esac
  done
  if [[ "$found" == false ]]; then
    echo "  No i915/xe force-probe or pcie_aspm.policy token in /proc/cmdline."
  fi

  echo
  echo "[Power-management ownership (v15.3)]"
  detect_power_managers
  printf '  TLP:        present=%s active=%s%s\n' "$TLP_PRESENT" "$TLP_ACTIVE" "${TLP_VERSION:+ (version $TLP_VERSION)}"
  echo "  power-profiles-daemon active: $PPD_ACTIVE"
  echo "  thermald active: $THERMALD_ACTIVE"
  if [[ "$TLP_ACTIVE" == true && "$FORCE_TLP_OVERRIDE" != true ]]; then
    echo "  Policy gates: script-side power writes are SKIPPED (TLP owns those domains)"
  elif [[ "$TLP_ACTIVE" == true ]]; then
    echo "  Policy gates: OVERRIDE in effect — script writes despite active TLP"
  else
    echo "  Policy gates: no active TLP — script may own power-policy writes"
  fi

  echo
  echo "[Battery charge end threshold]"
  found=false
  for f in /sys/class/power_supply/BAT*/charge_control_end_threshold; do
    [[ -e "$f" ]] || continue
    found=true
    printf '  %-12s %s%%\n' \
      "$(basename "$(dirname "$f")")" \
      "$(status_value "$f")"
  done
  if [[ "$found" == false ]]; then
    echo "  Unsupported or no battery threshold attribute found."
  fi
  if systemctl is-enabled --quiet battery-charge-threshold.service 2>/dev/null; then
    echo "  Persistent service: enabled"
  else
    echo "  Persistent service: disabled/not installed"
  fi
  if [[ -x /usr/lib/systemd/system-sleep/vivobook-battery ]]; then
    echo "  Resume re-apply hook: present (/usr/lib/systemd/system-sleep/vivobook-battery)"
  else
    echo "  Resume re-apply hook: absent"
  fi

  echo
  echo "[Battery health]"
  found=false
  while IFS=$'\t' read -r bh_name bh_full bh_design bh_cycles bh_health; do
    [[ -n "$bh_name" ]] || continue
    found=true
    printf '  %-12s charge_full=%s  charge_full_design=%s (uAh)  cycles=%s  health=%s\n' \
      "$bh_name" "$bh_full" "$bh_design" "$bh_cycles" "$bh_health"
  done < <(battery_health_rows)
  if [[ "$found" == false ]]; then
    echo "  No battery devices found."
  fi
  echo "  (Direct sysfs readings; a healthy design-cycle wear figure is normal on"
  echo "   a used laptop. charge_full vs charge_full_design is the health estimate.)"

  echo
  echo "[ACPI / ASUS thermal profile]"
  local pp_node pp_found=false
  for pp_node in /sys/class/platform_profile/*/profile; do
    [[ -r "$pp_node" ]] || continue
    pp_found=true
    echo "  Interface: $pp_node"
    echo "  Active:    $(status_value "$pp_node")"
    if [[ -r "$(dirname "$pp_node")/choices" ]]; then
      echo "  Choices:   $(status_value "$(dirname "$pp_node")/choices")"
    fi
  done
  if [[ "$pp_found" == false ]]; then
    if [[ -r /sys/firmware/acpi/platform_profile ]]; then
      echo "  Interface: /sys/firmware/acpi/platform_profile"
      echo "  Active:    $(status_value /sys/firmware/acpi/platform_profile)"
      if [[ -r /sys/firmware/acpi/platform_profile_choices ]]; then
        echo "  Choices:   $(status_value /sys/firmware/acpi/platform_profile_choices)"
      fi
    elif [[ -r /sys/devices/platform/asus-nb-wmi/throttle_thermal_policy ]]; then
      value="$(status_value /sys/devices/platform/asus-nb-wmi/throttle_thermal_policy)"
      case "$value" in
        0) value="balanced (0)" ;;
        1) value="performance (1)" ;;
        2) value="quiet (2)" ;;
      esac
      echo "  Interface: ASUS throttle_thermal_policy"
      echo "  Active:    $value"
    else
      echo "  No supported profile interface found."
    fi
  fi
  if systemctl is-enabled --quiet asus-thermal-profile.service 2>/dev/null; then
    echo "  Persistent service: enabled"
  else
    echo "  Persistent service: disabled/not installed"
  fi

  echo
  echo "[Intel P-State / Dynamic Turbo / EPP]"
  driver="$(status_value /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver)"
  echo "  Scaling driver: $driver"
  if [[ -r /sys/devices/system/cpu/intel_pstate/status ]]; then
    echo "  intel_pstate status: $(status_value /sys/devices/system/cpu/intel_pstate/status)"
  fi
  if [[ -r /sys/devices/system/cpu/intel_pstate/no_turbo ]]; then
    local noturbo
    noturbo="$(status_value /sys/devices/system/cpu/intel_pstate/no_turbo)"
    if [[ "$noturbo" == "0" ]]; then
      echo "  Turbo state: enabled (no_turbo=0)"
    elif [[ "$noturbo" == "1" ]]; then
      echo "  Turbo state: disabled (no_turbo=1)"
    else
      echo "  Turbo state: no_turbo=$noturbo"
    fi
  else
    echo "  intel_pstate no_turbo interface: unavailable"
  fi

  echo "  max_perf_pct: $(status_value /sys/devices/system/cpu/intel_pstate/max_perf_pct)"

  declare -A EPP_COUNTS=()
  found=false
  for f in /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference; do
    [[ -r "$f" ]] || continue
    found=true
    value="$(cat "$f" 2>/dev/null || echo unknown)"
    EPP_COUNTS["$value"]=$(( ${EPP_COUNTS["$value"]:-0} + 1 ))
  done
  if [[ "$found" == true ]]; then
    for value in "${!EPP_COUNTS[@]}"; do
      echo "  EPP '$value': ${EPP_COUNTS[$value]} CPU(s)"
    done
  else
    echo "  No energy_performance_preference nodes found."
  fi
  if systemctl is-enabled --quiet intel-epp-profile.service 2>/dev/null; then
    echo "  Persistent service: enabled"
  else
    echo "  Persistent service: disabled/not installed"
  fi

  echo
  echo "[Power coherence]"
  local coh_ppd coh_th coh_epp coh_note
  coh_ppd="$(ppd_current_profile)"
  coh_th="$(ppd_profile_for_thermal "${FAN_PROFILE:-}")"
  coh_epp="$(ppd_profile_for_epp "${EPP_PROFILE:-}")"
  echo "  power-profiles-daemon now: $coh_ppd"
  if [[ -n "$FAN_PROFILE" ]]; then
    echo "  Requested thermal profile: $FAN_PROFILE -> PPD '$coh_th'"
  else
    echo "  Requested thermal profile: not requested this run"
  fi
  if [[ -n "$EPP_PROFILE" ]]; then
    echo "  Requested CPU EPP:         $EPP_PROFILE -> PPD '$coh_epp'"
  else
    echo "  Requested CPU EPP:         not requested this run"
  fi
  coh_note="not requested"
  if [[ -n "$FAN_PROFILE" && -n "$EPP_PROFILE" ]]; then
    if [[ "$coh_th" == "$coh_epp" ]]; then
      coh_note="agree (both map to PPD '$coh_th')"
    else
      coh_note="MISMATCH (thermal wants '$coh_th', EPP wants '$coh_epp')"
    fi
  elif [[ -n "$FAN_PROFILE" ]]; then
    coh_note="thermal only ('$coh_th')"
  elif [[ -n "$EPP_PROFILE" ]]; then
    coh_note="EPP only ('$coh_epp')"
  fi
  echo "  Agreement:                 $coh_note"
  echo "  (PPD holds exactly one profile. --fan-profile and --epp are refused at"
  echo "   parse time when they would demand two different PPD profiles.)"

  echo
  echo "[Modern Standby (S2idle) / Package C-states]"
  if [[ -r /sys/power/mem_sleep ]]; then
    local mem_sleep
    mem_sleep="$(status_value /sys/power/mem_sleep)"
    echo "  mem_sleep:         $mem_sleep"
    if [[ "$mem_sleep" == *"[s2idle]"* ]]; then
      echo "  Active mode:       s2idle (Modern Standby / S0ix) — expected on this platform"
    elif [[ "$mem_sleep" == *"[deep]"* ]]; then
      echo "  Active mode:       deep (S3) — not natively supported on X1605VA; this platform is Modern Standby (S0ix/s2idle) only"
    else
      echo "  Active mode:       unknown/other"
    fi
  else
    echo "  /sys/power/mem_sleep: unavailable"
  fi
  local pmc_dir=/sys/kernel/debug/pmc_core
  if [[ -r "$pmc_dir/package_cstate_show" ]]; then
    local pc8 pc10
    pc8="$(awk -F: '/Package C8/ {gsub(/^[ \t]+/, "", $2); print $2}' "$pmc_dir/package_cstate_show" 2>/dev/null || true)"
    pc10="$(awk -F: '/Package C10/ {gsub(/^[ \t]+/, "", $2); print $2}' "$pmc_dir/package_cstate_show" 2>/dev/null || true)"
    echo "  PC8 residency:     ${pc8:-not reported}"
    echo "  PC10 residency:    ${pc10:-not reported}"
    if [[ -n "$pc10" && "$pc10" != "0" ]]; then
      echo "  Deep C-states:     PC10 reached (deep package idle is working)"
    elif [[ -n "$pc8" && "$pc8" != "0" ]]; then
      echo "  Deep C-states:     PC8 reached, PC10 never entered (check ASPM/USB/audio wakeups)"
    elif aspm_workaround_active; then
      echo "  Deep C-states:     neither PC8 nor PC10 reached — EXPECTED: the mt7921e"
      echo "                     ASPM workaround (disable_aspm=1) blocks the deep package"
      echo "                     idle paths on this platform. Not a fault; do not chase"
      echo "                     ASPM here."
    else
      echo "  Deep C-states:     neither PC8 nor PC10 reached since boot"
    fi
  elif [[ -d "$pmc_dir" ]]; then
    echo "  pmc_core:          present but package_cstate_show not readable (run as root)"
  elif [[ -d /sys/kernel/debug ]] && [[ ! -r /sys/kernel/debug/pmc_core ]] && (( EUID != 0 )); then
    echo "  pmc_core:          debugfs requires root to read C-state residency"
  else
    echo "  pmc_core:          not available (intel_pmc_core not loaded or debugfs unmounted)"
  fi
  if [[ -r "$pmc_dir/slp_s0_residency_usec" ]]; then
    echo "  SLP_S0 residency:  $(status_value "$pmc_dir/slp_s0_residency_usec") usec"
  fi
  if [[ -r /sys/devices/system/cpu/cpuidle/current_driver ]]; then
    echo "  cpuidle driver:    $(status_value /sys/devices/system/cpu/cpuidle/current_driver)"
  fi

  echo
  echo "[Intel UHD / Iris iGPU Frequency]"
  echo "  Active DRM driver: $(detect_active_drm_driver)"
  card="$(find_intel_drm_card || true)"
  if [[ -n "$card" ]]; then
    echo "  Detected Intel DRM device: $(basename "$card") ($card)"
    local max_f="unavailable" boost_f="unavailable" rp0_f="unavailable" rpn_f="unavailable" cur_f="unavailable"
    local freq_info
    freq_info="$(find_igpu_freq_files "$card" || true)"
    if [[ -n "$freq_info" ]]; then
      read -r max_f boost_f rp0_f rpn_f <<< "$freq_info"
      if [[ -r "$(dirname "$max_f")/rps_cur_freq_mhz" ]]; then
        cur_f="$(cat "$(dirname "$max_f")/rps_cur_freq_mhz" 2>/dev/null || echo unknown)"
      elif [[ -r "$(dirname "$max_f")/gt_cur_freq_mhz" ]]; then
        cur_f="$(cat "$(dirname "$max_f")/gt_cur_freq_mhz" 2>/dev/null || echo unknown)"
      fi
      max_f="$(cat "$max_f" 2>/dev/null || echo unknown)"
      boost_f="$(cat "$boost_f" 2>/dev/null || echo unknown)"
      rp0_f="$(cat "$rp0_f" 2>/dev/null || echo unknown)"
      rpn_f="$(cat "$rpn_f" 2>/dev/null || echo unknown)"
    fi

    echo "  Current frequency: ${cur_f} MHz"
    echo "  Max frequency:     ${max_f} MHz (HW RP0: ${rp0_f} MHz, Min RPn: ${rpn_f} MHz)"
    echo "  Boost frequency:   ${boost_f} MHz"
  else
    echo "  No Intel DRM device found or interface unavailable."
  fi

  echo
  echo "[i915 GuC/HuC]"
  if [[ -d /sys/module/i915 ]]; then
    echo "  enable_guc: $(status_value /sys/module/i915/parameters/enable_guc)"
    guc_lines="$(
      dmesg 2>/dev/null |
        grep -iE 'GuC firmware|HuC firmware|GuC.*submission|HuC.*authenticated' |
        tail -10 || true
    )"
    if [[ -n "$guc_lines" ]]; then
      printf '%s\n' "$guc_lines" | sed 's/^/  /'
    else
      echo "  No matching GuC/HuC lines available in the current dmesg buffer."
    fi
  elif [[ -d /sys/module/xe ]]; then
    echo "  Active graphics module is xe; i915 enable_guc is not applicable."
  else
    echo "  Neither i915 nor xe appears loaded."
  fi

  echo
  echo "[VA-API]"
  if command -v vainfo &>/dev/null; then
    va_output=""
    if [[ -e /dev/dri/renderD128 ]]; then
      va_output="$(
        vainfo --display drm --device /dev/dri/renderD128 2>&1 || true
      )"
    fi
    if [[ -z "$va_output" ]]; then
      va_output="$(vainfo 2>&1 || true)"
    fi
    va_driver="$(
      printf '%s\n' "$va_output" |
        grep -iE 'Driver version|vainfo: Driver version|Trying to open.*drv_video' |
        head -3 || true
    )"
    if [[ -n "$va_driver" ]]; then
      printf '%s\n' "$va_driver" | sed 's/^/  /'
    else
      echo "  vainfo is installed, but no active VA-API driver could be identified."
    fi
  else
    echo "  vainfo is not installed."
  fi

  echo
  echo "[Browser VA-API / Wayland Flags]"
  found=false
  while IFS=: read -r U_NAME _ U_UID _ _ U_HOME U_SHELL; do
    [[ "$U_UID" =~ ^[0-9]+$ ]] || continue
    (( U_UID >= 1000 && U_UID < 65000 )) || continue
    case "$U_SHELL" in
      */nologin|*/false|"") continue ;;
    esac
    [[ -n "$U_HOME" && -d "$U_HOME" ]] || continue
    found=true
    echo "  User: $U_NAME ($U_HOME)"
    for b_file in brave-flags.conf chrome-flags.conf chromium-flags.conf; do
      local f_path="${U_HOME}/.config/${b_file}"
      if [[ -f "$f_path" ]]; then
        if grep -q "Managed by vivobook_optimize" "$f_path" 2>/dev/null; then
          echo "    $b_file: managed (flags active)"
        else
          echo "    $b_file: present (custom/unmanaged)"
        fi
      else
        echo "    $b_file: absent"
      fi
    done
    # Snap Chromium
    local snap_chromium_dir="${U_HOME}/snap/chromium/common"
    if [[ -d "$snap_chromium_dir" ]]; then
      local snap_f="${snap_chromium_dir}/chromium-flags.conf"
      if [[ -f "$snap_f" ]]; then
        if grep -q "Managed by vivobook_optimize" "$snap_f" 2>/dev/null; then
          echo "    snap-chromium-flags.conf: managed (flags active)"
        else
          echo "    snap-chromium-flags.conf: present (custom/unmanaged)"
        fi
      else
        echo "    snap-chromium-flags.conf: absent"
      fi
    fi
  done < /etc/passwd
  if [[ "$found" == false ]]; then
    echo "  No desktop user accounts (UID >= 1000) detected."
  fi

  echo
  echo "[WirePlumber Audio Suspend]"
  wp_ver="$(get_wireplumber_version)"
  echo "  WirePlumber status:  $wp_ver"
  if [[ -f /etc/wireplumber/wireplumber.conf.d/50-alsa-powersave.conf ]]; then
    echo "  Managed SPA config:  present (/etc/wireplumber/wireplumber.conf.d/50-alsa-powersave.conf)"
    echo "  Configured timeout:  5 seconds"
  elif [[ -f /etc/wireplumber/main.lua.d/50-alsa-powersave.lua ]]; then
    echo "  Managed Lua config:  present (/etc/wireplumber/main.lua.d/50-alsa-powersave.lua)"
    echo "  Configured timeout:  5 seconds"
  else
    echo "  Managed config:      absent"
  fi

  echo
  echo "[USB Runtime Autosuspend]"
  if [[ -f /etc/udev/rules.d/99-usb-autosuspend.rules ]]; then
    echo "  Managed udev rule: present (/etc/udev/rules.d/99-usb-autosuspend.rules)"
  else
    echo "  Managed udev rule: absent"
  fi

  echo
  echo "[power-profiles-daemon Conflict State]"
  local ppd_present=false ppd_active="unknown" ppd_enabled="unknown" ppd_masked="no"
  if command systemctl list-unit-files power-profiles-daemon.service &>/dev/null && \
     [[ -n "$(command systemctl list-unit-files power-profiles-daemon.service 2>/dev/null | grep -i 'power-profiles-daemon')" ]]; then
    ppd_present=true
  fi
  if [[ "$ppd_present" == true ]]; then
    ppd_active="$(systemctl is-active power-profiles-daemon.service 2>/dev/null || echo inactive)"
    ppd_enabled="$(systemctl is-enabled power-profiles-daemon.service 2>/dev/null || echo unknown)"
    [[ "$ppd_enabled" == "masked" ]] && ppd_masked="yes"
    echo "  Service present:  yes"
    echo "  Active:           $ppd_active"
    echo "  Enabled status:   $ppd_enabled"
    echo "  Masked:           $ppd_masked"
  else
    echo "  Service present:  no"
  fi

  echo
  echo "[Kernel Sysctl Tuning]"
  for value in \
    vm.swappiness \
    vm.vfs_cache_pressure \
    fs.inotify.max_user_watches \
    kernel.nmi_watchdog \
    vm.dirty_writeback_centisecs
  do
    if sysctl -n "$value" &>/dev/null; then
      printf '  %-32s %s\n' "$value" "$(sysctl -n "$value")"
    else
      printf '  %-32s unavailable\n' "$value"
    fi
  done

  echo
  echo "[TCP BBR & Queuing]"
  local bbr_mod="unavailable"
  if modinfo tcp_bbr &>/dev/null || grep -qw bbr /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
    bbr_mod="available"
  fi
  echo "  BBR module support:  $bbr_mod"
  echo "  Congestion control:  $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)"
  echo "  Default qdisc:       $(sysctl -n net.core.default_qdisc 2>/dev/null || echo unknown)"
  if [[ -f /etc/sysctl.d/98-network-bbr.conf ]]; then
    echo "  Managed BBR config:  present (/etc/sysctl.d/98-network-bbr.conf)"
  else
    echo "  Managed BBR config:  absent"
  fi

  echo
  echo "[Wi-Fi Driver / Power Save]"
  wifi_found=false
  for iface_path in /sys/class/net/*; do
    [[ -d "$iface_path/wireless" ]] || continue
    iface="$(basename "$iface_path")"
    wifi_found=true
    driver="unknown"
    if [[ -L "$iface_path/device/driver" ]]; then
      driver="$(basename "$(readlink -f "$iface_path/device/driver")")"
    fi
    power_save="unknown"
    if command -v iw >/dev/null 2>&1; then
      power_save="$(iw dev "$iface" get power_save 2>/dev/null | awk -F': ' '/Power save:/ {print $2; exit}' || true)"
      [[ -n "$power_save" ]] || power_save="unknown"
    fi
    echo "  Interface: $iface"
    echo "  Driver:    $driver"
    echo "  Dynamic Power Save: $power_save (via iw)"
  done
  if [[ "$wifi_found" == false ]]; then
    echo "  No wireless interface detected."
  fi
  if [[ -f /etc/modprobe.d/iwlwifi.conf ]]; then
    echo "  Legacy /etc/modprobe.d/iwlwifi.conf: present (not used by the generic power-save path)"
  fi

  echo
  echo "[Wi-Fi ASPM — MediaTek MT7902 (mt7921e)]"
  if mt7921e_present; then
    echo "  mt7921e in use:        yes"
    if mt7921e_bound_iface >/dev/null 2>&1; then
      echo "  Bound interface:       $(mt7921e_bound_iface)"
    fi
  else
    echo "  mt7921e in use:        no (module not loaded and no interface bound)"
  fi
  echo "  disable_aspm (live):   $(mt7921e_disable_aspm_live)"
  if [[ -f "$MT7921E_CONF" ]]; then
    if mt7921e_conf_managed; then
      echo "  Config:                $MT7921E_CONF (script-managed)"
    else
      echo "  Config:                $MT7921E_CONF (present, NOT script-managed)"
    fi
    grep -E '^[[:space:]]*options[[:space:]]+mt7921e' "$MT7921E_CONF" 2>/dev/null | sed 's/^/     /' || true
  else
    echo "  Config:                $MT7921E_CONF absent"
  fi
  if aspm_workaround_active; then
    echo "  ASPM workaround:       active — PC8/PC10 absence is expected (not a fault)"
  else
    echo "  ASPM workaround:       not active — Wi-Fi may be unstable on this platform"
  fi

  echo
  echo "[Timers]"
  for value in fstrim.timer system-maintenance.timer; do
    timer_state="$(systemctl is-enabled "$value" 2>/dev/null || true)"
    [[ -n "$timer_state" ]] || timer_state="not-found"
    timer_next="$(
      systemctl show "$value" -p NextElapseUSecRealtime --value 2>/dev/null || true
    )"
    [[ -n "$timer_next" ]] || timer_next="unknown"
    printf '  %-27s enabled=%-10s next=%s\n' "$value" "$timer_state" "$timer_next"
  done

  echo
  echo "[Maintenance last run]"
  local maint_state maint_exit maint_when
  maint_state="$(systemctl show system-maintenance.service -p ActiveState --value 2>/dev/null || true)"
  maint_exit="$(systemctl show system-maintenance.service -p ExecMainStatus --value 2>/dev/null || true)"
  maint_when="$(systemctl show system-maintenance.service -p ActiveExitTimestamp --value 2>/dev/null || true)"
  if [[ -z "$maint_state" ]]; then
    maint_state="unavailable (service not installed)"
  fi
  printf '  %-22s %s\n' "ActiveState:" "$maint_state"
  printf '  %-22s %s\n' "ExecMainStatus:" "${maint_exit:-unavailable}"
  printf '  %-22s %s\n' "ActiveExitTimestamp:" "${maint_when:-unavailable}"

  echo
  echo "[zRAM]"
  found=false
  for f in /sys/block/zram[0-9]*; do
    [[ -e "$f" ]] || continue
    found=true
    echo "  Device: $(basename "$f")"
    [[ -r "$f/comp_algorithm" ]] &&
      echo "    Algorithm: $(cat "$f/comp_algorithm" 2>/dev/null || echo unknown)"
    [[ -r "$f/disksize" ]] &&
      echo "    Size:      $(numfmt --to=iec "$(cat "$f/disksize")" 2>/dev/null || cat "$f/disksize")"
    [[ -r "$f/mm_stat" ]] &&
      echo "    mm_stat:   $(cat "$f/mm_stat" 2>/dev/null || echo unknown)"
  done
  if [[ "$found" == false ]]; then
    echo "  No zRAM block device found."
  fi
  if command -v swapon &>/dev/null; then
    swapon --show 2>/dev/null | sed 's/^/  /' || true
  fi
  if [[ -f /etc/systemd/zram-generator.conf ]]; then
    echo "  zram-generator config: present (/etc/systemd/zram-generator.conf)"
  else
    echo "  zram-generator config: absent"
  fi
  if systemctl is-enabled --quiet zramswap.service 2>/dev/null; then
    echo "  zramswap.service (legacy zram-tools): enabled"
  else
    echo "  zramswap.service (legacy zram-tools): disabled/not installed"
  fi

  echo
  echo "[Intel RAPL Power Limits]"
  found=false
  # v15.3 (I-01/I-20): one shared enumerator (rapl_constraint_files) drives both
  # the dashboard and --status-json, deduped by canonical sysfs path. The lock
  # state is probed per constraint: on this machine PL1 is MSR-locked by the
  # BIOS while PL2 is writable, and a single PL1-only probe used to hide that.
  while IFS=$'\t' read -r rapl_zone rapl_file rapl_label; do
    [[ -n "$rapl_file" ]] || continue
    found=true
    local rapl_name rapl_uw rapl_watts rapl_lock
    rapl_name="$(cat "$(dirname "$rapl_file")/name" 2>/dev/null || echo "$rapl_zone")"
    rapl_uw="$(cat "$rapl_file" 2>/dev/null || echo 0)"
    rapl_watts="$(awk "BEGIN {printf \"%.1f\", $rapl_uw / 1000000}" 2>/dev/null || echo "$rapl_uw")"
    rapl_lock="$(rapl_probe_lock_state "$rapl_file")"
    printf '  %-12s %-6s %s W (lock probe: %s)\n' "$rapl_name" "$rapl_label" "$rapl_watts" "$rapl_lock"
  done < <(rapl_constraint_files)
  if [[ "$found" == false ]]; then
    echo "  No RAPL powercap interface found."
  else
    if (( EUID != 0 )); then
      echo "  (Lock state requires root: the probe writes the current value back and"
      echo "   reports 'unknown (needs root)' otherwise. No register is changed.)"
    fi
  fi
  if systemctl is-enabled --quiet rapl-power-limits.service 2>/dev/null; then
    echo "  Persistent service: enabled"
  else
    echo "  Persistent service: disabled/not installed"
  fi

  echo
  echo "[NVMe I/O Scheduler]"
  found=false
  for d in /sys/block/nvme[0-9]*; do
    [[ -d "$d" ]] || continue
    found=true
    local sched
    sched="$(cat "$d/queue/scheduler" 2>/dev/null || echo unknown)"
    printf '  %-12s %s\n' "$(basename "$d")" "$sched"
  done
  if [[ "$found" == false ]]; then
    echo "  No NVMe block devices found."
  fi
  echo
  echo "[Dynamic AC/Battery Power Switching]"
  if systemctl is-enabled --quiet vivobook-power-switch.service 2>/dev/null; then
    echo "  Boot service: enabled"
  else
    echo "  Boot service: disabled/not installed"
  fi
  if [[ -f /etc/udev/rules.d/99-vivobook-power.rules ]]; then
    echo "  udev rule: present"
  else
    echo "  udev rule: absent"
  fi
  local AC_ON=unknown
  for f in /sys/class/power_supply/AC*/online /sys/class/power_supply/ADP*/online; do
    [[ -e "$f" ]] || continue
    local val
    val="$(cat "$f" 2>/dev/null || echo 0)"
    [[ "$val" == "1" ]] && AC_ON=yes || AC_ON=no
    break
  done
  echo "  AC adapter online: $AC_ON"

  echo
  echo "[Keyboard Backlight Timeout]"
  if systemctl is-enabled --quiet vivobook-kbd-timeout.service 2>/dev/null; then
    echo "  Persistent service: enabled"
  else
    echo "  Persistent service: disabled/not installed"
  fi
  local KBD_LED=/sys/class/leds/asus::kbd_backlight
  if [[ -d "$KBD_LED" ]]; then
    echo "  Backlight device: present"
    echo "  Brightness: $(cat "$KBD_LED/brightness" 2>/dev/null || echo unknown)"
    if [[ -e "$KBD_LED/stop_time" ]]; then
      echo "  stop_time: $(cat "$KBD_LED/stop_time" 2>/dev/null || echo unknown)s"
    fi
  else
    echo "  Backlight device: not found"
  fi

  echo "===================================================="
  echo "Status mode is read-only; no configuration was changed."
  echo "===================================================="
}

show_status_json() {
  local batt_path batt_name batt_thresh="null"
  local va_output va_driver
  local f value
  local first=true
  local enabled next
  local swap_output
  local card wp_ver

  echo "{"
  echo "  \"generated\": $(json_string "$(date)"),"
  echo "  \"script\": { \"name\": $(json_string "$SCRIPT_NAME"), \"version\": $(json_string "$SCRIPT_VERSION"), \"schema\": $SCRIPT_SCHEMA },"

  # v15.3 (I-19): machine identity, boot integrity, kernel pin and cmdline.
  # Every value is guarded; missing data is null/unknown, never a crash.
  echo "  \"firmware\": {"
  echo "    \"product_name\": $(json_string "$(status_value /sys/class/dmi/id/product_name)"),"
  echo "    \"board_name\": $(json_string "$(status_value /sys/class/dmi/id/board_name)"),"
  echo "    \"bios_version\": $(json_string "$(status_value /sys/class/dmi/id/bios_version)"),"
  echo "    \"bios_date\": $(json_string "$(status_value /sys/class/dmi/id/bios_date)")"
  echo "  },"
  echo "  \"boot_integrity\": {"
  echo "    \"secure_boot\": $(json_string "$(secure_boot_state)"),"
  echo "    \"signing_hook\": $(json_string "$(signing_hook_state)"),"
  echo "    \"signing_hook_path\": $(json_string "$SIGNING_HOOK"),"
  echo "    \"running_kernel_signature\": $(json_string "$(running_kernel_signature_state)"),"
  echo "    \"running_kernel\": $(json_string "/boot/vmlinuz-$(uname -r)"),"
  echo "    \"sbverify_installed\": $(command -v sbverify >/dev/null 2>&1 && echo true || echo false)"
  echo "  },"
  echo "  \"kernel_pin\": {"
  echo "    \"path\": $(json_string "$STOCK_KERNEL_PREF"),"
  echo "    \"present\": $( [[ -f "$STOCK_KERNEL_PREF" ]] && echo true || echo false ),"
  echo "    \"blocks_stock_kernel\": $(stock_kernel_pin_blocks && echo true || echo false)"
  echo "  },"
  local cmdline_token cmdline_i915="null" cmdline_xe="null" cmdline_aspm="null"
  for cmdline_token in $(cat /proc/cmdline 2>/dev/null || true); do
    case "$cmdline_token" in
      i915.force_probe=*) cmdline_i915="$(json_string "$cmdline_token")" ;;
      xe.force_probe=*)   cmdline_xe="$(json_string "$cmdline_token")" ;;
      pcie_aspm.policy=*) cmdline_aspm="$(json_string "$cmdline_token")" ;;
    esac
  done
  echo "  \"kernel_cmdline\": {"
  echo "    \"i915_force_probe\": $cmdline_i915,"
  echo "    \"xe_force_probe\": $cmdline_xe,"
  echo "    \"pcie_aspm_policy\": $cmdline_aspm,"
  echo "    \"active_drm_driver\": $(json_string "$(detect_active_drm_driver)")"
  echo "  },"

  # v15.2: ownership snapshot for consumers that need to know why power
  # policy appears unchanged (TLP presence explains script-side SKIPs).
  detect_power_managers
  echo "  \"power_ownership\": {"
  echo "    \"tlp_present\": $TLP_PRESENT,"
  echo "    \"tlp_active\": $TLP_ACTIVE,"
  echo "    \"tlp_version\": $(json_string "${TLP_VERSION:-unknown}"),"
  echo "    \"ppd_active\": $PPD_ACTIVE,"
  echo "    \"thermald_active\": $THERMALD_ACTIVE,"
  echo "    \"force_tlp_override\": $FORCE_TLP_OVERRIDE"
  echo "  },"
  echo "  \"power_coherence\": {"
  echo "    \"ppd_current\": $(json_string "$(ppd_current_profile)"),"
  echo "    \"requested_thermal\": $(json_string "${FAN_PROFILE:-}"),"
  echo "    \"requested_thermal_ppd\": $(json_string "$(ppd_profile_for_thermal "${FAN_PROFILE:-}")"),"
  echo "    \"requested_epp\": $(json_string "${EPP_PROFILE:-}"),"
  echo "    \"requested_epp_ppd\": $(json_string "$(ppd_profile_for_epp "${EPP_PROFILE:-}")"),"
  if [[ -n "$FAN_PROFILE" && -n "$EPP_PROFILE" ]]; then
    if [[ "$(ppd_profile_for_thermal "$FAN_PROFILE")" == "$(ppd_profile_for_epp "$EPP_PROFILE")" ]]; then
      echo "    \"agree\": true,"
    else
      echo "    \"agree\": false,"
    fi
  else
    echo "    \"agree\": null,"
  fi
  echo "    \"note\": \"PPD holds exactly one profile; conflicting --fan-profile/--epp are refused at parse time\""
  echo "  },"

  batt_path="$(find_battery_threshold)"
  echo "  \"battery\": {"
  if [[ -n "$batt_path" ]]; then
    batt_name="$(basename "$(dirname "$batt_path")")"
    batt_thresh="$(status_value "$batt_path")"
    echo "    \"name\": $(json_string "$batt_name"),"
    echo "    \"charge_control_end_threshold\": $(json_string "$batt_thresh"),"
  else
    echo "    \"name\": null,"
    echo "    \"charge_control_end_threshold\": null,"
  fi
  local batt_hook=false
  [[ -x /usr/lib/systemd/system-sleep/vivobook-battery ]] && batt_hook=true
  echo "    \"resume_hook_present\": $batt_hook"
  echo "  },"
  echo "  \"battery_health\": {"
  local bh_seen=false bh_name bh_full bh_design bh_cycles bh_health
  while IFS=$'\t' read -r bh_name bh_full bh_design bh_cycles bh_health; do
    [[ -n "$bh_name" ]] || continue
    bh_seen=true
    if [[ "$bh_full" =~ ^[0-9]+$ ]]; then bh_full_j="$bh_full"; else bh_full_j=null; fi
    if [[ "$bh_design" =~ ^[0-9]+$ ]]; then bh_design_j="$bh_design"; else bh_design_j=null; fi
    if [[ "$bh_cycles" =~ ^[0-9]+$ ]]; then bh_cycles_j="$bh_cycles"; else bh_cycles_j=null; fi
    if [[ "$bh_health" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then bh_health_j="$bh_health"; else bh_health_j=null; fi
    echo "    \"device\": $(json_string "$bh_name"),"
    echo "    \"charge_full_uah\": $bh_full_j,"
    echo "    \"charge_full_design_uah\": $bh_design_j,"
    echo "    \"cycle_count\": $bh_cycles_j,"
    echo "    \"health_percent\": $bh_health_j"
    break
  done < <(battery_health_rows)
  if [[ "$bh_seen" == false ]]; then
    echo "    \"device\": null,"
    echo "    \"charge_full_uah\": null,"
    echo "    \"charge_full_design_uah\": null,"
    echo "    \"cycle_count\": null,"
    echo "    \"health_percent\": null"
  fi
  echo "  },"

  echo "  \"thermal\": {"
  local pp_node=""
  for pp_node in /sys/class/platform_profile/*/profile; do
    [[ -r "$pp_node" ]] || continue
    break
  done
  if [[ -n "$pp_node" && -r "$pp_node" ]]; then
    echo "    \"interface\": $(json_string "$pp_node"),"
    echo "    \"active\": $(json_string "$(status_value "$pp_node")"),"
    if [[ -r "$(dirname "$pp_node")/choices" ]]; then
      echo "    \"choices\": $(json_string "$(status_value "$(dirname "$pp_node")/choices")")"
    else
      echo "    \"choices\": null"
    fi
  elif [[ -r /sys/firmware/acpi/platform_profile ]]; then
    echo "    \"interface\": \"platform_profile\","
    echo "    \"active\": $(json_string "$(status_value /sys/firmware/acpi/platform_profile)"),"
    if [[ -r /sys/firmware/acpi/platform_profile_choices ]]; then
      echo "    \"choices\": $(json_string "$(status_value /sys/firmware/acpi/platform_profile_choices)")"
    else
      echo "    \"choices\": null"
    fi
  elif [[ -r /sys/devices/platform/asus-nb-wmi/throttle_thermal_policy ]]; then
    echo "    \"interface\": \"asus_throttle_thermal_policy\","
    echo "    \"active\": $(json_string "$(status_value /sys/devices/platform/asus-nb-wmi/throttle_thermal_policy)")"
  else
    echo "    \"interface\": null,"
    echo "    \"active\": null"
  fi
  echo "  },"

  echo "  \"cpu\": {"
  echo "    \"scaling_driver\": $(json_string "$(status_value /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver)"),"
  echo "    \"intel_pstate_status\": $(json_string "$(status_value /sys/devices/system/cpu/intel_pstate/status)"),"
  echo "    \"no_turbo\": $(json_string "$(status_value /sys/devices/system/cpu/intel_pstate/no_turbo)"),"
  echo "    \"max_perf_pct\": $(json_string "$(status_value /sys/devices/system/cpu/intel_pstate/max_perf_pct)"),"
  declare -A EPP_COUNTS=()
  for f in /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference; do
    [[ -r "$f" ]] || continue
    value="$(cat "$f" 2>/dev/null || echo unknown)"
    EPP_COUNTS["$value"]=$(( ${EPP_COUNTS["$value"]:-0} + 1 ))
  done
  echo "    \"epp\": {"
  first=true
  for value in "${!EPP_COUNTS[@]}"; do
    if [[ "$first" == true ]]; then first=false; else echo ","; fi
    printf '      %s: %s' "$(json_string "$value")" "${EPP_COUNTS[$value]}"
  done
  echo ""
  echo "    }"
  echo "  },"

  echo "  \"suspend\": {"
  local ms_raw="" ms_active="null" ms_s2idle=false
  if [[ -r /sys/power/mem_sleep ]]; then
    ms_raw="$(status_value /sys/power/mem_sleep)"
    ms_active="$(printf '%s\n' "$ms_raw" | grep -oE '\[[a-z0-9_]+\]' | tr -d '[]' | head -1 || true)"
    [[ "$ms_active" == "s2idle" ]] && ms_s2idle=true
    echo "    \"mem_sleep\": $(json_string "$ms_raw"),"
    echo "    \"active_mode\": $(json_string "${ms_active:-unknown}"),"
  else
    echo "    \"mem_sleep\": null,"
    echo "    \"active_mode\": null,"
  fi
  echo "    \"s2idle_active\": $ms_s2idle,"
  local pmc_dir=/sys/kernel/debug/pmc_core
  local pc8_j="null" pc10_j="null" slp_s0_j="null" pmc_avail=false
  if [[ -r "$pmc_dir/package_cstate_show" ]]; then
    pmc_avail=true
    pc8_j="$(awk -F: '/Package C8/ {gsub(/[ \t]+/, "", $2); print $2}' "$pmc_dir/package_cstate_show" 2>/dev/null || true)"
    pc10_j="$(awk -F: '/Package C10/ {gsub(/[ \t]+/, "", $2); print $2}' "$pmc_dir/package_cstate_show" 2>/dev/null || true)"
    [[ "$pc8_j" =~ ^[0-9]+$ ]] || pc8_j="null"
    [[ "$pc10_j" =~ ^[0-9]+$ ]] || pc10_j="null"
  fi
  if [[ -r "$pmc_dir/slp_s0_residency_usec" ]]; then
    slp_s0_j="$(status_value "$pmc_dir/slp_s0_residency_usec")"
    [[ "$slp_s0_j" =~ ^[0-9]+$ ]] || slp_s0_j="null"
  fi
  local deep_ok=false
  if [[ "$pc10_j" != "null" && "$pc10_j" != "0" ]] || [[ "$pc8_j" != "null" && "$pc8_j" != "0" ]]; then
    deep_ok=true
  fi
  local aspm_wa=false deep_expected=false
  if aspm_workaround_active; then
    aspm_wa=true
    # v15.3 (I-22): PC8/PC10 == 0 is the documented consequence of
    # disable_aspm=1 on this platform, not a fault to chase.
    [[ "$deep_ok" == false ]] && deep_expected=true
  fi
  echo "    \"pmc_core_available\": $pmc_avail,"
  echo "    \"pc8_residency\": $pc8_j,"
  echo "    \"pc10_residency\": $pc10_j,"
  echo "    \"deep_pc_states_reached\": $deep_ok,"
  echo "    \"aspm_workaround_active\": $aspm_wa,"
  echo "    \"deep_pc_states_expected_absent\": $deep_expected,"
  echo "    \"slp_s0_residency_usec\": $slp_s0_j,"
  echo "    \"cpuidle_driver\": $(json_string "$(status_value /sys/devices/system/cpu/cpuidle/current_driver)")"
  echo "  },"

  echo "  \"igpu\": {"
  card="$(find_intel_drm_card || true)"
  if [[ -n "$card" ]]; then
    local max_f="null" boost_f="null" rp0_f="null" rpn_f="null" cur_f="null"
    local freq_info
    freq_info="$(find_igpu_freq_files "$card" || true)"
    if [[ -n "$freq_info" ]]; then
      read -r max_f boost_f rp0_f rpn_f <<< "$freq_info"
      if [[ -r "$(dirname "$max_f")/rps_cur_freq_mhz" ]]; then
        cur_f="$(cat "$(dirname "$max_f")/rps_cur_freq_mhz" 2>/dev/null || echo null)"
      elif [[ -r "$(dirname "$max_f")/gt_cur_freq_mhz" ]]; then
        cur_f="$(cat "$(dirname "$max_f")/gt_cur_freq_mhz" 2>/dev/null || echo null)"
      fi
      max_f="$(cat "$max_f" 2>/dev/null || echo null)"
      boost_f="$(cat "$boost_f" 2>/dev/null || echo null)"
      rp0_f="$(cat "$rp0_f" 2>/dev/null || echo null)"
      rpn_f="$(cat "$rpn_f" 2>/dev/null || echo null)"
      [[ "$cur_f" =~ ^[0-9]+$ ]] || cur_f=null
      [[ "$max_f" =~ ^[0-9]+$ ]] || max_f=null
      [[ "$boost_f" =~ ^[0-9]+$ ]] || boost_f=null
      [[ "$rp0_f" =~ ^[0-9]+$ ]] || rp0_f=null
      [[ "$rpn_f" =~ ^[0-9]+$ ]] || rpn_f=null
    fi

    echo "    \"device\": $(json_string "$(basename "$card")"),"
    echo "    \"driver\": $(json_string "$(detect_active_drm_driver)"),"
    echo "    \"cur_freq_mhz\": ${cur_f:-null},"
    echo "    \"max_freq_mhz\": ${max_f:-null},"
    echo "    \"boost_freq_mhz\": ${boost_f:-null},"
    echo "    \"rp0_freq_mhz\": ${rp0_f:-null},"
    echo "    \"rpn_freq_mhz\": ${rpn_f:-null}"
  else
    # v15.3 (I-20): fixed key set in every branch.
    echo "    \"device\": null,"
    echo "    \"driver\": $(json_string "$(detect_active_drm_driver)"),"
    echo "    \"cur_freq_mhz\": null,"
    echo "    \"max_freq_mhz\": null,"
    echo "    \"boost_freq_mhz\": null,"
    echo "    \"rp0_freq_mhz\": null,"
    echo "    \"rpn_freq_mhz\": null"
  fi
  echo "  },"

  echo "  \"i915\": {"
  # v15.3 (I-20): fixed 5-key shape regardless of which DRM module is loaded.
  if [[ -d /sys/module/i915 ]]; then
    smod=i915
  elif [[ -d /sys/module/xe ]]; then
    smod=xe
  else
    smod=not_loaded
  fi
  echo "    \"module\": $(json_string "$smod"),"
  if [[ -d /sys/module/i915 ]]; then
    echo "    \"enable_guc\": $(json_string "$(status_value /sys/module/i915/parameters/enable_guc)"),"
    echo "    \"enable_fbc\": $(json_string "$(status_value /sys/module/i915/parameters/enable_fbc)"),"
    echo "    \"enable_psr\": $(json_string "$(status_value /sys/module/i915/parameters/enable_psr)"),"
    echo "    \"enable_dc\": $(json_string "$(status_value /sys/module/i915/parameters/enable_dc)")"
  else
    echo "    \"enable_guc\": null,"
    echo "    \"enable_fbc\": null,"
    echo "    \"enable_psr\": null,"
    echo "    \"enable_dc\": null"
  fi
  echo "  },"

  echo "  \"vaapi\": {"
  if command -v vainfo &>/dev/null; then
    va_output=""
    if [[ -e /dev/dri/renderD128 ]]; then
      va_output="$(vainfo --display drm --device /dev/dri/renderD128 2>&1 || true)"
    fi
    if [[ -z "$va_output" ]]; then
      va_output="$(vainfo 2>&1 || true)"
    fi
    va_driver="$(printf '%s\n' "$va_output" | grep -iE 'Driver version|vainfo: Driver version' | head -3 || true)"
    echo "    \"installed\": true,"
    echo "    \"driver_version\": $(json_string "$va_driver")"
  else
    echo "    \"installed\": false"
  fi
  echo "  },"

  echo "  \"browser_vaapi\": ["
  first=true
  while IFS=: read -r U_NAME _ U_UID _ _ U_HOME U_SHELL; do
    [[ "$U_UID" =~ ^[0-9]+$ ]] || continue
    (( U_UID >= 1000 && U_UID < 65000 )) || continue
    case "$U_SHELL" in
      */nologin|*/false|"") continue ;;
    esac
    [[ -n "$U_HOME" && -d "$U_HOME" ]] || continue
    if [[ "$first" == true ]]; then first=false; else echo ","; fi
    local br_b=false br_c=false br_cr=false br_snap=false
    [[ -f "${U_HOME}/.config/brave-flags.conf" ]] && grep -q "Managed by vivobook_optimize" "${U_HOME}/.config/brave-flags.conf" 2>/dev/null && br_b=true
    [[ -f "${U_HOME}/.config/chrome-flags.conf" ]] && grep -q "Managed by vivobook_optimize" "${U_HOME}/.config/chrome-flags.conf" 2>/dev/null && br_c=true
    [[ -f "${U_HOME}/.config/chromium-flags.conf" ]] && grep -q "Managed by vivobook_optimize" "${U_HOME}/.config/chromium-flags.conf" 2>/dev/null && br_cr=true
    if [[ -d "${U_HOME}/snap/chromium/common" ]]; then
      [[ -f "${U_HOME}/snap/chromium/common/chromium-flags.conf" ]] && grep -q "Managed by vivobook_optimize" "${U_HOME}/snap/chromium/common/chromium-flags.conf" 2>/dev/null && br_snap=true
    fi
    printf '    { "user": %s, "brave_managed": %s, "chrome_managed": %s, "chromium_managed": %s, "snap_chromium_managed": %s }' \
      "$(json_string "$U_NAME")" "$br_b" "$br_c" "$br_cr" "$br_snap"
  done < /etc/passwd
  # v15.2: empty list must be a valid empty JSON array, not [ null ].
  echo ""
  echo "  ],"

  echo "  \"wireplumber\": {"
  wp_ver="$(get_wireplumber_version)"
  local wp_managed=false
  [[ -f /etc/wireplumber/wireplumber.conf.d/50-alsa-powersave.conf || -f /etc/wireplumber/main.lua.d/50-alsa-powersave.lua ]] && wp_managed=true
  echo "    \"version\": $(json_string "$wp_ver"),"
  echo "    \"managed_config_present\": $wp_managed,"
  echo "    \"suspend_timeout_seconds\": 5"
  echo "  },"

  echo "  \"usb_autosuspend\": {"
  local usb_rule=false
  [[ -f /etc/udev/rules.d/99-usb-autosuspend.rules ]] && usb_rule=true
  echo "    \"rule_present\": $usb_rule"
  echo "  },"

  echo "  \"power_profiles_daemon\": {"
  local ppd_p=false ppd_act="unknown" ppd_en="unknown" ppd_msk=false
  if command systemctl list-unit-files power-profiles-daemon.service &>/dev/null && \
     [[ -n "$(command systemctl list-unit-files power-profiles-daemon.service 2>/dev/null | grep -i 'power-profiles-daemon')" ]]; then
    ppd_p=true
  fi
  if [[ "$ppd_p" == true ]]; then
    ppd_act="$(systemctl is-active power-profiles-daemon.service 2>/dev/null || echo inactive)"
    ppd_en="$(systemctl is-enabled power-profiles-daemon.service 2>/dev/null || echo unknown)"
    [[ "$ppd_en" == "masked" ]] && ppd_msk=true
  fi
  echo "    \"present\": $ppd_p,"
  echo "    \"active\": $(json_string "$ppd_act"),"
  echo "    \"enabled\": $(json_string "$ppd_en"),"
  echo "    \"masked\": $ppd_msk"
  echo "  },"

  echo "  \"sysctl\": {"
  first=true
  for value in \
    vm.swappiness \
    vm.vfs_cache_pressure \
    fs.inotify.max_user_watches \
    kernel.nmi_watchdog \
    vm.dirty_writeback_centisecs
  do
    if [[ "$first" == true ]]; then first=false; else echo ","; fi
    if sysctl -n "$value" &>/dev/null; then
      printf '    %s: %s' "$(json_string "$value")" "$(json_string "$(sysctl -n "$value")")"
    else
      printf '    %s: null' "$(json_string "$value")"
    fi
  done
  echo ""
  echo "  },"

  echo "  \"bbr\": {"
  local bbr_avail=false bbr_cfg=false
  if modinfo tcp_bbr &>/dev/null || grep -qw bbr /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
    bbr_avail=true
  fi
  [[ -f /etc/sysctl.d/98-network-bbr.conf ]] && bbr_cfg=true
  echo "    \"module_available\": $bbr_avail,"
  echo "    \"tcp_congestion_control\": $(json_string "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)"),"
  echo "    \"default_qdisc\": $(json_string "$(sysctl -n net.core.default_qdisc 2>/dev/null || echo unknown)"),"
  echo "    \"config_present\": $bbr_cfg"
  echo "  },"

  echo "  \"wifi\": {"
  local wifi_found=false wifi_first=true
  echo "    \"interfaces\": ["
  for iface_path in /sys/class/net/*; do
    [[ -d "$iface_path/wireless" ]] || continue
    iface="$(basename "$iface_path")"
    wifi_found=true
    driver="unknown"
    if [[ -L "$iface_path/device/driver" ]]; then
      driver="$(basename "$(readlink -f "$iface_path/device/driver")")"
    fi
    power_save="unknown"
    if command -v iw >/dev/null 2>&1; then
      power_save="$(iw dev "$iface" get power_save 2>/dev/null | awk -F': ' '/Power save:/ {print $2; exit}' || true)"
      [[ -n "$power_save" ]] || power_save="unknown"
    fi
    if [[ "$wifi_first" == true ]]; then wifi_first=false; else echo ","; fi
    # v15.2: control availability derived from whether 'iw' actually reported
    # a power-save state for this interface (unknown = control unavailable).
    local ps_available=false
    [[ "$power_save" != "unknown" ]] && ps_available=true
    printf '      { "interface": %s, "driver": %s, "power_save": %s, "power_save_control_available": %s }' \
      "$(json_string "$iface")" "$(json_string "$driver")" "$(json_string "$power_save")" "$ps_available"
  done
  # v15.2: empty list must be a valid empty JSON array, not [ null ].
  echo ""
  echo "    ],"
  echo "    \"legacy_iwlwifi_config_present\": $( [[ -f /etc/modprobe.d/iwlwifi.conf ]] && echo true || echo false ),"
  # v15.3 (I-03): mt7921e ASPM workaround state.
  echo "    \"mt7921e\": {"
  echo "      \"in_use\": $(mt7921e_present && echo true || echo false),"
  echo "      \"config_present\": $( [[ -f "$MT7921E_CONF" ]] && echo true || echo false ),"
  echo "      \"managed\": $(mt7921e_conf_managed && echo true || echo false),"
  echo "      \"disable_aspm_1\": $(mt7921e_conf_has_disable_aspm && echo true || echo false),"
  echo "      \"disable_aspm_live\": $(json_string "$(mt7921e_disable_aspm_live)"),"
  echo "      \"aspm_workaround_active\": $(aspm_workaround_active && echo true || echo false)"
  echo "    }"
  echo "  },"
  echo "  \"timers\": {"
  first=true
  for value in fstrim.timer system-maintenance.timer; do
    if [[ "$first" == true ]]; then first=false; else echo ","; fi
    enabled="$(systemctl is-enabled "$value" 2>/dev/null || echo unknown)"
    next="$(systemctl show "$value" -p NextElapseUSecRealtime --value 2>/dev/null || echo unknown)"
    printf '    %s: { "enabled": %s, "next": %s }' \
      "$(json_string "$value")" "$(json_string "$enabled")" "$(json_string "$next")"
  done
  echo ""
  echo "  },"
  # v15.3 (I-19): last system-maintenance run, for observability.
  echo "  \"maintenance\": {"
  maint_json_state="$(systemctl show system-maintenance.service -p ActiveState --value 2>/dev/null || true)"
  maint_json_exit="$(systemctl show system-maintenance.service -p ExecMainStatus --value 2>/dev/null || true)"
  maint_json_when="$(systemctl show system-maintenance.service -p ActiveExitTimestamp --value 2>/dev/null || true)"
  echo "    \"active_state\": $(json_string "${maint_json_state:-unknown}"),"
  echo "    \"exec_main_status\": $(json_string "${maint_json_exit:-unknown}"),"
  echo "    \"active_exit_timestamp\": $(json_string "${maint_json_when:-unknown}")"
  echo "  },"

  echo "  \"zram\": {"
  local zram_gen_cfg=false
  [[ -f /etc/systemd/zram-generator.conf ]] && zram_gen_cfg=true
  echo "    \"generator_config_present\": $zram_gen_cfg,"
  echo "    \"devices\": ["
  first=true
  for f in /sys/block/zram[0-9]*; do
    [[ -e "$f" ]] || continue
    if [[ "$first" == true ]]; then first=false; else echo ","; fi
    printf '      { "device": %s, "comp_algorithm": %s, "disksize": %s }' \
      "$(json_string "$(basename "$f")")" \
      "$(json_string "$(cat "$f/comp_algorithm" 2>/dev/null || echo unknown)")" \
      "$(json_string "$(cat "$f/disksize" 2>/dev/null || echo unknown)")"
  done
  # v15.2: empty list must be a valid empty JSON array, not [ null ].
  echo ""
  echo "    ],"
  swap_output="$(swapon --show --noheadings 2>/dev/null || true)"
  echo "    \"swap\": $(json_string "$swap_output")"
  echo "  },"

  echo "  \"rapl\": {"
  # v15.3 (I-01/I-20): shared enumerator, "available" always present, and the
  # per-constraint firmware lock state exposed separately. The limit keys keep
  # their v15.2 shape (numbers) so existing consumers keep working.
  first=true
  rapl_any=false
  rapl_limit_out=""
  rapl_lock_out=""
  rapl_lock_first=true
  while IFS=$'\t' read -r rapl_jzone rapl_jfile rapl_jlabel; do
    [[ -n "$rapl_jfile" ]] || continue
    rapl_any=true
    if [[ "$first" == true ]]; then first=false; else rapl_limit_out+=",
"; fi
    # Key on the unique zone directory name (intel-rapl:0, :0:0, ...) instead
    # of the zone "name" attribute, which can repeat across subzones.
    r_key="${rapl_jzone}_${rapl_jlabel}"
    r_uw="$(cat "$rapl_jfile" 2>/dev/null || echo 0)"
    [[ "$r_uw" =~ ^[0-9]+$ ]] || r_uw=0
    rapl_limit_out+="    $(json_string "$r_key"): $r_uw"
    r_lock="$(rapl_probe_lock_state "$rapl_jfile")"
    case "$r_lock" in
      locked)   r_lock_j=true ;;
      writable) r_lock_j=false ;;
      *)        r_lock_j=null ;;
    esac
    if [[ "$rapl_lock_first" == true ]]; then rapl_lock_first=false; else rapl_lock_out+=",
"; fi
    rapl_lock_out+="    $(json_string "$r_key"): $r_lock_j"
  done < <(rapl_constraint_files)
  echo "    \"available\": $rapl_any,"
  if [[ "$rapl_any" == true ]]; then
    printf '%s\n' "$rapl_limit_out" | sed 's/^/  /'
    echo "    ,\"locked\": {"
    printf '%s\n' "$rapl_lock_out" | sed 's/^/  /'
    echo "    }"
  else
    echo "    \"locked\": null"
  fi
  echo "  },"

  echo "  \"nvme\": {"
  first=true
  for d in /sys/block/nvme[0-9]*; do
    [[ -d "$d" ]] || continue
    if [[ "$first" == true ]]; then first=false; else echo ","; fi
    local n_sched
    n_sched="$(cat "$d/queue/scheduler" 2>/dev/null || echo unknown)"
    printf '    %s: %s' "$(json_string "$(basename "$d")")" "$(json_string "$n_sched")"
  done
  echo ""
  echo "  },"

  echo "  \"dynamic_power\": {"
  local ac_online="unknown"
  for f in /sys/class/power_supply/AC*/online /sys/class/power_supply/ADP*/online; do
    [[ -e "$f" ]] || continue
    ac_online="$(cat "$f" 2>/dev/null || echo 0)"
    break
  done
  echo "    \"ac_online\": $(json_string "$ac_online"),"
  local pwr_udev_present=false
  [[ -f /etc/udev/rules.d/99-vivobook-power.rules ]] && pwr_udev_present=true
  echo "    \"udev_rule_present\": $pwr_udev_present,"
  local pwr_svc
  pwr_svc="$(systemctl is-enabled vivobook-power-switch.service 2>/dev/null || echo unknown)"
  echo "    \"service_enabled\": $(json_string "$pwr_svc")"
  echo "  },"

  echo "  \"keyboard_backlight\": {"
  local kbd_svc
  kbd_svc="$(systemctl is-enabled vivobook-kbd-timeout.service 2>/dev/null || echo unknown)"
  echo "    \"service_enabled\": $(json_string "$kbd_svc"),"
  if [[ -d /sys/class/leds/asus::kbd_backlight ]]; then
    echo "    \"device_present\": true,"
    echo "    \"brightness\": $(json_string "$(cat /sys/class/leds/asus::kbd_backlight/brightness 2>/dev/null || echo unknown)")"
    if [[ -e /sys/class/leds/asus::kbd_backlight/stop_time ]]; then
      echo "    ,"
      echo "    \"stop_time\": $(json_string "$(cat /sys/class/leds/asus::kbd_backlight/stop_time 2>/dev/null || echo unknown)")"
    fi
  else
    echo "    \"device_present\": false"
  fi
  echo "  },"

  if [[ -e /var/run/reboot-required ]]; then
    echo "  \"reboot_required\": true"
  else
    echo "  \"reboot_required\": false"
  fi
  echo "}"
}

# ---- v15.3 (I-34): --safe-mode-check ---------------------------------------
# Read-only gate for "can I reboot / upgrade my kernel?". Exits 0 only when
# every critical item is present, 1 otherwise (listing what is missing). It
# performs no mutations: nothing is written, installed or enrolled.
safe_mode_check() {
  local -a SAFE_FAILS=()
  echo "===================================================="
  echo "ASUS Vivobook v15.3 — safe-mode / boot-integrity check"
  echo "Generated: $(date)"
  echo "Host: $(status_value /sys/class/dmi/id/product_name) / BIOS $(status_value /sys/class/dmi/id/bios_version)"
  echo "Kernel: $(uname -r)"
  echo "===================================================="

  echo
  echo "[1/5] Kernel signing hook"
  case "$(signing_hook_state)" in
    present-executable)
      echo "  OK    $SIGNING_HOOK exists and is executable."
      ;;
    present-not-executable)
      echo "  FAIL  $SIGNING_HOOK exists but is NOT executable — a newly installed kernel"
      echo "        would not be signed and Secure Boot would refuse it."
      SAFE_FAILS+=("kernel signing hook is not executable: $SIGNING_HOOK")
      ;;
    *)
      echo "  FAIL  $SIGNING_HOOK is missing — a newly installed kernel would not be"
      echo "        signed and Secure Boot would refuse it."
      SAFE_FAILS+=("kernel signing hook missing: $SIGNING_HOOK")
      ;;
  esac

  echo
  echo "[2/5] Stock-kernel apt pin"
  if stock_kernel_pin_blocks; then
    echo "  OK    $STOCK_KERNEL_PREF blocks the stock kernel meta-packages."
  elif [[ -f "$STOCK_KERNEL_PREF" ]]; then
    echo "  FAIL  $STOCK_KERNEL_PREF exists but no negative Pin-Priority for a linux"
    echo "        package was found; a stock kernel could replace the mainline one."
    SAFE_FAILS+=("apt pin exists but does not block stock kernels: $STOCK_KERNEL_PREF")
  else
    echo "  FAIL  $STOCK_KERNEL_PREF is missing; a stock kernel update could replace"
    echo "        the mainline kernel and Wi-Fi support with it."
    SAFE_FAILS+=("stock-kernel apt pin missing: $STOCK_KERNEL_PREF")
  fi

  echo
  echo "[3/5] Running-kernel signature (/boot/vmlinuz-$(uname -r))"
  case "$(running_kernel_signature_state)" in
    signed-by-vivobook-key)
      echo "  OK    signed by CN=Vivobook Kernel Key."
      ;;
    signed-by-other)
      echo "  FAIL  signed, but NOT by CN=Vivobook Kernel Key — Secure Boot will refuse it."
      SAFE_FAILS+=("running kernel is not signed by CN=Vivobook Kernel Key")
      ;;
    unsigned)
      echo "  FAIL  sbverify found no readable signature on the running kernel image."
      SAFE_FAILS+=("running kernel image has no readable signature")
      ;;
    file-missing)
      echo "  FAIL  /boot/vmlinuz-$(uname -r) not found."
      SAFE_FAILS+=("/boot/vmlinuz-$(uname -r) is missing")
      ;;
    *)
      echo "  UNVERIFIED  sbverify is not installed, so the signature cannot be checked."
      echo "              Install sbsigntools to make this item verifiable."
      SAFE_FAILS+=("sbverify not installed; kernel signature unverified")
      ;;
  esac

  echo
  echo "[4/5] Secure Boot"
  case "$(secure_boot_state)" in
    enabled)
      echo "  OK    Secure Boot is enabled (kernel signatures are enforced)."
      ;;
    disabled)
      echo "  WARN  Secure Boot is disabled — nothing here blocks booting, but the"
      echo "        signature checks above matter less while it stays off."
      ;;
    *)
      echo "  UNVERIFIED  neither mokutil nor efivarfs reported a Secure Boot state."
      echo "              Install mokutil to make this item verifiable."
      SAFE_FAILS+=("Secure Boot state unverified (install mokutil)")
      ;;
  esac

  echo
  echo "[5/5] MediaTek MT7902 (mt7921e) ASPM workaround"
  if mt7921e_present; then
    echo "  Interface/driver: in use."
    if mt7921e_conf_has_disable_aspm; then
      if mt7921e_conf_managed; then
        echo "  OK    $MT7921E_CONF is script-managed and sets disable_aspm=1."
      else
        echo "  OK    $MT7921E_CONF sets disable_aspm=1 (not script-managed; left alone)."
      fi
      if [[ "$(mt7921e_disable_aspm_live)" == "unavailable" ]]; then
        echo "  NOTE  The running module does not expose disable_aspm; the file applies"
        echo "        on the next boot."
      fi
    else
      echo "  FAIL  mt7921e is in use but $MT7921E_CONF does not set disable_aspm=1 —"
      echo "        expect Wi-Fi disconnects/packet loss."
      echo "        Fix: sudo bash $SCRIPT_PATH --with-mt7921e-aspm"
      SAFE_FAILS+=("mt7921e ASPM workaround missing: $MT7921E_CONF without disable_aspm=1")
    fi
  else
    echo "  N/A   mt7921e is not loaded and no interface is bound; nothing to check."
  fi

  echo
  echo "===================================================="
  if (( ${#SAFE_FAILS[@]} == 0 )); then
    echo "RESULT: OK — every critical item is present."
    echo "This machine is safe to reboot (and to install a new kernel)."
    echo "===================================================="
    return 0
  fi
  echo "RESULT: ${#SAFE_FAILS[@]} critical item(s) missing or unverified —"
  echo "DO NOT REBOOT until these are resolved:"
  local sf
  for sf in ${SAFE_FAILS[@]+"${SAFE_FAILS[@]}"}; do
    echo "  - $sf"
  done
  echo "===================================================="
  return 1
}

# ---- Pre-root read-only commands -------------------------------------------

if [[ "$HELP_REQUESTED" == true ]]; then
  usage
  exit 0
fi

if [[ "$VERSION_REQUESTED" == true ]]; then
  echo "$SCRIPT_NAME version $SCRIPT_VERSION (JSON schema $SCRIPT_SCHEMA)"
  exit 0
fi

if [[ "$STATUS_JSON" == true ]]; then
  show_status_json
  exit 0
fi

if [[ "$STATUS_MODE" == true ]]; then
  show_status_dashboard
  exit 0
fi

# v15.3 (I-34): read-only boot-integrity gate; exit 1 when something critical
# is missing so a "should I reboot?" question gets a hard yes/no.
if [[ "$SAFE_MODE_CHECK" == true ]]; then
  if safe_mode_check; then
    exit 0
  else
    exit 1
  fi
fi

# ---- Value validation ------------------------------------------------------

if [[ -n "$BATTERY_LIMIT" && "$BATTERY_LIMIT" != "off" ]]; then
  if [[ ! "$BATTERY_LIMIT" =~ ^[0-9]+$ ]] ||
     (( 10#$BATTERY_LIMIT < 20 || 10#$BATTERY_LIMIT > 100 )); then
    echo "Invalid --battery-limit value: '$BATTERY_LIMIT' (expected an integer 20-100, or 'off')." >&2
    exit 2
  fi
fi

case "$MAINTENANCE_SCHEDULE" in
  weekly|monthly) ;;
  *)
    echo "Invalid --maintenance-schedule value: '$MAINTENANCE_SCHEDULE' (expected weekly or monthly)." >&2
    exit 2
    ;;
esac

if [[ -n "$FAN_PROFILE" ]]; then
  case "$FAN_PROFILE" in
    quiet|balanced|performance) ;;
    *)
      echo "Invalid --fan-profile value: '$FAN_PROFILE' (expected quiet, balanced, or performance)." >&2
      exit 2
      ;;
  esac
fi

if [[ -n "$EPP_PROFILE" ]]; then
  case "$EPP_PROFILE" in
    performance|balance_performance|balance_power|power) ;;
    *)
      echo "Invalid --epp value: '$EPP_PROFILE'." >&2
      echo "Expected performance, balance_performance, balance_power, or power." >&2
      exit 2
      ;;
  esac
fi

if [[ -n "$PL1" ]]; then
  if [[ ! "$PL1" =~ ^[0-9]+$ ]] || (( 10#$PL1 <= 0 || 10#$PL1 > 300 )); then
    echo "Invalid --pl1 value: '$PL1' (expected an integer 1-300, in watts)." >&2
    exit 2
  fi
fi

if [[ -n "$PL2" ]]; then
  if [[ ! "$PL2" =~ ^[0-9]+$ ]] || (( 10#$PL2 <= 0 || 10#$PL2 > 300 )); then
    echo "Invalid --pl2 value: '$PL2' (expected an integer 1-300, in watts)." >&2
    exit 2
  fi
fi

if [[ -n "$PL1" && -n "$PL2" ]]; then
  if (( 10#$PL1 > 10#$PL2 )); then
    echo "Invalid --pl1/--pl2 combination: PL1 ($PL1 W) must not exceed PL2 ($PL2 W)." >&2
    exit 2
  fi
fi

# v15.3 (I-05): power-profiles-daemon holds exactly ONE profile. Both
# --fan-profile and --epp translate to PPD profiles, so requesting two
# different ones would silently collapse to whichever helper ran last. Detect
# and refuse that here, before any mutation. (Read-only detection; safe in
# --dry-run, which reaches this point.)
if [[ -n "$FAN_PROFILE" && -n "$EPP_PROFILE" ]]; then
  detect_power_managers
  if [[ "$PPD_ACTIVE" == true ]]; then
    PPD_REQ_THERMAL="$(ppd_profile_for_thermal "$FAN_PROFILE")"
    PPD_REQ_EPP="$(ppd_profile_for_epp "$EPP_PROFILE")"
    if [[ "$PPD_REQ_THERMAL" != "$PPD_REQ_EPP" ]]; then
      echo "ERROR: --fan-profile=$FAN_PROFILE and --epp=$EPP_PROFILE cannot both hold." >&2
      echo "       power-profiles-daemon is active and holds exactly one profile:" >&2
      echo "       --fan-profile=$FAN_PROFILE maps to PPD '$PPD_REQ_THERMAL'," >&2
      echo "       --epp=$EPP_PROFILE maps to PPD '$PPD_REQ_EPP'." >&2
      echo "       Choose one of them, or mask PPD with --disable-ppd." >&2
      exit 2
    fi
  fi
fi

# ---- Root / environment checks ---------------------------------------------

# --dry-run is intentionally permitted unprivileged: it only prints planned
# actions, and the execution-lock acquisition below is already skipped in
# dry-run mode.
if [[ "$DRY_RUN" != true && $EUID -ne 0 ]]; then
  echo "Please run with sudo: sudo bash $SCRIPT_PATH" >&2
  exit 1
fi

if ! command -v apt-get &>/dev/null; then
  echo "This script targets Debian/Ubuntu (apt-get not found). Aborting." >&2
  exit 1
fi

if ! grep -q GenuineIntel /proc/cpuinfo 2>/dev/null; then
  echo "This script targets Intel hardware. CPU vendor check failed — aborting." >&2
  exit 1
fi

if [[ -r /sys/class/dmi/id/sys_vendor ]]; then
  VENDOR="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
  if [[ -n "$VENDOR" && "$VENDOR" != *ASUS* && "$VENDOR" != *ASUSTeK* ]]; then
    echo "NOTE: DMI reports vendor '$VENDOR', not ASUS. This script was written for"
    echo "the Vivobook X1605VA specifically — continuing, but double-check relevance."
  fi
fi

# ---- Non-blocking execution lock -------------------------------------------

# A preview must not create/truncate the live execution lock file.
if [[ "$DRY_RUN" != true ]]; then
  exec 8>/run/vivobook-optimize.lock
  if ! flock -n 8; then
    echo "Another vivobook-optimize instance is already running; exiting." >&2
    exit 1
  fi
fi

# ---- Dry-run mode: override destructive commands to print-only -------------

if [[ "$DRY_RUN" == true ]]; then
  echo "=== DRY RUN MODE ==="
  echo "Parsed flags: guc=$WITH_GUC"
  echo "  auto-upgrade=$WITH_AUTO_UPGRADE maintenance-schedule=$MAINTENANCE_SCHEDULE"
  echo "  multiverse=$WITH_MULTIVERSE battery-limit=${BATTERY_LIMIT:-unchanged}"
  echo "  sysctl=$WITH_SYSCTL audio-powersave=$WITH_AUDIO_POWERSAVE"
  echo "  fan-profile=${FAN_PROFILE:-unchanged} epp=${EPP_PROFILE:-unchanged}"
  echo "  zram=$WITH_ZRAM"
  echo "  auto-power=$WITH_AUTO_POWER pl1=${PL1:-unchanged} pl2=${PL2:-unchanged}"
  echo "  kbd-timeout=$WITH_KBD_TIMEOUT"
  echo "  bbr=$WITH_BBR browser-wayland=$WITH_BROWSER_WAYLAND"
  echo "  usb-autosuspend=$WITH_USB_AUTOSUSPEND disable-ppd=$DISABLE_PPD"
  echo "  force-tlp-override=$FORCE_TLP_OVERRIDE"
  echo "  skip-update=$SKIP_UPDATE full-upgrade=$WITH_FULL_UPGRADE"
  echo ""

  # Override file-writing functions
  atomic_write() {
    local dest="$1" mode="$2"
    echo "[DRY-RUN] -> Write file: $dest (mode $mode)"
    local line
    while IFS= read -r line; do
      echo "[DRY-RUN]   | $line"
    done
  }

  write_unit_file() {
    local dest="$1" mode="$2"
    echo "[DRY-RUN] -> Install systemd unit: $dest (mode $mode)"
    local line
    while IFS= read -r line; do
      echo "[DRY-RUN]   | $line"
    done
  }

  # Override destructive system commands (v15.2 audit):
  # Mutating systemctl verbs are simulated. Read-only queries (is-active,
  # is-enabled, is-masked, list-unit-files, show, list-timers, status, cat)
  # PASS THROUGH to the real systemctl so skip/gate/report logic behaves
  # exactly like a real run instead of assuming "everything enabled".
  systemctl() {
    case "${1:-}" in
      enable|disable|mask|unmask|start|stop|restart|try-restart|reload|reload-or-restart|reenable|daemon-reload|preset|edit|set-property|halt|poweroff|reboot)
        echo "[DRY-RUN] systemctl $*"
        ;;
      *)
        command systemctl "$@"
        ;;
    esac
  }
  apt-get() { echo "[DRY-RUN] apt-get $*"; }
  # sysctl: only writers are simulated; readers (-n etc.) pass through.
  sysctl() {
    local sa
    for sa in "$@"; do
      case "$sa" in
        -w|--write|--system|-p|--load)
          echo "[DRY-RUN] sysctl $*"
          return 0
          ;;
      esac
    done
    command sysctl "$@"
  }
  udevadm() { echo "[DRY-RUN] udevadm $*"; }
  fwupdmgr() { echo "[DRY-RUN] fwupdmgr $*"; }
  snap() { echo "[DRY-RUN] snap $*"; }
  flatpak() { echo "[DRY-RUN] flatpak $*"; }
  runuser() { echo "[DRY-RUN] runuser $*"; }
  modprobe() { echo "[DRY-RUN] modprobe $*"; }
  install() { echo "[DRY-RUN] install $*"; }
  # rm: report only paths that actually exist ("would remove"), and say
  # explicitly when the call is a no-op — never claim a removal happened.
  rm() {
    local args=() arg t
    for arg in "$@"; do
      [[ "$arg" == -* ]] && continue
      args+=("$arg")
    done
    for t in ${args[@]+"${args[@]}"}; do
      if [[ -e "$t" || -L "$t" ]]; then
        echo "[DRY-RUN] Would remove: $t"
      else
        echo "[DRY-RUN] rm $t (not present — no-op)"
      fi
    done
    return 0
  }
  mv() { echo "[DRY-RUN] mv $1 $2"; }
  sed() {
    local inplace=false args=()
    for arg in "$@"; do
      [[ "$arg" == "-i" ]] && inplace=true && continue
      args+=("$arg")
    done
    if [[ "$inplace" == true ]]; then
      echo "[DRY-RUN] sed -i (in-place edit) with args: ${args[*]}"
    else
      command sed "$@"
    fi
  }
  flock() { return 0; }
  update-initramfs() { echo "[DRY-RUN] update-initramfs $*"; }
  swapoff() { echo "[DRY-RUN] swapoff $*"; }
  chmod() { echo "[DRY-RUN] chmod $*"; }
  chown() { echo "[DRY-RUN] chown $*"; }
  add-apt-repository() { echo "[DRY-RUN] add-apt-repository $*"; }

  echo "Simulated actions follow; nothing below is applied."
  echo ""
fi

if [[ "$RESTORE_DEFAULTS" == true ]]; then
  restore_defaults
  log_summary "$@"
  # v15.3 (I-12): the closing banner is printed at the END of the output. v15.2
  # printed it here — before hundreds of simulated "[DRY-RUN] -> Write file"
  # lines — where it read as a claim about actions that had not been shown yet.
  if [[ "$DRY_RUN" == true ]]; then
    echo "=== END DRY RUN — no files were modified. ==="
  fi
  exit 0
fi

# ---- Power-management ownership report (v15.2) ------------------------------
# Read-only detection: safe on every path that reaches this point, including
# --dry-run. Read-only modes (--help/--status/--status-json/--check) and
# --restore-defaults all return before this block and are NEVER gated by TLP.
detect_power_managers
echo "== Power-management ownership (TLP / power-profiles-daemon / thermald) =="
echo "   TLP: present=$TLP_PRESENT active=$TLP_ACTIVE${TLP_VERSION:+ version=$TLP_VERSION}"
echo "   power-profiles-daemon: active=$PPD_ACTIVE (helpers delegate via powerprofilesctl when active)"
echo "   thermald: active=$THERMALD_ACTIVE (thermal policy left to thermald)"
if [[ "$TLP_ACTIVE" == true ]]; then
  if [[ "$FORCE_TLP_OVERRIDE" == true ]]; then
    echo "   WARNING: --force-tlp-override given — power-policy steps will proceed"
    echo "   despite active TLP. Two managers will write the same knobs; consider"
    echo "   disabling the corresponding TLP features instead."
  else
    echo "   TLP is ACTIVE: script power-policy steps (audio power_save defaults,"
    echo "   ASUS battery charge threshold, thermal platform profile, CPU EPP,"
    echo "   USB runtime autosuspend) will be SKIPPED — TLP owns those domains."
    echo "   --with-auto-power is REFUSED outright under TLP at any time."
    echo "   All unrelated steps (updates, thermald, fstrim, microcode, VA-API,"
    echo "   i915 cleanup, maintenance, sysctl, BBR, zram, browser, kbd, RAPL)"
    echo "   continue normally."
  fi
fi

export DEBIAN_FRONTEND=noninteractive
APT_OPTS=(-y -o Dpkg::Options::=--force-confold -o DPkg::Lock::Timeout=600)

# ---- 1-3. Update block (optional skip) -------------------------------------

if [[ "$SKIP_UPDATE" == true ]]; then
  echo "== 1-3. Skipping update/fwupd/snap/flatpak (--skip-update) =="
else
  echo "== 1. Full system update (manual, supervised run) =="
  apt-get -o DPkg::Lock::Timeout=600 update
  if [[ "$WITH_FULL_UPGRADE" == true ]]; then
    apt-get "${APT_OPTS[@]}" full-upgrade
  else
    apt-get "${APT_OPTS[@]}" upgrade
  fi
  # Never run apt autoremove automatically: custom/mainline kernels may not be
  # protected by a distro kernel meta-package and can therefore be orphaned.
  # Kernel cleanup, when /boot is pressured, is a separate supervised action.
  apt-get "${APT_OPTS[@]}" autoclean

  review_kernel_purge() {
    local boot_pct="$1" running_kver installed candidates keep_vers kver
    running_kver="$(uname -r)"

    echo "   /boot is ${boot_pct}% full${BOOT_FS_NOTE:-} — reviewing installed kernel images."

    installed="$({
      dpkg-query -W -f='${binary:Package} ${Status}\n' 'linux-image*' 2>/dev/null || true
    } | awk '$2=="install" && $3=="ok" && $4=="installed" {print $1}' | sort -u)"

    # Identify all installed kernel ABI versions sorted newest to oldest.
    # v15.2 fix: v15.1 piped 'sort -V -r' into 'sort -u', and the second sort
    # RE-SORTED lexicographically, destroying the version order (e.g. keeping
    # 6.12+6.6 as "newest" fallbacks while offering 6.8 for purge). Dedupe
    # with awk instead so version order is preserved exactly.
    local sorted_versions
    sorted_versions="$(printf '%s\n' "$installed" | sed -n -E 's/^linux-image-(unsigned-)?([0-9].*)$/\2/p' | sort -Vr | awk '!seen[$0]++')"

    # Preserve the running kernel plus the two newest other installed kernels.
    keep_vers=("$running_kver")
    local fallbacks_kept=0
    for kver in $sorted_versions; do
      [[ "$kver" == "$running_kver" ]] && continue
      keep_vers+=("$kver")
      fallbacks_kept=$((fallbacks_kept + 1))
      (( fallbacks_kept >= 2 )) && break
    done

    # v15.2: if ANY installed kernel image package cannot be mapped to a
    # numeric ABI version, the whole purge becomes guesswork -> skip it.
    local mapping_ok=true
    candidates=""
    while IFS= read -r pkg; do
      [[ -n "$pkg" ]] || continue
      local ver=""
      case "$pkg" in
        linux-image-unsigned-*) ver="${pkg#linux-image-unsigned-}" ;;
        linux-image-*) ver="${pkg#linux-image-}" ;;
        *) continue ;;
      esac
      if [[ ! "$ver" =~ ^[0-9] ]]; then
        case "$pkg" in
          # Versionless meta-packages are expected and safe to ignore.
          linux-image-generic|linux-image-virtual|linux-image-lowlatency|linux-image-oem-*|linux-image-unsigned) : ;;
          *)
            echo "   Cannot map kernel package '$pkg' to a version — refusing to guess." >&2
            mapping_ok=false
            ;;
        esac
        continue
      fi

      local protect=false
      for kv in "${keep_vers[@]}"; do
        if [[ "$ver" == "$kv" ]]; then
          protect=true
          break
        fi
      done
      if [[ "$protect" == false ]]; then
        candidates+="$pkg"$'\n'
        for pfx in linux-modules linux-modules-extra linux-headers; do
          if dpkg-query -W -f='${Status}\n' "${pfx}-${ver}" 2>/dev/null | grep -qx 'install ok installed'; then
            candidates+="${pfx}-${ver}"$'\n'
          fi
        done
        # v15.3 (I-15): mainline kernels also install the arch-INDEPENDENT
        # linux-headers-<base> package (no -generic flavour suffix), which the
        # ${pfx}-${ver} loop above can never match, leaving it orphaned after a
        # purge. Add it when it is installed and no KEPT kernel shares its
        # base version.
        if [[ "$ver" == *-* ]]; then
          local base="${ver%-*}" base_shared=false kb
          for kb in "${keep_vers[@]}"; do
            if [[ "${kb%-*}" == "$base" ]]; then
              base_shared=true
              break
            fi
          done
          if [[ "$base_shared" == false ]] &&
             dpkg-query -W -f='${Status}\n' "linux-headers-${base}" 2>/dev/null | grep -qx 'install ok installed'; then
            candidates+="linux-headers-${base}"$'\n'
          fi
        fi
      fi
    done <<< "$installed"

    if [[ "$mapping_ok" != true ]]; then
      echo "   Kernel purge SKIPPED: unresolved package-to-version mapping above." >&2
      echo "   Nothing was removed; inspect manually with: dpkg -l 'linux-image*'" >&2
      return 0
    fi

    candidates="$(printf '%s' "$candidates" | sed '/^$/d' | sort -u)"
    if [[ -z "$candidates" ]]; then
      echo "   No obsolete kernel packages eligible for supervised purge (retaining running + 2 fallbacks)."
      return 0
    fi

    echo "   Obsolete kernel packages eligible for purge (retaining running + 2 fallbacks):"
    echo "$candidates" | sed 's/^/     /'
    # v15.3 (I-28): never block on a prompt in dry-run — report it and skip.
    if [[ "$DRY_RUN" == true ]]; then
      echo "[DRY-RUN] Would prompt: Type PURGE-KERNELS to purge the listed packages."
      echo "[DRY-RUN] Non-interactive dry-run: taking the skip path; nothing is purged."
      return 0
    fi
    if [[ ! -t 0 || ! -t 1 ]]; then
      echo "   Non-interactive execution detected; kernel purge skipped." >&2
      return 0
    fi

    local confirmation=""
    if ! read -r -p "   Type PURGE-KERNELS to purge the listed packages: " confirmation; then
      echo ""
      echo "   No confirmation received (input closed); kernel purge skipped."
      return 0
    fi
    if [[ "$confirmation" != "PURGE-KERNELS" ]]; then
      echo "   Kernel purge cancelled; no packages were removed."
      return 0
    fi

    # shellcheck disable=SC2086
    apt-get "${APT_OPTS[@]}" purge $candidates ||
      echo "   WARNING: supervised kernel purge encountered errors; inspect apt output." >&2
  }

  BOOT_PCT="$(df --output=pcent /boot 2>/dev/null | tail -1 | tr -dc '0-9' || true)"
  # v15.3 (I-28): when /boot is not a separate mount, df reports the root
  # filesystem — say so instead of implying a dedicated /boot partition.
  BOOT_FS_NOTE=""
  if [[ -d /boot ]]; then
    if command -v mountpoint >/dev/null 2>&1; then
      mountpoint -q /boot 2>/dev/null || BOOT_FS_NOTE=" (on root filesystem)"
    elif [[ "$(stat -c %d /boot 2>/dev/null || echo a)" == "$(stat -c %d / 2>/dev/null || echo b)" ]]; then
      BOOT_FS_NOTE=" (on root filesystem)"
    fi
  fi
  if [[ "$BOOT_PCT" =~ ^[0-9]+$ ]] && (( BOOT_PCT > 75 )); then
    review_kernel_purge "$BOOT_PCT"
  elif [[ "$BOOT_PCT" =~ ^[0-9]+$ ]]; then
    echo "   /boot usage: ${BOOT_PCT}%${BOOT_FS_NOTE} (supervised kernel purge threshold is 75%)."
  fi

  HELD="$(apt list --upgradable 2>/dev/null | grep -v '^Listing' || true)"
  if [[ -n "$HELD" ]]; then
    echo "   NOTE: packages remain upgradable (could be phasing, holds, dependency"
    echo "   transitions, or packages needing a full-upgrade — not necessarily just"
    echo "   a held-back kernel):"
    echo "$HELD" | sed 's/^/     /'
    echo "   Check explicit holds with: apt-mark showhold"
  fi

  echo "== 2. Firmware metadata refresh (updates applied only with --with-auto-upgrade) =="
  apt-get "${APT_OPTS[@]}" install fwupd
  fwupdmgr refresh --force || true
  fwupdmgr get-updates || true
  if [[ "$WITH_AUTO_UPGRADE" == true ]]; then
    echo "   --with-auto-upgrade given: applying available firmware updates via fwupd."
    echo "   (Some updates stage for the next reboot; do not power off mid-flash.)"
    fwupdmgr update -y --no-reboot-check ||
      echo "   NOTE: fwupdmgr update returned non-zero (often 'nothing to do' or a"\
           "device that needs AC power / a reboot). Review output above."
  else
    echo "   -> Review output above; run 'sudo fwupdmgr update' manually if you want to apply,"
    echo "      or re-run with --with-auto-upgrade to have this pass apply them."
  fi

  echo "== 3. Snap / Flatpak / developer runtime updates =="
  if command -v snap &>/dev/null; then
    snap refresh || true
  fi
  if command -v flatpak &>/dev/null; then
    flatpak update -y || true
    echo "   NOTE: this updated the SYSTEM flatpak installation only. If you have"
    echo "   user-scoped (--user) flatpaks, update those yourself as your normal user:"
    echo "     flatpak --user update -y"
    echo "   (The maintenance timer configured in step 10 now also sweeps"
    echo "    per-user flatpak installations automatically.)"
  fi

  # Developer runtimes: pipx-managed tools for each real user session
  if command -v runuser &>/dev/null; then
    PIPX_USERS=0
    while IFS=: read -r U_NAME _ U_UID _ _ U_HOME U_SHELL; do
      [[ "$U_UID" =~ ^[0-9]+$ ]] || continue
      (( U_UID >= 1000 && U_UID < 65000 )) || continue
      case "$U_SHELL" in
        */nologin|*/false|"") continue ;;
      esac
      [[ -n "$U_HOME" && -d "$U_HOME" ]] || continue
      [[ -d "$U_HOME/.local/share/pipx/venvs" || -d "$U_HOME/.local/pipx/venvs" ]] || continue
      PIPX_BIN=""
      if [[ -x "$U_HOME/.local/bin/pipx" ]]; then
        PIPX_BIN="$U_HOME/.local/bin/pipx"
      elif command -v pipx &>/dev/null; then
        PIPX_BIN="$(command -v pipx)"
      fi
      [[ -n "$PIPX_BIN" ]] || continue
      PIPX_USERS=$((PIPX_USERS + 1))
      echo "   Upgrading pipx-managed tools for: $U_NAME"
      runuser -u "$U_NAME" -- env \
        HOME="$U_HOME" \
        PATH="$U_HOME/.local/bin:/usr/local/bin:/usr/bin:/bin" \
        "$PIPX_BIN" upgrade-all ||
        echo "   WARNING: pipx upgrade-all failed for $U_NAME (continuing)."
    done < /etc/passwd
    if (( PIPX_USERS == 0 )); then
      echo "   No per-user pipx installations detected; nothing to upgrade."
    fi
  else
    echo "   NOTE: 'runuser' not available — skipping per-user pipx upgrades."
  fi
  if command -v npm &>/dev/null; then
    echo "   NOTE: a global npm is installed. This script does not run 'npm update -g'"
    echo "   automatically (version pins are common); run it yourself if desired."
  fi
fi

echo "== 4. thermald =="
apt-get "${APT_OPTS[@]}" install thermald
systemctl enable --now thermald

echo "== 5. powertop (interactive diagnostics only) =="
apt-get "${APT_OPTS[@]}" install powertop
# powertop --auto-tune blanket-overrides runtime PM for all PCI/USB devices and
# conflicts with kernel/desktop power management; the autotune service is not
# enabled. Remove any unit left over from an earlier --with-powertop run.
systemctl disable --now powertop-autotune.service 2>/dev/null || true
rm -f /etc/systemd/system/powertop-autotune.service
systemctl daemon-reload
echo "   powertop installed for interactive, read-only diagnostics: sudo powertop"
echo "   powertop-autotune.service is not enabled (removed if previously installed)."

echo "== 6. NVMe TRIM — weekly timer =="
systemctl enable --now fstrim.timer

echo "== 7. CPU microcode =="
apt-get "${APT_OPTS[@]}" install intel-microcode

echo "== 8. Intel VA-API / QuickSync =="
MULTIVERSE_ENABLED_NOW=false
if ! package_has_candidate intel-media-va-driver-non-free; then
  OS_ID=""
  [[ -r /etc/os-release ]] &&
    OS_ID="$(. /etc/os-release 2>/dev/null; echo "${ID:-}${ID_LIKE:+ $ID_LIKE}")"
  if [[ "$OS_ID" != *ubuntu* ]]; then
    echo "   'intel-media-va-driver-non-free' has no candidate and this does not look like"
    echo "   Ubuntu (os-release: '${OS_ID:-unknown}') — not touching repository configuration."
  elif ! command -v add-apt-repository &>/dev/null; then
    echo "   'intel-media-va-driver-non-free' has no candidate and add-apt-repository is"
    echo "   missing. Install it and re-run if you want the non-free codecs:"
    echo "     sudo apt-get install software-properties-common"
    echo "     sudo add-apt-repository multiverse && sudo apt-get update"
  else
    DO_MULTIVERSE=false
    if [[ "$WITH_MULTIVERSE" == true ]]; then
      DO_MULTIVERSE=true
      echo "   --with-multiverse given: enabling the 'multiverse' component."
    elif [[ "$DRY_RUN" == true ]]; then
      echo "[DRY-RUN] Would prompt: Enable the 'multiverse' repository component now? [y/N]"
      echo "[DRY-RUN] Non-interactive dry-run: taking the skip path (no repository changes)."
    elif [[ -t 0 ]]; then
      echo "   The non-free Intel VA-API driver is not available in your enabled repos."
      echo "   It ships in Ubuntu's 'multiverse' component and provides the fuller codec"
      echo "   set (e.g. hardware HEVC/AV1 paths) for QuickSync on this iGPU."
      REPLY_MV=""
      read -r -p "   Enable the 'multiverse' repository component now? [y/N] " REPLY_MV ||
        REPLY_MV="n"
      case "$REPLY_MV" in
        [yY]|[yY][eE][sS]) DO_MULTIVERSE=true ;;
        *) echo "   Declined — continuing with whatever driver is available." ;;
      esac
    else
      echo "   Non-interactive session and --with-multiverse not given: leaving repository"
      echo "   configuration untouched. Re-run with --with-multiverse to enable multiverse."
    fi

    if [[ "$DO_MULTIVERSE" == true ]]; then
      if add-apt-repository -y multiverse; then
        apt-get -o DPkg::Lock::Timeout=600 update
        MULTIVERSE_ENABLED_NOW=true
        if [[ "$DRY_RUN" == true ]]; then
          echo "[DRY-RUN] Would enable 'multiverse' and refresh package lists."
        else
          echo "   'multiverse' enabled and package lists refreshed."
        fi
      else
        echo "   WARNING: 'add-apt-repository -y multiverse' failed — continuing without it." >&2
      fi
    fi
  fi
fi

VA_PKG=""
if package_has_candidate intel-media-va-driver-non-free; then
  VA_PKG=intel-media-va-driver-non-free
elif package_has_candidate intel-media-va-driver; then
  VA_PKG=intel-media-va-driver
  echo "   NOTE: non-free VA-API driver unavailable in enabled repos; using free variant"
  echo "   (lacks some codec support, e.g. hardware AV1/HEVC encode)."
else
  echo "   WARNING: no Intel VA-API driver package has an installable candidate in"
  echo "   your enabled repos. Skipping. Check: sudo add-apt-repository multiverse"
fi
if [[ -n "$VA_PKG" ]]; then
  apt-get "${APT_OPTS[@]}" install "$VA_PKG" vainfo
  echo "   Package installed. Already-running apps (esp. browsers) may need a restart"
  echo "   to pick up hardware video acceleration."
  [[ "$MULTIVERSE_ENABLED_NOW" == true ]] &&
    echo "   (multiverse was enabled during this run to obtain: $VA_PKG)"
fi

echo "== 9. i915 legacy config cleanup + Intel DRM / GuC-HuC diagnostics =="
# Proactively remove /etc/modprobe.d/vivobook-i915.conf staged by older script
# versions (deprecated enable_guc=3 / enable_dc=2 / enable_fbc=1 / enable_psr=1
# parameters), even without --with-guc: those parameters persist across reboots
# and stay baked into the initramfs until removed. Safe no-op when the file is
# absent or was not script-managed.
remove_i915_conf
if [[ "$I915_CONF_REMOVED" == true ]]; then
  echo "   Removed stale /etc/modprobe.d/vivobook-i915.conf (deprecated i915 module parameters)."
fi
if [[ "$WITH_GUC" == true ]]; then
  GPU_DRIVER="$(detect_active_drm_driver)"

  case "$GPU_DRIVER" in
    xe)
      echo "   Kernel is using the 'xe' driver, not i915 — enable_guc is not applicable."
      echo "   GuC submission and HuC authentication are enabled by default on Gen12+;"
      echo "   this script does not stage i915 modprobe parameters (kernel defaults apply)."
      ;;
    i915)
      CURRENT_GUC="$(cat /sys/module/i915/parameters/enable_guc 2>/dev/null || echo unknown)"
      echo "   Current enable_guc value: ${CURRENT_GUC} (-1 = auto policy, not 'disabled')"
      echo "   Kernel GuC/HuC log lines:"
      dmesg 2>/dev/null |
        grep -iE 'GuC firmware|HuC firmware' |
        sed 's/^/     /' ||
        echo "     (none found in current dmesg buffer)"

      EXPLICIT_MODPROBE=false
      if grep -RhsE '^[[:space:]]*options[[:space:]].*\benable_guc=' \
        /etc/modprobe.d --include='*.conf' &>/dev/null; then
        EXPLICIT_MODPROBE=true
      fi
      EXPLICIT_CMDLINE=false
      if grep -qwE 'i915\.enable_guc=[^[:space:]]+' /proc/cmdline 2>/dev/null; then
        EXPLICIT_CMDLINE=true
      fi

      if $EXPLICIT_MODPROBE || $EXPLICIT_CMDLINE; then
        echo "   enable_guc is already explicitly configured (modprobe.d: $EXPLICIT_MODPROBE,"
        echo "   kernel cmdline: $EXPLICIT_CMDLINE) — leaving as-is."
      else
        echo "   No explicit override found; value is on auto policy (-1)."
        echo "   Auto (-1) does NOT mean GuC/HuC is off — it means kernel-chosen default,"
        echo "   and GuC submission/HuC authentication are enabled by default on Gen12+."
        echo "   This script no longer stages i915 modprobe parameters or rebuilds the"
        echo "   initramfs; the kernel default policy is retained."
      fi
      ;;
    *)
      echo "   Could not confirm i915 or xe as the active driver on any /sys/class/drm/card*."
      echo "   Skipping to avoid misconfiguring an unrelated driver."
      ;;
  esac
else
  echo "   Skipped. Re-run with --with-guc for read-only DRM/GuC/HuC diagnostics."
fi

# Rebuild all initramfs images when a deprecated modprobe config was removed
# above, so the stale i915 parameters disappear from the boot images too.
# Skipped entirely when nothing was removed.
if [[ "$I915_CONF_REMOVED" == true ]]; then
  if command -v update-initramfs >/dev/null 2>&1; then
    echo "   Rebuilding initramfs images to purge deprecated i915 parameters..."
    if update-initramfs -u -k all; then
      echo "   initramfs rebuilt; deprecated i915 parameters no longer staged in boot images."
    else
      echo "   WARNING: update-initramfs -u -k all failed; deprecated i915" >&2
      echo "   parameters may remain in existing initramfs images." >&2
    fi
  else
    echo "   NOTE: update-initramfs not available; rebuild the initramfs with your"
    echo "   distro tool (e.g. dracut -f) to purge the deprecated i915 parameters."
  fi
fi

echo "== 10. Automated maintenance (${MAINTENANCE_SCHEDULE}) =="
atomic_write /usr/local/bin/system-maintenance.sh 0755 << 'MAINTENANCE_EOF'
#!/usr/bin/env bash
# Managed by vivobook_optimize.sh v15.3
set -Eeuo pipefail

exec 9>/run/system-maintenance.lock
flock -n 9 || { echo "Another maintenance run is already in progress. Exiting."; exit 0; }

export DEBIAN_FRONTEND=noninteractive

JOURNAL_VACUUM_TIME="2weeks"
JOURNAL_VACUUM_SIZE="500M"

# v15.2: classify the outcome explicitly. Genuine failures are never hidden:
# the run ends FAILED (set -e), ends with NON-FATAL WARNINGS (network outage
# during apt-get update, a flaky flatpak remote, etc.), or fully SUCCEEDS.
WARN_COUNT=0
SUCCESS=false
trap '
  rc=$?
  if [[ "$SUCCESS" == true ]] && (( WARN_COUNT == 0 )); then
    echo "=== Completed successfully: $(date) ==="
  elif [[ "$SUCCESS" == true ]]; then
    echo "=== Completed with ${WARN_COUNT} non-fatal warning(s): $(date) ==="
  else
    echo "=== FAILED: $(date), exit $rc ==="
  fi
' EXIT

warn() {
  WARN_COUNT=$((WARN_COUNT + 1))
  echo "   WARNING: $*" >&2
}

echo "=== Starting Maintenance: $(date) ==="
if ! apt-get -o DPkg::Lock::Timeout=900 update; then
  warn "apt-get update failed (offline / mirror error?) — continuing independent maintenance steps."
fi

# Automated package upgrades and kernel pruning are intentionally NOT performed
# by this timer: standard security updates (including kernel management) are
# delegated to the distro's unattended-upgrades configuration.
echo "   (Skipping package upgrades/kernel pruning: standard security updates are"
echo "    handled by the distro's unattended-upgrades configuration.)"
apt-get -y autoclean || warn "apt-get autoclean failed"

if command -v flatpak &>/dev/null; then
  flatpak update -y || warn "system flatpak update failed"

  if command -v runuser &>/dev/null; then
    while IFS=: read -r U_NAME _ U_UID _ _ U_HOME U_SHELL; do
      [[ "$U_UID" =~ ^[0-9]+$ ]] || continue
      (( U_UID >= 1000 && U_UID < 65000 )) || continue
      case "$U_SHELL" in
        */nologin|*/false|"") continue ;;
      esac
      [[ -n "$U_HOME" && -d "$U_HOME" ]] || continue
      [[ -d "$U_HOME/.local/share/flatpak" ]] || continue
      if [[ ! -e "/run/user/$U_UID/bus" ]]; then
        echo "   Skipping user flatpak update for $U_NAME: D-Bus session bus is unavailable."
        continue
      fi
      echo "   Updating user-scoped flatpaks for: $U_NAME"
      runuser -u "$U_NAME" -- env \
        HOME="$U_HOME" \
        XDG_DATA_HOME="$U_HOME/.local/share" \
        XDG_CACHE_HOME="$U_HOME/.cache" \
        XDG_RUNTIME_DIR="/run/user/$U_UID" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$U_UID/bus" \
        flatpak --user update -y --noninteractive ||
        warn "user flatpak update failed for $U_NAME (continuing)"
    done < /etc/passwd
  else
    echo "   NOTE: 'runuser' not available — skipping per-user flatpak updates."
  fi
fi

# Developer runtimes: pipx-managed tools per user session
if command -v runuser &>/dev/null; then
  while IFS=: read -r U_NAME _ U_UID _ _ U_HOME U_SHELL; do
    [[ "$U_UID" =~ ^[0-9]+$ ]] || continue
    (( U_UID >= 1000 && U_UID < 65000 )) || continue
    case "$U_SHELL" in
      */nologin|*/false|"") continue ;;
    esac
    [[ -n "$U_HOME" && -d "$U_HOME" ]] || continue
    [[ -d "$U_HOME/.local/share/pipx/venvs" || -d "$U_HOME/.local/pipx/venvs" ]] || continue
    PIPX_BIN=""
    if [[ -x "$U_HOME/.local/bin/pipx" ]]; then
      PIPX_BIN="$U_HOME/.local/bin/pipx"
    elif command -v pipx &>/dev/null; then
      PIPX_BIN="$(command -v pipx)"
    fi
    [[ -n "$PIPX_BIN" ]] || continue
    echo "   Upgrading pipx-managed tools for: $U_NAME"
    runuser -u "$U_NAME" -- env \
      HOME="$U_HOME" \
      PATH="$U_HOME/.local/bin:/usr/local/bin:/usr/bin:/bin" \
      "$PIPX_BIN" upgrade-all ||
      warn "pipx upgrade-all failed for $U_NAME (continuing)"
  done < /etc/passwd
fi

if command -v fwupdmgr &>/dev/null; then
  fwupdmgr refresh || warn "fwupd metadata refresh failed"
  # Do not run fwupdmgr update unattended
fi

if command -v journalctl &>/dev/null; then
  echo "   Vacuuming journal (time > ${JOURNAL_VACUUM_TIME}, size > ${JOURNAL_VACUUM_SIZE})"
  journalctl --vacuum-time="${JOURNAL_VACUUM_TIME}" || warn "journal vacuum by time failed"
  journalctl --vacuum-size="${JOURNAL_VACUUM_SIZE}" || warn "journal vacuum by size failed"
  journalctl --disk-usage || true
fi

SUCCESS=true
MAINTENANCE_EOF

chmod 0755 /usr/local/bin/system-maintenance.sh

write_unit_file /etc/systemd/system/system-maintenance.service 0644 << 'EOF'
# Managed by vivobook_optimize.sh v15.3
[Unit]
Description=Automated System Maintenance and Updates
After=network-online.target
Wants=network-online.target
# v15.2: ConditionACPower=true removed. With a monthly timer it could skip
# maintenance indefinitely on an often-unplugged laptop; Persistent=true on
# the timer already reschedules runs missed while powered off, and the
# workload (update index refresh, autoclean, journal vacuum) is safe on
# battery and deliberately niced down.

[Service]
Type=oneshot
TimeoutStartSec=1h
Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=6
ExecStart=/usr/local/bin/system-maintenance.sh
StandardOutput=journal
StandardError=journal
EOF

# v15.3 (I-14): read the schedule the installed timer is CURRENTLY using before
# the unit file is rewritten. A no-change re-run must not restart the timer:
# restarting re-randomizes RandomizedDelaySec=1h and moves
# NextElapseUSecRealtime, so on a machine re-run more often than the schedule
# maintenance would never fire at all.
MAINT_TIMER_PREV=""
if [[ -f /etc/systemd/system/system-maintenance.timer ]]; then
  MAINT_TIMER_PREV="$(sed -n 's/^[[:space:]]*OnCalendar[[:space:]]*=[[:space:]]*//p' \
    /etc/systemd/system/system-maintenance.timer 2>/dev/null | head -1 | tr -d '[:space:]')"
fi

write_unit_file /etc/systemd/system/system-maintenance.timer 0644 << EOF
# Managed by vivobook_optimize.sh v15.3
[Unit]
Description=Run ${MAINTENANCE_SCHEDULE} system maintenance

[Timer]
OnCalendar=${MAINTENANCE_SCHEDULE}
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now system-maintenance.timer
if [[ "$MAINT_TIMER_PREV" != "$MAINTENANCE_SCHEDULE" ]]; then
  systemctl restart system-maintenance.timer
  echo "   Maintenance timer (re)started: schedule changed from '${MAINT_TIMER_PREV:-none}' to '${MAINTENANCE_SCHEDULE}'."
elif ! systemctl is-active --quiet system-maintenance.timer 2>/dev/null; then
  systemctl start system-maintenance.timer
  echo "   Maintenance timer already configured with the same schedule; started (it was inactive)."
else
  echo "   Maintenance timer already active with the same schedule; countdown preserved."
fi

echo ""
echo "   Maintenance timer configured. Schedule: $MAINTENANCE_SCHEDULE."
echo "   This value reflects only this run — re-run with a different"
echo "   --maintenance-schedule to change it later."
echo "   The timer never runs package upgrades, kernel purges, or firmware flashes:"
echo "   security updates are delegated to unattended-upgrades, and firmware"
echo "   updates require a supervised 'sudo fwupdmgr update' (only the metadata"
echo "   refresh runs unattended)."
echo "   Maintenance also vacuums the journal (2 weeks / 500M), upgrades pipx-managed"
echo "   tools, and updates per-user flatpak installations for accounts with"
echo "   UID >= 1000 and a real login shell."
echo "   Check status any time: journalctl -u system-maintenance.service"

echo "== 11. Kernel sysctl tuning (/etc/sysctl.d/99-vivobook.conf) =="
if [[ "$WITH_SYSCTL" == true ]]; then
  ZRAM_SWAPPINESS=10
  if [[ "$WITH_ZRAM" == true ]] ||
     [[ -f /etc/systemd/zram-generator.conf ]] ||
     [[ -f /usr/lib/systemd/zram-generator.conf ]] ||
     [[ -d /sys/block/zram0 ]] ||
     systemctl is-active --quiet systemd-zram-setup@zram0.service 2>/dev/null ||
     systemctl is-enabled --quiet zramswap.service 2>/dev/null; then
    ZRAM_SWAPPINESS=100
  fi
  atomic_write /etc/sysctl.d/99-vivobook.conf 0644 << EOF
# Managed by vivobook_optimize.sh v15.3 — safe, targeted desktop/laptop tuning.
# Use --restore-defaults to remove this file, reset writeback, and reapply distro sysctls.

# 16GB RAM: prefer keeping the working set resident, but do NOT disable swap
# pressure entirely (0/1 harms reclaim behaviour and hibernation headroom).
vm.swappiness = ${ZRAM_SWAPPINESS}

# IDEs, file managers, sync clients and dev tooling routinely exhaust the
# default watch limit; 524288 is the widely used desktop value.
fs.inotify.max_user_watches = 524288

# Disable NMI watchdog to reduce periodic CPU wakeups and save energy.
kernel.nmi_watchdog = 0

# Idle VM dirty page writeback interval extended to 15 seconds.
vm.dirty_writeback_centisecs = 1500
EOF
  chmod 0644 /etc/sysctl.d/99-vivobook.conf
  if sysctl --system > /dev/null; then
    echo "   Written and applied. Effective values now:"
    for k in vm.swappiness fs.inotify.max_user_watches kernel.nmi_watchdog vm.dirty_writeback_centisecs; do
      if sysctl -n "$k" &>/dev/null; then
        printf '     %s\n' "$(sysctl -n "$k" 2>/dev/null | sed "s|^|$k = |")"
      else
        printf '     %s = unavailable (optional kernel interface)\n' "$k"
      fi
    done
    echo "   NOTE: another file in /etc/sysctl.d/ that sorts AFTER 99-vivobook.conf"
    echo "   (or /etc/sysctl.conf semantics on some setups) can still override these."
  else
    echo "   WARNING: 'sysctl --system' reported an error; review output above." >&2
  fi
else
  echo "   Skipped (--no-sysctl). Existing /etc/sysctl.d/99-vivobook.conf, if any,"
  echo "   was left untouched."
fi

echo "== 11b. TCP BBR & Fair Queuing (/etc/sysctl.d/98-network-bbr.conf) =="
if [[ "$WITH_BBR" == true ]]; then
  # v15.2 ordering fix: v15.1 wrote /etc/modules-load.d/bbr.conf BEFORE the
  # support probe, leaving a dangling module-load file on kernels without BBR
  # (and with no managed marker, --restore-defaults could not remove it).
  # Sequence is now: detect -> attempt load -> verify -> only then persist.
  # v15.3 (I-11): probe read-only FIRST. In --dry-run, modprobe is a
  # print-only stub that returns 0, so probing it first made BBR look
  # supported even on kernels that do not ship tcp_bbr at all.
  BBR_SUPPORTED=false
  if grep -qw bbr /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
    BBR_SUPPORTED=true
  elif [[ "$DRY_RUN" == true ]]; then
    echo "   [DRY-RUN] tcp_bbr is not listed as available in the running kernel."
    echo "   [DRY-RUN] modprobe is NOT attempted in dry-run, so the enablement path is skipped."
  elif modprobe tcp_bbr 2>/dev/null; then
    BBR_SUPPORTED=true
  fi

  if [[ "$BBR_SUPPORTED" == true ]]; then
    # v15.3 (I-17): these two paths are generic (not namespaced), so an
    # existing unmanaged file must never be clobbered. Adoption is allowed
    # only when the stripped content is exactly what earlier versions of this
    # script wrote: 'tcp_bbr' for the modules-load file, and the
    # default_qdisc/tcp_congestion_control pair for the sysctl file.
    BBR_MODULE_OK=true
    if [[ -e /etc/modules-load.d/bbr.conf ]] &&
       ! managed_or_legacy_adoptable /etc/modules-load.d/bbr.conf "tcp_bbr"; then
      BBR_MODULE_OK=false
      echo "   SKIPPED: /etc/modules-load.d/bbr.conf exists and is not script-managed."
      echo "   (It was left untouched; the module may not load automatically at boot.)"
    fi
    BBR_SYSCTL_OK=true
    if [[ -e /etc/sysctl.d/98-network-bbr.conf ]] &&
       ! managed_or_legacy_adoptable /etc/sysctl.d/98-network-bbr.conf \
           "net.core.default_qdisc=fqnet.ipv4.tcp_congestion_control=bbr"; then
      BBR_SYSCTL_OK=false
      echo "   SKIPPED: /etc/sysctl.d/98-network-bbr.conf exists and is not script-managed."
      echo "   (It was left untouched, and no live sysctl value was changed either.)"
    fi

    if [[ "$BBR_MODULE_OK" == true ]]; then
      atomic_write /etc/modules-load.d/bbr.conf 0644 << 'BBR_MODULE_EOF'
# Managed by vivobook_optimize.sh v15.3 --with-bbr
tcp_bbr
BBR_MODULE_EOF
      chmod 0644 /etc/modules-load.d/bbr.conf
    fi
    if [[ "$BBR_SYSCTL_OK" == true ]]; then
      atomic_write /etc/sysctl.d/98-network-bbr.conf 0644 << 'EOF'
# Managed by vivobook_optimize.sh v15.3 --with-bbr
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
      chmod 0644 /etc/sysctl.d/98-network-bbr.conf
      sysctl -w net.core.default_qdisc=fq 2>/dev/null || true
      sysctl -w net.ipv4.tcp_congestion_control=bbr 2>/dev/null || true
      if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] TCP BBR & FQ qdisc would be enabled and persisted (/etc/sysctl.d/98-network-bbr.conf)."
      else
        echo "   TCP BBR & FQ qdisc enabled and persisted (/etc/sysctl.d/98-network-bbr.conf)."
      fi
    fi
    if [[ "$BBR_MODULE_OK" != true || "$BBR_SYSCTL_OK" != true ]]; then
      echo "   NOTE: part of the BBR configuration was skipped because an unmanaged file"
      echo "   is present at that path; merge the settings manually if you want it managed."
    fi
  else
    echo "   UNSUPPORTED: TCP BBR module is not supported/loadable in this kernel."
    echo "   SKIPPED — no configuration files were created or left dangling."
  fi
else
  echo "   Skipped. Re-run with --with-bbr to enable TCP BBR."
fi

echo "== 12. Intel HD Audio power saving =="
if [[ "$WITH_AUDIO_POWERSAVE" == true ]]; then
  if ! tlp_gate "static HD-audio power_save boot defaults (TLP: SOUND_POWER_SAVE_ON_AC/BAT)"; then
    echo "   Leaving snd_hda_intel power_save under TLP control (runtime + boot)."
  elif command -v lsmod >/dev/null 2>&1 && lsmod | grep -q snd_sof_pci_intel; then
    # SOF handles internal audio; do not force snd_hda_intel options.
    # v15.3 (I-16): a generic path — only remove the file when this script
    # wrote it. An unmanaged file is somebody's deliberate configuration.
    if [[ -e /etc/modprobe.d/audio-powersave.conf ]] &&
       ! is_managed_file /etc/modprobe.d/audio-powersave.conf; then
      echo "   NOTE: /etc/modprobe.d/audio-powersave.conf exists and is not script-managed;"
      echo "   NOTE: it was preserved. Edit or remove it yourself if it is stale."
    else
      remove_managed_config /etc/modprobe.d/audio-powersave.conf
    fi
    echo "   Intel SOF (snd_sof_pci_intel) is active — internal speakers/mics are"
    echo "   managed by SOF; snd_hda_intel power_save options are not forced."
  elif [[ -d /sys/module/snd_hda_intel ]] || modinfo snd_hda_intel &>/dev/null; then
    atomic_write /etc/modprobe.d/audio-powersave.conf 0644 << 'EOF'
# Managed by vivobook_optimize.sh v15.3
# Idle the HDA codec after 1s of silence, and allow the controller to suspend.
# If you hear a click/pop on playback start, or the first ~0.5s of audio is
# clipped, set power_save=0 here (or delete this file) and reboot.
options snd_hda_intel power_save=1 power_save_controller=Y
EOF
    chmod 0644 /etc/modprobe.d/audio-powersave.conf
    echo "   Wrote /etc/modprobe.d/audio-powersave.conf (applies on module reload/reboot)."

    if [[ -w /sys/module/snd_hda_intel/parameters/power_save ]]; then
      if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] Set snd_hda_intel/power_save to 1"
      elif { printf '%s\n' 1 > /sys/module/snd_hda_intel/parameters/power_save; } 2>/dev/null; then
        echo "   Applied live: power_save=1"
      fi
    fi
    if [[ -w /sys/module/snd_hda_intel/parameters/power_save_controller ]]; then
      if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] Set snd_hda_intel/power_save_controller to Y"
      elif { printf '%s\n' Y > /sys/module/snd_hda_intel/parameters/power_save_controller; } 2>/dev/null; then
        echo "   Applied live: power_save_controller=Y"
      fi
    fi
  else
    echo "   snd_hda_intel not present on this system — skipping (no file written)."
  fi
else
  echo "   Skipped (--no-audio-powersave). Existing /etc/modprobe.d/audio-powersave.conf,"
  echo "   if any, was left untouched."
fi

echo "== 12b. WirePlumber ALSA suspend timeout (upstream default) =="
# WirePlumber 0.5+ already defaults to a 5-second ALSA node suspend timeout, and
# WirePlumber 0.5 dropped the legacy Lua configuration framework. Do not write
# custom configuration; remove any files managed by earlier runs of this script.
remove_managed_config /etc/wireplumber/wireplumber.conf.d/50-alsa-powersave.conf
remove_managed_config /etc/wireplumber/main.lua.d/50-alsa-powersave.lua
echo "   WirePlumber's upstream 5s ALSA suspend timeout default is retained;"
echo "   managed WirePlumber configuration files removed if present."

echo "== 13. ASUS battery charge threshold (asus_wmi) =="
BAT_SYSFS=""
for b in /sys/class/power_supply/BAT*/charge_control_end_threshold; do
  [[ -e "$b" ]] || continue
  BAT_SYSFS="$b"
  break
done

if [[ -z "$BAT_SYSFS" ]]; then
  if ! lsmod 2>/dev/null | grep -qE '^asus_(nb_)?wmi'; then
    modprobe asus_nb_wmi &>/dev/null || modprobe asus_wmi &>/dev/null || true
    sleep 1
    for b in /sys/class/power_supply/BAT*/charge_control_end_threshold; do
      [[ -e "$b" ]] || continue
      BAT_SYSFS="$b"
      break
    done
  fi
fi

if [[ -z "$BAT_SYSFS" ]]; then
  echo "   No 'charge_control_end_threshold' attribute found under /sys/class/power_supply/BAT*."
  echo "   Either asus_wmi/asus_nb_wmi is not bound, or this firmware doesn't expose the"
  echo "   knob. Nothing to configure. Diagnose with:"
  echo "     lsmod | grep -i asus"
  echo "     ls /sys/class/power_supply/"
else
  BAT_NAME="$(basename "$(dirname "$BAT_SYSFS")")"
  CURRENT_THRESH="$(cat "$BAT_SYSFS" 2>/dev/null || echo unknown)"
  echo "   Supported on ${BAT_NAME} (current end threshold: ${CURRENT_THRESH}%)."

  if [[ -n "$BATTERY_LIMIT" ]] && ! tlp_gate "ASUS battery charge threshold (TLP: 'tlp setcharge' on ASUS)"; then
    echo "   Requested threshold change NOT applied; TLP retains ownership of this knob."
  elif [[ -z "$BATTERY_LIMIT" ]]; then
    if systemctl is-enabled --quiet battery-charge-threshold.service 2>/dev/null; then
      MANAGED_VAL="$(
        sed -n 's/^BATTERY_CHARGE_END_THRESHOLD=//p' \
          /etc/default/vivobook-battery 2>/dev/null || true
      )"
      echo "   A persistent threshold service from an earlier run is ENABLED"
      echo "   (configured value: ${MANAGED_VAL:-unknown}%). Leaving it in place."
      echo "   Change it with: sudo bash $SCRIPT_PATH --battery-limit=N"
      echo "   Remove it with: sudo bash $SCRIPT_PATH --battery-limit=off"
    else
      echo "   Not requested this run — no changes made."
      echo "   If the laptop lives mostly on AC, capping charge markedly slows calendar"
      echo "   ageing of the cell. Opt in with:"
      echo "     sudo bash $SCRIPT_PATH --with-battery-limit      # 80%"
      echo "     sudo bash $SCRIPT_PATH --battery-limit=60        # heavier desk-bound use"
      echo "   (Note: MyASUS/ASUS firmware may also expose this; avoid setting it in two"
      echo "    places with conflicting values. If TLP is active, prefer 'sudo tlp setcharge"
      echo "    80' — TLP owns ASUS charge thresholds when running.)"
    fi
  elif [[ "$BATTERY_LIMIT" == "off" ]]; then
    if [[ -e /etc/systemd/system/battery-charge-threshold.service ]]; then
      systemctl disable --now battery-charge-threshold.service &>/dev/null || true
      rm -f /etc/systemd/system/battery-charge-threshold.service
      rm -f /usr/local/bin/set-battery-threshold.sh
      rm -f /usr/lib/systemd/system-sleep/vivobook-battery
      rm -f /etc/default/vivobook-battery
      systemctl daemon-reload
      if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] Threshold service and resume hook would be removed."
      else
        echo "   Threshold service and resume hook removed."
      fi
    else
      echo "   No threshold service was installed; nothing to remove."
    fi
    for b in /sys/class/power_supply/BAT*/charge_control_end_threshold; do
      [[ -w "$b" ]] || continue
      if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] Restore $b to 100"
      else
        { printf '%s\n' 100 > "$b"; } 2>/dev/null || true
      fi
    done
    echo "   Charge threshold reset to 100% for this session."
  else
    atomic_write /etc/default/vivobook-battery 0644 <<EOF
# Managed by vivobook_optimize.sh v15.3 — consumed by set-battery-threshold.sh
BATTERY_CHARGE_END_THRESHOLD=${BATTERY_LIMIT}
EOF
    chmod 0644 /etc/default/vivobook-battery

    atomic_write /usr/local/bin/set-battery-threshold.sh 0755 << 'BATTERY_EOF'
#!/usr/bin/env bash
# Managed by vivobook_optimize.sh v15.3
set -Eeuo pipefail

THRESH=80
if [[ -r /etc/default/vivobook-battery ]]; then
  # shellcheck disable=SC1091
  . /etc/default/vivobook-battery
  THRESH="${BATTERY_CHARGE_END_THRESHOLD:-80}"
fi

if [[ ! "$THRESH" =~ ^[0-9]+$ ]] || (( THRESH < 20 || THRESH > 100 )); then
  echo "Invalid BATTERY_CHARGE_END_THRESHOLD='$THRESH'; refusing to apply." >&2
  exit 1
fi

SEEN=0
APPLIED=0
for f in /sys/class/power_supply/BAT*/charge_control_end_threshold; do
  [[ -e "$f" ]] || continue
  SEEN=$((SEEN + 1))
  if { printf '%s\n' "$THRESH" > "$f"; } 2>/dev/null; then
    echo "Set $(basename "$(dirname "$f")") charge end threshold to ${THRESH}%"
    APPLIED=$((APPLIED + 1))
  else
    echo "WARNING: failed to write $f" >&2
  fi
done

if (( APPLIED == 0 )); then
  if (( SEEN == 0 )); then
    # Attribute absent (e.g. asus_wmi not bound yet on early boot, or firmware
    # does not expose it). Threshold application is an optional best-effort
    # setting: report UNSUPPORTED and succeed so the boot service stays clean.
    echo "UNSUPPORTED at runtime: no charge_control_end_threshold attribute (asus_wmi loaded?)."
    exit 0
  fi
  echo "charge_control_end_threshold present but $SEEN attribute(s) refused the write." >&2
  exit 1
fi
BATTERY_EOF

    write_unit_file /etc/systemd/system/battery-charge-threshold.service 0644 << 'EOF'
# Managed by vivobook_optimize.sh v15.3
[Unit]
Description=Apply ASUS battery charge end threshold
After=basic.target
StartLimitIntervalSec=0

[Service]
Type=oneshot
RemainAfterExit=true
ExecStart=/usr/local/bin/set-battery-threshold.sh

[Install]
WantedBy=multi-user.target
EOF

    # Sleep hook: the ASUS EC can reset the threshold to 100% on S0ix resume,
    # and RemainAfterExit=true means the WantedBy=suspend.target dependency
    # alone won't re-run the oneshot. Force a restart on 'post'.
    atomic_write /usr/lib/systemd/system-sleep/vivobook-battery 0755 << 'EOF'
#!/usr/bin/env bash
# Managed by vivobook_optimize.sh v15.3
if [[ "${1:-}" == post ]]; then
  systemctl restart battery-charge-threshold.service >/dev/null 2>&1 || true
fi
EOF
    chmod 0755 /usr/lib/systemd/system-sleep/vivobook-battery

    systemctl daemon-reload
    systemctl reenable battery-charge-threshold.service &>/dev/null ||
      systemctl enable battery-charge-threshold.service
    if systemctl restart battery-charge-threshold.service; then
      NEW_THRESH="$(cat "$BAT_SYSFS" 2>/dev/null || echo unknown)"
      echo "   Threshold set to ${BATTERY_LIMIT}% and enabled at boot/resume"
      echo "   (${BAT_NAME} now reports: ${NEW_THRESH}%)."
      echo "   Resume hook: /usr/lib/systemd/system-sleep/vivobook-battery re-applies after sleep."
      echo "   Config file: /etc/default/vivobook-battery"
      echo "   Undo with:   sudo bash $SCRIPT_PATH --battery-limit=off"
      echo "   Expect the reported capacity to stop climbing at ${BATTERY_LIMIT}% — this is"
      echo "   the intended behaviour, not a battery fault."
    else
      echo "   WARNING: service failed to apply the threshold; check:" >&2
      echo "     journalctl -u battery-charge-threshold.service" >&2
    fi
  fi
fi

echo "== 14. ACPI platform profile / ASUS thermal profile =="
if [[ -z "$FAN_PROFILE" ]]; then
  echo "   Not requested — no thermal profile changes made."
  if systemctl is-enabled --quiet asus-thermal-profile.service 2>/dev/null; then
    echo "   A persistent asus-thermal-profile.service from an earlier run remains enabled."
  fi
else
  if ! tlp_gate "ACPI/ASUS thermal platform profile (TLP: PLATFORM_PROFILE_ON_AC/BAT)"; then
    echo "   Thermal profile left under TLP control; no service installed or changed."
  else
  PROFILE_INTERFACE=""
  PROFILE_NODE=""
  for node in /sys/class/platform_profile/*/profile /sys/firmware/acpi/platform_profile; do
    [[ -w "$node" ]] || continue
    PROFILE_NODE="$node"
    PROFILE_INTERFACE=platform_profile
    break
  done
  if [[ -n "$PROFILE_NODE" ]]; then
    if [[ "$PROFILE_NODE" == /sys/firmware/acpi/platform_profile ]]; then
      PROFILE_CHOICES=/sys/firmware/acpi/platform_profile_choices
    else
      PROFILE_CHOICES="$(dirname "$PROFILE_NODE")/choices"
    fi
    if [[ -r "$PROFILE_CHOICES" ]] &&
       ! grep -qw -- "$FAN_PROFILE" "$PROFILE_CHOICES"; then
      echo "   Requested profile '$FAN_PROFILE' is not listed by $PROFILE_CHOICES." >&2
      echo "   Available: $(cat "$PROFILE_CHOICES")" >&2
      exit 1
    fi
  elif [[ -w /sys/devices/platform/asus-nb-wmi/throttle_thermal_policy ]]; then
    PROFILE_INTERFACE=asus_policy
  fi

  if [[ -z "$PROFILE_INTERFACE" ]]; then
    echo "   No writable ACPI platform_profile or ASUS throttle_thermal_policy found."
    echo "   Nothing was configured."
  else
    atomic_write /etc/default/vivobook-thermal-profile 0644 <<EOF
# Managed by vivobook_optimize.sh v15.3
ASUS_THERMAL_PROFILE=${FAN_PROFILE}
EOF
    chmod 0644 /etc/default/vivobook-thermal-profile

    atomic_write /usr/local/bin/set-asus-thermal-profile.sh 0755 << 'THERMAL_EOF'
#!/usr/bin/env bash
# Managed by vivobook_optimize.sh v15.3
set -Eeuo pipefail

PROFILE=""
if [[ -r /etc/default/vivobook-thermal-profile ]]; then
  # shellcheck disable=SC1091
  . /etc/default/vivobook-thermal-profile
  PROFILE="${ASUS_THERMAL_PROFILE:-}"
fi

case "$PROFILE" in
  quiet|balanced|performance) ;;
  *)
    echo "Invalid ASUS_THERMAL_PROFILE='$PROFILE'." >&2
    exit 1
    ;;
esac

# Return semantics (v15.2): 0 = applied; 1 = a writable interface EXISTS but
# every write to it failed (genuine failure -> service fails, surfacing in
# logs); 2 = no interface at all (UNSUPPORTED on this hardware/firmware ->
# optional setting, exit 0 so the boot service stays clean).
set_platform_profile() {
  local profile="$1" saw_interface=false node p=0
  for node in /sys/class/platform_profile/*/profile /sys/firmware/acpi/platform_profile; do
    [[ -w "$node" ]] || continue
    saw_interface=true
    if { printf '%s\n' "$profile" > "$node"; } 2>/dev/null; then
      return 0
    fi
  done
  if [[ -w /sys/devices/platform/asus-nb-wmi/throttle_thermal_policy ]]; then
    saw_interface=true
    case "$profile" in
      balanced)    p=0 ;;
      performance) p=1 ;;
      quiet)       p=2 ;;
      *)           return 1 ;;
    esac
    if { printf '%s\n' "$p" > /sys/devices/platform/asus-nb-wmi/throttle_thermal_policy; } 2>/dev/null; then
      return 0
    fi
  fi
  if [[ "$saw_interface" == true ]]; then
    return 1
  fi
  return 2
}

# v15.3 (I-04): never report success from a swallowed failure. powerprofilesctl
# is checked for, the set is retried (D-Bus can be slow right after boot) and
# the result is read back before anything is reported as applied.
if systemctl is-active --quiet power-profiles-daemon.service; then
  if ! command -v powerprofilesctl >/dev/null 2>&1; then
    echo "power-profiles-daemon is active but powerprofilesctl is not installed;" >&2
    echo "cannot apply thermal profile '$PROFILE' via PPD." >&2
    exit 1
  fi
  case "$PROFILE" in
    performance) PPD_TARGET=performance ;;
    balanced)    PPD_TARGET=balanced ;;
    quiet)       PPD_TARGET=power-saver ;;
    *)
      echo "Invalid ASUS_THERMAL_PROFILE='$PROFILE'." >&2
      exit 1
      ;;
  esac
  PPD_APPLIED=false
  PPD_REPORTED=""
  for _try in 1 2 3; do
    powerprofilesctl set "$PPD_TARGET" >/dev/null 2>&1 || true
    PPD_REPORTED="$(powerprofilesctl get 2>/dev/null || true)"
    if [[ "$PPD_REPORTED" == "$PPD_TARGET" ]]; then
      PPD_APPLIED=true
      break
    fi
    sleep 1
  done
  if [[ "$PPD_APPLIED" == true ]]; then
    echo "Applied thermal profile '$PROFILE' via power-profiles-daemon (PPD reports: $PPD_REPORTED)."
  else
    echo "powerprofilesctl set '$PPD_TARGET' did not take effect for thermal profile '$PROFILE'." >&2
    echo "powerprofilesctl reports: '${PPD_REPORTED:-no value}'." >&2
    exit 1
  fi
else
  rc=0
  set_platform_profile "$PROFILE" || rc=$?
  case "$rc" in
    0)
      echo "Set ACPI/ASUS thermal profile to '$PROFILE'."
      ;;
    2)
      echo "UNSUPPORTED: no writable thermal profile interface on this hardware/firmware."
      echo "Optional setting — nothing to apply; service succeeds by design."
      ;;
    *)
      echo "Thermal profile interface is present but every write failed." >&2
      exit 1
      ;;
  esac
fi
THERMAL_EOF

    write_unit_file /etc/systemd/system/asus-thermal-profile.service 0644 << 'EOF'
# Managed by vivobook_optimize.sh v15.3
[Unit]
Description=Apply ASUS ACPI thermal platform profile
After=basic.target
# v15.3 (I-05): ordering only — this makes the helper run after PPD has claimed
# the platform profile. No Wants=, so the line is ignored when PPD is absent.
After=power-profiles-daemon.service
StartLimitIntervalSec=0

[Service]
Type=oneshot
ExecStart=/usr/local/bin/set-asus-thermal-profile.sh

[Install]
WantedBy=multi-user.target
EOF

    atomic_write /usr/lib/systemd/system-sleep/vivobook-thermal-profile 0755 << 'EOF'
#!/usr/bin/env bash
# Managed by vivobook_optimize.sh v15.3
if [[ "${1:-}" == post ]]; then
  systemctl restart asus-thermal-profile.service >/dev/null 2>&1 || true
fi
EOF

    systemctl daemon-reload
    systemctl reenable asus-thermal-profile.service &>/dev/null ||
      systemctl enable asus-thermal-profile.service
    if systemctl restart asus-thermal-profile.service; then
      echo "   Thermal profile '$FAN_PROFILE' applied and persisted across boot/resume."
    else
      echo "   WARNING: thermal profile service failed; check:" >&2
      echo "     journalctl -u asus-thermal-profile.service" >&2
    fi
  fi
  fi
fi

echo "== 15. Intel P-State Energy Performance Preference (EPP) =="
if [[ -z "$EPP_PROFILE" ]]; then
  echo "   Not requested — no EPP changes made."
  if systemctl is-enabled --quiet intel-epp-profile.service 2>/dev/null; then
    echo "   A persistent intel-epp-profile.service from an earlier run remains enabled."
  fi
else
  if ! tlp_gate "Intel P-state EPP (TLP: CPU_ENERGY_PERF_POLICY_ON_AC/BAT)"; then
    echo "   EPP left under TLP control; no service installed or changed."
  else
  PSTATE_STATUS="$(cat /sys/devices/system/cpu/intel_pstate/status 2>/dev/null || echo unavailable)"
  CPU_DRIVER="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver 2>/dev/null || echo unavailable)"

  if [[ "$PSTATE_STATUS" == "off" ||
        ( "$CPU_DRIVER" != "intel_pstate" && "$CPU_DRIVER" != "intel_cpufreq" ) ]]; then
    echo "   intel_pstate is not active (status=$PSTATE_STATUS, driver=$CPU_DRIVER)."
    echo "   Refusing to install an EPP override."
  else
    EPP_NODE_FOUND=false
    for f in /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference; do
      [[ -e "$f" ]] || continue
      EPP_NODE_FOUND=true
      break
    done

    if [[ "$EPP_NODE_FOUND" == false ]]; then
      echo "   intel_pstate is active, but no EPP nodes were found. Nothing configured."
    else
      atomic_write /etc/default/vivobook-epp 0644 <<EOF
# Managed by vivobook_optimize.sh v15.3
INTEL_EPP_PROFILE=${EPP_PROFILE}
EOF
      chmod 0644 /etc/default/vivobook-epp

      atomic_write /usr/local/bin/set-intel-epp.sh 0755 << 'EPP_EOF'
#!/usr/bin/env bash
# Managed by vivobook_optimize.sh v15.3
set -Eeuo pipefail

PROFILE=""
if [[ -r /etc/default/vivobook-epp ]]; then
  # shellcheck disable=SC1091
  . /etc/default/vivobook-epp
  PROFILE="${INTEL_EPP_PROFILE:-}"
fi

case "$PROFILE" in
  performance|balance_performance|balance_power|power) ;;
  *)
    echo "Invalid INTEL_EPP_PROFILE='$PROFILE'." >&2
    exit 1
    ;;
esac

PSTATE_STATUS="$(cat /sys/devices/system/cpu/intel_pstate/status 2>/dev/null || echo unavailable)"
CPU_DRIVER="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver 2>/dev/null || echo unavailable)"
if [[ "$PSTATE_STATUS" == "off" ||
      ( "$CPU_DRIVER" != "intel_pstate" && "$CPU_DRIVER" != "intel_cpufreq" ) ]]; then
  echo "intel_pstate is not active (status=$PSTATE_STATUS, driver=$CPU_DRIVER)." >&2
  exit 1
fi

# While power-profiles-daemon is active it owns CPU EPP; talk to it natively
# instead of fighting over the raw sysfs nodes.
# v15.3 (I-04): retry + read-back. A swallowed powerprofilesctl failure must
# never be reported as applied. (The command -v guard is in the condition.)
if command -v powerprofilesctl >/dev/null 2>&1 && systemctl is-active --quiet power-profiles-daemon.service; then
  case "$PROFILE" in
    performance)         PPD_TARGET=performance ;;
    balance_performance) PPD_TARGET=balanced ;;
    balance_power|power) PPD_TARGET=power-saver ;;
    *)
      echo "Invalid INTEL_EPP_PROFILE='$PROFILE'." >&2
      exit 1
      ;;
  esac
  PPD_APPLIED=false
  PPD_REPORTED=""
  for _try in 1 2 3; do
    powerprofilesctl set "$PPD_TARGET" >/dev/null 2>&1 || true
    PPD_REPORTED="$(powerprofilesctl get 2>/dev/null || true)"
    if [[ "$PPD_REPORTED" == "$PPD_TARGET" ]]; then
      PPD_APPLIED=true
      break
    fi
    sleep 1
  done
  if [[ "$PPD_APPLIED" == true ]]; then
    echo "Applied Intel EPP '$PROFILE' via power-profiles-daemon (PPD reports: $PPD_REPORTED)."
    exit 0
  fi
  echo "powerprofilesctl set '$PPD_TARGET' did not take effect for Intel EPP '$PROFILE'." >&2
  echo "powerprofilesctl reports: '${PPD_REPORTED:-no value}'." >&2
  exit 1
fi

# v15.2 semantics: no nodes at all = UNSUPPORTED (exit 0 — the CPU may lack
# HWP EPP or the driver changed; optional setting, keep boot clean). Nodes
# present but all writes failed = genuine failure (exit 1).
NODES=0
APPLIED=0
for f in /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference; do
  [[ -e "$f" ]] || continue
  NODES=$((NODES + 1))
  if [[ -w "$f" ]] && { printf '%s\n' "$PROFILE" > "$f"; } 2>/dev/null; then
    APPLIED=$((APPLIED + 1))
  else
    echo "WARNING: failed to apply '$PROFILE' to $f" >&2
  fi
done

if (( NODES == 0 )); then
  echo "UNSUPPORTED at runtime: no energy_performance_preference nodes present."
  exit 0
fi
if (( APPLIED == 0 )); then
  echo "EPP nodes exist but all $NODES writes failed." >&2
  exit 1
fi

echo "Applied Intel EPP '$PROFILE' to $APPLIED of $NODES CPU policy node(s)."
EPP_EOF

      write_unit_file /etc/systemd/system/intel-epp-profile.service 0644 << 'EOF'
# Managed by vivobook_optimize.sh v15.3
[Unit]
Description=Apply Intel P-State Energy Performance Preference
After=basic.target
# v15.3 (I-05): ordering only, no Wants= (ignored when PPD is absent).
After=power-profiles-daemon.service
StartLimitIntervalSec=0

[Service]
Type=oneshot
ExecStart=/usr/local/bin/set-intel-epp.sh

[Install]
WantedBy=multi-user.target
EOF

      atomic_write /usr/lib/systemd/system-sleep/vivobook-intel-epp 0755 << 'EOF'
#!/usr/bin/env bash
# Managed by vivobook_optimize.sh v15.3
if [[ "${1:-}" == post ]]; then
  systemctl restart intel-epp-profile.service >/dev/null 2>&1 || true
fi
EOF

      systemctl daemon-reload
      systemctl reenable intel-epp-profile.service &>/dev/null ||
        systemctl enable intel-epp-profile.service
      if systemctl restart intel-epp-profile.service; then
        echo "   EPP '$EPP_PROFILE' applied and persisted across boot/resume."
        echo "   NOTE: with power-profiles-daemon active, the profile is applied via powerprofilesctl."
      else
        echo "   WARNING: EPP service failed; check:" >&2
        echo "     journalctl -u intel-epp-profile.service" >&2
      fi
    fi
  fi
  fi
fi

echo "== 15c. power-profiles-daemon conflict resolution (--disable-ppd) =="
if [[ "$DISABLE_PPD" == true ]]; then
  PPD_EXISTS=false
  if command systemctl list-unit-files power-profiles-daemon.service &>/dev/null && \
     [[ -n "$(command systemctl list-unit-files power-profiles-daemon.service 2>/dev/null | grep -i 'power-profiles-daemon')" ]]; then
    PPD_EXISTS=true
  fi

  if [[ "$PPD_EXISTS" == true ]]; then
    if [[ ! -f /etc/default/vivobook-ppd-state ]]; then
      PPD_ACTIVE="false"
      command systemctl is-active --quiet power-profiles-daemon.service && PPD_ACTIVE="true" || PPD_ACTIVE="false"
      PPD_ENABLED="false"
      PPD_MASKED="false"
      PPD_STATUS="$(systemctl is-enabled power-profiles-daemon.service 2>/dev/null || echo "disabled")"
      if [[ "$PPD_STATUS" == "enabled" ]]; then
        PPD_ENABLED="true"
      elif [[ "$PPD_STATUS" == "masked" ]]; then
        PPD_MASKED="true"
      fi

      atomic_write /etc/default/vivobook-ppd-state 0644 << EOF
# Managed by vivobook_optimize.sh v15.3 --disable-ppd
PPD_WAS_PRESENT=true
PPD_WAS_ACTIVE=${PPD_ACTIVE}
PPD_WAS_ENABLED=${PPD_ENABLED}
PPD_WAS_MASKED=${PPD_MASKED}
EOF
      chmod 0644 /etc/default/vivobook-ppd-state
    fi

    systemctl stop power-profiles-daemon.service 2>/dev/null || true
    systemctl mask power-profiles-daemon.service 2>/dev/null || true
    echo "   power-profiles-daemon.service masked to prevent power profile conflicts."
  else
    echo "   power-profiles-daemon.service not present on this system. Skipping safely."
  fi
else
  echo "   Skipped. Re-run with --disable-ppd to resolve potential desktop EPP overlaps."
fi

echo "== 16. zRAM compressed in-memory swap =="
# v15.2: rerunning --with-zram against an already-correct zram must NOT
# swapoff/restart the populated device. Compare SEMANTICALLY (values, not
# file bytes) so a config written by a previous script version also matches;
# only a real difference triggers the disruptive reconfigure path.
ZRAM_DESIRED_CONF='# Managed by vivobook_optimize.sh v15.3 --with-zram
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
swap-priority = 100
fs-type = swap'

# Read-only probe: 0 = desired zram installed and live, 1 = anything differs.
zram_is_current() {
  local conf=/etc/systemd/zram-generator.conf
  [[ -f "$conf" ]] || return 1
  # Only consider script-managed files (any script version).
  grep -q 'Managed by vivobook_optimize' "$conf" 2>/dev/null || return 1
  grep -Eq '^[[:space:]]*zram-size[[:space:]]*=[[:space:]]*min\(ram ?/ ?2, ?8192\)' "$conf" 2>/dev/null || return 1
  grep -Eq '^[[:space:]]*compression-algorithm[[:space:]]*=[[:space:]]*zstd([[:space:]]|$)' "$conf" 2>/dev/null || return 1
  grep -Eq '^[[:space:]]*swap-priority[[:space:]]*=[[:space:]]*100([[:space:]]|$)' "$conf" 2>/dev/null || return 1
  # Live state: /dev/zram0 attached to swap at priority 100 (higher than disk
  # swap), with zstd selected as the ACTIVE algorithm (bracketed in sysfs).
  awk '$1 == "/dev/zram0" && $5 == 100 {found=1} END {exit(found?0:1)}' /proc/swaps 2>/dev/null || return 1
  grep -q '\[zstd\]' /sys/block/zram0/comp_algorithm 2>/dev/null || return 1
  return 0
}

if [[ "$WITH_ZRAM" == true ]]; then
  if zram_is_current; then
    echo "   Desired zram already installed and active (zstd, min(ram/2, 8192) MiB, priority 100)."
    echo "   NO-OP: populated /dev/zram0 left untouched (no swapoff, no service restart)."
    swapon --show 2>/dev/null | sed 's/^/     /' || true
  elif [[ -e /etc/systemd/zram-generator.conf ]] &&
       ! is_managed_file /etc/systemd/zram-generator.conf; then
    # v15.3 (I-17): /etc/systemd/zram-generator.conf is a generic path. Refuse
    # to overwrite an operator's zram configuration, and do not touch
    # zram-tools or the running device either.
    echo "   SKIPPED: /etc/systemd/zram-generator.conf exists and is not script-managed."
    echo "   Your zram configuration was left exactly as it is; no packages were changed."
  else
    apt-get "${APT_OPTS[@]}" install systemd-zram-generator
    systemctl disable --now zramswap.service 2>/dev/null || true
    apt-get "${APT_OPTS[@]}" purge zram-tools || true

    # v15.3 (I-24): here-string, NOT a pipe. In a pipeline the function body
    # runs in a subshell, so TMP_REGISTRY would be lost to the parent's EXIT
    # trap and a stray temp file could survive a mid-write failure.
    atomic_write /etc/systemd/zram-generator.conf 0644 <<< "$ZRAM_DESIRED_CONF"
    chmod 0644 /etc/systemd/zram-generator.conf

    systemctl daemon-reload
    # The legacy zramswap.service leaves /dev/zram0 attached as active swap;
    # detaching it first prevents "Device or resource busy" (EBUSY) when the
    # generator claims the device. No-op when the device is absent or inactive.
    swapoff /dev/zram0 2>/dev/null || true
    if systemctl restart systemd-zram-setup@zram0.service; then
      if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] zRAM would be enabled via systemd-zram-generator (zstd, min(ram/2, 8192) MiB)."
      else
        echo "   zRAM enabled via systemd-zram-generator (zstd, min(ram/2, 8192) MiB)."
      fi
      swapon --show 2>/dev/null | sed 's/^/     /' || true
    else
      echo "   WARNING: systemd-zram-setup@zram0.service failed; check:" >&2
      echo "     journalctl -u systemd-zram-setup@zram0.service" >&2
    fi
  fi
else
  echo "   Skipped. Re-run with --with-zram to install and configure systemd-zram-generator."
  if systemctl is-enabled --quiet zramswap.service 2>/dev/null; then
    echo "   An existing zramswap.service remains enabled."
  fi
fi

echo "== 17. Wi-Fi runtime power management (driver-agnostic, via iw) =="
# v15.2 relabel: the reference X1605VA ships a MediaTek MT7902 driven by
# mt7921e — nothing here is Intel-specific. Static iwlwifi/iwlmvm module
# options (uapsd_disable=0, amsdu_size=3) caused packet loss and disconnects
# and conflicted with dynamic 'iw' power-save switching; no static modprobe
# configuration is written. restore_iwlwifi_conf is retained deliberately as
# harmless compatibility cleanup for Intel-based Vivobooks upgraded from old
# script versions (unmanaged content is preserved; no-op on MediaTek).
IFACE_COUNT=0
for w in /sys/class/net/*; do
  [[ -d "$w/wireless" ]] || continue
  wdrv="unknown"
  [[ -L "$w/device/driver" ]] && wdrv="$(basename "$(readlink -f "$w/device/driver")")"
  echo "   Detected wireless interface: $(basename "$w") (driver: $wdrv)"
  IFACE_COUNT=$((IFACE_COUNT + 1))
done
(( IFACE_COUNT == 0 )) && echo "   No wireless interface detected on this run."
restore_iwlwifi_conf
echo "   No static wifi module options are staged by this step (upstream driver defaults"
echo "   kept). The MediaTek MT7902 ASPM workaround is managed separately in step 17a."
echo "   Wi-Fi power saving is controlled dynamically via 'iw dev <iface> set power_save'"
echo "   (AC off / battery on with --with-auto-power)."

echo "== 17a. MediaTek MT7902 (mt7921e) ASPM workaround (--with-mt7921e-aspm) =="
# Not TLP-gated on purpose: TLP does not manage /etc/modprobe.d/mt7921e.conf.
if [[ "$WITH_MT7921E_ASPM" == true ]]; then
  if ! mt7921e_present; then
    echo "   UNSUPPORTED: no mt7921e-bound wireless interface and the module is not loaded."
    echo "   Nothing was written."
  else
    MT7921E_IFACE="$(mt7921e_bound_iface 2>/dev/null || true)"
    echo "   mt7921e detected${MT7921E_IFACE:+ (interface $MT7921E_IFACE)}; live disable_aspm=$(mt7921e_disable_aspm_live)."
    if [[ -e "$MT7921E_CONF" ]] && ! mt7921e_conf_managed; then
      echo "   NOTE: $MT7921E_CONF exists and is NOT script-managed — leaving it untouched."
      if mt7921e_conf_has_disable_aspm; then
        echo "   Current state: it already sets disable_aspm=1. Nothing to do."
      else
        echo "   Current state: no disable_aspm=1 option found in it."
        echo "   Merge 'options mt7921e disable_aspm=1' manually if you want the workaround."
      fi
    elif mt7921e_conf_managed && mt7921e_conf_has_disable_aspm; then
      echo "   NO-OP: $MT7921E_CONF is already managed and sets disable_aspm=1."
    else
      atomic_write "$MT7921E_CONF" 0644 << 'MT7921E_EOF'
# Managed by vivobook_optimize.sh v15.3 --with-mt7921e-aspm
# MediaTek MT7902 (mt7921e): the Vivobook X1605VA Wi-Fi is unstable with PCIe
# ASPM enabled (disconnects, packet loss). disable_aspm=1 keeps the link stable.
# Side effect: deep package idle is blocked, so PC8/PC10 stay at 0 — that is
# expected on this platform, not a fault to chase.
# A REBOOT is required to apply (or: modprobe -r mt7921e && modprobe mt7921e).
options mt7921e disable_aspm=1
MT7921E_EOF
      echo "   Wrote $MT7921E_CONF ('options mt7921e disable_aspm=1'). A REBOOT is required."
      echo "   No update-initramfs run: mt7921e is not part of the initramfs on this machine."
    fi
  fi
else
  echo "   Skipped. Re-run with --with-mt7921e-aspm to stage the MT7902 ASPM workaround."
  if [[ -e "$MT7921E_CONF" ]]; then
    if mt7921e_conf_has_disable_aspm; then
      echo "   (An existing $MT7921E_CONF already sets disable_aspm=1 and was left untouched.)"
    else
      echo "   (An existing $MT7921E_CONF does not set disable_aspm=1; Wi-Fi may be unstable.)"
    fi
  fi
fi

echo "== 17b. USB Runtime Autosuspend (--with-usb-autosuspend) =="
if [[ "$WITH_USB_AUTOSUSPEND" == true ]]; then
  if ! tlp_gate "USB runtime autosuspend (TLP: USB_AUTOSUSPEND + USB_EXCLUDE_*)"; then
    echo "   Existing udev autosuspend rules left untouched; TLP keeps runtime PM policy."
  elif [[ -e /etc/udev/rules.d/99-usb-autosuspend.rules ]] &&
       ! is_managed_file /etc/udev/rules.d/99-usb-autosuspend.rules; then
    # v15.3 (I-17): generic path — never clobber an unmanaged rule file, and do
    # not reload/re-trigger udev for rules that were not deployed.
    echo "   SKIPPED: /etc/udev/rules.d/99-usb-autosuspend.rules exists and is not script-managed."
    echo "   Your rule file was left untouched; no udev reload or re-trigger was issued."
  else
  atomic_write /etc/udev/rules.d/99-usb-autosuspend.rules 0644 << 'UDEV_USB_EOF'
# Managed by vivobook_optimize.sh v15.3 --with-usb-autosuspend
# Enable USB runtime autosuspend by default
ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{power/control}="auto"

# Exempt USB HID devices (class 03) globally from autosuspend to prevent
# keyboard/mouse/receiver input lag
ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_interface", ATTR{bInterfaceClass}=="03", TEST=="../power/control", ATTR{../power/control}="on"

# Exempt USB Wireless / Bluetooth host controllers (class e0) from autosuspend
# to prevent Bluetooth mouse/keyboard/headset lag and disconnects
ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_interface", ATTR{bInterfaceClass}=="e0", TEST=="../power/control", ATTR{../power/control}="on"

# Exempt USB audio (bInterfaceClass 01) from autosuspend: avoid pops and
# delayed playback on DACs/headsets
ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_interface", ATTR{bInterfaceClass}=="01", TEST=="../power/control", ATTR{../power/control}="on"

# Exempt UVC video (bInterfaceClass 0e) from autosuspend: avoid delayed first
# frames and dropped webcam opens
ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_interface", ATTR{bInterfaceClass}=="0e", TEST=="../power/control", ATTR{../power/control}="on"
UDEV_USB_EOF
  chmod 0644 /etc/udev/rules.d/99-usb-autosuspend.rules

  udevadm control --reload-rules 2>/dev/null || true
  # Rules match ACTION=="add"; re-trigger add-uevents so already-connected
  # devices adopt the policy immediately, no replug or reboot needed.
  udevadm trigger --subsystem-match=usb --action=add 2>/dev/null || true
  echo "   USB runtime autosuspend rules deployed and applied to already-connected devices"
  echo "   (udev trigger replays 'add' events; no replug/reboot required)."
  echo "   Exempt: USB HID (keyboard/mouse/receivers), Bluetooth/wireless controllers,"
  echo "   USB audio (01) and UVC video (0e) — peripherals keep instant wake."
  fi
else
  echo "   Skipped. Re-run with --with-usb-autosuspend to enable runtime autosuspend."
fi

echo "== 17c. Browser Wayland Configuration (--with-browser-wayland) =="
if [[ "$WITH_BROWSER_WAYLAND" == true ]]; then
  APPLIED_USERS=0
  while IFS=: read -r U_NAME _ U_UID U_GID _ U_HOME U_SHELL; do
    [[ "$U_UID" =~ ^[0-9]+$ ]] || continue
    (( U_UID >= 1000 && U_UID < 65000 )) || continue
    case "$U_SHELL" in
      */nologin|*/false|"") continue ;;
    esac
    [[ -n "$U_HOME" && -d "$U_HOME" ]] || continue
    apply_browser_flags_for_user "$U_NAME" "$U_UID" "$U_GID" "$U_HOME"
    APPLIED_USERS=$((APPLIED_USERS + 1))
  done < /etc/passwd

  if (( APPLIED_USERS == 0 )); then
    echo "   No user accounts (UID >= 1000) found for browser tuning configuration."
  fi
else
  echo "   Skipped. Re-run with --with-browser-wayland to set the managed Wayland flag."
fi

echo "== 18. Non-destructive system status dashboard =="
echo "   Run at any time with:"
echo "     sudo bash $SCRIPT_PATH --status"
echo "   Alias:"
echo "     sudo bash $SCRIPT_PATH --check"
echo "   JSON:"
echo "     sudo bash $SCRIPT_PATH --status-json"

echo "== 19. Dynamic AC/Battery power switching (--with-auto-power) =="
if [[ "$WITH_AUTO_POWER" == true ]]; then
  # TLP and this optional dynamic policy both manage overlapping power controls.
  # Hard refusal for real runs; a dry-run REPORTS the refusal and skips the
  # installation without failing (read-only paths must never be blocked, and a
  # refusal must still be honest about what it rejects).
  AUTO_POWER_BLOCKED=false
  # v15.3 (I-33): use the boolean detect_power_managers already computed
  # instead of re-shelling systemctl with a second spelling of the unit name.
  if [[ "$TLP_ACTIVE" == true ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      echo "[DRY-RUN] TLP is active: --with-auto-power WOULD BE REFUSED (it must never coexist with TLP)."
      echo "[DRY-RUN] No auto-power helper, udev rule, or service would be installed."
      AUTO_POWER_BLOCKED=true
    else
      echo "ERROR: TLP is active. --with-auto-power continuously re-writes EPP, platform" >&2
      echo "       profile and Wi-Fi/audio power state and MUST NOT coexist with TLP." >&2
      echo "       Choose ONE dynamic manager: either keep TLP (its udev hooks do the same" >&2
      echo "       job) or 'sudo systemctl disable --now tlp' and re-run. This script never" >&2
      echo "       removes TLP. --force-tlp-override cannot bypass this refusal." >&2
      exit 1
    fi
  fi
  if [[ "$AUTO_POWER_BLOCKED" == true ]]; then
    echo "   (--with-auto-power blocked by active TLP; nothing was installed.)"
  else
  if ! command -v iw >/dev/null 2>&1; then
    apt-get "${APT_OPTS[@]}" install iw ||
      echo "   WARNING: iw could not be installed; dynamic Wi-Fi power saving will be skipped." >&2
  fi

  # Write the dynamic helper script
  atomic_write /usr/local/bin/vivobook-power-switch.sh 0755 << 'POWER_SWITCH_EOF'
#!/usr/bin/env bash
# Managed by vivobook_optimize.sh v15.3 --with-auto-power
set -Eeuo pipefail

# Debounce: adapter connect/disconnect fires multiple power_supply udev events
# within milliseconds. Hold an exclusive non-blocking lock so only one instance
# tunes at a time; later queued instances exit immediately. The lock fd is
# inherited by nothing long-lived; it is released when this script exits.
exec 9>/run/vivobook-power-switch.lock
flock -n 9 || exit 0

# v15.3 (I-25): every knob records what actually happened — applied,
# unsupported (<reason>) or failed. The summary at the end reports all of them,
# and the helper only fails when a writable node existed and every write to it
# was rejected.
declare -A KNOB_STATE=()
ANY_APPLIED=false
ANY_FAILED=false

# Detect AC / USB-PD power state
AC=0
for supply in /sys/class/power_supply/*; do
  [[ -d "$supply" && -r "$supply/type" && -r "$supply/online" ]] || continue
  case "$(cat "$supply/type" 2>/dev/null || true)" in
    Mains|USB|USB_PD|USB_C)
      if [[ "$(cat "$supply/online" 2>/dev/null || echo 0)" == "1" ]]; then
        AC=1
        break
      fi
      ;;
  esac
done

apply_epp() {
  local val="$1" target applied=false reported="" f nodes=0 applied_nodes=0 _try
  if command -v powerprofilesctl >/dev/null 2>&1 && systemctl is-active --quiet power-profiles-daemon.service; then
    case "$val" in
      performance)         target=performance ;;
      balance_power|power) target=power-saver ;;
      *)                   target=balanced ;;
    esac
    # v15.3 (I-04): retry, then read back. A swallowed failure is never
    # reported as applied.
    for _try in 1 2 3; do
      powerprofilesctl set "$target" >/dev/null 2>&1 || true
      reported="$(powerprofilesctl get 2>/dev/null || true)"
      if [[ "$reported" == "$target" ]]; then
        applied=true
        break
      fi
      sleep 1
    done
    if [[ "$applied" == true ]]; then
      KNOB_STATE[epp]="applied via power-profiles-daemon (PPD reports '$reported')"
      ANY_APPLIED=true
    else
      KNOB_STATE[epp]="failed via power-profiles-daemon (reports '${reported:-no value}', wanted '$target')"
      ANY_FAILED=true
    fi
    return 0
  fi
  for f in /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference; do
    [[ -e "$f" ]] || continue
    nodes=$((nodes + 1))
    if [[ -w "$f" ]] && { printf '%s\n' "$val" > "$f"; } 2>/dev/null; then
      applied_nodes=$((applied_nodes + 1))
    fi
  done
  if (( nodes == 0 )); then
    KNOB_STATE[epp]="unsupported (no energy_performance_preference nodes)"
  elif (( applied_nodes == 0 )); then
    KNOB_STATE[epp]="failed ($nodes node(s) present, every write rejected)"
    ANY_FAILED=true
  else
    KNOB_STATE[epp]="applied ($applied_nodes/$nodes policy node(s))"
    ANY_APPLIED=true
  fi
  return 0
}

apply_thermal() {
  local val="$1" p node saw=false
  # power-profiles-daemon owns the kernel platform profile: the powerprofilesctl
  # call in apply_epp already commands the matching profile. Writing
  # platform-profile sysfs here would desynchronize PPD's internal state
  # machine and reset desktop power UIs, so skip direct writes entirely while
  # PPD is active (not an error — PPD keeps platform profile in sync with EPP).
  if command -v powerprofilesctl >/dev/null 2>&1 &&
     systemctl is-active --quiet power-profiles-daemon.service; then
    # v15.3 (I-25): PPD keeps the platform profile in sync with the EPP profile
    # commanded above — a real result, not a silent skip.
    KNOB_STATE[thermal]="applied via power-profiles-daemon (profile follows PPD)"
    ANY_APPLIED=true
    return 0
  fi
  for node in /sys/class/platform_profile/*/profile /sys/firmware/acpi/platform_profile; do
    [[ -w "$node" ]] || continue
    saw=true
    if { printf '%s\n' "$val" > "$node"; } 2>/dev/null; then
      KNOB_STATE[thermal]="applied ($node)"
      ANY_APPLIED=true
      return 0
    fi
  done
  if [[ -w /sys/devices/platform/asus-nb-wmi/throttle_thermal_policy ]]; then
    saw=true
    case "$val" in
      balanced)    p=0 ;;
      performance) p=1 ;;
      quiet)       p=2 ;;
      *)           p="" ;;
    esac
    if [[ -n "$p" ]] &&
       { printf '%s\n' "$p" > /sys/devices/platform/asus-nb-wmi/throttle_thermal_policy; } 2>/dev/null; then
      KNOB_STATE[thermal]="applied (asus-nb-wmi throttle_thermal_policy=$p)"
      ANY_APPLIED=true
      return 0
    fi
  fi
  if [[ "$saw" == true ]]; then
    KNOB_STATE[thermal]="failed (interface present, every write rejected)"
    ANY_FAILED=true
  else
    KNOB_STATE[thermal]="unsupported (no writable platform profile interface)"
  fi
  return 0
}

# v15.3 (I-06): the global PCIe ASPM policy knob
# (/sys/module/pcie_aspm/parameters/policy) is deliberately NOT touched.
# It is unowned (no manager here claims it), unrecorded (no config file says
# what was written) and unrollbackable (--restore-defaults has no saved value
# to put back, and an operator may have chosen pcie_aspm.policy on the kernel
# cmdline). ASPM is precisely this platform's sensitive subsystem: the MT7902
# needs disable_aspm=1 for link stability, so silently rewriting the global
# policy is the one thing that must not happen automatically.

apply_wifi_powersave() {
  local val="$1" iface flags nodes=0 applied=0
  if ! command -v iw >/dev/null 2>&1; then
    KNOB_STATE[wifi_powersave]="unsupported (iw is not installed)"
    return 0
  fi
  case "$val" in
    on|off) ;;
    *)
      KNOB_STATE[wifi_powersave]="unsupported (invalid value '$val')"
      return 0
      ;;
  esac
  while IFS= read -r iface; do
    [[ -n "$iface" && -r "/sys/class/net/$iface/flags" ]] || continue
    flags="$(cat "/sys/class/net/$iface/flags" 2>/dev/null || true)"
    [[ "$flags" =~ ^0x[[:xdigit:]]+$ ]] || continue
    (( flags & 1 )) || continue  # IFF_UP: never bring an inactive interface up.
    nodes=$((nodes + 1))
    if iw dev "$iface" set power_save "$val" >/dev/null 2>&1; then
      applied=$((applied + 1))
    fi
  done < <(iw dev 2>/dev/null | awk '$1 == "Interface" {print $2}' || true)
  if (( nodes == 0 )); then
    KNOB_STATE[wifi_powersave]="unsupported (no active wireless interface)"
  elif (( applied == 0 )); then
    KNOB_STATE[wifi_powersave]="failed ($nodes interface(s) present, every write rejected)"
    ANY_FAILED=true
  else
    KNOB_STATE[wifi_powersave]="applied ($applied/$nodes interface(s))"
    ANY_APPLIED=true
  fi
  return 0
}

apply_audio_powersave() {
  local val="$1" node=/sys/module/snd_hda_intel/parameters/power_save
  # v15.3 (I-25): when Intel SOF owns the internal audio (this machine)
  # snd_hda_intel may not be loaded at all, so the node does not exist. That is
  # 'unsupported', and the old code called it applied anyway.
  if [[ ! -e "$node" ]]; then
    KNOB_STATE[audio_powersave]="unsupported (snd_hda_intel power_save not exposed; Intel SOF path)"
    return 0
  fi
  if [[ ! -w "$node" ]]; then
    KNOB_STATE[audio_powersave]="unsupported (power_save not writable)"
    return 0
  fi
  if { printf '%s\n' "$val" > "$node"; } 2>/dev/null; then
    KNOB_STATE[audio_powersave]="applied ($val)"
    ANY_APPLIED=true
  else
    KNOB_STATE[audio_powersave]="failed (write to power_save rejected)"
    ANY_FAILED=true
  fi
  return 0
}

if [[ "$AC" == "1" ]]; then
  # On AC: maximum sustained performance within firmware/thermal limits.
  POWER_LABEL="AC"
  apply_epp "performance"
  apply_thermal "performance"
  apply_wifi_powersave "off"
  apply_audio_powersave 0
else
  # On battery: EPP-driven power saving; no hard CPU/iGPU frequency ceilings,
  # RAPL overrides, backlight caps, or writeback delays (HWP race-to-sleep and
  # GuC SLPC govern CPU/GPU clocks natively).
  POWER_LABEL="battery"
  apply_epp "balance_power"
  apply_thermal "balanced"
  apply_wifi_powersave "on"
  apply_audio_powersave 1
fi

# v15.3 (I-25): report every knob's real state in one line, and fail the unit
# only when something writable was present and every write to it was rejected.
echo "vivobook-power-switch v15.3: $POWER_LABEL — epp=${KNOB_STATE[epp]:-unknown} | thermal=${KNOB_STATE[thermal]:-unknown} | wifi_powersave=${KNOB_STATE[wifi_powersave]:-unknown} | audio_powersave=${KNOB_STATE[audio_powersave]:-unknown}"
if [[ "$ANY_FAILED" == true && "$ANY_APPLIED" != true ]]; then
  echo "vivobook-power-switch v15.3: a writable control existed but every write to it failed." >&2
  exit 1
fi
POWER_SWITCH_EOF
  chmod 0755 /usr/local/bin/vivobook-power-switch.sh

  # Create udev rule with systemd integration
  atomic_write /etc/udev/rules.d/99-vivobook-power.rules 0644 << 'UDEV_EOF'
# Managed by vivobook_optimize.sh v15.3 --with-auto-power
# SYSTEMD_WANTS alone does not restart an already-active oneshot service.
# Queue a nonblocking restart on every adapter change; run tuning in systemd,
# never a long-running helper inside the udev worker.
ACTION=="change", SUBSYSTEM=="power_supply", ATTR{online}=="?*", TAG+="systemd", RUN+="/usr/bin/systemctl --no-block restart vivobook-power-switch.service"
UDEV_EOF

  # Create systemd boot-time oneshot service
  write_unit_file /etc/systemd/system/vivobook-power-switch.service 0644 << 'EOF'
# Managed by vivobook_optimize.sh v15.3
[Unit]
Description=Set ASUS Vivobook v15.3 AC/battery power profile
After=basic.target asus-thermal-profile.service intel-epp-profile.service rapl-power-limits.service
After=NetworkManager.service systemd-sysctl.service
# v15.3 (I-05): ordering only, no Wants= (ignored when PPD is absent).
After=power-profiles-daemon.service
# Adapter plug/unplug produces a burst of udev-triggered restarts; never
# rate-limit this service into a StartLimitBurst failure state.
StartLimitIntervalSec=0
ConditionPathExists=/usr/local/bin/vivobook-power-switch.sh

[Service]
Type=oneshot
ExecStart=/usr/local/bin/vivobook-power-switch.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable vivobook-power-switch.service
  udevadm control --reload-rules 2>/dev/null || true
  if systemctl restart vivobook-power-switch.service; then
    echo "   Dynamic power switching enabled: boot service + udev rule installed."
    echo "   Changes apply immediately on AC plug/unplug events."
    echo "   AC requests: performance EPP/thermal, Wi-Fi power save off."
    echo "   Battery requests: balance_power EPP (power-saver via PPD), balanced thermal, Wi-Fi power save on."
    echo "   Profiles apply via power-profiles-daemon when active; PPD then also owns"
    echo "   the platform profile (direct sysfs thermal writes are skipped in that case)."
    echo "   Without PPD, profiles apply via sysfs directly. Audio power_save: 0 (AC) / 1 (battery)"
    echo "   where snd_hda_intel exposes it — on this machine Intel SOF owns the internal"
    echo "   audio, so that knob is normally unsupported and is reported as such."
    echo "   The helper prints a per-knob state line (applied / unsupported / failed) and only"
    echo "   fails when a writable control existed and every write to it was rejected."
    echo "   No CPU/iGPU frequency clamps, RAPL overrides, backlight changes, or writeback changes."
    echo "   The global PCIe ASPM policy is not written: it is unowned, unrecorded and"
    echo "   unrollbackable, and ASPM is this platform's sensitive subsystem."
    echo "   Unsupported/firmware-locked controls are skipped; other power managers may override runtime settings."
  else
    echo "   WARNING: boot service failed; check journalctl -u vivobook-power-switch.service" >&2
  fi
  fi
else
  echo "   Skipped. Re-run with --with-auto-power to enable dynamic AC/battery switching."
fi

echo "== 20. Intel RAPL power limits (--pl1 / --pl2) =="
if [[ -n "$PL1" || -n "$PL2" ]]; then
  RAPL_BASE=""
  for d in /sys/class/powercap/intel-rapl:0 /sys/class/powercap/intel-rapl-mmio:0; do
    if [[ -r "$d/constraint_0_power_limit_uw" ]]; then
      RAPL_BASE="$d"
      break
    fi
  done

  if [[ -z "$RAPL_BASE" ]]; then
    echo "   UNSUPPORTED: no readable intel-rapl package domain found. Nothing changed."
    echo "   (RAPL left fully unmanaged — no values were invented.)"
    echo "   Check: ls /sys/class/powercap/intel-rapl*/"
  else
    RAPL_DIR="$(dirname "$RAPL_BASE")"
    RAPL_PKG="$(basename "$RAPL_BASE")"
    echo "   RAPL interface found: $RAPL_DIR/$RAPL_PKG"

    # v15.3 (I-01): probe EACH REQUESTED constraint independently. v15.2 wrote
    # only constraint_0 (PL1) back, so on this machine — BIOS MSR-locks PL1 at
    # 200 W while PL2 is writable at 45 W — every run reported "RAPL registers
    # are LOCKED by firmware" and the writable PL2 was never applied.
    RAPL_PL1_LOCKED=false
    RAPL_PL2_LOCKED=false
    if [[ "$DRY_RUN" == true ]]; then
      # v15.3 (I-10): the probe is a write, so it is skipped here — and that is
      # reported, instead of letting later lines imply the outcome is known.
      echo "   [DRY-RUN] Firmware-lock probe NOT performed (it is a write); a real run will"
      echo "   [DRY-RUN] probe each requested constraint independently."
    else
      if [[ -n "$PL1" ]]; then
        RAPL_PL1_STATE="$(rapl_probe_lock_state "$RAPL_BASE/constraint_0_power_limit_uw")"
        [[ "$RAPL_PL1_STATE" == locked ]] && RAPL_PL1_LOCKED=true
        echo "   PL1 (constraint_0) lock probe: $RAPL_PL1_STATE"
      fi
      if [[ -n "$PL2" ]]; then
        RAPL_PL2_STATE="$(rapl_probe_lock_state "$RAPL_BASE/constraint_1_power_limit_uw")"
        [[ "$RAPL_PL2_STATE" == locked ]] && RAPL_PL2_LOCKED=true
        echo "   PL2 (constraint_1) lock probe: $RAPL_PL2_STATE"
      fi
    fi

    # Only EVERY requested constraint being locked is a full firmware lock. A
    # partial lock is a NOTE, not a warning: the writable half still applies,
    # and its value is never invented or discarded.
    RAPL_REQUESTED=0
    RAPL_LOCKED_REQUESTED=0
    if [[ -n "$PL1" ]]; then
      RAPL_REQUESTED=$((RAPL_REQUESTED + 1))
      [[ "$RAPL_PL1_LOCKED" == true ]] && RAPL_LOCKED_REQUESTED=$((RAPL_LOCKED_REQUESTED + 1))
    fi
    if [[ -n "$PL2" ]]; then
      RAPL_REQUESTED=$((RAPL_REQUESTED + 1))
      [[ "$RAPL_PL2_LOCKED" == true ]] && RAPL_LOCKED_REQUESTED=$((RAPL_LOCKED_REQUESTED + 1))
    fi
    RAPL_ALL_LOCKED=false
    RAPL_ANY_LOCKED=false
    (( RAPL_LOCKED_REQUESTED > 0 )) && RAPL_ANY_LOCKED=true
    if (( RAPL_REQUESTED > 0 && RAPL_LOCKED_REQUESTED == RAPL_REQUESTED )); then
      RAPL_ALL_LOCKED=true
    fi
    if [[ "$RAPL_ALL_LOCKED" == true ]]; then
      echo "   WARNING: every requested RAPL constraint is LOCKED by firmware (BIOS MSR lock," >&2
      echo "   EPERM on write). The kernel rejects those changes on this system; the persistent" >&2
      echo "   service will still be installed so limits apply if a future BIOS unlocks them," >&2
      echo "   but the boot service will report 'failed' rather than pretend success." >&2
    elif [[ "$RAPL_ANY_LOCKED" == true ]]; then
      echo "   NOTE: only PART of the requested limits is firmware-locked (PL1 locked=$RAPL_PL1_LOCKED,"
      echo "   PL2 locked=$RAPL_PL2_LOCKED). The writable constraint is applied; the locked one is"
      echo "   left exactly as firmware set it (its value is never invented)."
    fi

    # Live hardware envelope — read-only. Missing values stay EMPTY and are
    # never replaced with an arbitrary wattage.
    PL1_HW=""
    PL2_HW=""
    if [[ -r "$RAPL_BASE/constraint_0_power_limit_uw" ]]; then
      RAPL_VAL="$(cat "$RAPL_BASE/constraint_0_power_limit_uw" 2>/dev/null || echo 0)"
      if [[ "$RAPL_VAL" =~ ^[0-9]+$ ]] && (( RAPL_VAL > 0 )); then
        PL1_HW=$(( RAPL_VAL / 1000000 ))
      fi
    fi
    if [[ -r "$RAPL_BASE/constraint_1_power_limit_uw" ]]; then
      RAPL_VAL="$(cat "$RAPL_BASE/constraint_1_power_limit_uw" 2>/dev/null || echo 0)"
      if [[ "$RAPL_VAL" =~ ^[0-9]+$ ]] && (( RAPL_VAL > 0 )); then
        PL2_HW=$(( RAPL_VAL / 1000000 ))
      fi
    fi
    echo "   Live hardware envelope: PL1=${PL1_HW:-unknown}W PL2=${PL2_HW:-unknown}W (informational; never persisted)."

    # Cross-validate a single-flag request against the live counterpart so an
    # invalid PL1<=PL2 relationship cannot be created. When the counterpart
    # is not readable we proceed — assuming nothing is safer than inventing.
    if [[ -n "$PL1" && -z "$PL2" && -n "$PL2_HW" ]] && (( 10#$PL1 > 10#$PL2_HW )); then
      echo "   ERROR: --pl1=${PL1}W exceeds the live hardware PL2 (${PL2_HW}W)." >&2
      echo "   Also pass --pl2, or lower --pl1. No value was invented for the other limit." >&2
      exit 2
    fi
    if [[ -n "$PL2" && -z "$PL1" && -n "$PL1_HW" ]] && (( 10#$PL2 < 10#$PL1_HW )); then
      # v15.3 (I-02): PL1 <= PL2 is not honored by every firmware. When the
      # live firmware state ALREADY reports PL2 < PL1, that invariant does not
      # hold on this machine (PL1 is MSR-locked at 200 W; PL2 is the writable,
      # meaningful burst limit), and refusing here would make it impossible to
      # apply the one constraint that CAN be applied. The hard failure is kept
      # when the invariant holds live, and when PL2_HW is unreadable.
      if [[ -n "$PL2_HW" ]] && (( 10#$PL2_HW < 10#$PL1_HW )); then
        echo "   NOTE: the live firmware state already reports PL2 (${PL2_HW}W) below PL1"
        echo "   (${PL1_HW}W), so this platform does not honor PL1 <= PL2. Proceeding; PL1"
        echo "   stays under firmware control and is never written."
      else
        echo "   ERROR: --pl2=${PL2}W is below the live hardware PL1 (${PL1_HW}W)." >&2
        echo "   Also pass --pl1, or raise --pl2. No value was invented for the other limit." >&2
        exit 2
      fi
    fi

    # Reject requests above a kernel-exposed constraint maximum, when present.
    check_constraint_max() {
      local watts="$1" maxfile="$2" label="$3" max_uw=""
      [[ -r "$maxfile" ]] || return 0
      max_uw="$(cat "$maxfile" 2>/dev/null || true)"
      [[ "$max_uw" =~ ^[0-9]+$ ]] && (( max_uw > 0 )) || return 0
      if (( 10#$watts * 1000000 > max_uw )); then
        echo "   ERROR: ${label}=${watts}W exceeds this constraint's hardware maximum ($(( max_uw / 1000000 ))W)." >&2
        return 1
      fi
      return 0
    }
    if [[ -n "$PL1" ]] && ! check_constraint_max "$PL1" "$RAPL_BASE/constraint_0_max_power_uw" "PL1"; then
      exit 2
    fi
    if [[ -n "$PL2" ]] && ! check_constraint_max "$PL2" "$RAPL_BASE/constraint_1_max_power_uw" "PL2"; then
      exit 2
    fi

    # Only explicitly requested limits become managed configuration. The
    # other constraint stays firmware-controlled: EMPTY in the config — a
    # value for it is NEVER invented (not from defaults, not from the live
    # value, not from a guess).
    atomic_write /etc/default/vivobook-rapl 0644 << EOF
# Managed by vivobook_optimize.sh v15.3
# PL1/PL2 in watts. An EMPTY value means: leave that constraint under
# firmware control — it is not written by the boot service.
PL1=${PL1:-}
PL2=${PL2:-}
EOF
    chmod 0644 /etc/default/vivobook-rapl

    atomic_write /usr/local/bin/set-rapl-limits.sh 0755 << 'RAPL_EOF'
#!/usr/bin/env bash
# Managed by vivobook_optimize.sh v15.3
set -Eeuo pipefail

CONFIG="/etc/default/vivobook-rapl"
[[ -r "$CONFIG" ]] || { echo "No RAPL config found." >&2; exit 1; }
# shellcheck disable=SC1091
. "$CONFIG"

# v15.2: PL1/PL2 may be EMPTY, meaning "leave this constraint under firmware
# control". Only managed (non-empty) constraints are written; a value for the
# other constraint is never invented here.
PL1="${PL1:-}"
PL2="${PL2:-}"

rapl_valid_watts() {
  local label="$1" val="$2"
  [[ -z "$val" ]] && return 0
  if [[ ! "$val" =~ ^[0-9]+$ ]] || (( 10#$val <= 0 )); then
    echo "Invalid persisted RAPL ${label}='${val}'; refusing to apply." >&2
    return 1
  fi
  return 0
}

rapl_valid_watts PL1 "$PL1" || exit 1
rapl_valid_watts PL2 "$PL2" || exit 1
if [[ -n "$PL1" && -n "$PL2" ]] && (( 10#$PL1 > 10#$PL2 )); then
  echo "Persisted RAPL configuration is invalid: PL1 (${PL1}W) exceeds PL2 (${PL2}W)." >&2
  exit 1
fi
if [[ -z "$PL1" && -z "$PL2" ]]; then
  echo "RAPL config manages no constraints (PL1/PL2 both empty); nothing to do." >&2
  exit 1
fi

# Attempt a write; distinguish "applied" from "rejected by firmware lock".
# Returns 0 on success, 1 on any failure (EPERM/EACCES/EINVAL).
try_write() {
  local val="$1" node="$2"
  # v15.3 (I-23): a compound-command redirect, so the shell's own
  # "Permission denied" for the failed open is suppressed too — with
  # 'cmd > file 2>/dev/null' the message escapes to stderr before 2>/dev/null
  # takes effect, which made every firmware-locked PL1 write look like a crash.
  { printf '%s\n' "$val" > "$node"; } 2>/dev/null
}

APPLIED=0
LOCKED=0
for d in /sys/class/powercap/intel-rapl:0 /sys/class/powercap/intel-rapl-mmio:0; do
  [[ -d "$d" ]] || continue
  NAME="$(cat "$d/name" 2>/dev/null || echo "$(basename "$d")")"
  if [[ -n "$PL1" && -w "$d/constraint_0_power_limit_uw" ]]; then
    if try_write "$(( 10#$PL1 * 1000000 ))" "$d/constraint_0_power_limit_uw"; then
      echo "Set ${NAME} PL1 = ${PL1} W"
      APPLIED=$((APPLIED + 1))
    else
      echo "WARNING: ${NAME} PL1 write rejected (EPERM) — RAPL registers are locked by firmware." >&2
      LOCKED=$((LOCKED + 1))
    fi
  fi
  if [[ -n "$PL2" && -w "$d/constraint_1_power_limit_uw" ]]; then
    if try_write "$(( 10#$PL2 * 1000000 ))" "$d/constraint_1_power_limit_uw"; then
      echo "Set ${NAME} PL2 = ${PL2} W"
      APPLIED=$((APPLIED + 1))
    else
      echo "WARNING: ${NAME} PL2 write rejected (EPERM) — RAPL registers are locked by firmware." >&2
      LOCKED=$((LOCKED + 1))
    fi
  fi
done

if (( APPLIED == 0 && LOCKED > 0 )); then
  echo "RAPL power limits are locked by BIOS/firmware (MSR PL lock bit set); nothing applied." >&2
  echo "Surface this boot as 'failed' via exit 1 so it is never mistaken for success;" >&2
  echo "a BIOS update or setting may unlock the MSRs." >&2
  exit 1
fi
if (( APPLIED == 0 )); then
  echo "No writable RAPL constraint nodes found for the managed limits." >&2
  exit 1
fi
RAPL_EOF
    chmod 0755 /usr/local/bin/set-rapl-limits.sh

    write_unit_file /etc/systemd/system/rapl-power-limits.service 0644 << 'EOF'
# Managed by vivobook_optimize.sh v15.3
[Unit]
Description=Set Intel RAPL power limits (PL1/PL2)
After=basic.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/set-rapl-limits.sh

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable rapl-power-limits.service
    if [[ "$RAPL_ALL_LOCKED" == true ]]; then
      echo "   RAPL service installed (PL1=${PL1:-firmware}W, PL2=${PL2:-firmware}W requested) but every"
      echo "   requested constraint is firmware-locked — limits take effect only if the MSRs become"
      echo "   writable; the service reports the lock instead of pretending success."
    elif systemctl restart rapl-power-limits.service; then
      if [[ "$DRY_RUN" == true ]]; then
        # v15.3 (I-10): the dry-run outcome is NOT known — it depends on a
        # per-constraint probe that requires a real write.
        echo "[DRY-RUN] RAPL limits would be handed to rapl-power-limits.service (PL1=${PL1:-firmware}W, PL2=${PL2:-firmware}W)."
        echo "[DRY-RUN] Whether the firmware accepts them is unknown in dry-run: the lock probe"
        echo "[DRY-RUN] above did not run, so no 'applied' claim is made."
      else
        echo "   RAPL limits applied and persisted at boot: PL1=${PL1:-firmware}W, PL2=${PL2:-firmware}W"
      fi
    else
      echo "   WARNING: RAPL service failed; check:" >&2
      echo "     journalctl -u rapl-power-limits.service" >&2
    fi
  fi
else
  echo "   Not requested. Use --pl1=WATTS --pl2=WATTS to manage specific limits."
  echo "   Providing only one value manages only that constraint; the other stays firmware-controlled."
fi

if [[ "$WITH_AUTO_POWER" == true && ( -n "$PL1" || -n "$PL2" ) ]]; then
  echo "   Auto-power takes runtime precedence over static --pl1/--pl2; reapplying current AC/battery profile."
  systemctl restart vivobook-power-switch.service ||
    echo "   WARNING: dynamic profile reapply failed; check journalctl -u vivobook-power-switch.service" >&2
fi

echo "== 21. NVMe I/O scheduler (kernel default) =="
# blk-mq already defaults multiqueue NVMe devices to the 'none' scheduler; a
# udev rule forcing it is redundant. Remove any rule managed by earlier runs —
# v15.3 (I-16): never an unmanaged one.
if [[ -e /etc/udev/rules.d/99-vivobook-nvme.rules ]] &&
   ! is_managed_file /etc/udev/rules.d/99-vivobook-nvme.rules; then
  echo "   NOTE: /etc/udev/rules.d/99-vivobook-nvme.rules exists and is not script-managed;"
  echo "   NOTE: it was preserved and left in effect."
else
  remove_managed_config /etc/udev/rules.d/99-vivobook-nvme.rules
fi
udevadm control --reload-rules 2>/dev/null || true
echo "   NVMe I/O scheduler left at the kernel default ('none' for multiqueue NVMe)."
echo "   Managed udev rule removed if present."
echo "   To verify: cat /sys/block/nvme*/queue/scheduler"

echo "== 22. Video Acceleration Environment (deprecated) =="
# LIBVA_DRIVER_NAME=iHD is redundant (libva auto-selects iHD on Intel Gen8+) and
# MOZ_ENABLE_WAYLAND=1 is obsolete (Firefox 121+ uses Wayland natively). Remove
# any environment.d snippet managed by earlier runs of this script — v15.3
# (I-16): never an unmanaged one.
if [[ -e /etc/environment.d/99-vivobook-vaapi.conf ]] &&
   ! is_managed_file /etc/environment.d/99-vivobook-vaapi.conf; then
  echo "   NOTE: /etc/environment.d/99-vivobook-vaapi.conf exists and is not script-managed;"
  echo "   NOTE: it was preserved. Remove it yourself if it is stale."
else
  remove_managed_config /etc/environment.d/99-vivobook-vaapi.conf
  echo "   /etc/environment.d/99-vivobook-vaapi.conf removed if script-managed and present."
fi
echo "   VA-API driver selection and Firefox protocol handling are left to upstream defaults."

echo "== 23. Keyboard backlight inactivity timeout (--with-kbd-timeout) =="
if [[ "$WITH_KBD_TIMEOUT" == true ]]; then
  KBD_LED=/sys/class/leds/asus::kbd_backlight
  if [[ -d "$KBD_LED" ]]; then
    # Write helper script
    atomic_write /usr/local/bin/vivobook-kbd-timeout.sh 0755 << 'KBD_EOF'
#!/usr/bin/env bash
# Managed by vivobook_optimize.sh v15.3 --with-kbd-timeout
set -Eeuo pipefail

KBD_LED=/sys/class/leds/asus::kbd_backlight

if [[ ! -d "$KBD_LED" ]]; then
  # Optional feature on systems without ASUS keyboard backlight: exit 0 so the
  # boot service stays clean (no-interface = not a failure).
  echo "Unsupported: keyboard backlight device not found at $KBD_LED"
  exit 0
fi

# Firmware-controlled stop_time; never alter the user's brightness as a fallback.
if [[ -w "$KBD_LED/stop_time" ]]; then
  { printf '%s\n' 30 > "$KBD_LED/stop_time"; } 2>/dev/null
  echo "Set keyboard backlight stop_time to 30s (firmware-controlled auto-off)."
  exit 0
else
  echo "Firmware stop_time not supported; leaving backlight brightness untouched."
  exit 0
fi
KBD_EOF
    chmod 0755 /usr/local/bin/vivobook-kbd-timeout.sh

    atomic_write /usr/lib/systemd/system-sleep/vivobook-kbd-timeout 0755 << 'EOF'
#!/usr/bin/env bash
# Managed by vivobook_optimize.sh v15.3
if [[ "${1:-}" == post ]]; then
  systemctl restart vivobook-kbd-timeout.service >/dev/null 2>&1 || true
fi
EOF
    chmod 0755 /usr/lib/systemd/system-sleep/vivobook-kbd-timeout

    # Create systemd service
    write_unit_file /etc/systemd/system/vivobook-kbd-timeout.service 0644 << 'EOF'
# Managed by vivobook_optimize.sh v15.3
[Unit]
Description=Set keyboard backlight inactivity timeout (30s)
After=basic.target
ConditionPathExists=/usr/local/bin/vivobook-kbd-timeout.sh

[Service]
Type=oneshot
ExecStart=/usr/local/bin/vivobook-kbd-timeout.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable vivobook-kbd-timeout.service
    if systemctl restart vivobook-kbd-timeout.service; then
      echo "   Keyboard backlight timeout service enabled and applied."
      if [[ -w "$KBD_LED/stop_time" ]]; then
        echo "   Firmware will auto-dim after 30s of inactivity."
      else
        echo "   (Firmware lacks stop_time support; backlight brightness left untouched.)"
      fi
    else
      echo "   WARNING: keyboard backlight service failed; check journalctl -u vivobook-kbd-timeout.service" >&2
    fi
  else
    echo "   Keyboard backlight device ($KBD_LED) not found on this system."
    echo "   No service installed."
  fi
else
  echo "   Skipped. Re-run with --with-kbd-timeout to enable keyboard backlight auto-off."
fi

log_summary "$@"

echo ""
echo "===================================================="
echo "Done — ASUS Vivobook Optimization Pass v15.3."
echo "Flags this run:"
echo "  guc=$WITH_GUC"
echo "  auto-upgrade=$WITH_AUTO_UPGRADE maintenance-schedule=$MAINTENANCE_SCHEDULE"
echo "  multiverse=$WITH_MULTIVERSE battery-limit=${BATTERY_LIMIT:-unchanged}"
echo "  sysctl=$WITH_SYSCTL audio-powersave=$WITH_AUDIO_POWERSAVE"
echo "  fan-profile=${FAN_PROFILE:-unchanged} epp=${EPP_PROFILE:-unchanged}"
echo "  zram=$WITH_ZRAM"
echo "  auto-power=$WITH_AUTO_POWER pl1=${PL1:-unchanged} pl2=${PL2:-unchanged}"
echo "  kbd-timeout=$WITH_KBD_TIMEOUT"
echo "  bbr=$WITH_BBR browser-wayland=$WITH_BROWSER_WAYLAND"
echo "  usb-autosuspend=$WITH_USB_AUTOSUSPEND disable-ppd=$DISABLE_PPD"
echo "  force-tlp-override=$FORCE_TLP_OVERRIDE"
echo "  dry-run=$DRY_RUN"
echo "  skip-update=$SKIP_UPDATE full-upgrade=$WITH_FULL_UPGRADE"
echo ""

if [[ -e /var/run/reboot-required ]]; then
  echo "System packages report a reboot IS required (/var/run/reboot-required):"
  [[ -f /var/run/reboot-required.pkgs ]] &&
    sed 's/^/  /' /var/run/reboot-required.pkgs
fi

echo "Also reboot to apply: CPU microcode (if its version changed this run);"
echo "snd_hda_intel power_save — only when the legacy HDA path is active, because this"
echo "machine uses Intel SOF where step 12 stages nothing; the mt7921e ASPM workaround"
echo "if --with-mt7921e-aspm staged it this run; unloading of module parameters staged"
echo "by earlier script versions (i915/iwlwifi, if any); and staged fwupd firmware"
echo "updates (if --with-auto-upgrade applied any)."
echo "thermald, VA-API packages, fstrim.timer, sysctl tuning, battery threshold,"
echo "thermal profile, EPP, zRAM, dynamic power switching, RAPL limits, keyboard"
echo "backlight timeout, and the maintenance timer are active now when requested"
echo "and supported (VA-API: restart already-running apps to pick it up)."
echo ""
echo "Verify after reboot:"
echo "  sudo fwupdmgr get-devices"
echo "  vainfo                       # run as your normal user, not root/sudo"
echo "  sudo dmesg | grep -iE 'GuC|HuC|microcode'"
echo "  systemctl list-timers"
echo "  journalctl -u system-maintenance.service"
echo "  sysctl vm.swappiness fs.inotify.max_user_watches kernel.nmi_watchdog vm.dirty_writeback_centisecs"
echo "  cat /sys/module/snd_hda_intel/parameters/power_save   # legacy HDA only; SOF here"
echo "  cat /sys/module/mt7921e/parameters/disable_aspm"
echo "  sudo bash $SCRIPT_PATH --safe-mode-check              # boot/Wi-Fi integrity gate"
echo "  cat /sys/class/power_supply/BAT*/charge_control_end_threshold"
echo "  systemctl status battery-charge-threshold.service"
echo "  cat /sys/firmware/acpi/platform_profile"
echo "  cat /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference"
echo "  cat /sys/power/mem_sleep"
echo "  sudo cat /sys/kernel/debug/pmc_core/package_cstate_show"
echo "  swapon --show"
echo "  cat /sys/class/powercap/intel-rapl*/name"
echo "  cat /sys/block/nvme*/queue/scheduler"
echo "  cat /sys/class/leds/asus::kbd_backlight/stop_time"
echo "  sudo bash $SCRIPT_PATH --status"
echo "===================================================="

# v15.3 (I-12): last line of a dry-run, so the banner cannot be misread as a
# statement about the simulated actions listed above it.
if [[ "$DRY_RUN" == true ]]; then
  echo "=== END DRY RUN — no files were modified. ==="
fi
