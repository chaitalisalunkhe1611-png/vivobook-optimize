# Changelog

All notable changes are documented here, following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Release tag convention: `v16.1.0`; the script reports `16.1`. JSON schema stays **3**.

## [16.1.0] - 2026-10-15

### Fixed
- **A-01:** Preserve custom assignments before rewriting owned `99-vivobook.conf`;
  migrate to owned `90-vivobook-local.conf`, deduplicate accumulated lines,
  refuse unowned destinations/key conflicts, and return custom data to an
  unmarked original file on restore. Preserve an unowned source on apply.
- **A-02:** USB interface exemptions now match `add|bind`. Settle the add replay
  before replaying interface bind events to avoid default-device-rule races.
- **A-03:** Shared current-frequency reader supports `rps_cur_freq_mhz`,
  `gt_cur_freq_mhz`, `cur_freq`, and `act_freq` in dashboard and JSON, with fallback.
- **A-04:** Report dynamic HDA overrides honestly; honour a staged positive HDA
  battery timeout instead of always forcing 1. Controller-only mismatch remains
  a module-load mismatch, not falsely attributed to dynamic power policy.
- **A-05:** Add the enabled-service-guarded `vivobook-power-switch` resume hook;
  include it in refresh/status/JSON/restore lifecycle, preserving an unowned hook.
- **A-06:** Clean stale managed flags only for the uninstalled browser (including
  Snap Chromium), retaining unrelated user flags and installed browsers' settings.
- **A-07:** One shared external-power helper handles Mains/USB/USB_PD/USB_C across
  dashboard, JSON and generated helper; an offline first supply no longer wins.
- **A-08:** Remove duplicate battery hook output; clean owned orphan artifacts
  even without the unit or battery sysfs; add missing nullable JSON keys.

### Safety qualification
- To meet the no-unowned-deletion hard rule, guard two inherited default cleanup
  paths: only owned powertop-autotune units are stopped/removed; an unmarked
  legacy-looking i915 config is preserved unless restore is explicitly requested.
  No additional tuning flags, values or policies are introduced.

### Added
- Documentation, commented audit baseline config, opt-in backed-up drift cleanup,
  read-only smoke tests, private-tree regressions and ShellCheck CI.
- Versioned standalone release copy and a unified v16.0-to-v16.1 patch.

## [16.0] - 2026-10-10

### Changed
- Drift-correction baseline described by the supplied script/audit: bound DRM
  driver reporting, read-only status RAPL telemetry, guarded static sleep hooks,
  ownership-aware restore and staged-versus-live audio reporting.
- Schema 3 adds hardware/boot/ASPM/residency telemetry. mt7921e ASPM disablement
  is an optional instability workaround, not a required boot-safety gate.

The v16.0 date is the supplied snapshot date, not a verified upstream release date.
