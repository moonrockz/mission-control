## MODIFIED Requirements

### Requirement: Setup
WHEN a user runs `mission-control-tools openspec setup`, the tools CLI SHALL run the snapshot check, SHALL refuse an OpenSpec CLI whose version is not 1.14.3, not a 1.16 patch release (1.16.x) and not a 2.2 patch release (2.2.x) with `Setup requires OpenSpec 1.14.3, 1.16.x or 2.2.x`, and SHALL run `openspec init` for the core profile in the repository, with `--scope project` for OpenSpec 2, and with a temporary configuration directory that it removes after the process ends.

#### Scenario: Personal preferences differ
- **WHEN** the user's global OpenSpec preference is delivery by commands
- **THEN** setup generates the core skills and the global preference file is unchanged

#### Scenario: Wrong OpenSpec version
- **WHEN** `openspec --version` prints `1.13.0`, `1.14.2`, `1.15.0`, `1.17.0`, `2.1.1` or `2.3.0`
- **THEN** setup prints `openspec-ext: Setup requires OpenSpec 1.14.3, 1.16.x or 2.2.x`, exits with 1 and runs no init

#### Scenario: OpenSpec 1.16 patch release
- **WHEN** `openspec --version` prints `1.16.0` or `1.16.1` and the snapshot check passes
- **THEN** setup runs `openspec init` for the core profile without `--scope` and exits with 0

#### Scenario: OpenSpec 2.2 patch release
- **WHEN** `openspec --version` prints `2.2.0` or `2.2.1` and the snapshot check passes
- **THEN** setup runs `openspec init --scope project` for the core profile and exits with 0

#### Scenario: Unreadable OpenSpec version
- **WHEN** `openspec --version` cannot run, or prints a text that is not three numbers joined with `.`, such as `1.16` or `1.16.1-beta.1`
- **THEN** setup prints `openspec-ext: Setup requires OpenSpec 1.14.3, 1.16.x or 2.2.x`, exits with 1 and runs no init
