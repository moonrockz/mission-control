## MODIFIED Requirements

### Requirement: OpenSpec checks
The OpenSpec profile SHALL report a requirement without a scenario, a scenario that does not use four `#` characters, a requirement without `SHALL` or `MUST`, a modified requirement whose name matches no existing requirement, and a delta for a capability that does not exist and is not added. WHEN a change is archived, the profile SHALL NOT report its modified or removed requirements that match no requirement, or its deltas for a capability that does not exist.

#### Scenario: Requirement without scenario
- **WHEN** a spec has a requirement with no scenario
- **THEN** the profile reports a finding for that requirement

#### Scenario: Archived removal
- **WHEN** an archived change removes a requirement that the main spec no longer has
- **THEN** the profile reports no `openspec-modified-unknown` finding for it

#### Scenario: Active removal of an unknown requirement
- **WHEN** an active change removes a requirement that the main spec does not have
- **THEN** the profile reports an `openspec-modified-unknown` finding
