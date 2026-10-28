# Share OpenSpec extensions

## Why

The html-design copies in Smithy, diagrams.mbt and Telescope have diverged. A portable bundle needs one owner and a repeatable way to install and check it.

## What Changes

- Add `moonrockz/openspec-ext` to Mission Control with install, check and setup commands.
- Share an offline HTML design schema, templates and license records.
- Keep repository context, tracker rules and change histories local.
- Adopt the bundle in Mission Control, the three existing html-design consumers, Moon-Lander, Krueger, PartiQL, gleam-parser, Ion and MoonSpec.

## Capabilities

### New Capabilities

- `openspec-extensions`: Install and check a portable versioned extension bundle and generate agent skills.

### Modified Capabilities

- `okf/profiles`: Profiles can retain Markdown configuration files as opaque assets.
- `okf/openspec`: Preserve custom schema templates during OpenSpec import and export.

## Tracking

Mission Control feature `moonbase-933` tracks the tool. Consumer changes follow their own repository policy.

## Impact

Adds published module `moonrockz/openspec-ext` to the existing release list. The OKF profile and conversion retain custom schema files as assets. Publication and release version selection remain separate from local implementation. Global OpenSpec settings and existing designs are out of scope.
