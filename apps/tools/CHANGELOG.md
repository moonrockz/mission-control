# Changelog of mission-control-tools

The tools CLI has its own version and its own tags (`tools-vX.Y.Z`). A section `## [X.Y.Z] - YYYY-MM-DD`
with its highlights written releases that version when it reaches main (see `apps/tools/README.md`).

## [Unreleased]

`openspec setup` now works in repositories that pin OpenSpec 2.2. Before, it accepted only 1.14.3 and
1.16.x. OpenSpec 2.2.0 was tested with the managed `html-design` files. The managed files and
`openspec check` do not change.

- `openspec setup` accepts OpenSpec 1.14.3, each 1.16 patch release (1.16.x) and each 2.2 patch release
  (2.2.x). Other versions get `Setup requires OpenSpec 1.14.3, 1.16.x or 2.2.x`.
- For OpenSpec 2, setup runs `openspec init --scope project`, so the skills stay in the repository and
  are not installed in your home directory. For OpenSpec 1 the command does not change.
- With OpenSpec 2.2, setup writes the OpenSpec 2 skill layout: one copy of each skill in
  `.agents/skills/`, links in `.claude/skills/` and `.grok/skills/`, and the `openspec` router skill.
  OpenSpec removes the copies it generated in `.cursor/`, `.gemini/`, `.github/` and `.opencode/`.
  Commit the new layout.
- Move the consumer mise pins to OpenSpec 2.2.0 and tools 0.1.3, then run
  `mission-control-tools openspec install`, `mise run openspec:setup` and `mise run openspec:verify`.

## [0.1.2] - 2026-11-09

The shared html-design bundle now guides authors through a concrete user or system journey. A running
example connects the constraints, choices and reasons, with diagrams and failure/recovery paths where
they help the reader. Small changes stay brief, and requirements and scenarios remain precise.

- Proposal, spec and design instructions and templates include the narrative guidance. New capability
  examples stay under Purpose so they survive archive. Existing designs are not rewritten.
- Managed snapshots use LF checkouts on Windows, preserving the hashes recorded by the installer.
- Move the consumer mise pin to 0.1.2, then run `mission-control-tools openspec install` and the bundle
  check. CLI commands, supported OpenSpec versions and lock format 2 stay the same.

## [0.1.1] - 2026-11-07

`openspec setup` now works in repositories that pin OpenSpec 1.16. Before, it accepted only 1.14.3,
so `mise run openspec:setup` stopped in finos/morphir-gleam (1.16.1) and finos/morphir-scala (1.16.0).
OpenSpec 1.16.0 and 1.16.1 were tested with the managed `html-design` files. The managed files and
`openspec check` do not change. After you move the mise entry to 0.1.1, run
`mission-control-tools openspec install`, so that the lock records 0.1.1 and `check --bundle` passes.

- `openspec setup` accepts OpenSpec 1.14.3 and each 1.16 patch release (1.16.x). Other versions get
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
