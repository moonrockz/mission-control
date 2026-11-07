## ADDED Requirements

### Requirement: Shared version scope
The version script SHALL require the root version for every workspace module except `moonrockz/mission-control-tools`, and SHALL NOT change the tools version when it sets the workspace version.

#### Scenario: Tools version differs
- **WHEN** the root `moon.mod` is 0.1.0 and `apps/tools/moon.mod` is 0.3.0
- **THEN** `mise run validate:versions` passes when every other module and sibling import is 0.1.0

### Requirement: Separate release workflows
The main Release workflow SHALL NOT build, tag or publish the tools CLI, and its tag filter SHALL NOT match a `tools-v` tag.

#### Scenario: Tools tag push
- **WHEN** the tag `tools-v0.1.0` is pushed
- **THEN** the main Release workflow does not start
