## MODIFIED Requirements

### Requirement: Install a project-local extension
WHEN a user installs html-design, the extension tool SHALL write the versioned schema, templates, license records and ownership lock into the selected repository, and the lock SHALL record format 2, the tool module `moonrockz/mission-control-tools` and the tool version that wrote it.

#### Scenario: Fresh repository
- **WHEN** a user installs the bundle into a directory without OpenSpec
- **THEN** the project default schema is html-design and the schema files are present

#### Scenario: Lock records the tool
- **WHEN** mission-control-tools 0.1.0 installs the bundle
- **THEN** the lock has `"format": 2`, `"tool": "moonrockz/mission-control-tools"`, `"version": "0.1.0"` and one digest for each of the seven managed files

## ADDED Requirements

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

## REMOVED Requirements

### Requirement: Compile the bundled script without warnings
**Reason**: The bundle no longer ships `scripts/openspec-ext.mbtx`. The released tools CLI carries the commands, and Mission Control compiles and tests them.
**Migration**: Pin `mission-control-tools` with mise, point the `openspec:*` tasks at it, run `mission-control-tools openspec install`, and remove the script tests from the consumer tasks. See `apps/tools/README.md`.
