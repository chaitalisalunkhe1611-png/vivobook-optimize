#!/usr/bin/env bash
# Fixture-only regression tests. Host /etc and /sys are never written.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
# Extract definitions before dispatch, redirect host paths into a private tree.
# This is a test harness only; the shipped script has no alternate-root flag.
sed '/^# ---- Pre-root read-only commands/,$d' vivobook_optimize.sh |
  sed -e "s|/etc/|$TMP/etc/|g" -e "s|/sys/|$TMP/sys/|g" \
      -e "s|/usr/lib/systemd/|$TMP/usr/lib/systemd/|g" > "$TMP/library.sh"
# Dynamic fixture generated above, never a host-provided defaults file.
# shellcheck source=/dev/null
source "$TMP/library.sh"
trap 'cleanup_tmp_registry; rm -rf "$TMP"' EXIT
mkdir -p "$TMP/etc/sysctl.d" "$TMP/sys/class/power_supply" "$TMP/gpu"
src="$TMP/etc/sysctl.d/99-vivobook.conf"
dest="$TMP/etc/sysctl.d/90-vivobook-local.conf"
printf '%s\n' '# Managed by vivobook_optimize.sh v16' 'vm.swappiness = 100' \
  'net.ipv6.conf.all.disable_ipv6 = 1' 'net.ipv6.conf.all.disable_ipv6 = 1' > "$src"
migrate_custom_vivobook_sysctls > /dev/null
[[ "$(grep -c '^net.ipv6' "$dest")" == 1 ]]
if grep -q '^vm.swappiness' "$dest"; then exit 1; fi
cp "$dest" "$TMP/migrated"
migrate_custom_vivobook_sysctls > /dev/null
cmp "$dest" "$TMP/migrated"
restore_remove_owned "$src"
restore_custom_vivobook_sysctls
[[ ! -e "$dest" ]] && grep -q '^net.ipv6' "$src"
if is_managed_file "$src"; then exit 1; fi
echo 'PASS A-01 migration, exact deduplication, repeat-run identity, restore preserves custom data'
printf '%s\n' '# Managed by vivobook_optimize.sh v16' 'net.ipv6.conf.all.disable_ipv6 = 1' > "$src"
printf '%s\n' '# administrator-owned' 'net.ipv6.conf.all.disable_ipv6 = 0' > "$dest"
cp "$src" "$TMP/original"
if migrate_custom_vivobook_sysctls > /dev/null 2>&1; then echo 'FAIL unowned migration destination'; exit 1; fi
cmp "$src" "$TMP/original"
printf '%s\n' '# Managed by vivobook_optimize.sh v16.1' 'net.ipv6.conf.all.disable_ipv6 = 0' > "$dest"
if migrate_custom_vivobook_sysctls > /dev/null 2>&1; then echo 'FAIL conflicting migration key'; exit 1; fi
cmp "$src" "$TMP/original"
echo 'PASS A-01 unowned/conflicting destination refuses migration without source loss'
for node in rps_cur_freq_mhz gt_cur_freq_mhz cur_freq act_freq; do
  printf '450\n' > "$TMP/gpu/$node"
  [[ "$(igpu_current_freq "$TMP/gpu")" == 450 ]]
  rm "$TMP/gpu/$node"
done
printf 'unreadable-data\n' > "$TMP/gpu/cur_freq"
printf '500\n' > "$TMP/gpu/act_freq"
[[ "$(igpu_current_freq "$TMP/gpu")" == 500 ]]
echo 'PASS A-03 all four frequency names and fallback after invalid cur_freq'
root="$TMP/sys/class/power_supply"
mkdir -p "$root/AC" "$root/PD"
printf 'Mains\n' > "$root/AC/type"; printf '0\n' > "$root/AC/online"
for type in Mains USB USB_PD USB_C; do
  printf '%s\n' "$type" > "$root/PD/type"; printf '1\n' > "$root/PD/online"
  is_external_power_online "$root"
done
printf '0\n' > "$root/PD/online"
rc=0; is_external_power_online "$root" || rc=$?; [[ "$rc" == 1 ]]
rc=0; is_external_power_online "$TMP/missing" || rc=$?; [[ "$rc" == 2 ]]
echo 'PASS A-07 offline first supply, all four online types, offline/unknown states'
mkdir -p "$(dirname "$AUDIO_CONF")" "$AUDIO_PARAM_DIR"
printf '%s\n' 'options other_module power_save=99' \
  'options snd_hda_intel power_save=0010 power_save_controller=N # comment' > "$AUDIO_CONF"
printf '0\n' > "$AUDIO_PARAM_DIR/power_save"; printf 'N\n' > "$AUDIO_PARAM_DIR/power_save_controller"
[[ "$(battery_audio_timeout)" == 10 ]]
# Invoked indirectly by the sourced audio_staged_verdict fixture.
# shellcheck disable=SC2329
systemctl() { [[ "$*" == 'is-enabled --quiet vivobook-power-switch.service' ]]; }
[[ "$(audio_staged_verdict)" == overridden-by-auto-power ]]
for value in 0 invalid 999999999999999999999999; do
  printf 'options snd_hda_intel power_save=%s\n' "$value" > "$AUDIO_CONF"
  [[ "$(battery_audio_timeout)" == 1 ]]
done
printf '%s\n' 'options snd_hda_intel power_save=0 power_save_controller=Y' > "$AUDIO_CONF"
[[ "$(audio_staged_verdict)" == staged-differs-from-live ]]
echo 'PASS A-04 staged timeout parsing, fallback, enabled override, controller-only mismatch'
mkdir -p "$TMP/browser/.config"
printf '%s\n' '# Managed by vivobook_optimize.sh v16' '--ozone-platform-hint=auto' '--custom-flag' > "$TMP/browser/.config/chrome-flags.conf"
printf '%s\n' '# Managed by vivobook_optimize.sh v16' '--ozone-platform-hint=auto' > "$TMP/browser/.config/chromium-flags.conf"
printf '%s\n' '--ozone-platform-hint=x11' > "$TMP/browser/.config/brave-flags.conf"
browser_installed() { [[ "$1" == brave ]]; }
apply_browser_flags_for_user fixture "$(id -u)" "$(id -g)" "$TMP/browser" > /dev/null
[[ "$(cat "$TMP/browser/.config/chrome-flags.conf")" == --custom-flag ]]
[[ ! -e "$TMP/browser/.config/chromium-flags.conf" ]]
[[ "$(cat "$TMP/browser/.config/brave-flags.conf")" == --ozone-platform-hint=x11 ]]
echo 'PASS A-06 target-only cleanup, custom flags preserved, installed pinned Brave unchanged'
hook="$(sleep_hook_body vivobook-power-switch.service)"
[[ "$hook" == *'is-enabled --quiet vivobook-power-switch.service'* ]]
[[ " ${SLEEP_HOOK_PAIRS[*]} " == *' vivobook-power-switch:vivobook-power-switch.service '* ]]
# Compile/lint the actual generated helper and hook (without executing writes).
awk '/^    cat << '\''POWER_SWITCH_HEADER'\''/{copy=1;next} /^POWER_SWITCH_HEADER$/{copy=0} copy' vivobook_optimize.sh > "$TMP/power-switch.sh"
declare -f is_external_power_online audio_staged_options audio_staged_opt battery_audio_timeout >> "$TMP/power-switch.sh"
awk '/^    cat << '\''POWER_SWITCH_EOF'\''/{copy=1;next} /^POWER_SWITCH_EOF$/{copy=0} copy' vivobook_optimize.sh >> "$TMP/power-switch.sh"
printf '%s\n' "$hook" > "$TMP/sleep-hook.sh"
bash -n "$TMP/power-switch.sh"
bash -n "$TMP/sleep-hook.sh"
shellcheck "$TMP/power-switch.sh" "$TMP/sleep-hook.sh"
echo 'PASS A-04/A-05 generated helper and guarded hook: bash -n + shellcheck'
# Exercise callers as well as the shared frequency/power helpers.
: > "$TMP/etc/passwd" # No real desktop accounts in caller fixtures.
mkdir -p "$TMP/card/device/tile0/gt0/freq0"
freq="$TMP/card/device/tile0/gt0/freq0"
for pair in max_freq:1400 rp0_freq:1400 min_freq:300 cur_freq:450; do
  printf '%s\n' "${pair#*:}" > "$freq/${pair%%:*}"
done
find_intel_drm_card() { printf '%s\n' "$TMP/card"; }
detect_active_drm_driver() { printf 'xe\n'; }
# Invoked indirectly by dashboard/JSON fixture functions.
# shellcheck disable=SC2329
systemctl() { return 1; }
printf '1\n' > "$root/PD/online"
for node in cur_freq act_freq rps_cur_freq_mhz gt_cur_freq_mhz; do
  rm -f "$freq/cur_freq" "$freq/act_freq" "$freq/rps_cur_freq_mhz" "$freq/gt_cur_freq_mhz"
  printf '450\n' > "$freq/$node"
  show_status_json > "$TMP/fixture.json"
  jq -e '.igpu.cur_freq_mhz == 450 and .dynamic_power.ac_online == "1"' "$TMP/fixture.json" > /dev/null
  show_status_dashboard > "$TMP/fixture.status"
  grep -q 'Current frequency: 450 MHz' "$TMP/fixture.status"
  grep -q 'AC adapter online: yes' "$TMP/fixture.status"
done
echo 'PASS A-03/A-07 dashboard and JSON callers use current-frequency/power helpers'
# Keyboard device without stop_time and legacy ASUS thermal branch must keep keys.
mkdir -p "$TMP/sys/class/leds/asus::kbd_backlight" "$TMP/sys/devices/platform/asus-nb-wmi"
printf '1\n' > "$TMP/sys/class/leds/asus::kbd_backlight/brightness"
printf '0\n' > "$TMP/sys/devices/platform/asus-nb-wmi/throttle_thermal_policy"
show_status_json > "$TMP/fixture.json"
jq -e '.thermal.choices == null and (.thermal | has("choices"))
  and .keyboard_backlight.brightness == "1"
  and (.keyboard_backlight | has("stop_time")) and .keyboard_backlight.stop_time == null' "$TMP/fixture.json" > /dev/null
echo 'PASS A-08 legacy thermal choices and present keyboard without stop_time keys'
# Execute just step 13 in a redirected tree: unit and battery node both absent.
sed -n '/^echo "== 13\./,/^echo "== 14\./p' vivobook_optimize.sh | sed '$d' |
  sed -e "s|/etc/|$TMP/etc/|g" -e "s|/sys/|$TMP/sys/|g" \
      -e "s|/usr/lib/systemd/|$TMP/usr/lib/systemd/|g" \
      -e "s|/usr/local/bin/|$TMP/usr/local/bin/|g" > "$TMP/battery-step.sh"
mkdir -p "$TMP/usr/lib/systemd/system-sleep" "$TMP/usr/local/bin" "$TMP/etc/default"
printf '%s\n' '# Managed by vivobook_optimize.sh v16' > "$TMP/usr/lib/systemd/system-sleep/vivobook-battery"
printf '%s\n' '# administrator-owned helper' > "$TMP/usr/local/bin/set-battery-threshold.sh"
printf '%s\n' '# Managed by vivobook_optimize.sh v16' > "$TMP/etc/default/vivobook-battery"
lsmod() { printf 'asus_wmi\n'; }
export BATTERY_LIMIT=off # Consumed by the sourced, redirected step-13 fragment.
# Mutator calls are inert successes; queries remain disabled/not installed.
# shellcheck disable=SC2329
systemctl() { case "${1:-}" in daemon-reload|disable) return 0 ;; *) return 1 ;; esac; }
# Step fragment generated above; all mutation paths are in TMP.
# shellcheck source=/dev/null
source "$TMP/battery-step.sh" > /dev/null
[[ ! -e "$TMP/usr/lib/systemd/system-sleep/vivobook-battery" ]]
[[ ! -e "$TMP/etc/default/vivobook-battery" ]]
[[ -e "$TMP/usr/local/bin/set-battery-threshold.sh" ]]
echo 'PASS A-08 orphan cleanup without unit/battery sysfs, unowned helper preserved'
# A current node must remain visible even without a readable maximum node.
rm "$freq/max_freq"
show_status_json > "$TMP/fixture.json"
jq -e '.igpu.cur_freq_mhz == 450' "$TMP/fixture.json" > /dev/null
echo 'PASS A-03 current telemetry independent of max-frequency availability'
# Run the real generated hook against an inert systemctl mock, not systemd.
mkdir -p "$TMP/mockbin"
cat > "$TMP/mockbin/systemctl" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  is-enabled) [[ "$HOOK_ENABLED" == true ]] ;;
  restart) printf '%s\n' "$*" >> "$HOOK_LOG" ;;
  *) exit 1 ;;
esac
MOCK
chmod 0755 "$TMP/mockbin/systemctl"
export HOOK_LOG="$TMP/hook.log" HOOK_ENABLED=false
: > "$HOOK_LOG"
PATH="$TMP/mockbin:$PATH" bash "$TMP/sleep-hook.sh" post
[[ ! -s "$HOOK_LOG" ]]
HOOK_ENABLED=true
PATH="$TMP/mockbin:$PATH" bash "$TMP/sleep-hook.sh" pre
[[ ! -s "$HOOK_LOG" ]]
PATH="$TMP/mockbin:$PATH" bash "$TMP/sleep-hook.sh" post
[[ "$(cat "$HOOK_LOG")" == 'restart vivobook-power-switch.service' ]]
echo 'PASS A-05 generated hook: disabled post and enabled pre do not restart; enabled post restarts'
# Inherited cleanup safety: legacy-looking unowned i915 file is not proof of ownership.
mkdir -p "$(dirname "$I915_CONF")"
printf 'options i915 enable_guc=3\n' > "$I915_CONF"
export RESTORE_DEFAULTS=false # Consumed by sourced remove_i915_conf.
remove_i915_conf > /dev/null
[[ -e "$I915_CONF" ]]
echo 'PASS ownership qualification: default cleanup preserves unmarked legacy-looking i915 config'
# Failed stdin copy in a conditional must not install a partial migration file.
if (
  # Mock is invoked indirectly by the sourced atomic_write definition.
  # shellcheck disable=SC2329
  cat() { return 1; }
  atomic_write "$TMP/refused.conf" 0644 <<< 'custom.setting = 1'
); then
  echo 'FAIL atomic_write accepted a failed stdin copy'; exit 1
fi
[[ ! -e "$TMP/refused.conf" ]]
echo 'PASS A-01 atomic_write refuses partial stdin in conditional/restore context'
# Do not infer that an administrator's symlink belongs to the script.
printf '%s\n' '# Managed by vivobook_optimize.sh v16.1' > "$TMP/marked-target"
ln -s "$TMP/marked-target" "$TMP/admin-link"
if is_managed_file "$TMP/admin-link"; then echo 'FAIL symlink inferred owned'; exit 1; fi
rc=0; restore_remove_owned "$TMP/admin-link" > /dev/null || rc=$?
[[ "$rc" == 1 && -L "$TMP/admin-link" ]]
echo 'PASS A-01/A-08 ownership: symlink to a marked file is preserved'
mkdir -p "$TMP/sys/class/power_supply/BAT0"
printf '60\n' > "$TMP/sys/class/power_supply/BAT0/charge_control_end_threshold"
# Same redirected step must reset live threshold after discovery, not just unlink orphans.
# shellcheck source=/dev/null
source "$TMP/battery-step.sh" > /dev/null
[[ "$(cat "$TMP/sys/class/power_supply/BAT0/charge_control_end_threshold")" == 100 ]]
echo 'PASS A-08 live threshold reset after discovery'
