# Verify-before-patching review: v16.0 → v16.1

All three attached source files were read. The v16.0 source, not the audit's
snippets/line numbers, defines the baseline. Locations below refer to the
**unmodified attached 6,458-line v16.0**. No hardware findings are claimed to
have been independently reproduced in this sandbox.

| ID | Real v16.0 location | Confirmed root cause (and correction) |
|---|---|---|
| A-01 | Step 11, 4692–4748; restore at 1745 | Whole-file replacement writes just four managed keys, regardless of custom assignments. Header version change is incidental: differing custom content is enough. Preserve assignments before rewriting/removing an owned source. |
| A-02 | Step 17b, 5627–5655 | All four interface exemptions match only add. No bind event can enforce the policy after a driver changes runtime PM; driver-specific causation is plausible, not proven by the snapshot. Use add-or-bind with settled replays. |
| A-03 | Dashboard 2372–2376; JSON 3151–3155 | Current-frequency readers only know i915 names, unlike existing xe max-frequency discovery. One reader now checks both i915 names and xe cur_freq/act_freq, even if maximum-frequency discovery fails. |
| A-04 | audio_staged_verdict 987–1010; dashboard 2530–2548; power helper 5921–5937 | Mismatch verdict ignores enabled dynamic policy, whose battery path always forces 1. Share parsed HDA options, use staged positive timeout on battery and label dynamic power_save overrides. |
| A-05 | Hook pairs 1016–1021; step 19 5687–6022; restore owned list 1699–1723 | No dynamic sleep hook is registered, generated or restored. Add it to the shared lifecycle, generate via sleep_hook_body, and guard restart with is-enabled. |
| A-06 | apply_browser_flags_for_user 1566–1569 | Uninstalled-browser branch only increments a count and continues. Move the existing per-file restore logic into a shared helper and apply it to that target alone. |
| A-07 | Dashboard 2829–2837; JSON 3511–3517; generated helper 5739–5754 | Human/JSON use AC*/ADP* filenames and stop at the first; generated helper already checks types. Use one type-scanning helper for every caller. |
| A-08 | Duplicate 2152–2157; battery-off 4944–4965; JSON 3028–3034, 3220–3222, 3531–3540 | Battery hook is printed twice; deletion depends on unit (and outer hardware-node) existence; optional JSON branches omit keys. Remove duplicate block, clean each owned artifact independently, add null keys. |

## Improvements over the proposed patch

### A-01 — ownership, ordering and reversibility

- `atomic_write` consumes standard input with `cat > "$tmp"`; **a here-string is
  valid** and keeps TMP_REGISTRY in the parent shell. Migration passes content
  without an extra trailing newline, preserving byte-identical re-run behavior.
- Critical atomic-write preparation now explicitly returns failure, because
  restore is called in a conditional context where Bash suppresses errexit; a
  failed input copy must not install partial migrated data.
- Lexical order is **90-vivobook-local.conf before 99-vivobook.conf**. Only
  non-core assignments are migrated; the four exact managed keys are excluded.
  The migration file created by this release therefore has no explicit core-key
  duplicates. Wildcards/other administrator files are not a promise of conflict
  freedom: later sysctl definitions can override earlier ones, so inspect the
  merged configuration and live readings on the laptop.
- The audit's `grep ... "$dest"` only checks the preexisting file. This version
  checks accumulating output too, so identical repeated source lines do not
  duplicate. Different lines for the same normalized key conservatively fail
  instead of choosing a winner. Existing unowned destination/symlinks fail closed;
  an unowned source is not overwritten by step 11.
- Migration is called before restore removes the owned source too. Restore then
  returns custom data to the original path **without a managed marker** and
  removes the new migration file. Leaving the 90 file forever violates the new-
  artifact restore requirement; deleting it without returning data loses IPv6
  policy. Occupied original path causes preservation/failure, not overwriting.
- A migration error protects the source and stops step 11. Earlier steps of a
  normal full run may already have executed; this is not a whole-run transaction.

### A-02 — valid rule syntax, but hardware causation is unproven

- `ACTION=="add|bind"` uses udev's alternative match patterns; usb_interface
  objects receive driver bind events and have bInterfaceClass.
- `TEST=="../power/control"` resolves relative to the interface's **real syspath**;
  its parent is the USB device. `ATTR{../power/control}="on"` writes that parent's
  runtime-PM control. It is not relative to the `/sys/bus/usb/devices` symlink directory.
- Cross-checked against upstream systemd `src/udev/udev-rules.c`: match values
  split into alternatives; TK_M_TEST prefixes a relative path with syspath;
  attribute assignment resolves the sysfs path before writing. Parser/runtime
  verification with the installed target version remains a hardware checklist item.
- The audit did not settle replay ordering. v16.1 settles add events **before**
  triggering interface-only bind and settles again afterward. That prevents an
  outstanding default device-add rule from undoing the final interface exemption.
- Other managers/rules can still override PM. No blanket claim that btusb/uvcvideo
  caused every mismatch, nor that these rules defeat all later writers.

### A-03 — shared reader and real fallbacks

Both outputs share the reader rather than duplicating the audit's conditional
chain. A failed/empty/non-numeric current node falls through to the next name,
including act_freq. Current discovery is independent of max/RP0 availability.
Unreadable or absent data remains unknown/null honestly, not a made-up clock.

### A-04/A-05 — dynamic ownership and hook lifecycle

- The audit's greedy sed could match another module's power_save. Use the
  existing HDA-only parser, last option wins; strip leading zeroes and bound a
  positive value to int32, otherwise retain the historical battery fallback 1.
- Only a power_save mismatch is labeled dynamic; power_save_controller-only
  mismatches remain a separate module-load mismatch (auto-power does not write it).
- `declare -f` embeds the **same** power/audio helpers in the generated script;
  no second copy can drift, and no extra library file/dependency is installed.
- The fifth resume hook is generated via the existing guarded body, registered
  in SLEEP_HOOK_PAIRS and owned restore list, and does not replace an unmarked hook.

### A-06 — reject the proposed whole-user restore

Calling restore_browser_flags_for_user when Chrome is absent would strip Brave's
managed flags too, and the loop might not subsequently re-add them. A single-
file shared restore preserves user tokens and cleans only the absent browser,
including Snap Chromium. Unmarked/pinned files are preserved.

### A-07/A-08 — consistency without renames

- `is_external_power_online` returns 0 for any recognized input online, 1 when
  readable recognized inputs are offline, 2 when none are usable. Dashboard
  retains yes/no/unknown and JSON retains string 1/0/unknown. The power helper
  retains its historical battery fallback when power state is unknown.
- Battery-off cleanup is outside hardware discovery and uses restore_unit_owned
  / restore_remove_owned independently, still respecting TLP ownership. No
  unmarked unit is disabled and no unmarked artifact is removed by this fix.
- Thermal `choices`, VA-API `driver_version`, keyboard `brightness` and
  `stop_time` exist in every relevant optional branch. No key is renamed;
  schema remains 3. The new sleep-hook entry is additive.

## Scope and assumptions

Assumption: the explicit no-unowned-deletion safety rule takes precedence over
retaining two unsafe inherited default-cleanup operations. Step 5 now uses
restore_unit_owned for powertop-autotune; default i915 cleanup preserves an
unmarked legacy-looking config (its inherited matcher requires explicit restore).
The shared ownership predicate also rejects symlinks to marked files: the link
itself is not proof of script ownership. These are ownership guards, not
additional tuning changes.

Script flag names, validation/default assignments and pre-root dispatch are
unchanged; tuning outside A-01..A-08 is not redesigned. Version/header changes
and justified lint annotations accompany the fixes. Existing legacy-adoption
rules are retained, rather than broadly refactoring inherited cleanup policy.
The separate one-time tool is stricter and requires opt-in for the known
unmanaged BBR duplicate.

Assumption for conflicting snapshot claims: the battery hook may be orphaned;
inspect on disk and require ownership, never delete based on the snapshot.
No remote repository, release, tag or push was created.
