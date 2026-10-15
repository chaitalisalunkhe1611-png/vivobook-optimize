# Sandbox test results — v16.1

Executed in this checkout on 2026-10-15. The sandbox is not the X1605VA and is
not an Ubuntu-26.04 laptop/systemd hardware validation environment. Only host
read-only commands, print-only dry-runs and redirected private-tree fixture
mutations were run. No actual optimizer apply/restore or cleanup --apply was run.

ShellCheck was initially absent; installed **shellcheck-py 0.11.0.1** into an
external development virtual environment. The bundled ShellCheck reports 0.11.0.
No runtime dependency was added to the optimization script or repository.

## Syntax and lint output

```text
$ bash --version (first line)
GNU bash, version 5.2.15(1)-release (x86_64-pc-linux-gnu)
$ shellcheck --version
ShellCheck - shell script analysis tool
version: 0.11.0
license: GNU General Public License, version 3
website: https://www.shellcheck.net
$ jq --version
jq-1.6

$ for file in project shell scripts; do bash -n "$file"; done
PASS bash -n vivobook_optimize.sh
PASS bash -n vivobook_optimize_v16.1.sh
PASS bash -n tools/cleanup-v16.0-drift.sh
PASS bash -n tests/smoke.sh
PASS bash -n tests/regression.sh

$ shellcheck vivobook_optimize.sh vivobook_optimize_v16.1.sh tools/*.sh tests/*.sh
shellcheck exit=0 (no diagnostics)
cmp canonical/versioned exit=0
```

Every project script, including the versioned release copy, was syntax checked
individually. ShellCheck had no diagnostics after fixes/justified annotations.
`.shellcheckrc` suppresses only two inherited style notes (SC2001/SC2143), with
reasons; it does not suppress correctness warnings. Optional host config uses
source=/dev/null annotations; the deferred ERR trap and indirect fixture mocks
have local documented suppressions. The original attached v16.0 is unchanged
and is not represented as passing this release's lint checks.

## Actual smoke/regression output

```text
PASS bash -n (all project shell scripts)
PASS shellcheck
PASS --help
vivobook_optimize.sh version 16.1 (JSON schema 3)
PASS --status
PASS --status-json | jq . and schema-3 additive keys
PASS A-01 migration, exact deduplication, repeat-run identity, restore preserves custom data
PASS A-01 unowned/conflicting destination refuses migration without source loss
PASS A-03 all four frequency names and fallback after invalid cur_freq
PASS A-07 offline first supply, all four online types, offline/unknown states
PASS A-04 staged timeout parsing, fallback, enabled override, controller-only mismatch
PASS A-06 target-only cleanup, custom flags preserved, installed pinned Brave unchanged
PASS A-04/A-05 generated helper and guarded hook: bash -n + shellcheck
PASS A-03/A-07 dashboard and JSON callers use current-frequency/power helpers
PASS A-08 legacy thermal choices and present keyboard without stop_time keys
PASS A-08 orphan cleanup without unit/battery sysfs, unowned helper preserved
PASS A-03 current telemetry independent of max-frequency availability
PASS A-05 generated hook: disabled post and enabled pre do not restart; enabled post restarts
PASS ownership qualification: default cleanup preserves unmarked legacy-looking i915 config
PASS A-01 atomic_write refuses partial stdin in conditional/restore context
PASS A-01/A-08 ownership: symlink to a marked file is preserved
PASS A-08 live threshold reset after discovery
PASS cleanup --help / --dry-run
PASS smoke tests (hardware mutation intentionally not tested)
```

The fixture regressions extract pre-dispatch definitions into a temporary tree,
redirect literal host paths, and mock systemctl. They validate both status
callers as well as shared helpers. Generated power-switch script and resume
hook are syntax checked and linted; the hook is run only against an inert mock.
Fixture paths are not assertions about real hardware paths.

## Read-only and dry-run exit codes

```text
status exit=0
status-json exit=0
jq . exit=0
default dry-run exit=0
opt-in dry-run exit=0
restore dry-run exit=0
safe-mode-check exit=1 (expected missing laptop boot prerequisites)
```

Commands run for the dry-runs:

```bash
bash vivobook_optimize.sh --dry-run --skip-update
bash vivobook_optimize.sh --dry-run --skip-update --with-auto-power --with-usb-autosuspend --with-browser-wayland --battery-limit=off
bash vivobook_optimize.sh --dry-run --restore-defaults
```

All three completed with the final no-files-modified banner. Some host hardware
branches are unavailable and skip; an exit-0 dry-run is not proof they work on
ASUS hardware. The opt-in dry-run emitted the generated dynamic helper and hook.

The extra read-only `--safe-mode-check` returned **1**, not a pass. The sandbox
lacks the reference signing hook, apt pin and readable laptop boot images/Secure
Boot setup. Its complete output is retained; no attempt was made to fabricate
or install those prerequisites.

## Complete captured outputs

- [Full --help](CLI-HELP.txt)
- [--version](test-output/version.txt)
- [--status](test-output/status.txt), [stderr](test-output/status.stderr.txt)
- [--status-json](test-output/status.json), [stderr](test-output/status-json.stderr.txt)
- [Default dry-run](test-output/dry-run-default.txt)
- [Opt-in dry-run](test-output/dry-run-opt-ins.txt)
- [Restore dry-run](test-output/dry-run-restore.txt)
- [Boot gate (expected failure here)](test-output/safe-mode-check.txt)

Personal home paths in recorded output are replaced with `/home/<user>`.
The JSON was validated with `jq .` before redaction and parsed again afterward.
GitHub-hosted CI was created but **not executed here**. USB udev parser/runtime,
actual laptop AC/USB-PD/suspend, firmware RAPL acceptance, package changes,
cleanup backups/interactive apply and real restore remain hardware/operator checks.

## Baseline integrity

Attached v16.0 SHA-256 (also compared byte-for-byte with the checkout's original):

```text
0a0ac4326fe6395065d98808a28dca081dfd88dde7a7a4d914d45b1c22bda64b  vivobook_optimize_v16.sh
```

[Integrity checks](test-output/integrity.txt) confirm exact patch reconstruction,
unchanged CLI defaults/parser and the known-identifier privacy scan.
The complete release patch was applied in a private temporary directory;
canonical/versioned script copies match byte-for-byte. No commit, tag, push or
remote release was made.
