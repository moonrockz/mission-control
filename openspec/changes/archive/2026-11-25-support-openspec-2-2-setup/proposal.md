# Support OpenSpec 2.2 in tools setup

## Why

`mission-control-tools openspec setup` accepts only OpenSpec 1.14.3 and 1.16.x. OpenSpec 2.2.0 is the latest release (2026-11-24), and the Morphir repositories are moving to it. finos/morphir-scala already pins 2.2.0, so `mise run openspec:setup` stops there with `Setup requires OpenSpec 1.14.3 or 1.16.x`.

Accepting the version is not enough. Since OpenSpec 2.1, `openspec init --tools <ids>` installs the skills for every project on the machine unless `--scope project` is given. Setup sets only `XDG_CONFIG_HOME` to its temporary directory, so without the option the skills would go to the user's real home and not to the repository.

A test on 2026-11-25 with OpenSpec 2.2.0 showed that the managed `html-design` files work with this version: `openspec schema validate html-design` passes, OpenSpec reads the schema and the templates from the repository, and after `openspec init --scope project` for the core profile, `openspec validate --all --strict` and `openspec check --bundle` pass.

## What Changes

- `openspec setup` accepts each 2.2 patch release (2.2.x), as well as 1.14.3 and 1.16.x. It refuses every other version, and a version text that it cannot read, before it runs `openspec init`.
- For OpenSpec 2, setup runs `openspec init --scope project`, so the skills stay in the repository. For OpenSpec 1, the arguments do not change; OpenSpec 1 does not know the option.
- The refusal message changes from `Setup requires OpenSpec 1.14.3 or 1.16.x` to `Setup requires OpenSpec 1.14.3, 1.16.x or 2.2.x`.
- `apps/tools/README.md` and `apps/tools/CHANGELOG.md` give the new rule and the OpenSpec 2 skill layout.

Out of scope:

- Changes to the managed `html-design` files, the lock or `openspec check`. The test showed that they need no change.
- OpenSpec 2.0.x, 2.1.x and versions after 2.2. A later change can add a version after a test like the one above.
- The OpenSpec version that Mission Control itself pins (1.14.3).
- Changes in consumer repositories.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `tools/openspec-commands`: The setup requirement accepts OpenSpec 2.2.x, keeps the skills in the repository for OpenSpec 2, and gives the new refusal message.

## Tracking

Bead morphir-vwuy.1 in finos/morphir tracks the work, under the epic morphir-vwuy (update OpenSpec to 2.2.0 across the Morphir ecosystem). It is the first part of the tools-v0.1.3 release.

## Impact

- `moonrockz/openspec-ext`: `SupportedOpenSpec` gets `scope_arguments`, and `host` gets `init_arguments`. The `run_init` function that `setup_with` takes now also receives the init arguments. This module is in the next main release.
- `moonrockz/mission-control-tools`: the `openspec setup` command and its documentation. It is released as tools-v0.1.3.
- Consumers that move to OpenSpec 2.2 get the OpenSpec 2 skill layout from setup: one copy of each skill in `.agents/skills/`, links in `.claude/skills/` and `.grok/skills/`, and the new `openspec` router skill. OpenSpec removes the copies it generated in `.cursor/`, `.gemini/`, `.github/` and `.opencode/`.
- Not changed: `moonrockz/mission-control-cli`, `moonrockz/mission-control-contracts`, `moonrockz/mdc`, `moonrockz/ears`, `moonrockz/okf`, `moonrockz/mission-control-web`, `moonrockz/mission-control-desktop`.
- No new CI or merge queue job.
