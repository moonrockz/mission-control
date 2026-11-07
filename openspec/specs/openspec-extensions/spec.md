# openspec-extensions Specification

## Purpose
Distribute a consistent OpenSpec HTML design workflow to independent repositories while preserving each project's own context and work history.

## Requirements

### Requirement: Install a project-local extension
WHEN a user installs html-design, the extension tool SHALL write the versioned schema, templates, license records and ownership lock into the selected repository, and the lock SHALL record format 2, the tool module `moonrockz/mission-control-tools` and the tool version that wrote it.

#### Scenario: Fresh repository
- **WHEN** a user installs the bundle into a directory without OpenSpec
- **THEN** the project default schema is html-design and the schema files are present

#### Scenario: Lock records the tool
- **WHEN** mission-control-tools 0.1.0 installs the bundle
- **THEN** the lock has `"format": 2`, `"tool": "moonrockz/mission-control-tools"`, `"version": "0.1.0"` and one digest for each of the seven managed files

### Requirement: Preserve project policy and history
WHEN a user installs the extension in an existing OpenSpec project, the tool SHALL preserve all configuration values except the default schema and SHALL preserve existing changes and accepted specifications.

#### Scenario: Adopt HTML designs
- **WHEN** a project with local context, task rules and an ongoing Markdown design installs the bundle
- **THEN** its context, rules and existing design remain intact

### Requirement: Protect local edits
WHEN a bundle file differs from both its recorded digest and the new bundle content, the tool SHALL reject the install before writing destination files.

#### Scenario: Customized template
- **WHEN** a user edits an installed template and runs install again
- **THEN** install fails and preserves the edited template and existing lock

#### Scenario: Unmanaged schema
- **WHEN** an unmanaged schema file conflicts with the bundle
- **THEN** install fails before creating other schema files

### Requirement: Detect drift without writes
WHEN a user checks an extension, the tool SHALL report failure for a changed managed file, an incompatible lock or a different default schema without writing files.

#### Scenario: Changed design template
- **WHEN** an installed design template is edited
- **THEN** check reports drift and preserves the edit

### Requirement: Isolate integration setup
WHEN a user runs setup with the supported OpenSpec CLI, the tool SHALL generate the six core agent skills using isolated profile and delivery preferences without changing the user's global settings.

#### Scenario: Personal preferences differ
- **WHEN** a user's global delivery preference is commands only
- **THEN** setup still generates the project's core skills and leaves the global preference intact

### Requirement: Keep shared policy portable
The html-design bundle SHALL use an offline standalone HTML design and SHALL defer tracker, approval and landing rules to the consuming repository.

#### Scenario: Unrelated repository
- **WHEN** another organization installs the bundle
- **THEN** its templates contain no Moonrockz issue IDs or required shared tracker hierarchy

### Requirement: Managed file set
The html-design bundle SHALL manage only `schema.yaml`, the four templates, `LICENSE` and `NOTICE` under `openspec/schemas/html-design/`, and SHALL NOT manage a task script or a test feature in the consumer.

#### Scenario: Install into a fresh repository
- **WHEN** a user installs the bundle
- **THEN** the repository has no `scripts/openspec-ext.mbtx` and no `scripts/features/openspec_ext.feature`

### Requirement: Retire files that leave the managed set
WHEN a previous lock records a file that the bundle no longer manages, the extension tool SHALL delete that file if its digest matches the previous lock, and SHALL reject the install before writing any file if the file differs from that digest.

#### Scenario: Unedited script copy
- **WHEN** a consumer with a format 1 lock and an unedited `scripts/openspec-ext.mbtx` runs install
- **THEN** install deletes the script and its feature and writes a format 2 lock

#### Scenario: Edited script copy
- **WHEN** the consumer edited `scripts/openspec-ext.mbtx` after the last install
- **THEN** install fails, names the script, and changes no file

### Requirement: Format 1 lock in a check
WHEN a check reads a format 1 lock, the extension tool SHALL report `Extension lock format 1 is from the bundled script. Run mission-control-tools openspec install.` and exit with 1.

#### Scenario: Consumer not yet migrated
- **WHEN** a consumer runs `mission-control-tools openspec check` before install
- **THEN** the command prints the format 1 message and exits with 1
