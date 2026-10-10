# ASUS Vivobook 16 X1605VA — Complete System Description

Everything below reflects the current state of the machine as of October 10, 2026, after all changes made during this session.

---

## 1. IDENTITY

| Field | Value |
|---|---|
| Manufacturer | ASUSTeK COMPUTER INC. |
| Model | Vivobook_ASUSLaptop X1605VA_X1605VA |
| Product version | 1.0 |
| Serial number | T3N0CV037093108 |
| Product UUID | 2af0ed40-2676-8544-8698-db287756d0f1 |
| Machine ID | ecdd51fcd75a42ed81f84318f31f0990 |
| Hostname | chaitu-Vivobook-ASUSLaptop-X1605VA-X1605VA |
| Chassis | Laptop |
| Board | ASUS X1605VA |
| BIOS | X1605VA.313 (2025-05-21) |
| BIOS revision | 5.27 |
| Embedded Controller | Included in BIOS |

---

## 2. PROCESSOR

| Field | Value |
|---|---|
| Model | 13th Gen Intel Core i5-13420H |
| Codename | Raptor Lake-H |
| Family / Model / Stepping | 6 / 186 (0xBA) / 2 |
| Cores | 8 physical (4 P-cores + 4 E-cores) |
| Threads | 12 |
| P-core max | 4600 MHz |
| E-core max | 3400 MHz |
| Min frequency | 400 MHz |
| L1d cache | 320 KiB (8 instances) |
| L1i cache | 384 KiB (8 instances) |
| L2 cache | 7 MiB (5 instances) |
| L3 cache | 12 MiB shared |
| BogoMIPS | 5222.40 |
| Microcode | 0x6134 |
| Virtualization | VT-x |
| Scaling driver | intel_pstate (active) |
| Scaling governor | powersave |
| no_turbo | 0 |
| max_perf_pct | 100 |
| min_perf_pct | 10 |
| EPP (all 12 CPUs) | performance |

**Core topology:**
| CPU | Core | Cache path | Max MHz |
|---|---|---|---|
| 0, 1 | 0 | 0:0:0:0 | 4600 |
| 2, 3 | 1 | 4:4:1:0 | 4600 |
| 4, 5 | 2 | 8:8:2:0 | 4600 |
| 6, 7 | 3 | 12:12:3:0 | 4600 |
| 8 | 4 | 20:20:5:0 | 3400 |
| 9 | 5 | 21:21:5:0 | 3400 |
| 10 | 6 | 22:22:5:0 | 3400 |
| 11 | 7 | 23:23:5:0 | 3400 |

**Notable CPU flags:** hwp, hwp_epp, hwp_notify, hwp_act_window, hwp_pkg_req, avx2, avx_vnni, vaes, vpclmulqdq, gfni, sha_ni, bmi1, bmi2, adx, smap, smep, umip, ibt, user_shstk, aes, fsrm, md_clear, flush_l1d, arch_capabilities, split_lock_detect.

**Vulnerability mitigations:** Spectre v1 (barriers), Spectre v2 (Enhanced IBRS + PBRSB-eIBRS + BHI_DIS_S), Spec Store Bypass (prctl), Vmscape (IBPB before exit), Reg File Data Sampling (Clear Register File). All others: not affected.

---

## 3. INTEGRATED GPU

| Field | Value |
|---|---|
| Model | Intel UHD Graphics (Raptor Lake-P) |
| PCI ID | 0x8086:0xa7a8 |
| Active driver | **xe** (forced) |
| Force-probe cmdline | `i915.force_probe=!a7a8 xe.force_probe=a7a8` |
| DMC firmware | i915/adlp_dmc.bin v2.20 |
| GuC firmware | i915/adlp_guc_70.bin v70.49.4 |
| HuC firmware | i915/tgl_huc.bin v7.9.3 |
| Max frequency (RP0) | 1400 MHz |
| Min frequency (RPn) | 300 MHz |
| Current (idle) | 450 MHz |
| Mesa | 26.0.8-1ubuntu0.3 |
| OpenGL | 4.6 (Mesa Intel RPL-P) |
| VA-API driver | Intel iHD 26.1.2 |
| VA-API version | 1.23 (libva 2.22.0) |
| DRM card | /sys/class/drm/card1 |
| Render node | /dev/dri/renderD128 |
| Connectors | card1-eDP-1, card1-HDMI-A-1 |

**Hardware decode:** H.264, HEVC, AV1, VP9, VP8, MPEG2, VC1, JPEG.

---

## 4. MEMORY

| Slot | Size | Vendor | Part | Speed |
|---|---|---|---|---|
| Controller0-ChannelA | 8 GB | Samsung | M378A1G44CB0-CWE | 3200 MT/s |
| Controller1-ChannelA-DIMM0 | 8 GB | Micron | 4ATF1G64HZ-3G2F1 | 3200 MT/s |

**Total:** 16 GB DDR4-3200 dual channel
**MemTotal:** 15,469,748 kB (~14 GiB usable)

---

## 5. STORAGE (NVMe SSD)

| Field | Value |
|---|---|
| Model | Micron MTFDKBA512QGN-1BN1AABGA |
| Capacity | 512 GB (476.9 GiB) |
| Firmware | V8MA000 |
| NVMe version | 1.4 |
| PCI vendor | 0x1344 |
| Serial | 24504CD931D6 |
| I/O scheduler | [none] mq-deadline |
| nr_requests | 1023 |

**SMART / Health:**
| Metric | Value |
|---|---|
| Critical warning | 0x00 |
| Temperature | 35–38 °C |
| Available spare | 100% |
| Percentage used | 4% |
| Data units read | 12.59 TB |
| Data units written | 7.77 TB |
| Host read commands | 313,799,363 |
| Host write commands | 280,035,593 |
| Power cycles | 787 |
| Power-on hours | 1,301 |
| Unsafe shutdowns | 132 |
| Media errors | 0 |
| Overall health | PASSED |

**Partitions:**
| Device | Size | FS | Mount |
|---|---|---|---|
| nvme0n1p1 | 1 GB | vfat | /boot/efi |
| nvme0n1p2 | 475.9 GB | ext4 | / |

**Disk usage:** 57 GB / 468 GB (13%)

---

## 6. WIRELESS

| Field | Value |
|---|---|
| Chip | MediaTek MT7902 (Filogic 310) |
| PCI ID | 14c3:7902 |
| Subsystem | AzureWave 1a3b:5520 |
| Driver | mt7921e |
| **disable_aspm (live)** | **N** (workaround removed) |
| Config file | **None in /etc/modprobe.d/** |
| Backup location | /root/vivobook-backups/modprobe/mt7921e.conf.disabled |
| Interface | wlo1 |
| MAC | a8:e2:91:c4:5c:fc |
| Wi-Fi generation | 802.11ax (Wi-Fi 6E) |
| Current SSID | chaitali's M55 |
| Channel | 149 (5745 MHz, 80 MHz) |
| Firmware build | 20251212032127 |
| Power save | off (on AC) |
| Errors since boot | 0 |

---

## 7. BLUETOOTH

| Field | Value |
|---|---|
| Chip | IMC Networks Wireless_Device |
| USB ID | 13d3:3579 |
| Driver | btusb |
| Bus position | Bus 001, Port 010 |

**Paired devices (still present):**
| MAC | Name |
|---|---|
| 66:38:A3:37:AC:83 | (unnamed) |
| 30:B9:30:55:C3:6C | (unnamed) |
| 5D:2F:CA:2C:B9:92 | (unnamed) |
| 45:B5:DC:B7:28:04 | Airdopes 161 |
| EF:88:09:C1:1D:F1 | Portronics Muffs M4 |
| 3D:BE:40:EA:60:DA | Airdopes 161 |
| B8:16:5F:B8:42:DD | Aarush's TV |

**Combined Bluetooth sink:** Removed (config deleted, PipeWire restarted).

---

## 8. AUDIO SUBSYSTEM

| Field | Value |
|---|---|
| Platform | Intel Alder Lake-P HD Audio with SOF |
| Internal codec | Realtek ALC256 (ALC269 family) |
| HDMI codecs | 4 outputs |
| SOF stack | snd_sof_pci_intel_tgl, snd_sof_pci_intel_cnl |
| SoundWire | Loaded |
| Audio server | PipeWire 1.6.2 |
| Session manager | WirePlumber 0.5.13 |
| HDA power_save | **0** (disabled) |
| HDA power_save_controller | N |
| /etc/modprobe.d/audio-powersave.conf | `options snd_hda_intel power_save=10 power_save_controller=N` (not applied at current module load — live value is 0) |

**Playback hardware:**
- card 0: PCH — ALC256 Analog
- card 0: PCH — HDMI 0, 1, 2, 3

---

## 9. BATTERY

| Field | Value |
|---|---|
| Device | BAT0 |
| Design capacity | 42,067,000 µWh (42.067 Wh) |
| Current full capacity | 37,611,000 µWh (37.611 Wh) |
| Health | ~89.4% of design |
| Cycle count | 114 |
| Charge end threshold | **100** (cap removed) |
| Cap service | Not installed |
| Resume hook | Absent |
| Current state | Not charging (AC connected) |

**Power input:**
| Source | Type | Online |
|---|---|---|
| Mains AC | Mains | Yes |
| USB-C PD | USB_PD | Available |

---

## 10. THERMAL & COOLING

| Field | Value |
|---|---|
| ACPI platform profile | **performance** |
| Choices | quiet balanced performance |
| Fan controller | Firmware-controlled (pwm1_enable=2) |
| Fan RPM (idle) | 1800–2100 |
| Package temp (idle, AC) | 53–56 °C |
| High/Critical | 100 °C |
| thermald | 2.5.11-0ubuntu1.1 (active) |
| Core temp driver | coretemp |
| Thermal zone (acpitz) | 65 °C reference |
| Core throttle (CPU2/3) | ~25,051 |
| Package throttle (CPU2) | ~17,995 |

---

## 11. OPERATING SYSTEM

| Field | Value |
|---|---|
| Distribution | Ubuntu 26.04.1 LTS (Resolute Raccoon) |
| Release | 26.04 |
| Codename | resolute |
| Kernel | 7.2.6-070206-generic |
| Kernel source | cappelikan/ppa (mainline) |
| Kernel type | unsigned |
| Kernel package | linux-image-unsigned-7.2.6-070206-generic |
| Kernel build date | 2026-09-14 |
| Kernel signature | CN=Vivobook Kernel Key |
| Secure Boot | enabled |
| Shell | zsh |
| User | chaitu (UID 1000) |
| Home | /home/chaitu |

---

## 12. BOOT & KERNEL CONFIG

**/proc/cmdline:**
```
BOOT_IMAGE=/boot/vmlinuz-7.2.6-070206-generic root=UUID=59c6eb3b-6049-4678-87f9-7d6fb28c102b ro quiet splash i915.force_probe=!a7a8 xe.force_probe=a7a8 crashkernel=...
```

**Boot images:** vmlinuz-7.2.6, initrd.img-7.2.6, mt86+x64, mt86+ia32

**Kernel apt pin:** `/etc/apt/preferences.d/block-stock-kernel.pref` — blocks `linux-image-generic`, `linux-headers-generic`, `linux-generic` at priority -1

**Kernel signing hook:** `/etc/kernel/postinst.d/zz-sign-kernel` (executable)

**MOK keys enrolled:**
| Key | Subject |
|---|---|
| 1 | Canonical Ltd. Master Certificate Authority |
| 2 | Custom Kernel Signing Key |
| 3 | Vivobook Kernel Key |

**MOK key files:**
- /root/mok/MOK.der, MOK.pem, MOK.priv (active)
- /root/MOK.der (Custom Kernel Signing Key)
- /root/mok-backup/MOK.{der,priv}

**Latest kernel available:** 7.2.6 (no newer in PPA)

---

## 13. APT REPOSITORIES

- archive.ubuntu.com/ubuntu resolute (main, updates, backports)
- security.ubuntu.com/ubuntu resolute-security
- esm.ubuntu.com/apps/ubuntu (apps security/updates)
- esm.ubuntu.com/infra/ubuntu (infra security/updates)
- brave-browser-apt-release.s3.brave.com stable
- ppa.launchpadcontent.net/cappelikan/ppa/ubuntu resolute (mainline kernels)
- ppa.launchpadcontent.net/papirus/papirus/ubuntu resolute

---

## 14. POWER MANAGEMENT

| Manager | State |
|---|---|
| TLP | Present, inactive (masked) |
| power-profiles-daemon | **Active** |
| thermald | **Active** |
| PPD current profile | performance |

**Intel RAPL power limits (current):**
| Constraint | Value | Lock |
|---|---|---|
| PL1 (constraint_0) | 200 W | **Firmware-locked** |
| PL2 (constraint_1) | **45 W** (set by script) | writable |
| constraint_2 | 155 W | firmware-controlled |
| rapl-power-limits.service | **active**, exit 0 (PL2 applied) | — |

**/etc/default/vivobook-rapl:**
```
PL1=
PL2=45
```

---

## 15. SLEEP & POWER STATES

| Field | Value |
|---|---|
| mem_sleep | [s2idle] deep |
| Active mode | s2idle (Modern Standby / S0ix) |
| cpuidle driver | intel_idle |

**Package C-state residency (after ASPM enabled, current boot):**
| State | Residency |
|---|---|
| PC2 | 15,380,284 |
| PC3 | 646,302 |
| **PC6** | **5,234,683** ✅ |
| PC7 | 0 |
| **PC8** | **24,745,281** ✅ |
| PC9 | 0 |
| PC10 | 0 |
| **SLP_S0** | **49,338,142 µs** ✅ |
| S0i2 | 0 |
| **S0i3** | **2,231,014 µs** ✅ |

**S0ix is now functional.** Previously all deep states were 0 because `mt7921e disable_aspm=1` blocked PCIe L1.x on the Wi-Fi link.

---

## 16. SYSCTL CONFIGURATION

**From /etc/sysctl.d/99-vivobook.conf:**
| Key | Value |
|---|---|
| vm.swappiness | 100 |
| fs.inotify.max_user_watches | 524288 |
| kernel.nmi_watchdog | 0 |
| vm.dirty_writeback_centisecs | 1500 |

**From /etc/sysctl.d/98-network-bbr.conf:**
| Key | Value |
|---|---|
| net.core.default_qdisc | fq |
| net.ipv4.tcp_congestion_control | bbr |

**From /etc/sysctl.d/99-optimize.conf:**
- vm.vfs_cache_pressure = 50
- vm.dirty_ratio = 10
- vm.dirty_background_ratio = 5

**From /etc/sysctl.d/99-security-hardening.conf:** 19 hardening values including:
- fs.protected_fifos = 2, fs.protected_regular = 2, fs.suid_dumpable = 0
- kernel.kptr_restrict = 2, kernel.dmesg_restrict = 1, kernel.sysrq = 0
- kernel.yama.ptrace_scope = 1, kernel.unprivileged_bpf_disabled = 1
- net.core.bpf_jit_harden = 2, and 10 network hardening values

**From /etc/sysctl.d/97-mglru.conf:** MGLRU sysctls (separate)
**From /etc/sysctl.d/30-brave.conf, 99-bbr.conf, 99-custom-performance.conf:** additional tuning

---

## 17. MEMORY COMPRESSION & SWAP

| Device | Type | Size | Priority | Algorithm |
|---|---|---|---|---|
| /dev/zram0 | partition | 7.4 GB | 100 | [zstd] (lzo-rle, lzo, lz4, lz4hc, deflate, 842 also listed) |
| /swap.img | file | 4.0 GB | -1 | swap |

**zRAM disksize:** 7,920,418,816 bytes
**zram-generator config:** /etc/systemd/zram-generator.conf present
**Swap usage:** 0 B on both

---

## 18. NETWORK STACK

| Field | Value |
|---|---|
| IPv4 (wlo1) | 10.79.62.55/24 |
| Broadcast | 10.79.62.255 |
| Loopback | 127.0.0.1/8 |
| DHCP | Active on wlo1 |
| TCP congestion | bbr |
| Default qdisc | fq |
| IPv6 | Disabled (via 99-vivobook.conf) |
| DNS resolver | systemd-resolved (127.0.0.53) |

---

## 19. FIREWALL (UFW)

| Field | Value |
|---|---|
| Status | active |
| Logging | on (low) |
| Default incoming | deny |
| Default outgoing | allow |
| Default routed | disabled |

**Rules:**
| Rule | Action | From |
|---|---|---|
| 22/tcp | ALLOW IN | 10.79.62.0/24 |

---

## 20. ACTIVE VIVOBOOK SERVICES

| Service | Description | State |
|---|---|---|
| battery-charge-threshold.service | Battery cap | **disabled** (cap removed) |
| asus-thermal-profile.service | Thermal profile | **disabled** |
| intel-epp-profile.service | EPP | **disabled** |
| vivobook-kbd-timeout.service | Keyboard backlight timeout | **enabled** |
| **rapl-power-limits.service** | RAPL PL1/PL2 | **enabled, active (PL2=45W)** |
| vivobook-power-switch.service | Dynamic AC/battery | **enabled** |
| system-maintenance.service | Maintenance oneshot | — |
| system-maintenance.timer | Weekly maintenance | **enabled** |
| fstrim.timer | SSD TRIM | enabled |
| lynis.timer | Lynis audit | enabled |
| apt-listchanges.timer | Package change notifications | enabled |
| dailyaidecheck.timer | AIDE integrity | enabled |

---

## 21. SLEEP HOOKS

| Path | Purpose |
|---|---|
| /usr/lib/systemd/system-sleep/vivobook-battery | (present if service was installed) |
| /usr/lib/systemd/system-sleep/vivobook-thermal-profile | Thermal reapply |
| /usr/lib/systemd/system-sleep/vivobook-intel-epp | EPP reapply |
| /usr/lib/systemd/system-sleep/vivobook-kbd-timeout | Keyboard reapply |

---

## 22. MANAGED CONFIGURATION FILES

**/etc/default/:**
| File | Content |
|---|---|
| vivobook-thermal-profile | ASUS_THERMAL_PROFILE=performance |
| vivobook-epp | INTEL_EPP_PROFILE=performance |
| vivobook-rapl | PL1= (empty), PL2=45 |

**/etc/modprobe.d/:**
| File | Content |
|---|---|
| audio-powersave.conf | `options snd_hda_intel power_save=10 power_save_controller=N` |
| cfg80211.conf | `options cfg80211 ieee80211_regdom=IN` |
| (mt7921e.conf) | **not present** (moved to /root/vivobook-backups/modprobe/) |

**/etc/sysctl.d/:**
| File | Purpose |
|---|---|
| 30-brave.conf | Brave sysctls |
| 97-mglru.conf | MGLRU |
| 98-network-bbr.conf | BBR + fq |
| 99-bbr.conf | Duplicate BBR (unmanaged) |
| 99-custom-performance.conf | Custom tuning |
| 99-optimize.conf | Additional tuning |
| 99-vivobook.conf | Main tuning |
| 99-security-hardening.conf | Security sysctls |

**/etc/udev/rules.d/:**
| File | Purpose |
|---|---|
| 99-usb-autosuspend.rules | USB runtime autosuspend |
| 99-vivobook-power.rules | AC/battery trigger |

**/usr/local/bin/:**
| File | Purpose |
|---|---|
| system-maintenance.sh | Weekly maintenance |
| set-battery-threshold.sh | Battery threshold |
| set-asus-thermal-profile.sh | Thermal |
| set-intel-epp.sh | EPP |
| vivobook-power-switch.sh | AC/battery switch |
| set-rapl-limits.sh | RAPL |
| vivobook-kbd-timeout.sh | Keyboard |
| vivobook_optimize_v15.3.sh | Main script (5,367 lines) |

---

## 23. BROWSER CONFIGURATION

**Managed flags:**
| File | Content |
|---|---|
| ~/.config/brave-flags.conf | `--ozone-platform-hint=auto` |
| ~/.config/chrome-flags.conf | managed |
| ~/.config/chromium-flags.conf | managed |

**Brave GPU:** Video Decode HW accelerated, Canvas/Compositing/Rasterization/WebGL/WebGPU accelerated, Video Encode software-only.

---

## 24. USB DEVICES

| Bus/Port | Device | ID | Driver |
|---|---|---|---|
| 1/3 | Lenovo 130 Wireless Mouse | 17ef:60ff | usbhid |
| 1/9 | ShineTech USB2.0 HD UVC WebCam | 3277:0036 | uvcvideo |
| 1/10 | IMC Networks Wireless_Device | 13d3:3579 | btusb |
| 1/root | USB 2.0 root hub | 1d6b:0002 | xhci_hcd |
| 2/root | USB 3.0 root hub | 1d6b:0003 | xhci_hcd |

**Runtime PM:**
| Device | Control | Autosuspend delay |
|---|---|---|
| 1-3 (mouse) | on | 2000 ms |
| 1-9 (webcam) | auto | 2000 ms |
| 1-10 (BT) | auto | 2000 ms |

---

## 25. FIRMWARE (fwupd)

| Device | Current version | Update |
|---|---|---|
| BIOS | X1605VA.313 | current |
| TPM | 600.18.35.2557 | current |
| ME | 16.1.35.2557 | current |
| NVMe | V8MA000 | current |
| Webcam | 1.1 | current |
| SBAT | 1.5.4 | current |
| System Firmware | 787 | current |

**Updates available:** none (ASUS not on LVFS)

---

## 26. KERNEL MODULES (relevant)

| Module | Purpose |
|---|---|
| xe | Intel graphics (active DRM) |
| i915 | Intel graphics (loaded, not bound) |
| asus_wmi, asus_nb_wmi | ASUS WMI platform |
| mt7921e, mt7921_common, mt792x_lib, mt76, mt76_connac_lib | Wi-Fi |
| mac80211, cfg80211 | Wi-Fi stack |
| btusb | Bluetooth |
| snd_sof, snd_sof_pci_intel_tgl, snd_sof_pci_intel_cnl | Audio |
| snd_hda_intel, snd_hda_codec_alc269 | HDA |
| intel_rapl_msr, intel_rapl_common | RAPL |
| tcp_bbr | Congestion control |
| coretemp | Temperature |
| intel_pmc_core | PMC |

**Total modules:** ~219

---

## 27. SECURITY POSTURE

| Layer | Status |
|---|---|
| Secure Boot | enabled |
| Kernel signing | MOK `CN=Vivobook Kernel Key` |
| Signing hook | present, executable |
| UFW | active, deny incoming |
| SSH | LAN only (10.79.62.0/24) |
| AppArmor | enabled (134 unconfined processes) |
| Lynis | 76/100 |
| AIDE | installed |
| rkhunter | installed, baselined |
| fail2ban | active |
| needrestart, debsums, apt-listchanges | installed |
| Password hashing | yescrypt (sha512 rounds=65536 fallback) |
| CUPS | disabled |
| auditd | not installed |

---

## 28. DESKTOP

| Setting | Value |
|---|---|
| DE | GNOME (Ubuntu session) |
| GTK | Yaru-blue-dark |
| Icons | Papirus-Dark |
| Cursor | Bibata-Modern-Classic (24 px) |
| Color scheme | prefer-dark |
| Accent | purple |
| Fonts | Inter 10.5, JetBrains Mono 10 |
| Animations | disabled |
| Hot corners | disabled |
| Clock | 12h, weekday shown |
| Button layout | appmenu:minimize,maximize,close |
| Wallpaper | /home/chaitu/Pictures/Wallpapers/vr592-wallpaper.cam.jpg |
| Display | N160JCE-ELL (Chi Mei), 1920×1200 (16:10) |

---

## 29. STORAGE USAGE

| Mount | FS | Size | Used | Use% |
|---|---|---|---|---|
| / | ext4 | 468 GB | 57 GB | 13% |
| /boot/efi | vfat | 1.1 GB | 6.4 MB | 1% |
| /run | tmpfs | 3.0 GB | 3.0 MB | 1% |
| /dev/shm | tmpfs | 7.4 GB | 0 | 0% |
| /tmp | tmpfs | 7.4 GB | 32 KB | 1% |
| /run/user/1000 | tmpfs | 1.5 GB | 84 KB | 1% |
| efivarfs | efivarfs | 192 KB | 139 KB | 75% |

---

## 30. INSTALLED SOFTWARE (selected)

**Package managers:** apt, snap, flatpak, pipx, npm

**Snap packages:** bare, canonical-livepatch, code, core20/22/24, desktop-security-center, firmware-updater, gnome-46-2404, gtk-common-themes, mesa-2404, prompting-client, snap-store, snapd, snapd-desktop-integration, steam

**Flatpak (user):** Extension Manager, Mesa 26.2.2, Intel VAAPI driver, Codecs Extra, GNOME 50, Yaru-dark

**Key apt:** thermald, powertop, fwupd, intel-microcode, intel-media-va-driver-non-free, vainfo, lm-sensors, stress-ng, lynis, smartmontools, nvme-cli, needrestart, debsums, apt-listchanges, aide, rkhunter, fail2ban, ufw, pavucontrol, pipewire-audio-client-libraries, libspa-0.2-bluetooth, systemd-zram-generator, zsh, python3.14

---

## 31. RECENT CHANGES (SESSION SUMMARY)

| Change | Old | New |
|---|---|---|
| mt7921e workaround | `disable_aspm=1` | **removed** (kernel 7.2.6 doesn't need it) |
| S0ix functionality | PC6=0, PC8=0, S0i3=0, SLP_S0=0 | **PC6=5.2M, PC8=24.7M, S0i3=2.2M, SLP_S0=49.3M** |
| Battery cap | 60% → 100% | **100% (uncapped)** |
| Audio power_save | 1 (aggressive) | 0 (module default; config staged for 10 next load) |
| RAPL PL2 | (empty — service was failing) | **45 W applied** |
| Combined BT sink | `combined_airdopes` | **removed** (config deleted) |
| Wi-Fi stability | unknown | **0 errors since boot** |

---

## 32. FIRMWARE BUGS / NOTES

- `[Firmware Bug]: TSC ADJUST: CPU0: -811428217 force to 0` — corrected at boot
- `[Firmware Bug]: TSC ADJUST differs within socket(s)` — corrected
- `Internal SPI Controller: Device firmware has been locked` — BIOS write-protect

---

## 33. CURRENT HEALTH INDICATORS

| Metric | Value | Trend |
|---|---|---|
| Battery health | 89.4% | (design vs current) |
| Battery cycles | 114 | +2 since last audit |
| NVMe wear | 4% used | stable |
| NVMe temperature | 35–38 °C | normal |
| CPU idle temp | 53–56 °C | AC, performance profile |
| Fan idle RPM | 1800–2100 | quiet |
| Wi-Fi errors | 0 | since boot |
| S0ix | working | (was 0) |

---

This is the complete current state of the machine.
