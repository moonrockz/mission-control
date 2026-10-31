## Purpose

Distribute a consistent OpenSpec HTML design workflow to independent repositories while preserving each project's own context and work history.

## ADDED Requirements

### Requirement: Install a project-local extension
WHEN a user installs html-design, the extension tool SHALL write the versioned schema, templates, license records and ownership lock into the selected repository.

#### Scenario: Fresh repository
- **WHEN** a user installs the bundle into a directory without OpenSpec
- **THEN** the project default schema is html-design and the schema files are present

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

### Requirement: Compile the bundled script without warnings
WHEN a consumer tests the bundled script with MoonBit 0.10.17+d971670cd or later, the extension tool SHALL supply a script that declares its imports in frontmatter and compiles without warnings.

#### Scenario: Deny warnings on MoonBit 0.10.18
- **WHEN** a consumer runs `moon test --deny-warn scripts/openspec-ext.mbtx` with MoonBit 0.10.18
- **THEN** the script compiles without an `unfenced_import` warning and its tests pass

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
