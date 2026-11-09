# Proposal

## Why

A reader can understand a design more easily when one concrete journey connects the constraints, choices and reasons. The Morphir acquisition design demonstrated this approach, but the shared authoring instructions do not yet guide other authors to use it.

## What Changes

- Add narrative guidance to the proposal, spec and design instructions in the shared html-design bundle.
- Update the templates and authoring guide. Keep short changes brief and keep requirements and scenarios precise.
- Publish mission-control-tools 0.1.2 with the changed bundle and a verified ownership lock.

## Capabilities

### New Capabilities

None. This is an authoring-documentation update. `skip_specs: true` records that the CLI, installed file set, lock format and runtime behavior stay the same.

### Modified Capabilities

None. Existing requirements for `openspec-extensions` and `tools/distribution` remain valid.

## Tracking

The user approved the narrative approach and prepared source patch on 9 November 2026, then authorized landing it as a new OpenSpec tools release. The change is `guide-narrative-designs`. Attach its PR link after creation. No Beads issue id is assigned in this fresh checkout; do not import another repository's issue hierarchy.

## Impact

The source module is `moonrockz/openspec-ext`; the released executable is `moonrockz/mission-control-tools`. Only the tools version family changes. Main-family publication, new CLI commands, automated prose scoring and changes to consumer requirements are out of scope.
