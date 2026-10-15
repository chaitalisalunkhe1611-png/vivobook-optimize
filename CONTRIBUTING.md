# Contributing

Keep patches scoped and reversibly managed. Preserve existing CLI flags/defaults
and schema-3 keys; use additive keys unless a documented schema bump is needed.
Never delete or overwrite administrator-owned files by inference from a filename.
Use `atomic_write`, managed markers, TLP gates, honest status and a restore path
for every new artifact. Generated helpers need syntax/ShellCheck coverage too.

Run `bash tests/smoke.sh` (development dependencies: Bash, shellcheck, jq).
After editing the canonical `vivobook_optimize.sh`, refresh its identical
`vivobook_optimize_v16.1.sh` release copy, CLI help and unified release patch.
Document hardware-only checks separately; do not represent fixture tests as a
real suspend/USB/firmware test. Do not run apply paths in CI.

Submit small, explained pull requests with test outputs. Redact all machine/user
identifiers from issues, commits and logs. Never add signing keys or system backups.
