# Support OpenSpec 1.16 in tools setup

## Why

`mission-control-tools openspec setup` accepts only OpenSpec 1.14.3. finos/morphir-gleam pins OpenSpec 1.16.1 and finos/morphir-scala pins 1.16.0, so `mise run openspec:setup` stops there with `Setup requires OpenSpec 1.14.3`. These consumers cannot regenerate their agent skills with the tools CLI.

A test on 2026-11-07 with OpenSpec 1.16.0 and 1.16.1 showed that the managed `html-design` files work with these versions: `openspec schema validate html-design` passes, OpenSpec reads the schema and the templates from the repository, a change made from the templates passes `openspec validate --strict`, and `openspec init` for the core profile changes only the `generatedBy` line of each skill.

## What Changes

- `openspec setup` accepts OpenSpec 1.14.3 and each 1.16 patch release (1.16.x). It refuses every other version, and a version text that it cannot read, before it runs `openspec init`.
- The refusal message changes from `Setup requires OpenSpec 1.14.3` to `Setup requires OpenSpec 1.14.3 or 1.16.x`.
- `apps/tools/README.md` and `apps/tools/CHANGELOG.md` give the new rule.

Out of scope:

- Changes to the managed `html-design` files, the lock or `openspec check`. The test showed that they need no change.
- OpenSpec 1.15.x, and versions after 1.16. A later change can add a version after a test like the one above.
- The OpenSpec version that Mission Control itself pins (1.14.3).
- Changes in consumer repositories.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `tools/openspec-commands`: The setup requirement accepts OpenSpec 1.14.3 and 1.16.x, and gives the new refusal message.

## Tracking

Bead moonbase-v0j tracks the work. It is the first part of the tools-v0.1.1 release.

## Impact

- `moonrockz/openspec-ext`: the pure package gets a type for a supported OpenSpec version, and `host` setup parses the version text into it. This module is in the next main release.
- `moonrockz/mission-control-tools`: the `openspec setup` command and its documentation. It is released as tools-v0.1.1.
- Not changed: `moonrockz/mission-control-cli`, `moonrockz/mission-control-contracts`, `moonrockz/mdc`, `moonrockz/ears`, `moonrockz/okf`, `moonrockz/mission-control-web`, `moonrockz/mission-control-desktop`.
- No new CI or merge queue job.
