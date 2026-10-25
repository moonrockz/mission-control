# Spec Delta

## ADDED Requirements

### Requirement: Typed OpenSpec names
The OpenSpec profile SHALL parse capability paths, change names and requirement names once into values with the rules of `check-okf-inputs`, and SHALL give OpenSpec types and change states as enums, not as text. A requirement name SHALL keep the backticks of its heading.

#### Scenario: Change state
- **WHEN** the profile loads an archived change
- **THEN** the change has the archived state value

#### Scenario: Requirement name with backticks
- **WHEN** a spec has the heading ``### Requirement: Parse `okf_version` ``
- **THEN** the requirement name is ``Parse `okf_version` ``

### Requirement: Invalid OpenSpec names
The `openspec-invalid-name` rule SHALL report a name value that is not valid, a requirement heading without a name, and a `state` value that is not `active` or `archived`. The view SHALL leave out the content that has an invalid name, and export SHALL refuse it.

#### Scenario: Invalid name in a native concept
- **WHEN** a native `Specification` concept has `capability: ../x`
- **THEN** the view leaves the concept out and validation reports `openspec-invalid-name`

#### Scenario: Requirement heading without a name
- **WHEN** a spec has the heading `### Requirement:` with no name
- **THEN** the view has no requirement for it, its scenarios belong to no other requirement, and validation reports `openspec-invalid-name`

#### Scenario: Invalid change state
- **WHEN** a native `Change` concept has `state: done`
- **THEN** validation reports `openspec-invalid-name`

#### Scenario: Export of an invalid requirement name
- **WHEN** a caller exports a bundle with a native `Requirement` concept whose `requirement` value is blank
- **THEN** export raises the conversion error for an invalid name

### Requirement: Task numbers
The OpenSpec profile SHALL parse a task number as dot-separated positive integers and SHALL order task numbers by their numbers, so that `1.2` comes before `1.10`. A task without a number SHALL have no number.

#### Scenario: Numeric order
- **WHEN** a task list has the tasks `1.10` and `1.2`
- **THEN** `1.2` orders before `1.10`

### Requirement: Complete renames
The OpenSpec profile SHALL give a rename only when it has both a from name and a to name, and SHALL report a rename with one part as a finding.

#### Scenario: Rename without TO
- **WHEN** a `RENAMED Requirements` section has `- FROM: X` and no `TO:` line
- **THEN** the view has no rename for `X` and validation reports `openspec-rename-incomplete`
