# Add the Mission Control tools CLI

## Why

About 16 repositories keep a copy of `scripts/openspec-ext.mbtx` and compile it with their own MoonBit toolchain. Each copy imports `moonbitlang/async`, `moonbitlang/x`, `yaml`, `moonspec` and `expect`, so each toolchain move can break every consumer. Now `moonspec` 0.11.0 blocks the move to MoonBit 0.10.20 (bead moonbase-tqc). A released binary removes this coupling: Mission Control builds and tests the commands one time for each release, and a consumer pins a version and a checksum.

On 2026-11-07 Damian decided that the OpenSpec commands do not go into the main `mission-control` CLI. They go into a separate tools CLI.

## What Changes

- Add the module `moonrockz/mission-control-tools` in `apps/tools`. It builds the executable `mission-control-tools`. The commands are in groups; the first group is `openspec`.
- Add `mission-control-tools openspec check`, `setup` and `install`. `check` and `setup` keep the behavior, the exit codes (0, 1, 2) and the problem messages of `scripts/openspec-ext.mbtx`. Each command takes an optional repository path.
- Add `mission-control-tools openspec check --bundle`. It also compares the repository with the bundle in the binary and with the tool version in the lock.
- Add `--json` to `openspec check` and to `version`, for agents and CI.
- **BREAKING** (for consumers): the bundle no longer manages `scripts/openspec-ext.mbtx` and `scripts/features/openspec_ext.feature`. The schema, the templates, `LICENSE` and `NOTICE` stay in each consumer under `openspec/schemas/html-design/`, under the lock.
- **BREAKING** (for consumers): the lock changes to format 2. It records the tool module and the tool version. `install` reads a format 1 lock, removes the two retired files when they are not edited, and writes format 2.
- Move the setup step from the script into the binary. It still runs `openspec init` with an isolated configuration directory.
- Remove `apps/openspec-ext/cmd`. `moonrockz/openspec-ext` stays a library (the bundle and the host I/O). The tools CLI is its only command.
- Release the tools CLI separately from the main CLI: its own version, the tag family `tools-vX.Y.Z`, five native archives and `checksums.txt`, and a GitHub workflow that has a dry run. The release notes give the exact mise `[tools]` entry, with a checksum for each platform. Windows arm64 uses the Windows x64 archive.
- Exclude `apps/tools` from the shared workspace version. `scripts/versions.mbtx` checks and sets the tools version as a second version family.
- Migrate Mission Control itself: its `openspec:*` tasks run the tools CLI from source, and its lock moves to format 2.
- Document the consumer migration in `apps/tools/README.md`.

Out of scope:

- Changes in consumer repositories. This change documents the steps and proves them in a scratch clone of finos/morphir only.
- Changes to the main `mission-control` CLI, its release assets or its version.
- Publication of `moonrockz/mission-control-tools` to mooncakes.io. The binary is the distribution.
- Artifact attestations. The main release has none; the tools release matches it.
- A wasm build of the tools CLI. `moonbitlang/async` file and process support needs a native host.

## Capabilities

### New Capabilities

- `tools/openspec-commands`: The `openspec` commands of the tools CLI: snapshot and bundle checks, installation, agent setup, JSON reports and exit codes.
- `tools/distribution`: The separate release of the tools CLI: version family, tags, assets, checksums and the consumer mise entry.

### Modified Capabilities

- `openspec-extensions`: The managed set no longer contains the script and its feature; the lock records the tool version; install retires files that leave the managed set. This capability is added by the open change `add-openspec-extensions`. Archive that change before this one.
- `tooling/release`: The shared version applies to every workspace module except the tools CLI.

## Tracking

Bead moonbase-4ca tracks the work. The MoonBit 0.10.20 move (moonbase-tqc) stays separate; this change removes one of its blockers for consumers.

## Impact

- New module `moonrockz/mission-control-tools` (not published to mooncakes.io; released as binaries).
- Changed module `moonrockz/openspec-ext`: the bundle loses two files, the lock format changes, `cmd` is removed, and `host` gains the snapshot check, the retirement step and the setup process.
- Not changed: `moonrockz/mission-control-cli`, `moonrockz/mission-control-contracts`, `moonrockz/mdc`, `moonrockz/ears`, `moonrockz/okf`, `moonrockz/mission-control-web`, `moonrockz/mission-control-desktop`.
- New workflow `.github/workflows/release-tools.yml`, new script `scripts/release-tools.mbtx`, and changes to `scripts/dist.mbtx`, `scripts/versions.mbtx`, `.config/mise/config.toml` and the Mission Control lock. No new job in CI or in the merge queue.
- Consumers: a mise tool entry replaces the script, its feature, its tests and the MoonBit compile in `openspec:verify`.
