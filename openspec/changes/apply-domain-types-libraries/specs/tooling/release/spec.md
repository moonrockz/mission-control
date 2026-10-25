# Spec Delta

## Purpose

Make the build and release scripts parse their inputs and classify failures once, as typed values, so that a typo or an unexpected text cannot change what a release does.

## ADDED Requirements

### Requirement: Release inputs
The release script SHALL parse the GitHub event, the dry-run flag and the ref once into a run trigger (pull request, dry run or push) and a git ref (a branch or a version tag), and SHALL stop with a typed error that names an event or a ref type that it does not know.

#### Scenario: Unknown event
- **WHEN** the release plan runs with the event `pull-request`
- **THEN** the script stops with an error that names `pull-request`, and plans no release

### Requirement: Build targets
The build, test and distribution scripts SHALL parse each target argument into a backend (`wasm`, `wasm-gc`, `js` or `native`) or a distribution target, and SHALL stop with a usage error for any other text before they run a build.

#### Scenario: Misspelled target
- **WHEN** a user runs `mise run test -- jss`
- **THEN** the script stops with a usage error that names `jss`, and runs no test

### Requirement: Failure classes
The publish and release scripts SHALL classify a failed command once into refused, conflict, transient, already published or other, from one table, and SHALL retry only transient failures.

#### Scenario: Same table in both scripts
- **WHEN** the publish and the release script classify the same output
- **THEN** both give the same class

### Requirement: Script exit codes
Every task script SHALL exit with 0 for success, 1 for a failure and 2 for a usage error.

#### Scenario: Usage error
- **WHEN** a user runs `moonx scripts/versions.mbtx` with no arguments
- **THEN** the script prints its usage and exits with 2

### Requirement: Release facts
The release script SHALL read whether the commit is on main and the state of the GitHub release (missing, incomplete or complete) as typed values, and SHALL skip only a version whose release is complete.

#### Scenario: Draft release
- **WHEN** the GitHub release of the version is a draft with every asset
- **THEN** the plan releases the version

### Requirement: Typed script errors
The version and credentials scripts SHALL give each error as a typed case, and SHALL print the message of that case.

#### Scenario: No version line
- **WHEN** the root `moon.mod` has no version line
- **THEN** the version check fails with the message `The root moon.mod has no version line.`

### Requirement: Whole breaking change notes
WHEN a commit body wraps a `BREAKING CHANGE:` footer at a line that starts with `Type::name` or `owner/module:`, the changelog SHALL show the whole footer.

#### Scenario: Wrapped footer
- **WHEN** a footer line ends with `use OpenSpecProfile() or` and the next line starts with `OpenSpecProfile::of_tree.`
- **THEN** the breaking change note ends with `OpenSpecProfile::of_tree.`
