# Verify on the laptop

These commands are **not reported as executed here**. Run from the reviewed
release directory on the X1605VA. Review backups/defaults first. Expected results
are conditional on the corresponding opt-in being installed and hardware support.
Do not change kernel, global ASPM or sleep mode just to satisfy this list.

## 1. Version, dry-run and actual apply

```bash
bash vivobook_optimize.sh --version
bash vivobook_optimize.sh --dry-run --skip-update --with-auto-power \
  --with-usb-autosuspend --with-browser-wayland --battery-limit=off
# After inspecting output; add the example defaults only if appropriate:
sudo bash vivobook_optimize.sh --skip-update --with-auto-power \
  --with-usb-autosuspend --with-browser-wayland --battery-limit=off
sudo bash vivobook_optimize.sh --status
sudo bash vivobook_optimize.sh --status-json | jq .
sudo bash vivobook_optimize.sh --safe-mode-check
```

Expected: version **16.1, schema 3**; dry-run ends “no files were modified”.
Actual apply is mutating, may install packages, and is not a sandbox check.
JSON parses; the boot gate should pass only if the reference hook, pin, images
and enrolled signing setup are intact. A gate failure is a reason to investigate,
not to disable Secure Boot or blindly reboot. The gate is not a full boot proof.

## 2. A-01: sysctl preservation and order

```bash
sudo grep -nE '^[[:space:]]*[^#;].*=' /etc/sysctl.d/90-vivobook-local.conf /etc/sysctl.d/99-vivobook.conf
sudo systemd-analyze cat-config sysctl.d | less
sysctl net.ipv6.conf.all.disable_ipv6 net.ipv6.conf.default.disable_ipv6
sysctl vm.swappiness fs.inotify.max_user_watches kernel.nmi_watchdog vm.dirty_writeback_centisecs
# Capture before repeating the SAME apply command (same defaults and flags):
sudo sha256sum /etc/sysctl.d/90-vivobook-local.conf /etc/sysctl.d/99-vivobook.conf
# Repeat the apply command from section 1, then repeat sha256sum.
```

Expected: if there were custom assignments in the owned old file, they appear
once in 90, not duplicated on a second run. 90 appears before 99 in the merged
configuration, and 99 carries the four core settings. IPv6 disablement stays 1
**if it was present before migration**, unless some other later config overrides
it. 90 may legitimately be absent on a clean installation. Investigate reported
unowned destination/key conflicts manually; do not remove an administrator file
just to make the script proceed. zRAM presence determines swappiness 10 vs 100.

## 3. A-02: installed udev syntax and webcam/Bluetooth PM

```bash
sudo udevadm verify /etc/udev/rules.d/99-usb-autosuspend.rules
# Discover the devices from the IDs in the supplied snapshot, not assumed ports:
for d in /sys/bus/usb/devices/*; do
  [ -r "$d/idVendor" ] && [ -r "$d/idProduct" ] || continue
  id="$(cat "$d/idVendor"):$(cat "$d/idProduct")"
  case "$id" in
    3277:0036|13d3:3579)
      printf '%s %s power/control=' "$d" "$id"
      cat "$d/power/control"
      for i in "$d"/*:*; do
        [ -r "$i/bInterfaceClass" ] || continue
        real="$(readlink -f "$i")"
        printf '  %s class=%s parent-control=' "$real" "$(cat "$i/bInterfaceClass")"
        cat "$real/../power/control"
      done
      ;;
  esac
done
```

Expected: rule verification succeeds; for webcam class 0e and BT class e0,
**parent** power/control is `on`. IDs must be rediscovered if hardware differs.
The source snapshot's `/sys/bus/usb/devices/1-9/power/control` and
`/sys/bus/usb/devices/1-10/power/control` should read `on` if those ports remain.

To inspect actual bind events while reconnecting a safe removable device:

```bash
sudo udevadm monitor --kernel --udev --subsystem-match=usb --property
```

Optional replay after apply (does not unbind drivers, but does reprocess PM rules):

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=usb --action=add
sudo udevadm settle
sudo udevadm trigger --subsystem-match=usb --property-match=DEVTYPE=usb_interface --action=bind
sudo udevadm settle
# Repeat the ID-based loop above after replay and after suspend/resume.
```

Expected: exemptions remain `on`. If they return to `auto`, inspect later rules,
TLP/powertop/other managers and the event log; do not claim the driver alone is
proven responsible. A parser-only check does not prove actual sysfs writes.

## 4. A-03: xe/i915 frequency in both outputs

```bash
for c in /sys/class/drm/card[0-9]*; do
  [ -r "$c/device/vendor" ] || continue
  [ "$(cat "$c/device/vendor")" = 0x8086 ] || continue
  readlink -f "$c/device/driver"
  for dir in "$c/gt/gt0" "$c" "$c"/device/tile*/gt*/freq0; do
    for node in rps_cur_freq_mhz gt_cur_freq_mhz cur_freq act_freq; do
      [ ! -r "$dir/$node" ] || { printf '%s=' "$dir/$node"; cat "$dir/$node"; }
    done
  done
done
sudo bash vivobook_optimize.sh --status | grep -A5 '\[Intel UHD / Iris iGPU Frequency\]'
sudo bash vivobook_optimize.sh --status-json | jq '.igpu'
```

Expected: if any current node is readable/numeric, current is numeric in JSON
and not “unavailable” on the dashboard. Values may change between samples;
450 MHz is the source's idle observation, not an acceptance threshold.

## 5. A-04/A-05/A-07: audio, power source and resume

```bash
systemctl is-enabled vivobook-power-switch.service
sudo cat /usr/lib/systemd/system-sleep/vivobook-power-switch
sudo bash -n /usr/local/bin/vivobook-power-switch.sh
for s in /sys/class/power_supply/*; do
  [ -r "$s/type" ] && [ -r "$s/online" ] || continue
  printf '%s type=%s online=%s\n' "$s" "$(cat "$s/type")" "$(cat "$s/online")"
done
sudo bash vivobook_optimize.sh --status-json | jq '{dynamic_power, audio, sleep_hooks}'
cat /sys/module/snd_hda_intel/parameters/power_save
cat /sys/module/snd_hda_intel/parameters/power_save_controller
journalctl -u vivobook-power-switch.service -b -n 30 --no-pager
```

Expected: dynamic service enabled if requested; hook contains an `is-enabled`
guard. With Mains **or** USB_PD (or USB/USB_C) online=1, JSON ac_online is string
`"1"`, dashboard says yes, and audio power_save=0. With all external inputs
offline, JSON `"0"`, dashboard no, battery audio uses staged positive timeout
(e.g. 10) or fallback 1. Controller stays separately configured. SOF-only/no-HDA
systems can honestly report audio unavailable/unsupported.

Test Mains and USB-PD independently (disconnect the other input), then battery.
For each, observe power_supply online states and repeat status/audio checks.
While safely suspended, connect/disconnect the adapter, then resume:

```bash
systemctl suspend
# After waking:
journalctl -u vivobook-power-switch.service --since '-5 min' --no-pager
sudo bash vivobook_optimize.sh --status-json | jq '{dynamic_power, audio, sleep_hooks}'
cat /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference
powerprofilesctl get
```

Expected: hook reapplies current source policy; journal has a post-wake per-knob
summary, or an honest unsupported/failed state. Active PPD owns EPP/thermal, so
its reported profile matters more than expecting exact static sysfs strings.
A disabled power-switch unit must not be restarted by this hook. Test that
only if you can deliberately manage/restore the current power policy.

## 6. A-06/A-08: stale files, battery artifacts and JSON keys

```bash
for f in "$HOME/.config/"{brave,chrome,chromium}-flags.conf \
         "$HOME/snap/chromium/common/chromium-flags.conf"; do
  [ ! -f "$f" ] || { printf '\n%s\n' "$f"; cat "$f"; }
done
sudo bash vivobook_optimize.sh --status-json | jq -e '
  .script.version == "16.1" and .script.schema == 3
  and (.thermal | has("choices")) and (.vaapi | has("driver_version"))
  and (.keyboard_backlight | has("brightness") and has("stop_time"))'
for f in /etc/systemd/system/battery-charge-threshold.service \
  /usr/local/bin/set-battery-threshold.sh /etc/default/vivobook-battery \
  /usr/lib/systemd/system-sleep/vivobook-battery; do
  if [ -e "$f" ] || [ -L "$f" ]; then printf 'still present: %s\n' "$f"; fi
done
cat /sys/class/power_supply/BAT*/charge_control_end_threshold
```

Expected: installed Brave retains its managed auto flag; pure-managed stale
Chrome/Chromium files disappear; mixed files retain custom flags. Unmarked
files remain unchanged. jq prints true. After battery-off, owned battery
artifacts are absent and supported thresholds read 100; unowned files are
listed/preserved instead. Battery hook is reported only once in its dashboard
section (JSON intentionally has both battery metadata and the hooks map).

## 7. RAPL and S0ix baseline (read-only)

```bash
sudo cat /sys/kernel/debug/pmc_core/package_cstate_show
sudo cat /sys/kernel/debug/pmc_core/slp_s0_residency_usec
sudo cat /sys/kernel/debug/pmc_core/substate_residencies
cat /sys/power/mem_sleep
cat /sys/module/mt7921e/parameters/disable_aspm
sudo bash vivobook_optimize.sh --status-json | jq '{rapl, suspend, wifi}'
```

Expected for the supplied baseline: s2idle active, ASPM workaround not live;
PC6/PC8/SLP_S0/S0i3 accumulate across idle/suspend. PC10=0 is not itself failure.
PL2 remains 45 W **if already configured/requested**; PL1 remains firmware-owned.
Status RAPL lock probes remain false/null. Missing debugfs data is not a fabricated
hardware failure; do not mount or change settings automatically for this test.

## 8. Optional restore acceptance (destructive to managed tuning)

Back up relevant configs and arrange a recovery plan before testing this:

```bash
bash vivobook_optimize.sh --dry-run --restore-defaults
sudo bash vivobook_optimize.sh --restore-defaults
sudo test ! -e /usr/lib/systemd/system-sleep/vivobook-power-switch
sudo test ! -e /etc/sysctl.d/90-vivobook-local.conf
sudo grep -nE '^[[:space:]]*net\.ipv6\.' /etc/sysctl.d/99-vivobook.conf
sudo bash vivobook_optimize.sh --status-json | jq .
```

Expected: new owned hook/migration file removed; migrated custom settings return
to an unmarked 99 file, not erased. The grep is only expected to find IPv6 lines
if they existed in the source. Administrator-owned collisions cause preservation
and a report, not deletion. Reboot only after independent boot-safety review;
packages and your installed main executable/defaults are not rolled back.
