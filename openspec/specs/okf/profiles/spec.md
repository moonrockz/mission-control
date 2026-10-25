# okf/profiles Specification

## Purpose
Let implementors extend OKF with their own conventions, such as record types, states, references and check rules, without changes to the library. The library ships the API, not producer-specific profiles.

## Requirements

### Requirement: Profile contract
The library SHALL define a profile contract. A profile SHALL be able to give a name, a vocabulary of frontmatter keys, document classification, metadata derivation, typed references, registers, templates and rule sets. Each part SHALL be optional.

#### Scenario: Empty profile
- **WHEN** a caller loads a bundle with a profile that gives only a name
- **THEN** the result equals the result with no profile

### Requirement: Profile composition
The library SHALL apply several profiles together, in the order that the caller gives. WHEN two profiles claim the same frontmatter key or register type with different definitions, the library SHALL report the conflict and SHALL not select one in silence.

#### Scenario: Conflicting key
- **WHEN** two profiles define the key `state` with different value sets
- **THEN** the library reports a profile conflict that names `state` and both profiles

### Requirement: Vocabulary
The library SHALL treat the keys of the OKF specification and of the active profiles as known. It SHALL report each other key with the rule `frontmatter-unknown-key` at the severity information.

#### Scenario: Profile key
- **WHEN** a profile defines the key `decided` and a concept has `decided: 2026-10-01`
- **THEN** validation reports no unknown key for `decided`

### Requirement: Document classification and derived metadata
A profile SHALL be able to classify a document by its path and body, and to give metadata for a document that has no frontmatter, such as its type and title. Derived metadata SHALL be marked as derived and SHALL not change the document text.

#### Scenario: Type from path
- **WHEN** a profile maps `specs/*/spec.md` to the type `Specification` and a file at that path has no frontmatter
- **THEN** the document is a concept with the derived type `Specification`

### Requirement: Bundle configuration keys
A profile SHALL be able to define keys in the root index frontmatter that turn on profile behavior for that bundle, and the library SHALL give the profile those values.

#### Scenario: Bundle flag
- **WHEN** a profile defines the bundle key `intent` and the root index has `intent: true`
- **THEN** the profile sees that the bundle has `intent` set to true

### Requirement: Registers
A profile SHALL be able to define a register: a typed view of the concepts of one type. A register SHALL give each record an ID, a state, its typed fields and its source concept.

#### Scenario: Decision register
- **WHEN** a test profile defines the register `Decision Record` and a bundle has three concepts of that type
- **THEN** the register lists three records with their IDs and states

### Requirement: Record IDs
A register SHALL be able to take a record ID from the leading digits of the file name, padded to a given width. IDs SHALL be unique in a bundle. WHEN two records have the same ID, the library SHALL report a duplicate ID. WHEN a lookup matches several records, it SHALL report the ambiguity.

#### Scenario: Padded ID
- **WHEN** a record file is `/decisions/42-use-yaml.md` and the width is 4
- **THEN** the record ID is `0042`

#### Scenario: Duplicate ID
- **WHEN** two record files in one bundle both start with `0042`
- **THEN** the library reports a duplicate ID for `0042`

### Requirement: States and transitions
A register SHALL be able to define its states, its allowed transitions and the obligations of each transition. WHEN a caller asks for a transition with an unmet obligation, the library SHALL refuse it before any edit and SHALL name the obligation.

#### Scenario: Unmet obligation
- **WHEN** a test register requires `reason` for the transition to `Cancelled` and a caller cancels a record without a reason
- **THEN** the library refuses the transition and names `reason`

#### Scenario: Allowed transition
- **WHEN** a caller moves a record from `Backlog` to `Refinement` and the register allows it
- **THEN** the library returns an edit plan that sets the new state

### Requirement: Supersession
A register SHALL be able to define supersession fields. The library SHALL resolve them in the bundle, follow supersession chains, and report a supersession that is not mutual or that names an unknown record.

#### Scenario: One-way supersession
- **WHEN** record `0007` has `superseded_by: 12` and record `0012` has no `supersedes` entry for `0007`
- **THEN** the library reports that the supersession is not mutual

### Requirement: Typed document references
A profile SHALL be able to define reference fields whose values name a document, such as `bundle-label:/path.md`. The library SHALL parse and resolve them and SHALL report a malformed or unresolved reference.

#### Scenario: Unresolved reference
- **WHEN** a record has `capability: morphir/ir:/caps/missing.md` and that document does not exist
- **THEN** the library reports an unresolved reference

### Requirement: Reference profile in tests
The test suites SHALL include a morphir reference profile, built only with the public profile API, that reproduces the morphir Intent and Decision Record registers and their check rules. The library SHALL not ship that profile.

#### Scenario: morphir decisions
- **WHEN** the morphir reference profile loads a copy of the morphir knowledge base
- **THEN** it lists the same Decision Records, with the same IDs and states, as the morphir `kb decision list` command

### Requirement: Checked registers
The library SHALL build a register only through a constructor that checks it: the name and the concept type are not empty, an ID width is from 1 to 9, and, when the register lists states, every transition target and superseded state is one of them. The constructor SHALL raise a typed error that names the broken rule.

#### Scenario: Unknown transition target
- **WHEN** a caller builds a register with the states `Backlog` and `Done` and a transition to `Review`
- **THEN** the constructor raises an error that names `Review`

#### Scenario: Width zero
- **WHEN** a caller builds a register with an ID width of 0
- **THEN** the constructor raises an error for the width

### Requirement: Typed register parts
The library SHALL give record IDs, state names and register names as values, and a record without an ID SHALL have no ID, not an empty one. A reference field that names a register SHALL name one that a profile defines, and profile checks SHALL report one that does not.

#### Scenario: Unknown register in a reference field
- **WHEN** a profile defines a reference field for the register `decisoins` and no profile defines that register
- **THEN** the profile checks report the unknown register name
