## Executive Summary

v16.0 should bring `vivobook_optimize_v15.3.sh` into alignment with the ASUS Vivobook 16 X1605VA’s verified October 10, 2026 baseline without rewriting its architecture or changing working power-management policy. The highest-priority correction is to stop treating `mt7921e disable_aspm=1` as a prerequisite for safe rebooting: the reference machine now runs kernel 7.2.6 without that workaround, Wi-Fi has recorded zero errors since boot, and package PC6/PC8 plus S0i3 residency are nonzero. v16 should also make the status interfaces genuinely read-only, improve S0ix and audio-state observability, preserve the staged `snd_hda_intel` settings, and close a gap between the promised managed-file ownership rules and `--restore-defaults`. The existing RAPL PL2=45 W configuration, firmware-locked PL1, battery threshold of 100%, power-manager ownership rules, signed-kernel safeguards, atomic writes, and existing user-facing flags should otherwise remain intact. v16 is an incremental correctness and observability release; it will not introduce blanket tuning, change firmware settings, or modify unmanaged configuration.

## Findings

### F-01 — The MT7902 ASPM workaround is incorrectly treated as a reboot prerequisite

**What was observed**

- Script lines 63–68 describe `--with-mt7921e-aspm` as required for Wi-Fi link stability.
- The `aspm_workaround_active()` helper, lines 529–539, treats the live module parameter or staged configuration as evidence that the workaround is active.
- `safe_mode_check()`, approximately lines 2600–2700, makes a missing `disable_aspm=1` configuration a critical failure whenever `mt7921e` is in use. It advises against rebooting and instructs the user to enable the workaround.
- The restore path, lines 1119–1129, warns that removing the workaround will expose the machine to Wi-Fi disconnects and packet loss.
- The Wi-Fi status section reports that Wi-Fi may be unstable when the workaround is absent.

**Machine evidence**

System facts §6 and §31, lines 152–165 and 660–666, establish that the active driver remains `mt7921e`, the live `disable_aspm` value is `N`, the configuration has been removed from `/etc/modprobe.d/`, and Wi-Fi has recorded zero errors since boot. The prior file is retained at `/root/vivobook-backups/modprobe/mt7921e.conf.disabled`.

System facts §15, lines 349–363, confirms nonzero PC6, PC8, SLP_S0, and S0i3 residency after removing the workaround. The current kernel is 7.2.6.

**Why it matters**

The current gate can reject a reboot even though the machine's boot-integrity prerequisites are satisfied and the formerly required workaround is no longer required by the documented baseline. It also presents the absence of a configuration workaround as evidence of likely Wi-Fi instability without considering the current operating state.

**Classification:** Confirmed real issue.

**Proposed change:** Make ASPM-workaround status informational rather than a critical safe-mode requirement. Retain the existing opt-in flag for compatibility, correct the obsolete descriptions, and report the observed configuration and live parameter separately.

### F-02 — The status dashboard does not adequately describe the currently working S0ix state

**What was observed**

- `show_status_dashboard()`, approximately lines 1611–1629, reads Package C8 and C10 from `package_cstate_show`.
- The same block suggests checking ASPM, USB, and audio wakeups when PC8 is reached but PC10 is not observed.
- The dashboard reads SLP_S0 residency separately, but it does not display PC6 or the S0i2/S0i3 breakdown.
- `show_status_json()`, approximately lines 2215–2247, preserves PC8, PC10, a combined deep-state Boolean, the workaround-active Boolean, and SLP_S0 residency. It does not expose the broader state inventory in the machine facts.

**Machine evidence**

System facts §15 records PC6=5,234,683, PC8=24,745,281, SLP_S0=49,338,142 µs, and S0i3=2,231,014 µs, with PC10=0. The facts explicitly state that S0ix is functional.

**Why it matters**

PC10 being zero is not sufficient evidence that S0ix is broken. The dashboard's existing message can encourage unnecessary investigation, while the current JSON omits useful state information that is available in the documented machine inventory.

The facts do not identify the exact kernel interface used to obtain the S0i3 counter. v16 must not invent a sysfs path or infer S0i3 residency from SLP_S0.

**Classification:** Confirmed observability gap; the lack of a documented S0i3 source is an unresolved implementation detail, not proof of a kernel defect.

**Proposed change:** Parse the available package C-state counters, retain SLP_S0 reporting, and improve the interpretation of PC8-without-PC10. Add S0i2/S0i3 telemetry only if a validated read-only source can be identified on this machine.

### F-03 — Root-run status modes write to RAPL sysfs nodes

**What was observed**

- `rapl_probe_lock_state()`, lines 564–588, writes the current value back to the selected RAPL limit node to classify it as writable or firmware-locked.
- `show_status_dashboard()`, approximately lines 1945–1959, invokes that function for each reported constraint.
- `show_status_json()`, approximately lines 2510–2528, invokes the same function while constructing the JSON lock-state map.
- The CLI documentation promises that `--status` and `--status-json` are read-only. The dashboard's closing message explicitly says that no configuration was changed.

**Machine evidence**

System facts §14, lines 325–331, documents a firmware-locked PL1 of 200 W and a writable PL2 of 45 W. The `rapl-power-limits.service` is active and has successfully applied PL2=45 W.

**Why it matters**

Writing an unchanged value may leave the numerical limit unchanged, but it is still a write operation. These status commands therefore do not satisfy a strict read-only contract.

**Classification:** Confirmed design inconsistency.

**Proposed change:** Keep write-based RAPL lock probing in the mutating `--pl1`/`--pl2` path, but do not call it from status functions. The dashboard should report that lock state was not probed in read-only mode. The JSON should use `null` for unknown lock values and explicitly record that no write probe was performed.

### F-04 — The staged audio configuration can be removed or overridden without the status output explaining why

**What was observed**

- In step 12, approximately lines 3750–3799, v15.3 detects the Intel SOF stack with `lsmod | grep snd_sof_pci_intel`.
- If SOF is detected, v15.3 avoids forcing `snd_hda_intel` options, but removes `/etc/modprobe.d/audio-powersave.conf` when that file has the managed marker. If it is unmarked, the script preserves it.
- If the legacy HDA branch is used instead, the script stages `power_save=1 power_save_controller=Y`.
- The dynamic helper's `apply_audio_powersave()`, lines 4803–4842, independently changes the live `power_save` value to 0 on AC and 1 on battery when the writable sysfs parameter exists.
- The status dashboard reports WirePlumber suspend configuration but does not compare the staged HDA module options against the live module parameters.

**Machine evidence**

System facts §8, lines 194–208, records an active SOF stack and an existing `/etc/modprobe.d/audio-powersave.conf` containing:

`options snd_hda_intel power_save=10 power_save_controller=N`

The documented live `power_save` value remains 0 because the configuration has not been applied at the current module load.

The facts do **not** state whether the file currently has a `Managed by vivobook_optimize` marker.

**Why it matters**

Whether v15.3 deletes the existing file depends on marker ownership, which the facts do not establish. The script also lacks a diagnostic that distinguishes staged configuration from the live module state. The dynamic AC/battery helper has a separate, documented runtime policy and can intentionally override the live `power_save` value.

**Classification:** Confirmed observability and policy-alignment gap; whether the current file is at risk of deletion is conditional on its marker.

**Proposed change:** Preserve an existing audio configuration when the SOF branch is selected; do not remove it merely because SOF is active. Align the fallback legacy-HDA defaults with the documented `10`/`N` values. Add read-only reporting for both staged and live values. Retain the existing dynamic AC/battery behavior unless a separate policy decision authorizes changing it.

### F-05 — Restore can delete files that do not have the managed marker

**What was observed**

`restore_defaults()`, lines 1046–1158, disables and removes a fixed list of service units, helpers, sleep hooks, default files, and udev rules using direct `rm -f` operations.

Examples include:

- Lines 1060–1062: disabling and deleting the listed systemd units without first confirming that their unit files contain the managed marker.
- Lines 1072–1087: removing helper scripts, hooks, and `/etc/default/vivobook-*` files without checking ownership.
- Lines 1152–1155: removing the Vivobook power, NVMe, and USB autosuspend udev rule paths without a marker check.

The script already has `is_managed_file()` and `remove_managed_config()`. Other configuration paths, including the BBR and USB installation blocks, explicitly protect unmanaged files.

**Why it matters**

The unconditional restore deletions do not fully satisfy the declared rule that unmanaged files at the same path are off-limits. For example, the USB installation block refuses to overwrite an unmarked existing rule, but the restore block would later delete it.

**Classification:** Confirmed ownership-policy inconsistency. The facts do not establish that any of these current paths contains an unmanaged collision; the issue is the behavior on such a collision.

**Proposed change:** Make restore ownership-aware. Stop or disable a service only when the corresponding unit is confirmed managed by this script. Remove managed helpers, hooks, configs, and udev rules only when their ownership can be established. Preserve unmarked files and report the skipped paths. Retain narrowly scoped legacy-adoption behavior only where v15.3 already explicitly allows it.

### F-06 — Restoring BBR may leave an unmanaged BBR override active

**What was observed**

- In `restore_defaults()`, approximately lines 1106–1117, the script remembers whether `/etc/sysctl.d/98-network-bbr.conf` was managed, removes managed BBR configuration, resets the live congestion-control value to cubic when appropriate, and then invokes `sysctl --system`.
- The status output reports the managed BBR config path, but it does not explain whether another unmanaged file will reapply the same values.

**Machine evidence**

System facts §16, lines 377–396, records `/etc/sysctl.d/98-network-bbr.conf` and a duplicate `/etc/sysctl.d/99-bbr.conf` that is explicitly identified as unmanaged.

**Why it matters**

An unmanaged later configuration can reapply BBR during `sysctl --system`. This does not justify deleting the file: it is unmanaged and must be preserved. However, a user may incorrectly interpret the restore output as meaning that BBR will no longer be active.

**Classification:** Confirmed machine-specific observability issue; not a reason to change the unmanaged configuration.

**Proposed change:** Detect the documented unmanaged BBR override and report that it will remain untouched and may reapply BBR after restore. Add the override information to the status output and JSON. Do not edit or delete `/etc/sysctl.d/99-bbr.conf`.

### F-07 — Several important current settings already match v15.3's intended behavior and should not change

**What was observed**

The facts document establishes the following baseline:

- RAPL configuration is `PL1=` and `PL2=45`; the firmware-locked PL1 is left under firmware control while the writable PL2 is applied.
- Battery charge threshold is 100%; the cap service is disabled and the resume hook is absent.
- TLP is present but inactive/masked; power-profiles-daemon and thermald are active. The live desktop profile and ASUS platform profile are `performance`.
- The kernel signing hook is present and executable, Secure Boot is enabled, the running kernel is signed by the Vivobook Kernel Key, and the stock-kernel package pin is present.
- The current kernel is 7.2.6 from the cappelikan PPA, with no newer release available according to the facts.
- zRAM is active with zstd and priority 100; dynamic AC/battery power switching is enabled.
- The combined Bluetooth sink has been removed.

**Why it matters**

These states are consistent with existing script behavior or with deliberate machine configuration. Changing them without evidence would increase regression risk without solving a demonstrated problem.

**Classification:** Correct baseline or intentional design choice.

**Proposed change:** Preserve the current RAPL validation and per-constraint handling, battery behavior, PPD/TLP/thermald ownership rules, signed-kernel protections, supervised kernel-purge policy, zRAM no-op behavior, and existing Bluetooth state. Do not create new automatic actions for these settings.

## Proposed Changes

Changes are ordered by priority. No new persistent configuration file is required for the proposed work; any existing managed file that v16 must rewrite must continue to use the established atomic-write path.

### C-01 — Remove the ASPM workaround from the critical reboot gate

**Rationale:** The reference machine's kernel 7.2.6 baseline works without `disable_aspm=1`. A missing workaround must no longer block a reboot or imply that Wi-Fi instability is expected.

**Files affected:** `vivobook_optimize_v15.3.sh` only: usage block, `aspm_workaround_active()`, `safe_mode_check()`, restore warning, Wi-Fi status text, and step 17a.

**Exact modification:**

1. In `safe_mode_check()`, replace checkpoint `[5/5] MediaTek MT7902 (mt7921e) ASPM workaround` with an informational checkpoint. Report the live `disable_aspm` value, whether `/etc/modprobe.d/mt7921e.conf` exists, whether it is managed, and whether the staged file sets `disable_aspm=1`.
2. Do not append a `SAFE_FAILS` entry solely because the workaround is absent.
3. Keep the existing boot-integrity checks for the signing hook, apt pin, running-kernel signature, and Secure Boot verification. Preserve their current failure semantics.
4. Keep `--with-mt7921e-aspm` as a compatibility flag. Update its usage text and step 17a comments to describe it as an **opt-in legacy workaround**, not a default requirement for kernel 7.2.6. If explicitly selected, continue to use `atomic_write` and include the managed marker. Do not overwrite an unmanaged `mt7921e.conf`.
5. Update the restore warning so it does not state that Wi-Fi stability universally requires the workaround. State that removing it is appropriate for the documented current kernel baseline, while any later Wi-Fi regression should be diagnosed from actual link behavior.
6. Update the Wi-Fi status message so that an inactive workaround is not itself reported as evidence of likely instability. Retain reporting of the actual live parameter and staged-file state.

No automatic deletion of a previously managed ASPM file should occur simply because the user omitted the flag on a later run; existing additive-flag semantics remain intact.

**Behavior change:** Before, `--safe-mode-check` can fail solely because the ASPM workaround is absent. After, its absence is informational, and the command fails only for the existing boot-integrity blockers. The opt-in workaround remains available.

**Interaction with existing flags:**

- `--with-mt7921e-aspm`: remains supported; managed configuration is written atomically.
- `--restore-defaults`: removes the workaround only when the artifact is confirmed managed; the backup at `/root/vivobook-backups/modprobe/mt7921e.conf.disabled` remains untouched.
- `--dry-run`: describes any proposed config write or removal without applying it.
- `--status` / `--status-json`: report actual state without treating absence as a failure.
- `--safe-mode-check`: retains the same flag and exit-code contract for genuine boot-integrity failures.

**Risk:** Low. The principal risk is overly reassuring language. Mitigate it by keeping real boot-signature, pin, and Secure Boot verification failures blocking, while making only the ASPM condition informational.

**Test cases:**

- **Positive:** With kernel 7.2.6, `mt7921e` in use, live `disable_aspm=N`, and no active config file, the ASPM checkpoint is informational and does not add a failure.
- **Negative:** Remove or invalidate the kernel-signing hook or stock-kernel pin in a test environment; `--safe-mode-check` must still fail and identify the problem.
- **Ownership:** Place an unmarked `/etc/modprobe.d/mt7921e.conf` in a test environment; explicitly requesting `--with-mt7921e-aspm` must preserve that file and report the conflict.
- **Idempotent:** Run the flag twice with the script-managed config already correct; the second run does not replace the file.
- **Dry-run:** `--dry-run --with-mt7921e-aspm` does not change the config or claim that the workaround was applied.

**Effort:** 1.5 hours.

### C-02 — Improve package C-state and S0ix reporting

**Rationale:** The machine currently reaches PC6 and PC8 and has nonzero SLP_S0 and S0i3 residency. v15.3 does not expose this full picture in its status output.

**Files affected:** `show_status_dashboard()` and `show_status_json()`, especially the suspend/C-state blocks around lines 1611–1635 and 2200–2247.

**Exact modification:**

1. Extract the package C-state counters that are present in the existing `/sys/kernel/debug/pmc_core/package_cstate_show` output. At minimum, report PC6, PC8, and PC10; include PC2, PC3, PC7, and PC9 when present.
2. Continue reading SLP_S0 from the existing `slp_s0_residency_usec` interface.
3. Preserve the existing JSON keys `pc8_residency`, `pc10_residency`, `deep_pc_states_reached`, `aspm_workaround_active`, and `slp_s0_residency_usec` for compatibility.
4. Add an explicit package-C-state object or equivalent additive fields to `suspend` in the JSON output. Missing or unreadable counters must be `null` or clearly marked unavailable, not fabricated as zero.
5. Reword the dashboard's “PC8 reached, PC10 never entered” message. It must distinguish “PC10 not observed” from “S0ix is broken,” and must not make PC10 a required pass condition on this machine.
6. Do not infer S0i3 from SLP_S0. Add an S0i3 field only after its read-only source has been identified and verified on the target. Otherwise report it as unavailable.

**Behavior change:** Before, the dashboard focuses on PC8/PC10 and may encourage unnecessary investigation when PC10 is zero. After, it exposes the available package-state counters and SLP_S0 independently, so the documented current state is represented more accurately.

**Interaction with existing flags:**

- `--status` remains read-only.
- `--status-json` retains old keys and adds telemetry fields.
- `--dry-run` does not affect telemetry acquisition.
- `--restore-defaults` has no new artifacts to remove.

**Risk:** Low. All changes are diagnostic. The main mitigation is to distinguish missing data from a measured zero and not assume an undocumented interface for S0i3.

**Test cases:**

- **Positive:** On the reference machine, confirm PC6 and PC8 are nonzero and PC10 is reported as zero when the corresponding interfaces report those values.
- **Negative:** Run with debugfs unavailable or unreadable; the command should report unavailable state without failing or inventing counters.
- **S0i3:** If a valid source is identified, compare its value with the reference machine's collected measurement. If no source is validated, confirm the new S0i3 field is `null`/unavailable rather than derived from SLP_S0.
- **Idempotent:** Repeated status runs produce the same field structure and do not change system state.

**Effort:** 2.5 hours.

### C-03 — Make RAPL status probing genuinely read-only

**Rationale:** The status interfaces must not write to sysfs merely to report a lock state.

**Files affected:** `rapl_probe_lock_state()`, `show_status_dashboard()` around lines 1945–1959, and `show_status_json()` around lines 2510–2528.

**Exact modification:**

1. Retain `rapl_probe_lock_state()` for the explicitly mutating `--pl1` / `--pl2` configuration path.
2. Add a read-only reporting path for status functions. It must not open a RAPL limit node for writing.
3. In the dashboard, report the current power limit and state that firmware lock status was not probed in read-only mode.
4. In JSON, preserve the existing RAPL limit fields and `locked` map. Where the lock state is unknown because no probe was performed, use JSON `null`, not `true` or `false`.
5. Add an explicit field such as `lock_state_probed: false` to make this behavior machine-readable.
6. Bump `SCRIPT_SCHEMA` to 3 as part of the v16 JSON-contract update. Keep the old schema-2 keys wherever possible, documenting the intentional change in the interpretation of lock-state values.

**Behavior change:** Root-run `--status` and `--status-json` will no longer write the current RAPL values back to sysfs. They will report limits accurately but will not claim a definitive hardware lock state unless it was obtained by a mutating configuration operation.

**Interaction with existing flags:**

- `--pl1` / `--pl2`: continue the existing per-requested-constraint probe and validation.
- `--dry-run --pl2=45`: continue to skip write-based probes and avoid any “applied” claim.
- `--status-json`: returns schema 3 with explicit unknown/unprobed lock information.
- `--restore-defaults`: unchanged RAPL cleanup; this change does not invent a saved firmware baseline or attempt to rewrite locked PL1.

**Risk:** Low. The main trade-off is less lock-state detail in read-only mode. Mitigate it by retaining the actual limit values and distinguishing “not probed” from “locked.”

**Test cases:**

- **Positive:** Compare PL1/PL2 values before and after `--status` and `--status-json`; values must be unchanged, and tracing must show no write-open against RAPL constraint nodes.
- **Negative:** With a missing RAPL interface, status must report it as unavailable and must not fail because a lock probe could not run.
- **Mutating-path regression:** In a test environment reproducing a writable PL2 and locked PL1, `--pl2=45` must still probe/apply only the requested constraint and leave PL1 unmanaged.
- **Dry-run:** No RAPL write probe occurs and no success is claimed.
- **Idempotent:** Repeated status runs do not alter configuration, sysfs values, or file timestamps.

**Effort:** 1.5 hours.

### C-04 — Preserve staged audio settings and report configured-versus-live state

**Rationale:** The machine has an explicit `power_save=10 power_save_controller=N` staged configuration. The script must not remove that managed file solely because SOF is present, and its status should explain why the live module value may differ.

**Files affected:** Step 12, approximately lines 3750–3805; the `apply_audio_powersave()` helper around lines 4803–4824; audio reporting in `show_status_dashboard()` and `show_status_json()`.

**Exact modification:**

1. In the SOF branch, do not call `remove_managed_config /etc/modprobe.d/audio-powersave.conf` merely because `snd_sof_pci_intel` is loaded. Preserve an existing file and report that its options are staged, not necessarily reflected in the currently loaded module. If the file is unmarked, continue to preserve it.
2. If the legacy HDA branch is used, change the generated defaults from `power_save=1 power_save_controller=Y` to `power_save=10 power_save_controller=N`, matching the documented current configuration. Update the associated comments to accurately describe the configured values.
3. Add read-only audio telemetry for:
   - whether `/etc/modprobe.d/audio-powersave.conf` exists;
   - whether it carries the managed marker;
   - configured `power_save` and `power_save_controller` values, when parseable;
   - live module parameters when their sysfs nodes are available;
   - whether the staged and live values match or differ.
4. Parse the configuration as text. Do not source or execute `/etc/modprobe.d/audio-powersave.conf`.
5. Preserve the dynamic helper's existing AC/battery policy: when the live parameter is writable, it continues to request `power_save=0` on AC and `power_save=1` on battery. Report this runtime behavior clearly so users understand that a configured value of 10 may not remain the live value while the dynamic helper is managing it.
6. Preserve the semantics of `--no-audio-powersave`: it skips the static configuration step, but does not silently disable the audio action of `--with-auto-power`.
7. Add the audio telemetry fields to JSON schema 3 while retaining the existing `wireplumber` section.

**Behavior change:** Before, the SOF branch can delete the existing audio config if it is marked as managed, and the status output does not clearly distinguish staged settings from live settings. After, the existing file is preserved during normal SOF operation, the fallback HDA configuration aligns with the documented 10/N values, and status reports both configuration layers.

**Interaction with existing flags:**

- `--no-audio-powersave`: remains a skip for the static configuration path.
- `--with-auto-power`: maintains its current live AC/battery behavior.
- `--restore-defaults`: removes the audio config only if it is managed, consistent with the ownership model; an unmarked file remains untouched.
- `--dry-run`: any changed staged configuration is simulated and no live module parameter is written.
- `--status` / `--status-json`: reports current values without modification.

**Risk:** Low to medium. Audio module options can affect codec idle timing and the live dynamic policy may intentionally override `power_save`. Mitigate with tests covering actual playback, microphone capture, suspend/resume, and AC/battery transitions. Do not change the dynamic policy in this release.

**Test cases:**

- **Positive:** With SOF active and the existing 10/N file present, a normal run preserves it and status reports its configured values separately from the live values.
- **Negative/ownership:** If the file is unmarked, v16 must not overwrite or remove it. If `snd_hda_intel` is absent, report unavailable live parameters rather than claiming they were applied.
- **Legacy HDA:** In a test environment where the fallback branch is selected and the path is script-manageable, confirm the generated configuration contains `power_save=10 power_save_controller=N`.
- **Dynamic interaction:** Test AC and battery states. The live parameter should follow the existing 0/1 dynamic policy when writable; the staged file must not be rewritten by those transitions.
- **Idempotent:** With the correct managed file and policy already present, a second run leaves the file content and timestamp unchanged.

**Effort:** 2.5 hours.

### C-05 — Enforce managed-marker ownership during restore

**Rationale:** `--restore-defaults` must not disable or delete user-managed artifacts just because they occupy a path the script commonly uses.

**Files affected:** `restore_defaults()`, lines 1046–1158, plus any narrowly scoped helper needed to validate ownership before stopping services or deleting their associated files.

**Exact modification:**

1. Before running `systemctl disable --now` on a listed script unit, verify that its unit file is script-managed. If a unit file exists without the marker, leave that unit untouched and report the path.
2. Replace unconditional removal of generated helpers, sleep hooks, namespaced default files, and udev rules with marker-aware removal. Reuse `remove_managed_config()` where its behavior is sufficient.
3. If a path is unmarked, do not stop its associated service or delete the file. Print an explicit `SKIPPED` message in a real run and an equivalent simulation in dry-run mode.
4. Preserve the existing narrow, explicit legacy-cleanup logic for paths that v15.3 deliberately recognizes as adoptable. Do not broaden the rule to treating arbitrary unmarked files as script-owned.
5. Keep transient lock-file cleanup separate from persistent-artifact ownership. The active `/run/vivobook-optimize.lock` must continue to be retained.
6. Where a feature's unit or file cannot be shown to be managed, do not claim that it was removed. Keep the final restore summary accurate about skipped artifacts.

**Behavior change:** Before, restore can remove some unmarked files and stop associated units. After, it reverses only artifacts whose ownership is established, preserving unmarked user-managed paths and reporting them.

**Interaction with existing flags:**

- `--restore-defaults`: remains the global cleanup command, but cleanup is ownership-aware.
- `--dry-run --restore-defaults`: reports only actions that the real ownership checks would permit.
- `--status`: no change beyond improved visibility of residual artifacts.
- Normal feature flags must retain their existing marker-protection behavior and must not bypass the ownership rule.

**Risk:** Medium. A legitimate old artifact with a missing marker may be retained rather than removed. Mitigate this by retaining exact, previously defined legacy-adoption rules where they already exist and making skipped paths explicit instead of silently deleting them.

**Test cases:**

- **Positive:** With all known v15.3 artifacts present and bearing managed markers, restore removes those artifacts and disables only their corresponding managed units.
- **Negative/ownership:** Place an unmarked file at `/etc/udev/rules.d/99-usb-autosuspend.rules` and an unmarked unit at a script-used unit path in a disposable test environment. Restore must preserve them and report the skip.
- **Failure visibility:** A failed removal or stop must not be reported as a successful removal.
- **Dry-run:** No persistent file, service, unit, or sysfs state is changed; the simulated result matches the ownership checks.
- **Idempotent:** A second restore reports the absence of already-removed managed artifacts as no-ops and does not disturb the unmarked test files.

**Effort:** 3.0 hours.

### C-06 — Report surviving unmanaged BBR overrides during restore and status

**Rationale:** The reference machine contains an unmanaged duplicate BBR sysctl file that can reapply the policy after the managed file is removed.

**Files affected:** The `restore_defaults()` BBR block around lines 1106–1117 and its later sysctl-reset/reapply sequence; the status dashboard's `[TCP BBR & Queuing]` section; the `bbr` object in `show_status_json()`.

**Exact modification:**

1. Add a read-only detector for `/etc/sysctl.d/99-bbr.conf` that checks both the relevant BBR keys and the absence of the managed marker.
2. During restore, if that unmanaged file contains BBR settings, report that it remains untouched and that `sysctl --system` may reapply BBR.
3. In status output, distinguish the managed BBR configuration from any detected unmanaged override.
4. Add an additive JSON field, such as `unmanaged_override_files`, to the `bbr` object. If no override is detected, use an empty array.
5. Do not write, remove, rename, or adopt `/etc/sysctl.d/99-bbr.conf`.

**Behavior change:** Restore continues to remove the script-managed BBR config and reset the live value before reapplying sysctls. The output now explains why BBR may remain active due to the separate unmanaged file.

**Interaction with existing flags:** `--with-bbr`, `--restore-defaults`, `--status`, `--status-json`, and `--dry-run` retain their existing configuration behavior. Only reporting changes.

**Risk:** Low. Detection is read-only and does not alter policy. The detector must not claim a file will override a setting unless it actually contains the relevant key and its load order is understood.

**Test cases:**

- **Positive:** With an unmanaged later BBR file present, status detects it and restore explicitly reports that it was preserved.
- **Negative:** With the file absent, or with no BBR settings in it, no override warning is emitted.
- **Ownership:** Confirm the unmanaged file remains byte-identical through normal runs, dry-runs, and restore.
- **Idempotent:** Repeated status runs report the same detected override without writes.

**Effort:** 1.0 hour.

## Non-Goals

v16 should deliberately avoid the following:

1. **No power-policy redesign.** Do not change the current PPD `performance` profile, active thermald service, inactive/masked TLP state, or the existing TLP gating and `--force-tlp-override` semantics.
2. **No RAPL policy changes.** Keep PL1 empty in the managed configuration and leave the firmware-locked 200 W value alone. Preserve the existing writable PL2=45 W behavior. Do not invent a PL1 value to make PL1 ≤ PL2.
3. **No battery-cap changes.** Keep the current 100% threshold and do not reinstall or enable the cap service by default.
4. **No automatic ASPM enable/disable policy.** Do not toggle global PCIe ASPM, move or delete the backup at `/root/vivobook-backups/modprobe/mt7921e.conf.disabled`, or auto-enable the legacy workaround. Retain the existing opt-in compatibility flag.
5. **No kernel, Secure Boot, or firmware changes.** Do not change the cappelikan PPA, apt pin, signing hook, MOK keys, kernel command line, BIOS, or firmware configuration. Do not change the supervised kernel-purge policy.
6. **No unrelated tuning or cleanup.** No `powertop --auto-tune`, blanket service disabling, new CPU/iGPU frequency clamps, NVMe scheduler rules, unmanaged sysctl changes, Bluetooth sink recreation, or broad USB/autosuspend redesign.
7. **No new persistent state for telemetry.** The additional status fields should be read-only observations. v16 should not create a new state file merely to remember observations or manufacture a baseline.
8. **No unsupported state inference.** Do not hard-code an unverified S0i3 path, equate SLP_S0 with S0i3, or report “applied” when a setting could not be applied.

## Testing Plan

Testing should be regression-safe and use a disposable Ubuntu test system or snapshot for destructive restore and configuration scenarios. The live target currently has working power management and a signed mainline kernel; `--restore-defaults` should not be run on it merely as a casual test.

### 1. Static checks

- Run `bash -n vivobook_optimize_v16.sh`.
- Run ShellCheck and review new warnings, particularly around `set -Eeuo pipefail`, subshells, heredocs, conditional returns, and sysfs write redirections.
- Check that every new or modified persistent file continues to use `atomic_write` and the established `mktemp → chmod → mv` path.
- Verify that `TMP_REGISTRY` and its EXIT cleanup trap remain intact.
- Verify that every new managed artifact carries a `Managed by vivobook_optimize` marker.
- Search for stale user-facing claims that `disable_aspm=1` is required or that omitting it necessarily risks Wi-Fi instability. Do not mechanically rewrite historical comments that describe earlier releases.
- Verify that the only new writes are the intended managed configuration changes. No status path should call a write-based RAPL probe.

### 2. Dry-run inspection

Run the relevant new and affected flag combinations with `--dry-run`. Confirm that dry-run:

- does not create or modify persistent files;
- accurately distinguishes a proposed file write from an already-correct no-op;
- does not report the ASPM workaround or audio configuration as applied when it was only simulated;
- does not perform the RAPL lock probe;
- shows the same ownership decisions as a real run;
- does not claim that an unmarked file will be removed;
- prints the final dry-run banner after all simulated actions.

Include `--dry-run --restore-defaults` in the test set, using disposable fixtures with managed and unmarked artifacts.

### 3. Idempotency verification

On a prepared test system, run the same v16 configuration twice. Capture hashes and timestamps for managed config files before and after the second run. Verify:

- byte-identical files are not replaced;
- file timestamps do not change on a true no-op;
- systemd services and timers are not restarted unnecessarily;
- a correct populated zRAM device is not detached;
- correct audio and MT7921E managed files do not churn;
- a read-only status run does not change configuration or runtime values.

The first v16 run may legitimately migrate a managed file whose desired content has changed. The second identical run must be a true no-op for those files.

### 4. `--restore-defaults` verification

Run in a disposable image/snapshot with representative managed and unmanaged fixtures.

Confirm that:

- managed units, helpers, sleep hooks, and configs are removed;
- units whose files are unmarked are not stopped or removed;
- unmarked USB, power, and NVMe rule files survive;
- the moved disabled ASPM backup is untouched;
- the battery threshold is restored to 100% wherever writable;
- zRAM detach behavior and failure warnings remain intact;
- managed RAPL artifacts are removed without inventing a replacement PL1/PL2 value;
- the BBR override warning appears when `/etc/sysctl.d/99-bbr.conf` would reapply the setting;
- files lacking the managed marker are preserved;
- no apt packages are removed by restore;
- every reported success corresponds to a real or accurately simulated result.

### 5. `--status-json` comparison against v15.3

Capture a v15.3 baseline in a disposable test environment, then capture v16 output for the same simulated system state. Normalize both with `jq -S` before diffing.

The expected differences are:

- `script.version` changes to `16.0`;
- `script.schema` changes from `2` to `3`;
- new package-C-state/audio fields are added;
- the read-only RAPL lock-state values become unknown (`null`) when not probed;
- the new BBR override field identifies the unmanaged override when present;
- `pc8_residency`, `pc10_residency`, `deep_pc_states_reached`, and `aspm_workaround_active` remain available.

All unrelated fields should retain their existing names and types. Do not treat a change from a probed lock Boolean to `null` as a RAPL configuration regression: it is the intentional consequence of making status read-only.

For the live reference machine, separately confirm that the reported values are consistent with the machine facts: battery 100%, PL2=45 W, current `disable_aspm=N`, PPD active, and S0ix counters as observed during the same measurement interval.

### 6. Per-flag positive and negative tests

| Area | Positive case | Negative case |
|---|---|---|
| `--safe-mode-check` | Required boot-integrity controls are correct and the ASPM workaround is absent; the gate passes | Missing signing hook or broken stock-kernel pin still fails |
| `--with-mt7921e-aspm` | Present driver and an eligible path create the managed config through `atomic_write` | No driver/module returns honest `UNSUPPORTED`; an unmarked config is preserved |
| `--pl2=45` | Writable PL2 applies while locked PL1 remains untouched | Missing RAPL interface returns `UNSUPPORTED`; dry-run does not claim an applied value |
| `--battery-limit=off` | Threshold is 100% and the service is absent; it remains a no-op apart from truthful reporting | Unwritable threshold produces an honest warning rather than a false success |
| Audio configuration | SOF is active and existing staged options are preserved; live/configured values are separately reported | Missing live parameter is reported unavailable; unmarked files remain untouched |
| `--with-auto-power` | AC/battery policy continues to select the existing EPP/thermal/Wi-Fi/audio values | Active TLP continues to block dynamic power switching |
| `--status` / `--status-json` | Values and JSON structure are reported successfully without writes | Missing diagnostic interfaces produce unknown/unavailable values instead of aborting |
| `--restore-defaults` | Managed artifacts are removed and user-managed files survive | Unmarked unit/config collision is reported and left alone |

### 7. Target-machine acceptance criteria

Before v16 is considered complete, the test record should demonstrate that:

- the missing ASPM workaround no longer causes a false critical reboot failure;
- PC6/PC8 and SLP_S0 are represented accurately when their interfaces are readable;
- the RAPL status paths perform no sysfs writes;
- audio settings are reported as staged versus live, and a normal SOF run does not discard the existing file;
- restore removes only owned artifacts;
- the unmanaged BBR override is preserved and its effect is explained;
- all existing functionality not explicitly listed in these changes remains unchanged.

## Rollback Plan

### `--restore-defaults`

C-01 through C-06 primarily modify script logic and status reporting; they do not introduce a new persistent state file. Restore must nonetheless clean up any managed artifact written through the existing feature flags.

- **MT7921E ASPM:** Remove `/etc/modprobe.d/mt7921e.conf` only if it is marked as script-managed. Do not touch `/root/vivobook-backups/modprobe/mt7921e.conf.disabled`.
- **Audio:** Remove `/etc/modprobe.d/audio-powersave.conf` only if it is marked as script-managed. Preserve an unmarked file.
- **Status telemetry:** No persistent file or sysfs cleanup is required.
- **BBR:** Remove the script-managed BBR artifacts, but leave `/etc/sysctl.d/99-bbr.conf` untouched. Report that this unmanaged file may reapply BBR.
- **Other script-managed services, helpers, and rules:** Apply the ownership-aware removal rules from C-05.
- **Battery and RAPL:** Retain the current restore semantics: return the battery threshold to 100% where writable; remove managed RAPL configuration without inventing a hardware baseline. Do not rewrite firmware-locked PL1.

### Downgrade to v15.3

A downgrade should not require removing all currently working configuration.

1. Back up the v16 script and record the current state of relevant managed files, service enablement, and the `--status-json` output.
2. Replace the v16 script file with the saved `vivobook_optimize_v15.3.sh`. Do not execute `--restore-defaults` as part of the downgrade, because doing so would remove managed configuration that may still be wanted.
3. Do not immediately rerun the full v15.3 apply pass. The old release still treats the missing ASPM workaround as a safe-mode failure; its SOF audio branch may also remove the audio file if it is marked as managed. Its root-run status paths still perform the RAPL write probe.
4. If v15.3 must be executed, first review the selected flags and current config ownership. In particular, do not pass `--with-mt7921e-aspm` unless deliberately re-enabling the legacy workaround. Use `--no-audio-powersave` when preserving the audio file is required, and avoid a full update/apply run unless that is intended.
5. Recheck the signed kernel, apt pin, PL2=45 W configuration, battery threshold, dynamic power-switch service, audio configuration, and ASPM state after replacement.

The main downgrade risk is not data loss from replacing the script file; it is executing v15.3 afterward and allowing its old behavior to alter the current configuration. Keep the original managed artifacts backed up until the v15.3 rollback state has been verified.

## Updated Header / Changelog

Replace the current top-level header and v15.3 release summary with the following text:

```bash
#!/usr/bin/env bash
#
# ASUS Vivobook 16 (X1605VA) — Optimization Pass v16.0
# i5-13420H (Raptor Lake-H, 4P+4E) / Intel UHD iGPU / 16GB DDR4 / Micron NVMe
#
# v16.0 — reference-baseline alignment and read-only diagnostics.
# Fixes: MT7902 ASPM workaround no longer required by safe-mode-check on the
# documented kernel 7.2.6 baseline; S0ix/package C-state status expanded;
# root-run status modes no longer write RAPL limit values to probe firmware
# locks; audio staged-versus-live values reported and staged options preserved
# on the SOF path; restore cleanup checks managed ownership before stopping or
# deleting artifacts; unmanaged BBR sysctl overrides are reported, not changed.
# JSON schema 3: retain v15.3 keys where possible and add audio, package-C-state,
# and unmanaged-BBR-override telemetry. Read-only RAPL lock state is unknown
# unless a mutating configuration path explicitly probes it.
#
```

Also make these exact version/usage edits:

```bash
SCRIPT_VERSION="16.0"
SCRIPT_SCHEMA=3
```

Replace the existing `--with-mt7921e-aspm` usage description with:

```text
#   sudo bash __SCRIPT_NAME__ --with-mt7921e-aspm                opt in to the legacy MediaTek MT7902 (mt7921e)
#                                                                ASPM workaround. Not required by the documented
#                                                                kernel 7.2.6 reference baseline. Can suppress deep
#                                                                package-idle states; use only for a diagnosed
#                                                                Wi-Fi issue. Needs a reboot. Unmanaged files
#                                                                are never overwritten.
```

Replace the `--safe-mode-check` usage description with:

```text
#   bash __SCRIPT_NAME__ --safe-mode-check                       read-only boot-integrity gate. Checks kernel
#                                                                signing hook, stock-kernel apt pin, running-kernel
#                                                                signature and Secure Boot. MT7921E ASPM state is
#                                                                informational, not a reboot prerequisite on the
#                                                                documented kernel 7.2.6 baseline.
```

Update the user-facing version strings in status, restore, and safe-mode banners to v16.0. For generated managed-file headers, update the version tag when that file's content is already being changed by v16; do not rewrite unrelated files solely to change historical comments. This avoids unnecessary config churn and preserves atomic-write no-op behavior after the first v16 run.

## Open Questions

The design can proceed without blocking clarification, but three details should be verified during implementation:

1. **S0i3 source:** The facts document gives an S0i3 counter but not the exact kernel interface or command that produced it. The implementation should identify and test the actual read-only source on the target. Until then, v16 should report S0i3 as unavailable rather than infer it from SLP_S0.
2. **Audio config ownership:** The facts document does not say whether `/etc/modprobe.d/audio-powersave.conf` currently contains the managed marker. v16 should handle both cases safely: preserve it during the SOF path, but remove it during restore only if the marker establishes script ownership.
3. **Dynamic audio policy:** This proposal preserves the existing `--with-auto-power` behavior of setting live `power_save` to 0 on AC and 1 on battery. Consequently, the staged value of 10 is not a promise that the live value will stay at 10 while that service is controlling the parameter. Changing that policy should be a separate, explicit decision rather than being bundled into v16.

## Recommended Next Round Deliverable

If this specification is approved, the next round should produce an **implementation-ready unified diff against `vivobook_optimize_v15.3.sh`**, limited to C-01 through C-06. It should include precise insertion points, preserve existing function and flag structure, retain all managed-marker and atomic-write conventions, and include a regression command matrix for `--dry-run`, `--status`, `--status-json`, `--safe-mode-check`, `--restore-defaults`, and idempotent reruns.

The diff should be reviewed against the current machine facts before being applied. A complete replacement script should be generated only if needed after the incremental diff has been validated.
