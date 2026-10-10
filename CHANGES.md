# vivobook_optimize v16.0 — changes from v15.3

v16.0 (JSON schema 3) builds on `vivobook_optimize_v15.3.sh`. It merges two
review documents:

- **Spec A**: `2ND.txt`, findings F-01..F-11 and changes C-01..C-11
- **Spec B**: `Executive Summary.md`, findings F-01..F-07 and changes C-01..C-06

Both are checked against `ASUS Vivobook 16 X1605VA.md` (the machine facts).
v16 adds **no new flags, services or managed files**. The v15.3 script is unchanged.

| File | Purpose |
|---|---|
| `vivobook_optimize_v16.sh` | the new script (new header changelog, updated usage for `--with-mt7921e-aspm` and `--safe-mode-check`) |
| `patches/NN-*.patch` | the v15.3 → v16 diff split by change number. Applied in order to a copy of v15.3 named `vivobook_optimize_v16.sh` (`patch -p1`), they rebuild v16 byte-for-byte |
| `patches/v15.3-to-v16.full.diff` | the same diff in one piece |
| `verify_v16.sh` | static checks, sandbox checks and fixture checks (see "Verification") |

## Changes by priority

The numbers match the patch files.

### P0

**1. `--safe-mode-check`: the mt7921e item is informational** (A C-01, B C-01)
- Shows the live `disable_aspm` value and the config state (absent, script-managed or unmanaged; sets `=1` or not) on separate lines.
- WARN only when this boot's kernel log has mt7921e error lines.
  - The log comes from `journalctl -k -b`, with `dmesg` as the fallback. If neither is readable, the count is `unknown`.
  - The error match is a heuristic regex: `mt7921e.*(timeout|timed out|failed|error|crash|assert)`.
- A WARN keeps exit 0. It is listed under "Informational warning(s)" and never added to `SAFE_FAILS`.
- The signing hook, apt pin, kernel signature and Secure Boot checks are still hard gates (exit 1).

**2. ASPM wording now follows the actual state** (A C-03, B C-01)
- New helper `aspm_workaround_live()`.
  - "live": the running module has `disable_aspm=Y`.
  - "active": live **or** staged (v15.3 meaning, kept for the existing JSON key).
- Reworded: the flag help, the header of the generated `mt7921e.conf`, the dashboard C-state text, the "not configured" line, the step 17/17a text, the restore message (now a NOTE on stdout, not a WARNING), the final summary (`MT7921E_STAGED_THIS_RUN`) and the power-switch comment.
- `--with-mt7921e-aspm` stays as an **optional fallback**. The text says it blocked PC6/PC8/S0i3 before kernel 7.2.6.
- JSON adds `aspm_workaround_live` under `suspend` and `wifi.mt7921e`.

**3. Version 16.0, schema 3** (A C-11)
- `SCRIPT_VERSION="16.0"`, `SCRIPT_SCHEMA=3`.
- Generated headers, unit `Description=` lines, echoes, the dashboard title and the safe-mode title now say `v16`.
- The marker substring `Managed by vivobook_optimize` is unchanged, so v15.3 and v16 recognise each other's files.
- Historical `v15.3 (I-xx)` code comments are kept.

### P1

**4. Status modes no longer write to RAPL** (B C-03, B F-03)
- `--status` prints `lock: unknown (read-only)` and no longer calls `rapl_probe_lock_state`.
- `--status-json` keeps the `rapl.locked.*` keys, with value `null`, and adds `rapl.lock_state_probed: false`.
- The write-back probe now runs only in step 20, on real `--pl1/--pl2` runs.

**5. `--restore-defaults` only removes what the script owns** (B C-05, B F-05)
- New helpers `restore_remove_owned` and `restore_unit_owned`.
- A unit is disabled/stopped and removed only if `/etc/systemd/system/<unit>` has the marker.
- Helpers, sleep hooks, `/etc/default/vivobook-*` files, udev rules, sysctl/modprobe/wireplumber/environment.d files: same rule, marker required.
- The BBR pair also uses the v15.3 legacy-adoption rule (`managed_or_legacy_adoptable`, exact normalized content). An adopted file also triggers the live `cubic` reset.
- Unmarked paths are kept. Each one prints `SKIPPED (not script-managed, preserved)` and all are listed at the end.
- A failed removal of a managed path gives a stderr WARNING and **exit 1** (v15.3 always exited 0).
- `zramswap.service` disable and the live `/dev/zram0` detach only happen if a zram config was script-managed. Ownership is checked before the configs are removed.
- PPD unmask/enable/start reads `/etc/default/vivobook-ppd-state` only if the script owns it: marker, or exactly the four `PPD_WAS_*=true|false` lines that pre-marker releases wrote. The file is parsed, never sourced.
- The legacy `vivobook-pstate-defaults` / `vivobook-igpu-defaults` files (pre-v15, pre-marker) keep their v15.3 rule.
- Kept unchanged: the `/run` lock cleanup, the counted battery-to-100% reset, max_perf_pct, swappiness/writeback, the BBR `cubic` reset, PPD unmask and browser flags.

**6. Audio** (A C-05, B C-04, B F-04)
- On the SOF path, step 12 deletes a marked `audio-powersave.conf` only when its normalized content is exactly `options snd_hda_intel power_save=1 power_save_controller=Y`. Any other marked file (for example the machine's 10/N file) is kept with a NOTE.
- Unmarked files: kept, as before.
- New `[HD Audio power save]` dashboard section showing:
  - live `power_save` / `power_save_controller`;
  - whether SOF is loaded (`/proc/modules`);
  - whether a staged file exists and whether it is managed, plus its options;
  - a verdict, e.g. `staged differs from live — applies on next module load/reboot`;
  - a reminder that `--with-auto-power` writes 0 (AC) / 1 (battery) at runtime.
- New JSON `audio` object.
- Corrected the "normally unsupported under SOF" claims (power-switch helper comment, KNOB_STATE text, step 19 echo, final summary, verify list).
- Values not changed: the `--with-auto-power` 0/1 writes and the 10/N file.
- `--restore-defaults` still removes a marked but hand-edited file (restore reverses every managed file), but now prints a NOTE first, with a backup hint.

**7. Sleep hooks** (A C-04)
- All four hooks share one body, `sleep_hook_body <unit>`. It restarts the unit on `post` **only if** `systemctl is-enabled --quiet <unit>`. The body is written via a here-string.
- New default-run step **15d** refreshes **existing, marked** hooks in place.
  - It compares content first, so a second run and `--dry-run` show no write.
  - It never creates a hook, never touches an unmarked one, never enables or starts a unit.
- Status: the "Persistent service:" lines show `enabled` / `installed-disabled` / `not-installed`. A v15.3 hook is flagged `UNGUARDED`.
- JSON adds `battery.service_state`, `thermal.service_state`, `cpu.epp_service_state`, `keyboard_backlight.service_state` and a top-level `sleep_hooks` object.

**8. `--safe-mode-check` also checks the newest installed kernel** (A C-02)
- New `kernel_image_signature_state <path>`; `running_kernel_signature_state` remains as a wrapper.
- New `newest_installed_kernel_image`: `sort -V` over `/boot/vmlinuz-*`, ignoring `.old/.bak/.orig/.unsigned/.dpkg-*`.
- If the newest image is not the running one:
  - not signed by "Vivobook Kernel Key": FAIL;
  - no `sbverify`: UNVERIFIED, which also counts as a failure (same policy as the running kernel).
- Dashboard and JSON add `newest_kernel_image` / `newest_kernel_signature`.

**9. Graphics status follows the bound driver** (A C-06)
- The `[i915 GuC/HuC]` section and JSON `i915` use `detect_active_drm_driver`.
- `i915.module` names the **bound** driver (`xe` here). This is the one non-additive schema-3 change.
- `enable_*` values are reported only when i915 is bound. The object still has exactly 5 keys.

### P2

**10. PC6 and S0i2/S0i3 residency** (A C-08, B C-02)
- Exact-label `pmc_pkg_cstate`, so C1 no longer matches C10. PC6 is added; PC8/PC10/SLP_S0 are kept.
- "PC8 reached, PC10 not" is now informational.
- S0i2/S0i3 come **only** from `pmc_core/substate_residencies`, and only if the whole file matches the upstream format.
  - Format: a header line with "Substate" and "Residency" (newer kernels prefix `pmcN`), then `S0iX.Y <n>` rows. Only the first PMC block is read.
  - Otherwise the value is `unavailable` / `null`. It is never inferred from SLP_S0 and no other path is guessed.
- The output notes that the counters are cumulative since boot.
- JSON adds `pc6_residency`, `package_cstates`, `s0ix_substates`, `s0i2_residency_usec`, `s0i3_residency_usec`, `s0ix_substate_source` and `residency_counters`.

**11. Battery health** (A C-07)
- `battery_health_rows` now has 6 columns. It uses the `charge_*` pair if valid, otherwise the `energy_*` pair (µWh), and never mixes the two.
- Both callers were updated.
- `charge_full_uah` / `charge_full_design_uah` stay unit-pure (`null` for energy data). New keys `full`, `full_design` and `unit` are added.
- With the facts' values the result should be 89.4 %. The fixture test reproduces this.

**12. Unmanaged sysctl overrides** (B C-06, B F-06)
- Report only, never edited: any unmarked file in the sysctl.d directories or `/etc/sysctl.conf` that sets a key this script manages (the four step-11 keys plus the BBR pair).
  - The scan honours basename shadowing, `/dev/null` masks and symlinked duplicates.
  - Each finding is marked as applied after the managed file, before it, or with no managed file present.
- Shown in a dashboard section, in JSON (`sysctl_overrides`, `bbr.unmanaged_override_files`) and as restore NOTEs before `sysctl --system`.
- IPv6: TODO comment only (see open questions).

### P3

**13. `--battery-limit=off` reports what actually happened** (A C-09)
- New function `battery_limit_off_reset`. It prints "set to 100% on X of Y", "already 100%" or "none found".
- If a reset fails, it prints a stderr WARNING and returns 1. The caller still continues.

**14. Flag echo** (A C-09)
- `mt7921e-aspm=$WITH_MT7921E_ASPM` is now printed in the dry-run flag block and in "Flags this run".

**15. USB exempt-class diagnostic** (A C-10)
- Read-only.
- Lists devices with an interface of class 03, e0, 01 or 0e, with their `power/control` value.
- `MISMATCH` is printed for `auto` only when the managed rule is installed. The rule itself is unchanged.
- JSON: `usb_autosuspend.exempt_class_devices`, `exempt_class_devices_on_auto` and `mismatch_applicable`.

## Where spec A and spec B conflict

| Topic | A | B | v16 |
|---|---|---|---|
| mt7921e absent in safe-mode | informational | remove from gate | informational; WARN only on logged errors; exit 0 |
| SOF audio file removal | remove only exact 1/Y content | preserve staged settings | A's exact-content rule (unknown variants are kept) |
| RAPL status lock | (not covered) | no write in status | B; keys kept, value `null` + `lock_state_probed:false` |
| Version stamps | replace everywhere | — | A; one-time rewrite of stamped files |
| Restore ownership | removes the 4 hooks unconditionally | marker-aware | B (marker-aware), plus the v15.3 BBR legacy rule |
| Newest kernel without sbverify | UNVERIFIED | — | counts as a failure, same as the running kernel |
| BBR override | — | report BBR file | report only, extended to all managed keys |
| S0i3 source | path unconfirmed | improve reporting | read only after runtime validation of `substate_residencies`, else `null` |
| Rollback | rerun v15.3 default pass | do not rerun v15.3 immediately | B's more cautious guidance (below) |

**Where a requirement conflicted with the script's principles, the principles won:**
- `--with-mt7921e-aspm` was kept as an optional fallback. It was not removed, and v16 never turns the workaround on or off by itself.
- No unmanaged file is edited (99-bbr.conf, the audio file, the sysctl overrides).

## JSON schema 3 (additive except `i915.module`)

All new keys, by section:

- `suspend`: `aspm_workaround_live`, `pc6_residency`, `package_cstates`, `s0ix_substates`, `s0i2_residency_usec`, `s0i3_residency_usec`, `s0ix_substate_source`, `residency_counters`
- `wifi.mt7921e`: `aspm_workaround_live`
- `audio` (new object)
- `battery`: `service_state`
- `thermal`: `service_state`
- `cpu`: `epp_service_state`
- `keyboard_backlight`: `service_state`
- `sleep_hooks` (new object)
- `battery_health`: `full`, `full_design`, `unit`
- `boot_integrity`: `newest_kernel_image`, `newest_kernel_signature`
- `rapl`: `lock_state_probed`
- `bbr`: `unmanaged_override_files`
- `sysctl_overrides` (new array)
- `usb_autosuspend`: `exempt_class_devices`, `exempt_class_devices_on_auto`, `mismatch_applicable`

Changed values:
- `rapl.locked.*` are now always `null`.
- `battery_health.charge_*_uah` are `null` for energy-reporting batteries.
- `i915.module` now names the bound driver.

## First v16 run on the reference machine

- Files carrying the version stamp are rewritten **once**, because the header changed from v15.3 to v16. After that, a second run changes nothing.
- **IPv6 caution:** step 11 rewrites `/etc/sysctl.d/99-vivobook.conf` with its four keys only. Run `grep -n ipv6 /etc/sysctl.d/99-vivobook.conf` **before** the first v16 default run. Move any IPv6 lines to an unmanaged file first.
- Step 15d converts the existing thermal/EPP v15.3 hooks to the guarded form. Their units stay disabled.

## Rollback

- `--restore-defaults`: v16 creates no new artifacts. Restore removes only marked or legacy-rule files and lists what it kept. `/root/vivobook-backups/...` and `/etc/sysctl.d/99-bbr.conf` are never touched.
- Downgrading to v15.3, following spec B's caution:
  1. Save `--status-json`.
  2. Back up `/etc/modprobe.d/audio-powersave.conf`.
  3. Replace the script file. Do **not** run `--restore-defaults`, and do **not** immediately rerun the v15.3 apply pass. v15.3 still:
     - fails safe-mode on the missing workaround;
     - deletes a marked SOF audio file;
     - write-probes RAPL from `sudo --status`.
  4. If you must run v15.3, review the flags first. Use `--no-audio-powersave` and avoid `--with-mt7921e-aspm`.
  5. v16's guarded hooks keep working under v15.3. Schema-3 consumers can ignore the extra keys.

## Known gaps in v15.3 found during the review (flagged, not changed: outside the requested scope)

1. Step 5 removes `powertop-autotune.service` without checking for the marker.
2. `--battery-limit=off` removes the threshold service, helper, hook and `/etc/default` file without checking for the marker.
3. On the legacy-HDA (non-SOF) path, step 12 overwrites an existing **unmarked** `audio-powersave.conf`. Not relevant on this SOF machine.

## Needs your confirmation / open questions

1. **IPv6**: the facts (§18) say IPv6 is disabled "via 99-vivobook.conf", but §16 lists only the four keys v15.3 writes. Which is true? Not fixed (TODO comment at step 11).
2. **battery-charge-threshold.service / set-battery-threshold.sh**: §20/§22 list them as present, §9 says "not installed". v16 handles both cases (restore checks markers), but which is current?
3. **S0i3 = 2,231,014 µs**: the facts don't say where this number came from. v16 reads it only from a validated `substate_residencies` file (upstream creates it for Raptor Lake-P via the TGL map). Please confirm that `sudo cat /sys/kernel/debug/pmc_core/substate_residencies` looks like `S0i3.0  <n>` rows.
4. **Marker on the 10/N audio file**: unknown. Both cases are handled: marked (kept with NOTE) and unmarked (kept).
5. **mt7921e error regex**: it is a heuristic. Give me real error lines if you have them and I'll tighten it.
6. **Newest kernel with no `sbverify`**: treated as a failure (UNVERIFIED), matching the running-kernel policy. Say if you prefer a warning.

## Verification

Run `bash verify_v16.sh`. In the build sandbox the result was **114 passed, 0 failed** (Debian 12, unprivileged, shellcheck 0.11.0).

**What was run:**
- `bash -n`.
- shellcheck v15.3 vs v16, comparing normalized messages: no new findings. The guarded hook body is also shellcheck-clean.
- Static checks: version and schema, anchors, flag set unchanged, every v15.3 JSON key literal still present, the patches rebuild v16.
- Read-only runs in the sandbox: `--status`, `--status-json` (valid JSON, every v15.3 key path still present), `--safe-mode-check`, `--dry-run`, `--restore-defaults --dry-run`, `--help`, `--version`.
- A normalized v15.3 vs v16 `--dry-run` comparison showed only the intended differences.
- Fixture tests: the functions are extracted from v16 and every absolute system path is redirected into a temporary tree. systemctl, journalctl, sbverify and the rest are mocked. The fixtures model the documented facts.
- Mutation checks: an unguarded hook body, a restore that ignores markers, and fatal mt7921e errors were each caught by the tests.

**Not verified:**
- Nothing ran on the X1605VA.
- Nothing was run as root.
- No real debugfs/pmc_core, suspend/resume, Secure Boot/MOK/sbverify, SOF/snd_hda_intel or mt7921e hardware.
- No real apply pass and no real `--restore-defaults`.
