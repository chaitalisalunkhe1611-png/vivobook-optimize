vivobook_optimize_v16.sh (v16.0, JSON schema 3) is a well-engineered drift-correction pass over v15.3. Its 15 changes accurately reflect the major state transitions your ASUS Vivobook 16 X1605VA underwent on October 10, 2026: removing mt7921e disable_aspm=1 on mainline kernel 7.2.6-070206-generic (which unlocked PC6/PC8 and S0i3/SLP_S0 Modern Standby with 0 Wi-Fi errors), binding the xe DRM driver (0x8086:0xa7a8), applying PL2=45W while leaving firmware-locked PL1=200W untouched, and removing the battery charge cap.
However, cross-referencing vivobook_optimize_v16.sh line-by-line against your live system state exposes 8 concrete bugs, hardware-path mismatches, and system-drift hazards that should be resolved in v16.1.
Part 1: Deep-Dive Code Audit of vivobook_optimize_v16.sh
| ID | Severity | Subsystem / Lines | Finding & Root Cause on Your X1605VA |
|---|---|---|---|
| A-01 | CRITICAL | Step 11 (99-vivobook.conf)
Lines 1499–1538 | Default run silently wipes IPv6 disablement. Your live network stack disables IPv6 via /etc/sysctl.d/99-vivobook.conf. Because WITH_SYSCTL=true by default (line 138) and v16.0 bumps the managed header comment from v15.3 to v16, the first run of v16.0 (without --no-sysctl) executes atomic_write /etc/sysctl.d/99-vivobook.conf with only 4 keys (vm.swappiness, fs.inotify.max_user_watches, kernel.nmi_watchdog, vm.dirty_writeback_centisecs), destroying any hand-added net.ipv6.conf.* lines in that file. |
| A-02 | HIGH | Step 17b (USB Autosuspend)
Lines 669–696, 1100–1116, 1796–1825 | Why Webcam (1-9) and Bluetooth (1-10) fail exemption and stay on auto. On your laptop, 1-9 (ShineTech UVC Webcam, uvcvideo) and 1-10 (IMC Networks Bluetooth, btusb) have power/control = auto despite /etc/udev/rules.d/99-usb-autosuspend.rules being installed. v16.0 flags this as MISMATCH and blames external tools. The actual bug is in the udev rule itself: lines 1802–1816 only match ACTION=="add". When btusb (compiled with CONFIG_BT_HCIBTUSB_AUTOSUSPEND=y) and uvcvideo bind to the interfaces during kernel driver probe, the kernel calls usb_enable_autosuspend() and emits ACTION=="bind", flipping power/control back to auto after ACTION=="add" has already finished. |
| A-03 | HIGH | xe iGPU Current Frequency
Lines 339–349, 978–982, 1252–1256 | cur_freq_mhz is always "unavailable" / null on xe. find_igpu_freq_files() maps xe's /sys/class/drm/card1/device/tile0/gt0/freq0/{max_freq,rp0_freq,min_freq}. However, show_status_dashboard() and show_status_json() only look for i915 filenames (rps_cur_freq_mhz or gt_cur_freq_mhz) in $(dirname "$max_f"). Under xe, the current frequency node in freq0/ is named cur_freq (and act_freq), so your 450 MHz idle clock is never read. |
| A-04 | MEDIUM | Step 12 & Step 19 (Audio PM)
Lines 483–508, 1061–1095, 2024–2059 | False staged-differs-from-live verdict when --with-auto-power is active. Your /etc/modprobe.d/audio-powersave.conf stages power_save=10 power_save_controller=N, while live power_save is 0. Because vivobook-power-switch.service is enabled on your machine and runs apply_audio_powersave 0 on AC and 1 on battery (lines 2050, 2059), vivobook-power-switch.sh overwrites power_save at every boot and AC event. Telling the user "staged differs from live — applies on next module load/reboot" (line 1084) is misleading because vivobook-power-switch.service will immediately overwrite 10 back to 0 on reboot. |
| A-05 | MEDIUM | Step 19 & Sleep Hooks
Lines 509–529, 1986–2009, 2127–2145 | vivobook-power-switch.service has no S0ix resume hook. On your machine, static asus-thermal-profile.service and intel-epp-profile.service are disabled, while vivobook-power-switch.service is enabled. Because v16.0 guards the static sleep hooks with is-enabled (Change 7) and vivobook-power-switch.service has no sleep hook in /usr/lib/systemd/system-sleep/, unplugging or plugging AC while the laptop is suspended in s2idle—or an EC/driver reset of EPP/thermal/Wi-Fi power save during S0ix—is not reconciled upon wake. |
| A-06 | MEDIUM | Step 17c (Browser Flags)
Lines 803–827 | Stale chrome-flags.conf and chromium-flags.conf are never cleaned up. Only Brave is installed on your laptop, yet ~/.config/chrome-flags.conf and ~/.config/chromium-flags.conf remain present and managed from a pre-v15.3 run. In apply_browser_flags_for_user(), when ! browser_installed "$browser", the loop executes continue (line 812) instead of removing stale script-managed flag files for uninstalled browsers. |
| A-07 | LOW | AC/USB-PD Status Detection
Lines 1255–1262, 1422–1428 vs 1875–1885 | Status dashboard & JSON ignore USB_PD and break on the first AC* node. Your laptop exposes both Mains AC (Mains) and USB-C PD (USB_PD) power supplies. vivobook-power-switch.sh checks all `Mains |
| A-08 | LOW | Dashboard & JSON Schema Consistency
Lines 797–802, 1160–1167, 1309, 1450, 1712 | 1) Lines 797–802 print the battery resume hook status twice (persistent_service_line already prints Resume hook:, followed by a duplicate Resume re-apply hook:).
2) --battery-limit=off (line 1712) only cleans up /usr/lib/systemd/system-sleep/vivobook-battery if /etc/systemd/system/battery-charge-threshold.service exists, which left /usr/lib/systemd/system-sleep/vivobook-battery orphaned on your machine when the unit was disabled/removed.
3) show_status_json() omits "choices": null in two thermal branches (lines 1160–1167), "driver_version": null in vaapi (line 1309), and "brightness": null / "stop_time": null in keyboard_backlight (line 1450). |
Part 2: The v16.1 Plan — Code Patches (vivobook_optimize_v16.1.sh)
Below are the exact, surgical code changes to turn vivobook_optimize_v16.sh into vivobook_optimize_v16.1.sh.
1. Fix A-01: Preserve Unmanaged Keys (IPv6 Disablement) in 99-vivobook.conf
Instead of blindly clobbering /etc/sysctl.d/99-vivobook.conf in Step 11, extract any non-managed sysctl keys (such as your net.ipv6.conf.*.disable_ipv6 = 1 settings) and migrate them cleanly into /etc/sysctl.d/90-vivobook-local.conf before rewriting 99-vivobook.conf:
# Add helper before Step 11:
migrate_custom_vivobook_sysctls() {
  local src="/etc/sysctl.d/99-vivobook.conf"
  local dest="/etc/sysctl.d/90-vivobook-local.conf"
  [[ -f "$src" ]] || return 0
  local -a custom_lines=()
  local line key
  while IFS= read -r line || [[ -n "$line" ]]; do
    local stripped="${line%%#*}"
    stripped="${stripped%%;*}"
    [[ "$stripped" == *=* ]] || continue
    key="${stripped%%=*}"
    key="${key//[[:space:]]/}"
    key="${key#-}"
    key="${key//\//.}"
    case "$key" in
      vm.swappiness|fs.inotify.max_user_watches|kernel.nmi_watchdog|vm.dirty_writeback_centisecs)
        continue
        ;;
      *)
        custom_lines+=("$line")
        ;;
    esac
  done < "$src"

  if (( ${#custom_lines[@]} > 0 )); then
    echo "   Preserving ${#custom_lines[@]} custom sysctl line(s) from $src -> $dest"
    local out="# Preserved custom sysctls migrated from 99-vivobook.conf"$'\n'
    local cl
    if [[ -f "$dest" ]]; then
      out="$(cat "$dest")"$'\n'
    fi
    for cl in "${custom_lines[@]}"; do
      grep -Fqx "$cl" "$dest" 2>/dev/null || out+="$cl"$'\n'
    done
    atomic_write "$dest" 0644 <<< "$out"
  fi
}

Call migrate_custom_vivobook_sysctls at the top of Step 11 (if [[ "$WITH_SYSCTL" == true ]]; then) and at the top of restore_defaults() before restore_remove_owned /etc/sysctl.d/99-vivobook.conf so your IPv6 disablement is never lost.
2. Fix A-02: Fix USB Autosuspend Exemptions on ACTION=="add|bind" (Step 17b)
Update /etc/udev/rules.d/99-usb-autosuspend.rules in Step 17b so that when btusb (1-10) and uvcvideo (1-9) bind and enable autosuspend in kernel space, udev immediately enforces power/control="on" on the bind event as well, and replay both add and bind triggers:
  atomic_write /etc/udev/rules.d/99-usb-autosuspend.rules 0644 << 'UDEV_USB_EOF'
# Managed by vivobook_optimize.sh v16.1 --with-usb-autosuspend
# Enable USB runtime autosuspend by default on device addition
ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{power/control}="auto"

# Exempt USB HID (03), Wireless/Bluetooth (e0), USB Audio (01), and UVC Video (0e)
# on BOTH add and bind events (btusb and uvcvideo call usb_enable_autosuspend during driver bind)
ACTION=="add|bind", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_interface", ATTR{bInterfaceClass}=="03", TEST=="../power/control", ATTR{../power/control}="on"
ACTION=="add|bind", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_interface", ATTR{bInterfaceClass}=="e0", TEST=="../power/control", ATTR{../power/control}="on"
ACTION=="add|bind", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_interface", ATTR{bInterfaceClass}=="01", TEST=="../power/control", ATTR{../power/control}="on"
ACTION=="add|bind", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_interface", ATTR{bInterfaceClass}=="0e", TEST=="../power/control", ATTR{../power/control}="on"
UDEV_USB_EOF
  udevadm control --reload-rules 2>/dev/null || true
  udevadm trigger --subsystem-match=usb --action=add 2>/dev/null || true
  udevadm trigger --subsystem-match=usb --action=bind 2>/dev/null || true

3. Fix A-03: Read cur_freq / act_freq for the xe DRM Driver
In both show_status_dashboard() (line 978) and show_status_json() (line 1252), add the xe frequency node names (cur_freq and act_freq):
      local freq_dir
      freq_dir="$(dirname "$max_f")"
      if [[ -r "$freq_dir/rps_cur_freq_mhz" ]]; then
        cur_f="$(cat "$freq_dir/rps_cur_freq_mhz" 2>/dev/null || echo unknown)"
      elif [[ -r "$freq_dir/gt_cur_freq_mhz" ]]; then
        cur_f="$(cat "$freq_dir/gt_cur_freq_mhz" 2>/dev/null || echo unknown)"
      elif [[ -r "$freq_dir/cur_freq" ]]; then
        cur_f="$(cat "$freq_dir/cur_freq" 2>/dev/null || echo unknown)"
      elif [[ -r "$freq_dir/act_freq" ]]; then
        cur_f="$(cat "$freq_dir/act_freq" 2>/dev/null || echo unknown)"
      fi

4. Fix A-04: Respect User-Edited audio-powersave.conf Timeout on Battery & Clarify Verdict
 * In vivobook-power-switch.sh (apply_audio_powersave, line 2024), if the user staged a custom non-zero timeout in /etc/modprobe.d/audio-powersave.conf (like your power_save=10), use that timeout on battery instead of hardcoding 1:
   # Inside vivobook-power-switch.sh on battery branch:
BAT_AUDIO_PS=1
if [[ -f /etc/modprobe.d/audio-powersave.conf ]]; then
  staged_ps="$(sed -n -e 's/#.*$//' -e 's/.*power_save=\([0-9]\{1,\}\).*/\1/p' /etc/modprobe.d/audio-powersave.conf 2>/dev/null | tail -1)"
  [[ "$staged_ps" =~ ^[0-9]+$ ]] && (( staged_ps > 0 )) && BAT_AUDIO_PS="$staged_ps"
fi
apply_audio_powersave "$BAT_AUDIO_PS"

 * In audio_staged_verdict() (line 483), if systemctl is-enabled --quiet vivobook-power-switch.service 2>/dev/null is true and differs=true, return overridden-by-auto-power so --status and --status-json accurately report that vivobook-power-switch.service dynamically controls power_save (0 on AC, ${BAT_AUDIO_PS} on battery).
5. Fix A-05: Add Guarded S0ix Sleep Hook for vivobook-power-switch.service
 * Add vivobook-power-switch:vivobook-power-switch.service to SLEEP_HOOK_PAIRS (line 512):
   SLEEP_HOOK_PAIRS=(
  vivobook-battery:battery-charge-threshold.service
  vivobook-thermal-profile:asus-thermal-profile.service
  vivobook-intel-epp:intel-epp-profile.service
  vivobook-kbd-timeout:vivobook-kbd-timeout.service
  vivobook-power-switch:vivobook-power-switch.service
)

 * In Step 19 (--with-auto-power, line 2145), write /usr/lib/systemd/system-sleep/vivobook-power-switch using sleep_hook_body vivobook-power-switch.service, and include it in restore_defaults() (owned_path list, line 403). Whenever your laptop wakes from s2idle (S0ix), it will immediately re-verify AC/USB-PD status and restore your AC/battery EPP, thermal profile, Wi-Fi power save, and audio power save.
6. Fix A-06: Clean Up Stale Managed Browser Flag Files for Uninstalled Browsers
In apply_browser_flags_for_user() (lines 810–813), replace the bare continue when a browser is not installed with cleanup of any leftover script-managed file:
    if ! browser_installed "$browser"; then
      if [[ -f "$target" ]] && is_managed_file "$target"; then
        restore_browser_flags_for_user "$u_name" "$u_uid" "$u_gid" "$u_home"
      fi
      not_installed=$((not_installed + 1))
      continue
    fi

7. Fix A-07 & A-08: Unified AC/USB-PD Detection, Orphan Cleanup on --battery-limit=off, and Strict JSON Keys
 * Unified AC/USB-PD helper: Add is_external_power_online() checking Mains|USB|USB_PD|USB_C with online == 1 and use it in show_status_dashboard() and show_status_json() so USB-C PD charging is reported identically to vivobook-power-switch.sh.
 * Complete --battery-limit=off cleanup (lines 1712–1725): Check for any of the 4 battery artifacts (battery-charge-threshold.service, /usr/local/bin/set-battery-threshold.sh, /usr/lib/systemd/system-sleep/vivobook-battery, /etc/default/vivobook-battery) using restore_unit_owned and restore_remove_owned so orphaned hooks/helpers are removed even when the .service file was already deleted.
 * Remove duplicate battery hook line in show_status_dashboard() (delete lines 798–802, since persistent_service_line on line 797 already prints the hook state).
Part 3: Best Action Plan for Your Vivobook 16 X1605VA Right Now
Based on your October 10, 2026 system description (ASUS Vivobook 16 X1605VA (1).md), your hardware and kernel (7.2.6-070206-generic) are already in an excellent baseline state (PC6/PC8/S0i3 working, xe forced, PL2=45W active, 0 Wi-Fi errors). However, your filesystem currently has 5 specific pieces of configuration drift left over from earlier sessions:
 * Duplicate Unmanaged BBR File (/etc/sysctl.d/99-bbr.conf): You have both /etc/sysctl.d/98-network-bbr.conf (managed) and /etc/sysctl.d/99-bbr.conf (unmanaged duplicate).
 * Orphaned Disabled Static Services & Sleep Hooks: battery-charge-threshold.service, asus-thermal-profile.service, and intel-epp-profile.service are disabled because vivobook-power-switch.service (--with-auto-power) dynamically manages your AC/battery profiles and your battery cap is removed (100%). Yet their orphaned sleep hooks (/usr/lib/systemd/system-sleep/vivobook-{battery,thermal-profile,intel-epp}) and /etc/default/vivobook-{thermal-profile,epp} files are still sitting on disk.
 * Stale Managed Browser Configs: ~/.config/chrome-flags.conf and ~/.config/chromium-flags.conf are sitting in /home/chaitu/.config/ even though only Brave is installed.
 * USB Autosuspend MISMATCH on Webcam (1-9) & Bluetooth (1-10): Both are currently stuck on power/control = auto because 99-usb-autosuspend.rules lacked ACTION=="add|bind".
 * Old Script Binary in /usr/local/bin/: /usr/local/bin/vivobook_optimize_v15.3.sh is still installed in /usr/local/bin/.
Step-by-Step Execution Plan on Your Laptop
Step 1: Clean up the duplicate unmanaged BBR sysctl, stale browser files, and orphaned static units/hooks
Run this one-time cleanup block to remove the leftover artifacts identified in your system audit:
# 1. Protect any custom IPv6 lines in 99-vivobook.conf into a dedicated file
grep -E '^[[:space:]]*net\.ipv6\.' /etc/sysctl.d/99-vivobook.conf 2>/dev/null | \
  sudo tee /etc/sysctl.d/90-ipv6-disable.conf >/dev/null
[[ -s /etc/sysctl.d/90-ipv6-disable.conf ]] || sudo rm -f /etc/sysctl.d/90-ipv6-disable.conf

# 2. Remove the duplicate unmanaged 99-bbr.conf (98-network-bbr.conf is already managed)
sudo rm -f /etc/sysctl.d/99-bbr.conf

# 3. Remove stale Chrome/Chromium flag files (only Brave is installed)
rm -f ~/.config/chrome-flags.conf ~/.config/chromium-flags.conf

# 4. Cleanly remove the 3 disabled static units & their orphaned sleep hooks
#    (vivobook-power-switch.service already handles AC/battery EPP & thermal dynamically)
sudo systemctl disable --now battery-charge-threshold.service asus-thermal-profile.service intel-epp-profile.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/battery-charge-threshold.service \
           /etc/systemd/system/asus-thermal-profile.service \
           /etc/systemd/system/intel-epp-profile.service \
           /usr/lib/systemd/system-sleep/vivobook-battery \
           /usr/lib/systemd/system-sleep/vivobook-thermal-profile \
           /usr/lib/systemd/system-sleep/vivobook-intel-epp \
           /etc/default/vivobook-battery \
           /etc/default/vivobook-thermal-profile \
           /etc/default/vivobook-epp \
           /usr/local/bin/set-battery-threshold.sh \
           /usr/local/bin/set-asus-thermal-profile.sh \
           /usr/local/bin/set-intel-epp.sh
sudo systemctl daemon-reload

Step 2: Persist your exact optimal flags in /etc/vivobook-optimize/defaults.conf
Your script automatically sources /etc/vivobook-optimize/defaults.conf before parsing CLI flags (line 169 of vivobook_optimize_v16.sh). Creating this file means you never have to remember which flags match your machine's configuration:
sudo install -d -m 0755 /etc/vivobook-optimize
sudo tee /etc/vivobook-optimize/defaults.conf >/dev/null << 'EOF'
# Optimal baseline for chaitu's ASUS Vivobook 16 X1605VA (Kernel 7.2.6+)
WITH_ZRAM=true
WITH_AUTO_POWER=true
PL2=45
WITH_KBD_TIMEOUT=true
WITH_BBR=true
WITH_BROWSER_WAYLAND=true
WITH_USB_AUTOSUSPEND=true
MAINTENANCE_SCHEDULE=weekly
# Keep MT7902 ASPM enabled natively (S0ix + PC6/PC8 working, 0 Wi-Fi errors)
WITH_MT7921E_ASPM=false
EOF

Step 3: Run the rapid configuration pass & verify
Once the v16.1 patches above are applied (or with v16.0 after Step 1 & Step 2), run the fast configuration pass (--skip-update) followed by the status and boot-integrity gates:
sudo bash vivobook_optimize_v16.1.sh --skip-update
sudo bash vivobook_optimize_v16.1.sh --safe-mode-check
sudo bash vivobook_optimize_v16.1.sh --status

Would you like me to generate the complete, downloadable vivobook_optimize_v16.1.sh file with all 8 audit fixes integrated?
