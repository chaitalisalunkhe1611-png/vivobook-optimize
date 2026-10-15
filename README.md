# Vivobook Optimize · v16.1

A Bash configuration and diagnostics pass for the **ASUS Vivobook 16 X1605VA**.
This release fixes the eight findings in the supplied v16.0 audit; it does not
add tuning flags or change their defaults. Two inherited unowned-cleanup paths
are also guarded to meet the explicit safety requirement. **JSON schema: 3.**

> **Root warning:** inspect the entire script and a dry-run before using sudo.
> A normal run is not just diagnostics: it updates packages unless skipped,
> installs packages, writes system configuration, enables maintenance/TRIM/
> thermald services, and may alter power policy when requested. Misconfiguration
> can break networking, audio, suspend or boot. No performance, battery-life,
> firmware compatibility or recovery guarantee is made. Keep external backups.

## Target and scope

Reference source: X1605VA, i5-13420H, 16 GB DDR4, Intel UHD, MediaTek MT7902,
Ubuntu **26.04.1**, mainline **7.2.6-070206-generic**, xe, systemd/udev.
These versions come from the supplied 2026-10-10 snapshot, **not a hardware test
performed here**. The script checks apt-get and Intel CPU presence and warns for
non-ASUS DMI; that is not a declaration of support for every Debian/Intel laptop.
i915 and xe frequency reporting are supported. See [hardware notes](docs/HARDWARE-NOTES.md).

Default work includes supervised apt updates, firmware metadata checks,
Snap/Flatpak/pipx updates where available, thermald, powertop for diagnostics,
TRIM, microcode/VA-API packages, maintenance timer, four targeted sysctls and
legacy cleanup. Opt-ins cover charge caps, EPP/thermal, zRAM, dynamic power,
RAPL, USB PM, browser Ozone auto-detection, BBR and keyboard timeout.
No global ASPM writes, hard CPU/GPU frequency ceilings, or new kernel installation.

## Inspect and install

From a reviewed checkout or extracted release ZIP:

```bash
bash vivobook_optimize.sh --version
bash vivobook_optimize.sh --help
bash vivobook_optimize.sh --status
bash vivobook_optimize.sh --status-json | jq .
bash vivobook_optimize.sh --dry-run --skip-update
# Optional stable executable name, after review:
sudo install -m 0755 vivobook_optimize.sh /usr/local/bin/vivobook_optimize.sh
```

Bash and Ubuntu's standard system utilities are required. Requested steps use
apt to install their existing packages; the v16.1 script adds **no runtime
dependencies**. `shellcheck` and `jq` are development/test dependencies, not
required for the script to emit JSON. Never pipe an unaudited download into sudo.

```bash
# Default supervised pass (includes upgrades):
sudo bash vivobook_optimize.sh
# Preview the reference opt-in policy without applying it:
bash vivobook_optimize.sh --dry-run --skip-update --with-auto-power \
  --with-usb-autosuspend --with-browser-wayland --battery-limit=off
# Rapid pass: skips ONLY steps 1–3, not all package installation:
sudo bash vivobook_optimize.sh --skip-update
# Read-only boot-integrity gate, tailored to the reference signing setup:
sudo bash vivobook_optimize.sh --safe-mode-check
```

## Complete flag table

Read against this release's actual `--help` and CLI parser. Full verbatim help
is in [docs/CLI-HELP.txt](docs/CLI-HELP.txt). Flags are additive unless stated.

| Flag | Default / accepted values | Meaning |
|---|---|---|
| `-h`, `--help` | Off | Print usage and exit; no root required. |
| `--version` | Off | Print script name, 16.1 and schema 3. |
| `--status`, `--check` | Off | Read-only dashboard; sudo exposes more telemetry. |
| `--status-json` | Off | Read-only schema-3 JSON. |
| `--safe-mode-check` | Off | Read-only signing-hook, apt-pin, kernel-signature and Secure Boot gate; 1 if missing/unverified. Wi-Fi item only warns. |
| `--dry-run` | Off | Parse/probe and print planned writes; no root required, no apply. |
| `--restore-defaults` | Off | Remove owned tuning artifacts, reset documented live baselines and reapply remaining sysctls; not package/BIOS/kernel rollback. |
| `--skip-update` | Off | Skip steps 1–3 only. |
| `--with-full-upgrade` | Off | Use apt full-upgrade rather than upgrade in step 1. |
| `--with-guc` | Off | Read-only bound-DRM/GuC/HuC diagnostics in step 9. |
| `--with-auto-upgrade` | Off | Apply available fwupd updates during supervised step 2, not the timer. |
| `--with-multiverse` | Off | Opt into enabling Ubuntu multiverse if the non-free VA-API driver has no candidate. |
| `--with-battery-limit` | Unchanged | Alias for 80% cap. |
| `--battery-limit=N` | Unchanged; integer 20–100 | Persistent ASUS charge-end threshold if supported. |
| `--battery-limit=off` | Unchanged | Remove owned battery artifacts, including orphans, and reset supported live thresholds to 100. TLP ownership gate retained. |
| `--maintenance-schedule=weekly\|monthly` | `weekly` | Regenerated maintenance schedule reflects the latest run. |
| `--fan-profile=quiet\|balanced\|performance` | Unchanged | Static ASUS/ACPI thermal policy, delegating to active PPD. |
| `--epp=performance\|balance_performance\|balance_power\|power` | Unchanged | Static CPU EPP, delegating to active PPD. Conflicting PPD thermal/EPP requests refused. |
| `--with-zram` | Off | zstd compressed swap, min(ram/2,8192) MiB, priority 100; avoids restarting already-correct live zRAM. |
| `--with-auto-power` | Off | Dynamic AC/battery EPP, thermal, Wi-Fi and HDA power policy via service, udev and guarded resume hook. Always refuses active TLP. |
| `--pl1=WATTS` | Unmanaged; integer 1–300 | Request only PL1; validate hardware envelope/maxima and probe requested constraint on real apply. |
| `--pl2=WATTS` | Unmanaged; integer 1–300 | Request only PL2; never invent the unspecified constraint. Reference firmware PL2<PL1 exception retained. |
| `--with-kbd-timeout` | Off | Firmware-supported 30s keyboard backlight timeout; never dim brightness as fallback. |
| `--with-bbr` | Off | BBR + fq if supported; preserve incompatible unowned generic config. |
| `--with-browser-wayland` | Off | Ozone auto-detection for installed Brave/Chrome/Chromium; remove only managed tokens from stale uninstalled-browser files. |
| `--with-browser-vaapi` | Off | Compatibility alias for `--with-browser-wayland`; not forced VA-API switches. |
| `--with-mt7921e-aspm` | Off | Optional **disable_aspm=1** instability fallback; may prevent deep idle. Not needed by the supplied stable baseline. |
| `--with-usb-autosuspend` | Off | Runtime USB autosuspend, exempt interface classes HID 03, BT/wireless e0, audio 01, video 0e on add/bind. |
| `--disable-ppd` | Off | Mask power-profiles-daemon, recording prior state for restore. |
| `--force-tlp-override` | Off | Permit gated static policy writes despite TLP; does not permit auto-power with TLP. Not recommended. |
| `--no-sysctl` | Tuning on | Skip step-11 sysctl tuning/migration; leave existing file untouched. |
| `--no-audio-powersave` | Static tuning on | Skip static HDA boot config only; dynamic audio still applies with auto-power. |

Auto-power uses AC performance EPP/thermal, Wi-Fi saving off, HDA `power_save=0`;
battery balance_power EPP (power-saver via PPD), balanced thermal without PPD,
Wi-Fi saving on, positive staged HDA timeout (otherwise 1). It does not manage
`power_save_controller`. It scans **all** Mains/USB/USB_PD/USB_C supplies.

## Safety and reversibility

- `--dry-run` overrides mutators and prints content; read-only probes still
  observe this host, so unsupported hardware may skip branches. It is **not**
  a hardware success test. It does not acquire the live execution lock.
- `--status`, JSON and `--safe-mode-check` return before mutation. Status never
  writes back RAPL values to infer lock state. Unknown is not “unlocked”.
- TLP gates overlapping static writes; auto-power refuses TLP outright.
  PPD remains the owner of its profile when active; thermald is left running.
- Generic managed artifacts use ownership markers and existing documented
  legacy-adoption rules. Default powertop cleanup is ownership-guarded; an
  unmarked legacy-looking i915 config requires explicit restore for removal.
  Review existing legacy configs before applying;
  marker presence is an ownership convention, not cryptographic provenance.
- Atomic writes compare content to avoid needless rewrites. Disabled services
  are not restarted by the managed sleep hooks. New dynamic hook is removed by
  restore, and existing unmarked copies are preserved.
- A-01 migrates custom assignments only from an owned `99-vivobook.conf` to an
  owned `90-vivobook-local.conf`. Exact duplicates are collapsed, conflicting
  same-key assignments/unowned destinations abort migration rather than risk
  data loss. The four managed keys remain only in 99, which sorts after 90.
  Later admin files, or `/etc/sysctl.conf`, may still override values.
- Restore returns migrated custom assignments to an **unmarked** original
  `99-vivobook.conf` and removes the owned migration file. Custom settings are
  user data, not tuning to erase. An occupied original path causes preservation
  and a failure report, never forced replacement. A later apply preserves this
  unmarked custom file until you deliberately merge/move it yourself.

```bash
bash vivobook_optimize.sh --dry-run --restore-defaults
sudo bash vivobook_optimize.sh --restore-defaults
```

Restore does not uninstall packages or revert package upgrades, firmware flashes,
BIOS, signing infrastructure or kernel cmdline. It resets documented baseline
knobs, not arbitrary previous values; remaining sysctls can reapply overrides.
Live module/RAPL reset may need reboot. User-installed main binary and the
operator-created defaults file are deliberately not removed.

## Persist the audit's optional baseline

Example (not built-in defaults):

```bash
WITH_ZRAM=true
WITH_AUTO_POWER=true
PL2=45
WITH_KBD_TIMEOUT=true
WITH_BBR=true
WITH_BROWSER_WAYLAND=true
WITH_USB_AUTOSUSPEND=true
MAINTENANCE_SCHEDULE=weekly
WITH_MT7921E_ASPM=false
```

Read [config/defaults.conf.example](config/defaults.conf.example) before copying:

```bash
sudo install -d -m 0755 /etc/vivobook-optimize
# Do not overwrite an existing defaults.conf without reviewing/backing it up.
sudo test ! -e /etc/vivobook-optimize/defaults.conf && \
  sudo install -o root -g root -m 0644 config/defaults.conf.example /etc/vivobook-optimize/defaults.conf
```

The defaults file is **sourced as shell code**, even in early read-only modes.
Only trust root-controlled contents. CLI arguments take precedence; omitted
flags do not generally uninstall earlier opt-ins. No battery limit assignment
means unchanged, not “off”. PL2=45 is specific to the supplied machine.

## Drift cleanup

```bash
sudo bash tools/cleanup-v16.0-drift.sh --dry-run --user='<user>'
# After checking the eligible list; interactive confirmation still required:
sudo bash tools/cleanup-v16.0-drift.sh --apply --user='<user>' --include-unmanaged-bbr
```

The extra BBR opt-in permits only the exact duplicate described by the audit,
with the managed replacement present. The tool defaults to dry-run, preserves
unowned/mixed files and active/enabled static units, backs up everything before
removing anything, and never blindly rewrites IPv6 sysctls. Backups stay private
under timestamped `/var/backups/vivobook-v16.0-drift-*` directories. Do not run
apply as part of CI.

## Verification, tests and release files

- [Verified audit/root causes and deviations](docs/PATCH-REVIEW.md)
- [Exact on-laptop commands and expected results](docs/VERIFY-ON-HARDWARE.md)
- [Recorded sandbox outputs and limitations](docs/TEST-RESULTS.md)
- [Release notes and publishing commands](releases/v16.1.0.md)
- [`vivobook_optimize_v16.1.sh`](vivobook_optimize_v16.1.sh) is a byte-identical
  standalone download of `vivobook_optimize.sh`; keep the canonical file as source.
- [`releases/v16.0-to-v16.1.patch`](releases/v16.0-to-v16.1.patch) is the complete
  unified diff against the attached v16.0, not a selectively abbreviated diff.

```bash
sudo apt-get install shellcheck jq   # Development tools only.
bash tests/smoke.sh
```

CI runs syntax, ShellCheck, read-only telemetry and private-tree regressions.
It does not validate USB driver timing, sysfs writability, AC/suspend policy,
firmware limits or boot signatures on your laptop.

## Privacy and license

Public source notes replace usernames/hostnames with `<user>` / `<hostname>`
and personal home paths with `/home/<user>`. Hardware identifiers unrelated to
model support are also redacted. Runtime status intentionally shows the real
machine/user state: redact it before opening an issue. Do not upload keys,
serials, full kernel logs, private config or backups.

The original checkout's **Git history may still contain the unredacted attached
notes**. A ZIP/clean export excludes `.git`; do not publish old history without a
separate privacy review. No history rewrite or remote push was performed here.
MIT licensed; replace the copyright-name placeholder before publishing.
