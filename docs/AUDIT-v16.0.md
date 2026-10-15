# v16.0 audit — cleaned source record

Source: the supplied audit of `vivobook_optimize_v16.sh` (v16.0, schema 3),
referencing the supplied X1605VA state on 2026-10-10. Original line numbers were
inaccurate. The complete original prose is retained, privacy-redacted, in
[`../audit .md`](../audit%20.md). This document organizes its findings and plan;
**the historical patch proposals are not instructions to run unreviewed**.
See [PATCH-REVIEW.md](PATCH-REVIEW.md) for verified locations and corrections.

## Context claimed by the audit

The reference machine uses mainline 7.2.6-070206-generic, xe bound to
8086:a7a8, PL2=45 W with firmware-locked PL1=200 W, no charge cap, and native
mt7921e ASPM after removing disable_aspm=1. PC6/PC8/S0i3 and SLP_S0 are reported
working with zero Wi-Fi errors since boot. These are source observations only.

## Eight findings

| ID | Audit severity | Claim and root cause |
|---|---|---|
| A-01 | Critical | Step 11 rewrites all of `99-vivobook.conf` with four managed keys and loses hand-added IPv6 disablement/custom keys. A different version header ensures differing content but is not the underlying cause. |
| A-02 | High | USB exemptions match interface add only, not driver bind. Audit attributes webcam/BT `auto` to drivers enabling autosuspend after addition. |
| A-03 | High | Both status readers check only i915 current-frequency names even though max/RP0 discovery supports xe. |
| A-04 | Medium | Audio verdict says a staged/live mismatch will resolve at reload, while enabled auto-power continually writes 0 on AC and 1 on battery. |
| A-05 | Medium | Dynamic power-switch has no resume hook; guarded disabled static hooks cannot restore dynamic policy after s2idle. |
| A-06 | Medium | Browser installation checks skip uninstalled Chrome/Chromium without cleaning their older managed flags. |
| A-07 | Low | Dashboard/JSON inspect AC*/ADP* names and break on the first node; generated helper already scans power types including USB_PD. (The source table row was truncated; this reconstructs the prose intent.) |
| A-08 | Low | Duplicate battery hook status, battery-off cleanup nested under unit existence, and missing nullable thermal/VA-API/keyboard JSON keys. |

## Original proposed patch plan

1. Extract non-managed `key=value` lines from `99-vivobook.conf` to
   `90-vivobook-local.conf` before apply **and restore**. Exclude
   vm.swappiness, fs.inotify.max_user_watches, kernel.nmi_watchdog and
   vm.dirty_writeback_centisecs; normalize optional leading `-` and slash keys.
   Append only lines not already in the destination, using `atomic_write <<<`.
2. Use `ACTION=="add|bind"` on usb_interface rules for classes 03/e0/01/0e,
   `TEST=="../power/control"` and `ATTR{../power/control}="on"`. Replay add and bind.
3. Add xe `cur_freq` and `act_freq` fallbacks in both human and JSON readers.
4. Use staged positive audio timeout on battery (default 1), still 0 on AC;
   report `overridden-by-auto-power` for enabled dynamic-policy mismatches.
5. Add `vivobook-power-switch:vivobook-power-switch.service` to hook pairs,
   generate the shared guarded hook in step 19, and include it in restore.
6. The audit suggested calling `restore_browser_flags_for_user` when **one**
   uninstalled browser has a managed flags file. This is rejected: it would
   strip managed flags from installed browsers too. Use single-file cleanup.
7. Share power-input detection among all callers; remove owned battery artifacts
   independently of unit existence; remove duplicate status lines and add the
   missing null keys without renaming schema-3 keys.

### Issues with the proposed migration

The proposal did not guard ownership of the destination, deduplicated only
against the old on-disk file, did not resolve conflicting key values, and did
not specify a reversible migration lifecycle. v16.1 improves all four points.
A 90-* file sorts before 99-vivobook.conf. It must not contain the four managed
keys; later unrelated administrator files can still override custom values.

### Issues with the proposed USB replay

Both patterns are valid alternatives in udev match syntax. Interface sysfs paths
are children of their USB device, so `../power/control` targets device runtime
PM, not just interface runtime PM. Replay must settle add before bind, otherwise
a delayed device add rule can undo interface exemptions. Actual driver timing
and the machine's installed udev rules still require hardware verification.

## Historical drift cleanup plan (superseded by the safer tool)

The original plan listed:
- Hand-copy IPv6 lines into `90-ipv6-disable.conf`.
- Delete unmanaged duplicate `99-bbr.conf` while keeping `98-network-bbr.conf`.
- Delete stale Chrome/Chromium flags; only Brave is reported installed.
- Disable/remove the three static battery, thermal and EPP units, their hooks,
  defaults files and helper scripts.
- Remove the older installed `vivobook_optimize_v15.3.sh` binary.

Do **not** use unconditional `rm` or overwrite a 90-* file. Instead use
[`tools/cleanup-v16.0-drift.sh`](../tools/cleanup-v16.0-drift.sh), which defaults
to dry-run, verifies eligibility, backs up every removal and requires interactive
confirmation. Use v16.1's migration rather than the historical `grep | tee` step.

## Audit Step 2 — reference defaults

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

The commented version is [`config/defaults.conf.example`](../config/defaults.conf.example).
This example is not the script's default policy and omits BATTERY_LIMIT; omission
does not remove an earlier cap. Use `--battery-limit=off` explicitly.

## Audit Step 3 — rapid pass and checks

After reviewing the defaults and dry-run on the laptop:

```bash
sudo bash vivobook_optimize.sh --skip-update
sudo bash vivobook_optimize.sh --safe-mode-check
sudo bash vivobook_optimize.sh --status
```

`--skip-update` skips only steps 1–3, not all package operations. The boot gate is
specific to the supplied custom-kernel signing setup, not a universal guarantee.
