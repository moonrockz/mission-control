# Tasks

## 1. Supported OpenSpec version and init scope

Bead: morphir-vwuy.1 (finos/morphir)

- [x] 1.1 Add the failing tests first: unit tests in `apps/openspec-ext/extension_wbtest.mbt` for `SupportedOpenSpec` on each side of each limit (2.0.0, 2.1.0, 2.1.1, 2.2.0, 2.2.1, 2.2.17, 2.3.0, 3.2.0) and for `scope_arguments` (none for 1.14.3 and 1.16.x, `--scope project` for 2.2.x), and acceptance tests in `tests/openspec-ext-acceptance` that `setup_with` passes the init arguments for 1.14.3, 1.16.0, 1.16.1, 2.2.0 and 2.2.1, and refuses 2.1.1 and 2.3.0 with `Setup requires OpenSpec 1.14.3, 1.16.x or 2.2.x`; verify that they fail.
- [x] 1.2 Add `Series(2, 2)` to the support table, `SupportedOpenSpec::scope_arguments` to `moonrockz/openspec-ext`, and `init_arguments` to `host`, and pass the arguments to `run_init`; verify the tests of 1.1 pass with `moon test apps/openspec-ext tests/openspec-ext-acceptance --target native` and `--target wasm`.

## 2. Documentation

Bead: morphir-vwuy.1 (finos/morphir)

- [x] 2.1 Give the new rule and the OpenSpec 2 skill layout in `apps/tools/README.md` and an `[Unreleased]` entry in `apps/tools/CHANGELOG.md`; verify the texts against the spec delta.

## 3. Integration

Bead: morphir-vwuy.1 (finos/morphir)

- [x] 3.1 Run the built `mission-control-tools openspec setup` with OpenSpec 2.2.0 against scratch copies of Mission Control and finos/morphir; verify exit 0, a diff of agent skill files only, no OpenSpec skill in the user's home, `openspec validate --all --strict` and `openspec check --bundle`. Run it with OpenSpec 1.14.3 against Mission Control; verify exit 0 and no diff.
- [x] 3.2 Run `mise run check` and `openspec validate --all --strict`; verify both pass.

## Workflow follow-up

- Archive this change in the pull request that implements it.
- Release tools-v0.1.3 with this change.
