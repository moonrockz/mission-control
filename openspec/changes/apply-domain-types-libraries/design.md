# Design

## Context

See `proposal.md`. The review notes for each finding are in the audit of this change's pull request; the main facts:

- `moonrockz/mdc` exposes `Heading(level~ : Int)`, `InvalidFrontmatter(line~, column~, message~)` for both invalid YAML and a non-mapping payload, and tells callers to add `body_offset()` and `body_line() - 1` themselves; `moonrockz/ears` and `moonrockz/okf` repeat that arithmetic.
- `moonrockz/ears` has `EmptyClause(keyword~ : String)` and two copies of the keyword list.
- `pkgs/contracts` returns `version() -> String` and `parse_command -> Command?`; `apps/cli` and `apps/desktop` copy command names.
- `scripts/release.mbtx` takes `plan(event : String, ref_type : String, ..., five Bool flags)`; scripts compare targets as text and copy `@sys.exit(if code > 0 { code } else { 1 })` about 12 times.

## Goals / Non-Goals

**Goals:** typed values at every boundary listed in the proposal, with the published API changes grouped into one release and documented.

**Non-Goals:** new behavior; a shared script library.

## Decisions

### D1. Published modules change once

All breaking changes to `moonrockz/mdc` and `moonrockz/ears` land in one release, with release notes that name each changed case and its replacement. `moonrockz/okf` moves to the new mdc values in the same change.

### D2. `HeadingLevel` in mdc

`pub(all) enum HeadingLevel { H1; H2; H3; H4; H5; H6 }` (every case is a valid level, so callers can build levels) with `to_int()` and `HeadingLevel::of_int(n) -> HeadingLevel?`. `moonrockz/okf` then uses the mdc type directly and drops its own (`apply-domain-types-okf` D3).

### D3. `FrontmatterError` and positions

`Frontmatter::Frontmatter` raises `FrontmatterError { InvalidYaml(at~ : TextPosition, message~ : String); NotAMapping; MultipleDocuments(count~ : Int) }`. `Document::Document` keeps `ParseError` and wraps the frontmatter error in a case, plus `UnterminatedFrontmatter`. `TextPosition::TextPosition(line~, column~) raise PositionError` and `SourceRange` are new; `Document::source_range(loc) -> SourceRange?` replaces the caller arithmetic; it gives `None` for a location that cmark did not record or that is not in the body.

### D4. EARS keywords with dialects

`pub enum Keyword { Where; While; When; If }` replaces the text in `EmptyClause`. `add-ears-dialects` adds lead-ins and openers but no new clause keywords, so the enum stays closed. Whichever of the two changes lands second adapts to the first.

### D5. Contracts and CLI

`Version` (private parts, `Version::Version(text) raise VersionError`, `to_string`) lives in contracts; `scripts/versions.mbtx` rewrites the `Version::current()` body by pattern as it does today for `version()`. `Command::Command(name) raise CommandError`, `Command::name()` and `Command::proton_id()` replace `parse_command` and `command_name`. `ExitCode` lives in `apps/cli` with `success()`, `failure()` and `usage()`.

### D6. Scripts

Each script that needs them gets private `Version`, `ExitCode`, `Backend` and `Failure` types. `scripts/test-scripts.mbtx` gains a check that the copies of the failure table in `publish.mbtx` and `release.mbtx` are equal, as it does today for the publish lists.

### D7. Follow-ups

The review of the dialects change found four more places with raw values. They land before the release, so the breaking changes still ship in one release (D1).

- `SourceSpan` duplicated the offsets and the start position of `@mdc.SourceRange` as raw integers and had no end position. `Origin::Text` and `Origin::Markdown` now hold `@mdc.SourceRange`, and `SourceSpan` is removed. Markdown origins take the range from `Document::source_range` with no copy.
- `Lexicon::from_yaml` found lines by matching text, so a flow list, a quoted key or a block scalar gave the key line. It now reads the line of each top-level key and each list item from the marked events of the YAML parser.
- `ReleaseFacts { on_main : Bool; released : Bool }` becomes `{ main : MainState; release : ReleaseState }`, with `MainState { OnMain; OffMain }` and `ReleaseState { Missing; Incomplete; Complete }`. `ReleaseState::of` replaces `release_complete`.
- `versions.mbtx` gives `RootVersionError { NoVersionLine; NotAVersion }` and `credentials.mbtx` gives `CredentialsError { TokenNotSet; NoMoonDirectory }`, each with `message()`.
- git-cliff read a wrapped footer line that starts with `Type::name` or `owner/module:` as a new footer, so the breaking change notes of #16 and #18 stopped in the middle of a sentence. Two commit preprocessors in `cliff.toml` join such lines to the line before them.

## Risks / Trade-offs

- [Breaking published APIs] → One release with clear notes (D1); the modules are at 0.0.x.
- [Copies of types in single-file scripts] → A script test compares the copies (D6).
- [Overlap with `add-ears-dialects`] → D4 sets the order rule.

## Migration Plan

Callers of `moonrockz/mdc` change `Heading(level~)` matches to `HeadingLevel`, and `InvalidFrontmatter` matches to `FrontmatterError` cases. Callers of `moonrockz/ears` change `EmptyClause(keyword~)` matches to `Keyword`, and read `Origin` ranges with `start_offset()`, `end_offset()`, `start().line()` and `start().column()` in place of the `SourceSpan` methods. The release notes list each change. Rollback is a revert before the release.
