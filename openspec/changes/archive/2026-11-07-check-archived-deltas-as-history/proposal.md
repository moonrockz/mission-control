# Check archived deltas as history

## Why

The archive of `add-tools-cli` fails the OpenSpec checks of `moonrockz/okf`. Its REMOVED requirement `Compile the bundled script without warnings` matches no requirement of `openspec-extensions`, because the archive removed it. The rules `openspec-modified-unknown` and `openspec-delta-unknown-capability` are the checks that OpenSpec runs when it archives a change. After the archive, the main specs move on, so these checks report false problems for every archived removal and for later renames.

## What Changes

- `openspec-modified-unknown` and `openspec-delta-unknown-capability` skip the spec deltas of an archived change. The EARS rule already skips archived changes for the same reason.
- Active changes are checked as before.

Out of scope: the other OpenSpec rules, which still check archived changes; the OKF conversion.

## Capabilities

### New Capabilities

### Modified Capabilities

- `okf/openspec`: The OpenSpec checks do not run the archive-time checks on archived changes.

## Tracking

Found while archiving `add-tools-cli` (bead moonbase-4ca).

## Impact

Published module `moonrockz/okf` (`moonrockz/okf/openspec`): fewer findings for archived changes. No API change. No other module changes.
