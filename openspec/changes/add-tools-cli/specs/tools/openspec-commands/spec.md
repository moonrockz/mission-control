## Purpose

Give consumer repositories the shared OpenSpec commands as one released binary, so that a consumer runs a pinned tool and does not compile a script with its own MoonBit toolchain.

## ADDED Requirements

### Requirement: Snapshot check
WHEN a user runs `mission-control-tools openspec check`, the tools CLI SHALL compare each file that the lock records with its SHA-256 digest, SHALL check that the lock has the supported format and the html-design file set, and SHALL check that the default schema in `openspec/config.yaml` is html-design, without writing files.

#### Scenario: Valid snapshot
- **WHEN** the lock, the managed files and the config agree
- **THEN** the command prints `html-design snapshot: OK` and exits with 0

#### Scenario: Edited template
- **WHEN** a user edits `openspec/schemas/html-design/templates/design.html`
- **THEN** the command prints `openspec-ext: Extension drift: openspec/schemas/html-design/templates/design.html` to standard error, exits with 1 and keeps the edit

#### Scenario: Wrong default schema
- **WHEN** `openspec/config.yaml` selects `spec-driven`
- **THEN** the command prints `openspec-ext: Default schema must be html-design` and exits with 1

### Requirement: Script messages
The tools CLI SHALL print the problem texts of the shared script: `Unsupported extension lock`, `Unexpected extension file set`, `Missing digest: <path>`, `Extension drift: <path>` and `Default schema must be html-design`, each after `openspec-ext: ` on standard error, without the source location that the script added.

#### Scenario: Malformed lock
- **WHEN** the lock is a JSON object without the format field
- **THEN** the command prints `openspec-ext: Unsupported extension lock` and exits with 1

### Requirement: Missing inputs
WHEN the lock, a managed file or the config does not exist, the tools CLI SHALL report `Missing file: <path>` for that path and exit with 1.

#### Scenario: Deleted template
- **WHEN** a user deletes `openspec/schemas/html-design/templates/tasks.md`
- **THEN** the check prints `openspec-ext: Missing file: openspec/schemas/html-design/templates/tasks.md` and exits with 1

### Requirement: All problems in one run
WHEN a check finds more than one problem, the tools CLI SHALL report each problem in the order lock, managed files, config, and SHALL exit with 1.

#### Scenario: Drift and wrong schema
- **WHEN** a template is edited and the config selects `spec-driven`
- **THEN** the output has the drift line before the schema line

### Requirement: Bundle check
WHEN a user runs `mission-control-tools openspec check --bundle`, the tools CLI SHALL also report a problem when the lock does not record this tool module and version or when a managed file differs from the bundle in the binary.

#### Scenario: Pin moved without install
- **WHEN** the lock records tool version 0.1.0 and the binary is version 0.2.0
- **THEN** the command prints `openspec-ext: Extension lock records mission-control-tools 0.1.0; this is 0.2.0. Run mission-control-tools openspec install.` and exits with 1

#### Scenario: Snapshot of the same version
- **WHEN** the repository was installed by the same tool version and nothing is edited
- **THEN** the command prints `html-design snapshot: OK` and exits with 0

### Requirement: Repository argument
The tools CLI SHALL take one optional repository path after the `openspec` command and options, and SHALL use the current directory when no path is given.

#### Scenario: Check another repository
- **WHEN** a user runs `mission-control-tools openspec check ../consumer`
- **THEN** the command checks `../consumer` and reads no file of the current directory

### Requirement: Usage errors
WHEN the arguments name an unknown command, an unknown option or more than one repository path, the tools CLI SHALL print its usage to standard error and exit with 2 before it reads a file.

#### Scenario: Unknown command
- **WHEN** a user runs `mission-control-tools openspec lint`
- **THEN** the command prints the usage and exits with 2

### Requirement: Install
WHEN a user runs `mission-control-tools openspec install`, the tools CLI SHALL install the html-design bundle of its version with the safety rules of the openspec-extensions capability, SHALL write a format 2 lock, and SHALL print `html-design: OK (mission-control-tools <version>)`.

#### Scenario: Fresh repository
- **WHEN** a user installs into a directory without OpenSpec
- **THEN** the schema files, `openspec/config.yaml` and the lock exist and the command exits with 0

### Requirement: Setup
WHEN a user runs `mission-control-tools openspec setup`, the tools CLI SHALL run the snapshot check, SHALL refuse an OpenSpec CLI other than 1.14.3 with `Setup requires OpenSpec 1.14.3`, and SHALL run `openspec init` for the core profile in the repository with a temporary configuration directory that it removes after the process ends.

#### Scenario: Personal preferences differ
- **WHEN** the user's global OpenSpec preference is delivery by commands
- **THEN** setup generates the core skills and the global preference file is unchanged

#### Scenario: Wrong OpenSpec version
- **WHEN** `openspec --version` prints `1.13.0`
- **THEN** setup prints `openspec-ext: Setup requires OpenSpec 1.14.3`, exits with 1 and runs no init

### Requirement: JSON check report
WHEN a user adds `--json` to `openspec check`, the tools CLI SHALL print one JSON object on standard output with the tool name and version, the check level, the repository path, an `ok` value and a list of problems, each with a code, an optional path and a message, and SHALL keep the exit code of the text mode.

#### Scenario: Drift as JSON
- **WHEN** a user runs `mission-control-tools openspec check --json` and a template is edited
- **THEN** standard output is a JSON object with `"ok": false` and one problem with the code `drift` and the template path, and the exit code is 1

### Requirement: Version command
WHEN a user runs `mission-control-tools version`, the tools CLI SHALL print `mission-control-tools <version>`.

#### Scenario: Plain version
- **WHEN** a user runs `mission-control-tools version`
- **THEN** the output is `mission-control-tools 0.1.0` for version 0.1.0

### Requirement: JSON version
WHEN a user runs `mission-control-tools version --json`, the tools CLI SHALL print a JSON object with the tool name, the version and the html-design bundle name.

#### Scenario: Version for an agent
- **WHEN** an agent runs `mission-control-tools version --json`
- **THEN** the output is `{"tool":"mission-control-tools","version":"0.1.0","bundle":"html-design"}` for version 0.1.0
