# tools/distribution Specification

## Purpose
Release the tools CLI on its own schedule, as native binaries with checksums, so that a consumer can pin an exact version with mise and verify each download.

## Requirements

### Requirement: Own version family
The tools CLI SHALL take its version from `apps/tools/moon.mod`, independently of the workspace version, and the version script SHALL fail when the version text in the tools CLI or the version in the Mission Control extension lock differs from that version.

#### Scenario: Workspace release
- **WHEN** a maintainer sets the workspace version to 0.2.0
- **THEN** the version of `apps/tools/moon.mod` does not change

#### Scenario: Stale version text
- **WHEN** `apps/tools/moon.mod` is 0.2.0 and the version text in the tools CLI is 0.1.0
- **THEN** `mise run validate:versions` names the file and fails

### Requirement: Tag family
WHEN the tools release workflow releases version X.Y.Z, the tools release workflow SHALL create the tag `tools-vX.Y.Z` and a GitHub release with that tag, and SHALL NOT create, move or read a `vX.Y.Z` tag of the main CLI.

#### Scenario: Different versions
- **WHEN** the main CLI is 0.1.0 and the tools CLI releases 0.1.0
- **THEN** the tags `v0.1.0` and `tools-v0.1.0` are separate and each release has only its own assets

### Requirement: Release assets
A tools release SHALL hold exactly `mission-control-tools-linux-x64.tar.gz`, `mission-control-tools-linux-arm64.tar.gz`, `mission-control-tools-darwin-arm64.tar.gz`, `mission-control-tools-darwin-x64.tar.gz`, `mission-control-tools-windows-x64.zip` and `checksums.txt`, with the executable at the root of each archive and the SHA-256 of each archive in `checksums.txt`.

#### Scenario: Verify a download
- **WHEN** a user downloads the six assets and runs `sha256sum -c checksums.txt`
- **THEN** each archive reports OK

### Requirement: Windows build host
The tools release SHALL build the Windows x64 executable on a Windows runner and the other four executables with the pinned zig cross compiler.

#### Scenario: Windows arguments
- **WHEN** a user runs `mission-control-tools.exe openspec check C:\repo` on Windows
- **THEN** the command checks `C:\repo`

### Requirement: Smoke check on each platform
WHEN the tools release workflow builds the archives, the tools release workflow SHALL run `mission-control-tools version` and `mission-control-tools openspec check --bundle` on a runner of each of the five platforms, and SHALL NOT release when one of them fails.

#### Scenario: Broken platform build
- **WHEN** the linux-arm64 executable fails the bundle check of the Mission Control repository
- **THEN** the workflow stops before it creates a tag or a release

### Requirement: Dry run
WHEN a maintainer starts the tools release workflow with `dry_run`, the workflow SHALL plan, validate, build and smoke check the release and SHALL NOT create a tag or a GitHub release.

#### Scenario: Dry run of the next version
- **WHEN** a maintainer runs the workflow with `dry_run` set to true
- **THEN** the run uploads the archives as a workflow artifact and the repository has no new tag

### Requirement: Release only from main
WHEN the tools release workflow runs without `dry_run`, the tools release workflow SHALL release only a commit on main, only a version whose GitHub release is missing or incomplete, and only a version that has a section with highlights in `apps/tools/CHANGELOG.md`.

#### Scenario: Version already released
- **WHEN** `tools-v0.1.0` has a complete release and the workflow runs again for 0.1.0
- **THEN** the plan skips the release

### Requirement: Skip a version without a changelog section
WHEN `apps/tools/CHANGELOG.md` has no section for the version, the tools release plan SHALL skip the release and SHALL exit with 0.

#### Scenario: First merge of the tools CLI
- **WHEN** the change that adds `apps/tools/moon.mod` merges and the changelog has no 0.1.0 section
- **THEN** the workflow plans no release and creates no tag

### Requirement: Artifact attestations
WHEN the tools release workflow builds the release assets, the tools release workflow SHALL create a GitHub build provenance attestation for each archive and for `checksums.txt`, signed by the workflow `.github/workflows/release-tools.yml`, in dry runs and in releases.

#### Scenario: Verify an archive
- **WHEN** a user runs `gh attestation verify mission-control-tools-linux-x64.tar.gz --repo moonrockz/mission-control --signer-workflow moonrockz/mission-control/.github/workflows/release-tools.yml --source-ref refs/heads/main` on a released archive
- **THEN** the command reports a verified attestation

#### Scenario: Smoke check verifies the attestation
- **WHEN** the smoke job of a platform runs
- **THEN** it verifies the attestation of its archive with `gh attestation verify` and `--signer-workflow` before it runs the binary

### Requirement: Latest release stays on the main CLI
WHEN the tools release workflow creates a GitHub release, the tools release workflow SHALL NOT mark it as the latest release.

#### Scenario: Stable main CLI download URL
- **WHEN** `tools-v0.1.0` is released after `v0.1.0`
- **THEN** `releases/latest/download/mission-control-linux-x64.tar.gz` still downloads the main CLI

### Requirement: Consumer mise entry
WHEN the tools release workflow creates a release, the release notes SHALL contain a mise `[tools]` entry for the `github:` backend of `moonrockz/mission-control` with the exact version, `version_prefix = "tools-v"` and a version-free asset pattern for linux-x64, linux-arm64, macos-arm64, macos-x64, windows-x64 and windows-arm64, where windows-arm64 uses the Windows x64 archive.

#### Scenario: Install with the entry
- **WHEN** a consumer copies the entry into `.config/mise/config.toml` and runs `mise install`
- **THEN** mise downloads the archive of the platform from the `tools-v` release, checks it against the GitHub asset digest and the attestation, and puts `mission-control-tools` on the path

#### Scenario: Renovate bump
- **WHEN** Renovate reads the entry
- **THEN** it reads only `tools-v` releases and proposes the next tools version without a change to the asset patterns

### Requirement: Entry next to the main CLI
WHEN a consumer also installs the main CLI from `github:moonrockz/mission-control`, the release notes SHALL give a second form of the entry that uses a `[tool_alias]` name for the tools CLI.

#### Scenario: Both tools in one file
- **WHEN** a consumer declares the main CLI and the alias form of the tools CLI in one mise file
- **THEN** `mise install` installs both, each from its own tag family
