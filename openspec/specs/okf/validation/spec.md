# okf/validation Specification

## Purpose
Check OKF bundles against the OKF v0.2 conformance rules and against rules that profiles and callers add, and report the results as structured findings.

## Requirements

### Requirement: Findings
The library SHALL report each validation result as a finding with a severity (error, warning or information), a rule name, a document path, an optional line, a message and an optional hint.

#### Scenario: Finding fields
- **WHEN** a concept at `/tables/orders.md` has no `type`
- **THEN** the finding has the severity error, the rule `concept-missing-type` and the path `/tables/orders.md`

### Requirement: Finding order
The library SHALL sort findings by severity, then by subject (the validation config, then profiles by name, then documents of bundles by bundle label and path, then stray files by path), then by line, then by rule name, then by message, so that the same input always gives the same order.

#### Scenario: Stable order
- **WHEN** a caller validates the same bundle two times
- **THEN** both runs return the same findings in the same order

### Requirement: OKF v0.2 conformance rules
The library SHALL ship a rule set for OKF v0.2 conformance. It SHALL report an error for each concept without parseable frontmatter, for each concept without a non-empty `type`, and for each `index.md` or `log.md` that does not follow its format.

#### Scenario: Conformant bundle
- **WHEN** every concept has valid frontmatter with a non-empty `type`
- **THEN** the conformance rule set reports no error

#### Scenario: Empty type
- **WHEN** a concept has `type: ""`
- **THEN** the conformance rule set reports an error for that concept

### Requirement: Tolerated content
The library SHALL not report an error for missing optional fields, unknown types, unknown keys, broken links or a missing `index.md`.

#### Scenario: Unknown type and broken link
- **WHEN** a concept has `type: Playbook` and a broken link
- **THEN** the conformance rule set reports no error for that concept

### Requirement: Advisory rules
The library SHALL ship advisory rules that report missing `title` or `description`, unknown `status` values, stale concepts, concepts not indexed, description drift, duplicate titles, broken links and links that escape the bundle. The caller SHALL choose the severity of each advisory rule.

#### Scenario: Broken link as a warning
- **WHEN** a concept has a broken link and the caller sets `link-broken` to warning
- **THEN** the finding for that link has the severity warning

### Requirement: Rule sets
The library SHALL run validation as a composition of rule sets. A caller or a profile SHALL be able to add a rule set, and to turn off a rule by name.

#### Scenario: Turn off a rule
- **WHEN** a caller turns off `duplicate-title`
- **THEN** validation reports no `duplicate-title` finding

#### Scenario: Profile rule set
- **WHEN** a profile adds a rule set with the rule `decision-no-id`
- **THEN** validation reports `decision-no-id` findings together with the core findings

### Requirement: Deterministic inputs
WHEN a rule needs the current date or time, the library SHALL get it from the clock provider that the caller supplies, and SHALL not read the system clock in the core.

#### Scenario: Fixed clock
- **WHEN** a caller validates with a clock fixed at `2026-10-23T00:00:00Z`
- **THEN** staleness findings use that instant

### Requirement: Validation summary
The library SHALL give the number of findings for each severity, and SHALL say whether the result fails for a given strictness: errors fail always, and warnings fail only in strict mode.

#### Scenario: Strict mode
- **WHEN** validation finds warnings and no errors, and the caller selects strict mode
- **THEN** the summary says that the result fails

### Requirement: Rule names
The library SHALL represent rule names as values that are not empty and are in kebab case, and SHALL report a validation config that overrides or turns off a rule name that no active rule set and no built-in rule defines. The config SHALL turn off and change the severity of the built-in rules `profile-invalid` and `validation-config-unknown-rule` as it does for other rules.

#### Scenario: Misspelled rule
- **WHEN** a caller turns off `link-broke` and no rule has that name
- **THEN** validation reports that the config names an unknown rule

#### Scenario: Built-in rule turned off
- **WHEN** a caller turns off `validation-config-unknown-rule` and also turns off `link-broke`
- **THEN** validation reports no finding for either name

### Requirement: Finding subjects
A finding SHALL name its subject as a document of a bundle (a bundle label and a bundle path) or as a stray file (a store path), not as raw text.

#### Scenario: Stray file
- **WHEN** validation reports a stray Markdown file
- **THEN** the finding has a stray subject with the store path of the file

### Requirement: Invalid profiles
The library SHALL report a profile whose definitions break a rule of a value type, such as a rule name that is not in kebab case, as a `profile-invalid` error, for each profile method that can fail. The library SHALL use none of the definitions that fail, and SHALL keep the definitions of the other profiles.

#### Scenario: Severity for a rule name with spaces
- **WHEN** a profile gives a severity for the rule name `Not Kebab`
- **THEN** validation reports `profile-invalid` for that profile

#### Scenario: Invalid vocabulary
- **WHEN** a profile raises an error when it gives its vocabulary
- **THEN** validation reports `profile-invalid` for that profile

#### Scenario: Registers of a valid profile
- **WHEN** one profile has an invalid register and another profile defines the register that a record reference names
- **THEN** the record reference resolves
