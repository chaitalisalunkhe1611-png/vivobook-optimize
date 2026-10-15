# Reference hardware notes

Source: the attached **ASUS Vivobook 16 X1605VA** system description and audit,
representing **2026-10-10**. These are reported observations, not independent
measurements in this repository or a guarantee for another machine/kernel.

## Platform

- ASUS Vivobook 16 X1605VA; BIOS X1605VA.313 (2025-05-21).
- Core i5-13420H, 4P+4E / 12 threads; 16 GB DDR4-3200; Micron 512 GB NVMe.
- Reported Ubuntu 26.04.1 LTS; mainline `7.2.6-070206-generic`, custom signature
  `CN=Vivobook Kernel Key`, Secure Boot enabled. Do not treat this as a tested
  kernel support matrix; no kernel installation or signing changes are added.

## MT7902 / mt7921e

- Wi-Fi PCI ID `14c3:7902`, driven by `mt7921e`; live `disable_aspm=N`.
- The old `options mt7921e disable_aspm=1` was removed; the snapshot reports
  zero Wi-Fi errors since boot afterward. Native ASPM enabled PC6/PC8/S0i3 there.
- Keep `WITH_MT7921E_ASPM=false` for that baseline. The flag is a fallback for
  actual link instability, not a generic power optimization. It requires reboot
  and can block deep idle. Wi-Fi runtime saving (`iw`) is a separate setting.

## Intel graphics

- PCI ID `8086:a7a8`; **xe** bound while i915 is loaded but not bound.
- Reported cmdline: `i915.force_probe=!a7a8 xe.force_probe=a7a8` (not added here).
- Observed DRM card `/sys/class/drm/card1`, render node `/dev/dri/renderD128`;
  do not assume those indices on subsequent boots.
- Reported RP0 1400 MHz, RPn 300 MHz, idle 450 MHz. xe publishes frequency
  attributes under `device/tile*/gt*/freq0`; current uses `cur_freq` / `act_freq`.
- GuC submission/SLPC are kernel-controlled; this release adds no clock clamps.

## PC6 / PC8 / S0ix

- Reported active sleep mode `[s2idle] deep`; active s2idle / Modern Standby.
- Snapshot cumulative counters: PC6 **5,234,683**, PC8 **24,745,281**, PC10 **0**;
  SLP_S0 **49,338,142 us**, S0i3 **2,231,014 us**, S0i2 **0**.
- PC10=0 does not prove S0ix failure. Compare SLP_S0/substate counters before and
  after suspend; package and substate counters are cumulative, not per-suspend.
- The description lists `deep`, while script prose says S3 is not natively
  supported. Safest assumption: retain the working s2idle selection; do not
  switch sleep mode based on either claim.

## RAPL PL1 / PL2

- Reported PL1 200 W, firmware/MSR locked; PL2 **45 W**, writable and applied by
  `rapl-power-limits.service`. A third 155 W constraint remains firmware-owned.
- Saved configuration: `PL1=` (empty), `PL2=45`. An empty value is intentional.
- Firmware already reports PL2 below PL1. v16.0's platform exception is retained;
  neither status mode nor JSON probes register locks by writing them back.
- Do not copy 45 W to unrelated hardware or try to defeat a firmware lock.

## Audio, battery and USB

- SOF + snd_hda_intel coexist; staged `power_save=10 power_save_controller=N`,
  live `power_save=0` on AC. Enabled auto-power explains the runtime override.
- BAT0 reports energy in uWh, ~89.4% health, threshold 100 (uncapped).
- The notes disagree about battery artifacts (absent in battery section,
  disabled/potentially present elsewhere). Inspect actual files; never infer
  ownership or deletion eligibility from that snapshot alone.
- Webcam: ShineTech `3277:0036` at reported `1-9` (uvcvideo).
- Bluetooth: IMC Networks `13d3:3579` at reported `1-10` (btusb).
- Both reported `power/control=auto`; mouse `1-3` reported `on`. Discover by ID
  when verifying rather than assuming the bus numbers remain stable.
- Power inputs include Mains and USB_PD. “Available” in the snapshot is not an
  explicit online=1 reading; verify sysfs with each adapter connected separately.
