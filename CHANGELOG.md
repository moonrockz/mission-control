# Changelog

All notable changes to `moonrockz/mission-control` are listed here, newest first.
Versions follow [Semantic Versioning](https://semver.org); while the version
is 0.x, a minor release can contain breaking changes.

<!-- git-cliff: end of header -->

## [0.1.0] - 2026-10-25

<!-- Highlights: replace this comment with a few sentences on what this release brings. -->

### ⚠️ Breaking changes

- Moonrockz/mdc: BlockKind::Heading holds a HeadingLevel (H1 to H6) in place of Int; Frontmatter::Frontmatter raises FrontmatterError (InvalidYaml, NotAMapping, MultipleDocuments), and ParseError::InvalidFrontmatter wraps it. moonrockz/ears: ParseError::EmptyClause holds a Keyword in place of a string, parse errors carry a SentencePosition, and Trigger is read-only. moonrockz/mission-control-contracts: version() gives a Version value, and Command::Command(name) and Command::name() replace parse_command and command_name. The mission-control command exits with 2 for an unknown command. ([#16](https://github.com/moonrockz/mission-control/pull/16))
- *(ears)* Requirement::system() now gives String? instead of String. ParseError has a new case, UnresolvedPronoun. OpenSpecProfile is no longer built with OpenSpecProfile::{}; use OpenSpecProfile() or OpenSpecProfile::of_tree. ([#18](https://github.com/moonrockz/mission-control/pull/18))
- *(ears)* Moonrockz/ears removes SourceSpan. Origin::Text and Origin::Markdown hold an @mdc.SourceRange; use start_offset(), end_offset(), start().line() and start().column(). ([#20](https://github.com/moonrockz/mission-control/pull/20))

### 🚀 Features

- *(okf)* Add the moonrockz/okf module for Open Knowledge Format bundles ([#11](https://github.com/moonrockz/mission-control/pull/11)) by @DamianReeves
- *(okf)* Add browser write methods, a worker fallback and an IndexedDB store ([#17](https://github.com/moonrockz/mission-control/pull/17)) by @DamianReeves
- *(ears)* [**breaking**] Add EARS dialects and check OpenSpec requirements as EARS ([#18](https://github.com/moonrockz/mission-control/pull/18)) by @DamianReeves

### 🐛 Bug fixes

- *(okf)* Check edit, export and log inputs, and import the domain type guidance ([#13](https://github.com/moonrockz/mission-control/pull/13)) by @DamianReeves

### 🚜 Refactoring

- *(okf)* Apply domain types to the OKF module ([#15](https://github.com/moonrockz/mission-control/pull/15)) by @DamianReeves
- [**breaking**] Apply domain types to mdc, ears, contracts, the CLI and the scripts ([#16](https://github.com/moonrockz/mission-control/pull/16)) by @DamianReeves
- *(ears)* [**breaking**] Finish the domain type follow-ups before the 0.1.0 release ([#20](https://github.com/moonrockz/mission-control/pull/20)) by @DamianReeves

### 📚 Documentation

- *(openspec)* Archive add-okf-module and propose browser storage options and EARS dialects ([#12](https://github.com/moonrockz/mission-control/pull/12)) by @DamianReeves
- *(openspec)* Propose domain types for okf and for the other libraries and tools ([#14](https://github.com/moonrockz/mission-control/pull/14)) by @DamianReeves
- *(openspec)* Archive add-ears-dialects ([#19](https://github.com/moonrockz/mission-control/pull/19)) by @DamianReeves

### 🏗️ Build and CI

- Set up OpenSpec for Claude, Codex, Cursor, Grok, Muse and Copilot ([#10](https://github.com/moonrockz/mission-control/pull/10)) by @DamianReeves

**Full changelog**: https://github.com/moonrockz/mission-control/compare/v0.0.2...v0.1.0

## [0.0.2] - 2026-10-22

Moonbase is now Mission Control. The repository is `moonrockz/mission-control`,
and the command and the release assets are named `mission-control`. The
modules are now `moonrockz/mission-control-contracts`,
`moonrockz/mission-control-cli`, `moonrockz/mission-control-web`,
`moonrockz/mission-control-desktop`, `moonrockz/mdc` and `moonrockz/ears`.
Replace the `moonrockz/moonbase-*` dependencies with these names.

This repository no longer publishes `moonrockz/notebooks`. Use the module that
moonrockz/moon-lander publishes.

### 🐛 Bug fixes

- *(release)* Set the version in every version assertion ([#9](https://github.com/moonrockz/mission-control/pull/9)) by @DamianReeves

### 🚜 Refactoring

- Rename Moonbase to Mission Control ([#6](https://github.com/moonrockz/mission-control/pull/6)) by @DamianReeves

### 🏗️ Build and CI

- Remove the notebooks module, which moon-lander publishes ([#7](https://github.com/moonrockz/mission-control/pull/7)) by @DamianReeves

**Full changelog**: https://github.com/moonrockz/mission-control/compare/v0.0.1...v0.0.2

## [0.0.1] - 2026-10-19

Moonbase's first release publishes immutable Markdown documents and EARS
requirements alongside the shared contracts, CLI, web UI and desktop shell.
The independent `moonrockz/notebooks` module adds Jupyter and .NET Interactive
DIB models, format-specific inspection, and shared cursors, traversal and
immutable metadata. Jupyter support covers notebook schema 4.0 through 4.5,
including the format used by Python nbformat 5.11. Checked usage guides and
public API comments accompany the notebook packages.

### 🚀 Features

- Scaffold the Moonbase monorepo by @DamianReeves
- *(mdc)* Add immutable Markdown documents ([#1](https://github.com/moonrockz/Moonbase/pull/1)) by @DamianReeves
- *(mdc)* Add cursors and bottom-up reduction ([#2](https://github.com/moonrockz/Moonbase/pull/2)) by @DamianReeves
- *(ears)* Parse text and Markdown specifications ([#3](https://github.com/moonrockz/Moonbase/pull/3)) by @DamianReeves
- *(notebooks)* Add Jupyter and DIB notebook APIs ([#4](https://github.com/moonrockz/Moonbase/pull/4)) by @DamianReeves
