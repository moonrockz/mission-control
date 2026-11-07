# Tasks

## 1. Supported OpenSpec version

Bead: moonbase-v0j

- [x] 1.1 Add the failing tests first: unit tests in `apps/openspec-ext/extension_wbtest.mbt` for `SupportedOpenSpec` on each side of each limit (1.14.2, 1.14.3, 1.14.4, 1.15.0, 1.16.0, 1.16.1, 1.16.9, 1.17.0, 2.16.0, 0.16.0, `1.16`, `1.16.1-beta.1`, empty text), and acceptance tests in `tests/openspec-ext-acceptance` that `setup_with` runs init for 1.16.0 and 1.16.1 and refuses 1.13.0, 1.15.0, 1.17.0, `1.16` and no version with `Setup requires OpenSpec 1.14.3 or 1.16.x`; verify that they fail.
- [x] 1.2 Add `SupportedOpenSpec`, `OpenSpecVersionError` and `supported_openspec` to `moonrockz/openspec-ext`, and make host setup parse the version text into it; verify the tests of 1.1 pass with `moon test apps/openspec-ext tests/openspec-ext-acceptance --target native` and `--target wasm`.

## 2. Documentation

Bead: moonbase-v0j

- [x] 2.1 Give the new rule in `apps/tools/README.md` and an `[Unreleased]` entry in `apps/tools/CHANGELOG.md`; verify the texts against the spec delta.

## 3. Integration

Bead: moonbase-v0j

- [x] 3.1 Run the built `mission-control-tools openspec setup` with OpenSpec 1.16.0 and 1.16.1 against a scratch copy of the repository; verify exit 0, a skill diff of `generatedBy` only, `openspec validate --all --strict` and `openspec check --bundle`. Verify that 1.15.0 is refused with exit 1.
- [x] 3.2 Run `mise run check` and `openspec validate --all --strict`; verify both pass.

## Workflow follow-up

- Archive this change in the pull request that implements it.
- Release tools-v0.1.1 with this change.
