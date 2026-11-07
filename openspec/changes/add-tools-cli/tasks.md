# Tasks

## 1. Core checks and lock format 2 in openspec-ext

Bead: moonbase-4ca

- [ ] 1.1 Remove the script and its feature from the bundle; parse the lock at the boundary into a typed format 1 or format 2 lock; write format 2 with the tool module and version; verify the unit tests for the lock text, the digests and each lock parse error.
- [ ] 1.2 Add the pure snapshot and bundle checks that return typed problems in a fixed order, with the script texts; verify `tests/openspec-ext-acceptance` scenarios for a valid snapshot, drift, a missing file, a wrong schema, a malformed lock, a format 1 lock, a tool version mismatch and several problems.
- [ ] 1.3 Make host install retire unedited files that the previous lock records and the bundle does not manage, and refuse edited ones before any write; verify filesystem acceptance scenarios for a format 1 consumer with an unedited and an edited script.
- [ ] 1.4 Move the isolated setup process into the host with an injected process runner, and remove `apps/openspec-ext/cmd`; verify the setup test of the environment, the preferences and the cleanup, and `openspec-ext` README.

## 2. Tools CLI

Bead: moonbase-4ca

- [ ] 2.1 Add `apps/tools` (`moonrockz/mission-control-tools`) to `moon.work` with the pure argument parser, `ExitCode`, `Version` and the text and JSON output; verify unit tests for each command, option order, usage errors and exit codes, and `mise run validate:packages`.
- [ ] 2.2 Add `main` that runs the host commands and prints the results; verify acceptance scenarios that run the commands against fixture repositories, including `--json` output and a check of another directory.
- [ ] 2.3 Move the Mission Control `openspec:*` tasks to `moon run apps/tools -- openspec …`, run install to move the lock to format 2, and remove `scripts/openspec-ext.mbtx`, its feature and its script test entry; verify `mise run openspec:check`, `mise run test:scripts` and `openspec validate --all --strict`.

## 3. Version family and distribution

Bead: moonbase-4ca

- [ ] 3.1 Add the tools version family to `scripts/versions.mbtx` (`check` covers both families, `set` the workspace only, `set-tools` the tools only) with feature scenarios on each side of the family boundary; verify `mise run validate:versions` and `mise run test:scripts`.
- [ ] 3.2 Add the `tools` product to `scripts/dist.mbtx` without a change to the CLI outputs; verify feature scenarios for the tools asset names, and a local cross-build and pack of `dist-tools/` with `checksums.txt`.
- [ ] 3.3 Add `scripts/release-tools.mbtx` (`plan`, `notes`, `github`, `status`) with typed inputs and feature scenarios for each plan outcome and the generated mise entry; verify `mise run test:scripts` and a local `plan` with `DRY_RUN=true`.
- [ ] 3.4 Add `.github/workflows/release-tools.yml` with no pull request or merge queue trigger, `actions/attest@v4` for the six assets in the build job, `gh attestation verify --signer-workflow` in each smoke job, `--latest=false` on release create, and `apps/tools/CHANGELOG.md`; verify `mise run lint` (yamllint) and that the main Release workflow tag filter excludes `tools-v`.
- [ ] 3.5 Generate the `github:` mise entry (plain and alias forms) and the `gh attestation verify` command in the release notes; verify feature scenarios of the notes text, and record the mise 2026.11.3 test of the backend mechanism in the design.

## 4. Consumer migration

Bead: moonbase-4ca

- [ ] 4.1 Write the consumer migration in `apps/tools/README.md` (mise entry, attestation check, tasks, install, removals, lock) and link it from the root README and AGENTS.md; verify the links and the examples against the commands.
- [ ] 4.2 In a scratch clone of finos/morphir, apply the migration with the locally built binary and run `mise run openspec:verify`; verify that it passes and that nothing is pushed.

## 5. Integration

Bead: moonbase-4ca

- [ ] 5.1 Run `mise run check`, `mise run test:scripts` and `openspec validate --all --strict`; open the pull request and get CI and the existing Release pull request run green; fix verified review findings.

## Workflow follow-up

- Archive `add-openspec-extensions` before this change, because this change modifies its capability.
- After approval and merge, run `gh workflow run release-tools.yml -f dry_run=true` and check the attestation step and all five smoke jobs, including Windows.
- The first release (`tools-v0.1.0`) needs Damian's approval: a pull request that adds the 0.1.0 section to `apps/tools/CHANGELOG.md`.
- After the release, migrate the consumers in their own repositories.
