# Changelog of mission-control-tools

The tools CLI has its own version and its own tags (`tools-vX.Y.Z`). A section `## [X.Y.Z] - YYYY-MM-DD`
with its highlights written releases that version when it reaches main (see `apps/tools/README.md`).

## [Unreleased]

- `openspec setup` accepts OpenSpec 1.16.x as well as 1.14.3. Other versions get
  `Setup requires OpenSpec 1.14.3 or 1.16.x`.

## [0.1.0] - 2026-11-07

The first release of `mission-control-tools`. It carries the shared OpenSpec commands, so a consumer
pins one checksummed binary with mise and no longer compiles its own copy of `scripts/openspec-ext.mbtx`.

- `openspec check` keeps the checks, messages and exit codes of the script. `openspec check --bundle`
  also checks that the lock records this tool version and that the files match this binary.
- `openspec install` installs the `html-design` bundle and writes lock format 2. It deletes an unedited
  script copy and its feature, and refuses an edited one before it writes anything.
- `openspec setup` regenerates the core agent skills with isolated OpenSpec preferences.
- `--json` for `check` and `version`.
- Five native archives with `checksums.txt` and GitHub build provenance attestations. Windows on Arm uses
  the x64 archive. The mise entry, the attestation check and the migration steps are in
  `apps/tools/README.md`.
