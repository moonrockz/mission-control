///|
/// Fixed paths for files owned by the portable html-design bundle.
/// The set is closed: a consumer's task scripts and tests are not part of it.
pub(all) enum BundleFile {
  Schema
  Proposal
  Spec
  Design
  Tasks
  Notice
  License
} derive(Eq)

///|
#deprecated
pub extend BundleFile with Eq::{equal, not_equal}

///|
pub fn files() -> Array[BundleFile] {
  [Schema, Proposal, Spec, Design, Tasks, Notice, License]
}

///|
pub fn BundleFile::path(self : BundleFile) -> String {
  match self {
    Schema => "openspec/schemas/html-design/schema.yaml"
    Proposal => "openspec/schemas/html-design/templates/proposal.md"
    Spec => "openspec/schemas/html-design/templates/spec.md"
    Design => "openspec/schemas/html-design/templates/design.html"
    Tasks => "openspec/schemas/html-design/templates/tasks.md"
    Notice => "openspec/schemas/html-design/NOTICE"
    License => "openspec/schemas/html-design/LICENSE"
  }
}

///|
pub fn BundleFile::content(self : BundleFile) -> String {
  match self {
    Schema =>
      (
        #|name: html-design
        #|version: 1
        #|description: OpenSpec spec-driven workflow with an HTML design document - proposal → specs → design.html → tasks
        #|artifacts:
        #|  - id: proposal
        #|    generates: proposal.md
        #|    description: Initial proposal document outlining the change
        #|    template: proposal.md
        #|    instruction: |
        #|      Create the proposal document that establishes WHY this change is needed.
        #|
        #|      Ground the motivation in an observable user or system problem and intended
        #|      outcome. Use a short concrete example when it helps; keep the detailed
        #|      journey and technical decisions in the design.
        #|
        #|      Sections:
        #|      - **Why**: 1-2 sentences on the problem or opportunity. What problem does this solve? Why now?
        #|      - **What Changes**: Bullet list of changes. Be specific about new capabilities, modifications, or
        #|        removals. Mark breaking changes with **BREAKING**.
        #|      - **Capabilities**: Identify which specs will be created or modified:
        #|          - **New Capabilities**: List capabilities being introduced. Each becomes a new
        #|          `specs/<capability-path>/spec.md`. Name each capability for a durable system behavior (for example,
        #|          `user-auth`), not the work in this change (for example, `add-login-endpoint`). Choose a cohesive boundary
        #|          that can own related requirements as the system evolves; avoid broad catch-all capabilities. Use
        #|          kebab-case for path segments you introduce (e.g., `user-auth` or `identity/user-auth`) and follow the
        #|          project's existing spec organization.
        #|          - **Modified Capabilities**: List existing capabilities whose REQUIREMENTS are changing. Only
        #|          include if spec-level behavior changes (not just implementation details). Each needs a delta spec file.
        #|          Use the exact existing path under `openspec/specs/`. Leave empty if no requirement changes.
        #|      - **Impact**: Affected code, APIs, dependencies, or systems.
        #|
        #|      IMPORTANT: The Capabilities section is critical. It creates the contract between
        #|      proposal and specs phases. Research existing specs before filling this in:
        #|      run `openspec list --specs` for the project's capability inventory, then
        #|      `openspec show "<spec-id>" --type spec --json --no-scenarios` for any that
        #|      look related - that returns a capability's purpose and requirement texts
        #|      without pulling whole spec files into context. Append `--store "<id>"` to
        #|      both commands only for a registered standalone store, and keep `--type
        #|      spec`: a change and a spec sharing a name is otherwise an ambiguous-item
        #|      error. `openspec list` without `--specs` lists in-flight changes, not
        #|      specs - it never shows what the project already covers. Reuse an existing
        #|      capability's exact path instead of introducing a near-duplicate name.
        #|      The filtered read is only an overview. Before deciding what is already
        #|      covered or what should change, read each relevant spec in full, including
        #|      scenarios, with `openspec show "<spec-id>" --type spec` (same `--store` rule).
        #|      Each capability listed here will need a corresponding spec file.
        #|
        #|      Every change must either declare at least one capability (new or
        #|      modified) or explicitly opt out of specs: `openspec validate` rejects a
        #|      change with zero deltas unless the change's `.openspec.yaml` sets
        #|      `skip_specs: true`. Use `skip_specs: true` only when no spec-level
        #|      behavior changes (pure refactor, tooling, docs) - specs describe
        #|      behavior, so if behavior does not change, no spec should change either.
        #|      Do not invent a requirement just to satisfy validation.
        #|
        #|      Follow the consuming repository's AGENTS.md and openspec/config.yaml for
        #|      tracking, approval and landing policy. Do not import another repository's
        #|      issue IDs, tracker hierarchy, release gates or authorization rules.
        #|
        #|      Keep it concise (1-2 pages). Focus on the "why" not the "how" -
        #|      implementation details belong in design.html.
        #|
        #|      This is the foundation - specs, design, and tasks all build on this.
        #|    requires: []
        #|
        #|  - id: specs
        #|    generates: "specs/**/*.md"
        #|    description: Detailed specifications for the change
        #|    template: spec.md
        #|    instruction: |
        #|      Create specification files that define WHAT the system should do.
        #|
        #|      A spec is a behavior contract, not an implementation plan.
        #|
        #|      For unfamiliar behavior, use a brief running example or diagram to help
        #|      readers understand the contract. Keep this explanatory material separate
        #|      from normative requirements and testable scenarios. For a new capability,
        #|      put durable explanatory context under Purpose so it survives archive.
        #|      Keep the prescribed delta headings and scenario structure unchanged.
        #|
        #|      Good spec content:
        #|      - Observable behavior users or downstream systems rely on
        #|      - Inputs, outputs, and error conditions
        #|      - External constraints (security, privacy, reliability, compatibility)
        #|      - Scenarios that can be tested or explicitly validated
        #|
        #|      Avoid in specs:
        #|      - Internal class/function names
        #|      - Library or framework choices
        #|      - Step-by-step implementation details
        #|      - Detailed execution plans (those belong in design.html or tasks.md)
        #|
        #|      Quick test: if the implementation can change without changing externally
        #|      visible behavior, it likely does not belong in the spec.
        #|
        #|      Create one spec file per capability listed in the proposal's Capabilities section.
        #|      `<capability-path>` is the spec directory relative to `specs/` (for example,
        #|      `user-auth` or `identity/user-auth`). Preserve the full path:
        #|      - New capabilities: use the exact path from the proposal at `specs/<capability-path>/spec.md`. Any path
        #|        segment newly introduced in the proposal must be kebab-case. Follow the project's existing organization; do
        #|        not add a new domain level when the project uses a flat layout.
        #|      - Modified capabilities: use the exact existing path from `openspec/specs/<capability-path>/` when
        #|        creating the delta at `specs/<capability-path>/spec.md`. Run `openspec list --specs` to confirm that path
        #|        before writing the delta, appending `--store "<id>"` only for a registered standalone store - a mistyped or
        #|        invented path targets a capability that does not exist rather than the one you meant. Do not move or rename
        #|        the capability.
        #|
        #|      Write the spec files one at a time, so the user sees progress and an
        #|      interrupted run keeps the files it already wrote:
        #|      - Before writing anything, compare the capabilities the proposal lists
        #|        with the `specs/<capability-path>/spec.md` files that already exist,
        #|        and start with the first capability that has no file. Do not rewrite
        #|        an existing file unless the user asks you to.
        #|      - Before each file, say in one line which capability you are writing.
        #|      - Write each file as soon as you have drafted it. Do not plan every file
        #|        before writing the first.
        #|      - Stop when every capability the proposal lists has its file.
        #|
        #|      There must be at least one spec file unless the change's `.openspec.yaml`
        #|      sets `skip_specs: true` (no spec-level behavior change) - `openspec validate`
        #|      rejects a zero-delta change without that marker. If the proposal lists no
        #|      capabilities and `skip_specs` is not set, revisit the proposal first.
        #|
        #|      Delta operations (use ## headers):
        #|      - **ADDED Requirements**: New capabilities
        #|      - **MODIFIED Requirements**: Changed behavior - MUST include full updated content
        #|      - **REMOVED Requirements**: Deprecated features - MUST include **Reason** and **Migration**
        #|      - **RENAMED Requirements**: Name changes only - use FROM:/TO: format
        #|
        #|      Format requirements:
        #|      - Each requirement: `### Requirement: <name>` followed by description
        #|      - Use SHALL/MUST for normative requirements (avoid should/may)
        #|      - Each scenario: `#### Scenario: <name>` with WHEN/THEN format
        #|      - **CRITICAL**: Scenarios MUST use exactly 4 hashtags (`####`). Using 3 hashtags or bullets will fail silently.
        #|      - Every requirement MUST have at least one scenario.
        #|      - Keep each requirement's description (the text between `### Requirement:` and its first scenario) to
        #|        500 characters or fewer. `openspec validate` flags longer descriptions in ADDED requirements and in the main
        #|        spec. This is a warning: normal validation still passes, but `openspec validate --strict` fails on it. When
        #|        writing a new requirement, state one behavior per requirement: move examples and edge cases into scenarios,
        #|        and split a requirement that covers several behaviors into separate `### Requirement:` blocks, each with its
        #|        own scenarios. Under MODIFIED, keep the existing requirement block whole; never split, trim or rewrite
        #|        existing text just to meet the length. Split an existing long requirement only when the user asks for it, in
        #|        a change made for that purpose: under MODIFIED, keep its header and every scenario and cut its description
        #|        down to one behavior without changing its meaning, then add each behavior you removed as its own ADDED
        #|        requirement with its own scenarios.
        #|
        #|      New capabilities only: the delta spec's first section is `## Purpose` -
        #|      one or two sentences (50+ characters, or `openspec validate --strict`
        #|      reports it as too brief) describing what the capability is for. Archive
        #|      copies it into the main spec it creates; without it the new main spec is
        #|      left with a `TBD ... Update Purpose after archive` placeholder to fill in
        #|      by hand. Do NOT add `## Purpose` to a delta for an existing capability -
        #|      that spec already has one and the delta's is ignored. To change an
        #|      existing capability's Purpose - including a leftover `TBD` placeholder -
        #|      edit `<planningHome.root>/openspec/specs/<capability-path>/spec.md`
        #|      directly. `planningHome.root` comes from the `openspec instructions ...
        #|      --json` response. Always use it rather than a repo-relative path: it
        #|      resolves to the store whenever the change lives in one - whether that
        #|      came from `--store`, a project `store:` pointer, or a global default
        #|      store - and to the current repository otherwise. Do not try to work out
        #|      which case applies; the field already has.
        #|
        #|      MODIFIED requirements workflow:
        #|            1. Locate the existing requirement in `<planningHome.root>/openspec/specs/<capability-path>/spec.md`
        #|      (the same store-aware root as above)
        #|      2. Copy the ENTIRE requirement block (from `### Requirement:` through all scenarios)
        #|      3. Paste under `## MODIFIED Requirements` and edit to reflect new behavior
        #|      4. Ensure header text matches exactly (whitespace-insensitive)
        #|
        #|      Common pitfall: Using MODIFIED with partial content loses detail at archive time.
        #|      If adding new concerns without changing existing behavior, use ADDED instead.
        #|
        #|      Example (a new capability, so its first section is `## Purpose`):
        #|      ```
        #|      # Spec Delta
        #|
        #|      ## Purpose
        #|
        #|      Lets users take their data out of the product in a portable format.
        #|
        #|      ## ADDED Requirements
        #|
        #|      ### Requirement: User can export data
        #|      The system SHALL allow users to export their data in CSV format.
        #|
        #|      #### Scenario: Successful export
        #|      - **WHEN** user clicks "Export" button
        #|      - **THEN** system downloads a CSV file with all user data
        #|
        #|      ## REMOVED Requirements
        #|
        #|      ### Requirement: Legacy export
        #|      **Reason**: Replaced by new export system
        #|      **Migration**: Use new export endpoint at /api/v2/export
        #|      ```
        #|
        #|      Specs should be testable - each scenario is a potential test case.
        #|
        #|    requires:
        #|      - proposal
        #|
        #|  - id: design
        #|    generates: design.html
        #|    description: Technical design document with implementation details, as an HTML page for review
        #|    template: design.html
        #|    instruction: |
        #|      Create the design document that explains HOW to implement the change.
        #|
        #|      Use a narrative organized around a concrete user or system journey.
        #|      Carry a consistent worked example through the relevant stages. Introduce
        #|      constraints where they affect a decision, then explain the choice, why it
        #|      fits, and the alternatives considered. Include significant failure and
        #|      recovery paths. Organize the narrative around the behavior being designed,
        #|      not the author's investigation history.
        #|
        #|      Use diagrams and worked examples where they clarify boundaries, state
        #|      transitions or data flow. Distinguish observed behavior, proposed interfaces
        #|      and assumptions. Scale this to the change: one paragraph and one example
        #|      can suffice for a small change. Do not force personas, diagram quotas,
        #|      extra sections or repeated motivation. Preserve required sections and
        #|      decision identifiers, and keep normative contracts precise.
        #|
        #|      Write a standalone HTML page, not Markdown. Copy the schema's design.html
        #|      template, which has inline CSS for light and dark mode:
        #|      - Keep the doctype, language, charset, viewport and color-scheme metadata.
        #|        Set <title> and <h1> to the change name.
        #|      - Keep CSS inline. Add no external styles, fonts, scripts or remote resources.
        #|        The page must open offline and survive archiving without path changes.
        #|      - Replace the example content inside <main> with the sections below. Give
        #|        each section an <h2 id="..."> and list every section in nav.toc.
        #|      - Put code in <pre><code class="language-moonbit"> (also toml, json, console,
        #|        diff). Escape <, > and & in text and code.
        #|      - Use tables, <details> and inline SVG diagrams where they help a reviewer.
        #|        Keep links to proposal.md, tasks.md and change-local specs relative.
        #|
        #|      The tasks artifact requires design, so always create design.html. Keep it
        #|      brief for simple work; expand these cases:
        #|      - Cross-cutting change (multiple services/modules) or new architectural pattern
        #|      - New external dependency or significant data model changes
        #|      - Security, performance, or migration complexity
        #|      - Ambiguity that benefits from technical decisions before coding
        #|
        #|      Sections:
        #|      - **Context**: Only the current state and constraints needed to explain the approach. Reference the
        #|        proposal for motivation instead of restating it (e.g., "See proposal.md - Why").
        #|      - **Goals / Non-Goals**: What this design achieves and explicitly excludes. Don't restate the proposal's
        #|        scope - add only design-level boundaries.
        #|      - **Decisions**: Key technical choices with rationale (why X over Y?). Include alternatives considered
        #|        for each decision.
        #|        Name each decision with a short slug for its area, 2 to 5 capital letters, and a number: `SRV-1`, `SRV-2`
        #|        for server decisions, `UI-1` for the interface. Do not use single-letter ids such as `D1`: the slug tells
        #|        the reader what the decision is about. Give the heading the lowercase id as its `id` (`<h3 id="srv-1">`)
        #|        and use the same id wherever another section refers to the decision.
        #|      - **Risks / Trade-offs**: Known limitations, things that could go wrong. Format: [Risk] → Mitigation
        #|      - **Migration Plan**: Steps to deploy, rollback strategy (if applicable)
        #|      - **Open Questions**: Unknowns that can safely be answered later without
        #|        changing the specs, the approach, or the task breakdown. Omit if none.
        #|
        #|      Open questions are for genuinely deferrable unknowns, not decisions you
        #|      skipped. If a question would change the specs, the chosen approach, or
        #|      the task breakdown, resolve it now - ask the user instead of guessing.
        #|
        #|      Focus on architecture and approach, not line-by-line implementation.
        #|      The proposal covers why and what; design covers how. Reference the
        #|      proposal for motivation and, once written, the specs for requirements -
        #|      if a section would only restate them, point to them instead.
        #|
        #|      Good design docs explain the "why" behind technical decisions.
        #|
        #|    requires:
        #|      - proposal
        #|
        #|  - id: tasks
        #|    generates: tasks.md
        #|    description: Implementation checklist with trackable tasks
        #|    template: tasks.md
        #|    instruction: |
        #|      Create the task list that breaks down the implementation work.
        #|
        #|      Before writing tasks, check design.html for Open Questions. If any of them
        #|      would change what gets built, resolve them with the user first - do not
        #|      bake an unstated assumption into the task list.
        #|
        #|      **IMPORTANT: Follow the template below for tracked tasks.** The apply phase parses
        #|      checkbox format to track progress. A box holding only `x` counts as done,
        #|      upper or lower case and with any spacing, so `- [ x]` is done too. Every
        #|      other marker, including `- [~]`, `- [-]` and an empty `- []`, reads as
        #|      unfinished. A line with no checkbox is not tracked at all.
        #|
        #|      Guidelines:
        #|      - Group related tracked tasks under ## numbered headings
        #|      - Each tracked task MUST be a checkbox: `- [ ] X.Y Task description`
        #|      - Tasks should be small enough to complete in one session
        #|      - Order tasks by dependency (what must be done first?)
        #|      - Track implementation and verification work that can be completed before
        #|        archive. If the requested workflow includes archive or work that requires
        #|        this change to be archived, preserve those steps as plain bullets in an
        #|        optional `## Workflow follow-up` section at the end of tasks.md. These
        #|        bullets are reference information outside tracked task progress.
        #|      - Each task MUST state how to verify completion (a test, command,
        #|        observable behavior, or delivered artifact). Put the verification in
        #|        that task's checkbox description. Use a separate verification task only
        #|        when it checks broader integration or system behavior that spans
        #|        multiple implementation tasks.
        #|      - Each task group MUST land the tests and documentation its own work
        #|        calls for. Do NOT collect testing or documentation into a final group -
        #|        when a late group first exercises work from an early one, the failures
        #|        cascade back through every group in between and force rework. A group
        #|        whose work calls for neither, such as scaffolding or dependency setup,
        #|        carries neither. A final group is for integration checks only, not for
        #|        the tests and docs an earlier group owed.
        #|
        #|      Example:
        #|      ```
        #|      # Tasks
        #|
        #|      ## 1. Setup
        #|
        #|      - [ ] 1.1 Create new module structure and verify expected files are present
        #|      - [ ] 1.2 Add dependencies to package.json and verify package installation succeeds
        #|
        #|      ## 2. Core Implementation
        #|
        #|      - [ ] 2.1 Implement data export function and verify the export test passes
        #|      - [ ] 2.2 Add CSV formatting utilities and verify unit tests cover quoting and delimiters
        #|      - [ ] 2.3 Document the export API in docs/export.md and verify the documented command runs as written
        #|      ```
        #|
        #|      When applicable, append workflow follow-up as plain bullets, for example:
        #|      ```
        #|      ## Workflow follow-up
        #|
        #|      - Archive the change after the project's review requirements are satisfied.
        #|      - Verify the archived result.
        #|      ```
        #|
        #|      Reference specs for what needs to be built, design for how to build it.
        #|
        #|      Follow the repository's tracking policy for group IDs and dependencies.
        #|      Keep each group's tests and documentation with its implementation.
        #|    requires:
        #|      - specs
        #|      - design
        #|
        #|apply:
        #|  requires: [tasks]
        #|  tracks: tasks.md
        #|  instruction: |
        #|    Read context files, work through pending tasks, mark complete as you go.
        #|    Pause if you hit blockers or need clarification.
        #|
        #|    Keep repository-local tracking in step with tasks.md, using AGENTS.md and
        #|    openspec/config.yaml. Do not infer publication or merge approval from a task.
        #|
      )
    Proposal =>
      (
        #|# Proposal
        #|
        #|## Why
        #|
        #|<!-- Explain the observable user or system problem and intended outcome. Add a short concrete example when helpful. Why now? -->
        #|
        #|## What Changes
        #|
        #|<!-- Describe what will change. Be specific about new capabilities, modifications, or removals. -->
        #|
        #|## Capabilities
        #|
        #|### New Capabilities
        #|<!-- Capabilities being introduced. Name each capability for a cohesive system
        #|     behavior that can own related requirements as the system evolves. Do not name
        #|     implementation tasks or proposal sections. Avoid broad catch-all names. Use
        #|     kebab-case for path segments you introduce (e.g., user-auth or identity/user-auth)
        #|     that follow the project's existing spec organization. Each creates
        #|     specs/<capability-path>/spec.md. -->
        #|- `<capability-path>`: <brief description of what this capability covers>
        #|
        #|### Modified Capabilities
        #|<!-- Existing capabilities whose REQUIREMENTS are changing (not just implementation).
        #|     Only list here if spec-level behavior changes. Each needs a delta spec file.
        #|     Use the exact existing path under openspec/specs/. Leave empty if no requirement
        #|     changes. A change with no capabilities at all (pure refactor, tooling, docs)
        #|     must set `skip_specs: true` in its .openspec.yaml - openspec validate rejects
        #|     a zero-delta change without that marker. Do not invent a requirement just to
        #|     satisfy validation. -->
        #|- `<existing-capability-path>`: <what requirement is changing>
        #|
        #|## Tracking
        #|
        #|<!-- Follow AGENTS.md for repository-local tracking. Link existing work; do not invent IDs. -->
        #|
        #|## Impact
        #|
        #|<!-- Affected code, APIs, dependencies, systems -->
        #|
      )
    Spec =>
      (
        #|# Spec Delta
        #|
        #|## Purpose
        #|<!-- New capabilities only: one or two sentences (50+ characters) on what this capability is for. Delete this section for an existing capability. -->
        #|<!-- Optional: add a brief running example or diagram under Purpose so it survives archive. Keep explanatory material separate from the normative requirements below. -->
        #|
        #|## ADDED Requirements
        #|
        #|### Requirement: <!-- requirement name -->
        #|<!-- requirement text -->
        #|
        #|#### Scenario: <!-- scenario name -->
        #|- **WHEN** <!-- condition -->
        #|- **THEN** <!-- expected outcome -->
        #|
      )
    Design =>
      (
        #|<!doctype html>
        #|<html lang="en">
        #|<head>
        #|<meta charset="utf-8">
        #|<meta name="viewport" content="width=device-width, initial-scale=1">
        #|<title>Change name: design</title>
        #|<meta name="color-scheme" content="light dark">
        #|<style>
        #|:root { color-scheme: light dark; --bg: #fafafa; --fg: #18212f; --muted: #526071;
        #|  --line: #cbd5e1; --panel: #eef2f6; --link: #075caa; }
        #|@media (prefers-color-scheme: dark) {
        #|  :root { --bg: #111827; --fg: #e5e7eb; --muted: #b0bdce;
        #|    --line: #475569; --panel: #1e293b; --link: #8cc8ff; }
        #|}
        #|* { box-sizing: border-box; }
        #|body { margin: 0; background: var(--bg); color: var(--fg);
        #|  font: 1rem/1.6 system-ui, sans-serif; }
        #|main { max-width: 70rem; margin: auto; padding: clamp(1rem, 4vw, 3rem); }
        #|h1, h2, h3 { line-height: 1.25; overflow-wrap: anywhere; }
        #|h2 { margin-top: 2rem; border-bottom: 1px solid var(--line); padding-bottom: .4rem; }
        #|a { color: var(--link); }
        #|a:focus-visible { outline: 3px solid var(--link); outline-offset: 3px; }
        #|.meta { color: var(--muted); }
        #|.toc, pre, details { background: var(--panel); border: 1px solid var(--line);
        #|  border-radius: .4rem; padding: 1rem; }
        #|code { font-family: ui-monospace, monospace; overflow-wrap: anywhere; }
        #|pre { overflow-x: auto; } pre code { overflow-wrap: normal; }
        #|table { border-collapse: collapse; width: 100%; }
        #|th, td { border: 1px solid var(--line); padding: .6rem; text-align: left;
        #|  overflow-wrap: anywhere; }
        #|svg { max-width: 100%; height: auto; }
        #|@media print { main { max-width: none; padding: 0; } pre, tr { break-inside: avoid; } }
        #|</style>
        #|</head>
        #|<body>
        #|<main>
        #|<h1>Change name: design</h1>
        #|<p class="meta">OpenSpec change | date | status</p>
        #|
        #|<nav class="toc" aria-label="Contents">
        #|<ul>
        #|<li><a href="#context">Context</a></li>
        #|<li><a href="#goals">Goals and non-goals</a></li>
        #|<li><a href="#decisions">Decisions</a></li>
        #|<li><a href="#risks">Risks and trade-offs</a></li>
        #|<li><a href="#migration">Migration plan</a></li>
        #|<li><a href="#open-questions">Open questions</a></li>
        #|</ul>
        #|</nav>
        #|
        #|<h2 id="context">Context</h2>
        #|<p>Current state and constraints that shape the approach. See proposal.md for motivation; do not restate it.</p>
        #|
        #|<h2 id="goals">Goals and non-goals</h2>
        #|<p><strong>Goals:</strong> what this design aims to achieve.</p>
        #|<p><strong>Non-goals:</strong> what is explicitly out of scope.</p>
        #|
        #|<h2 id="decisions">Decisions</h2>
        #|<p>Follow a concrete user or system journey through the decisions below. Carry one worked example through the relevant stages and use diagrams where they clarify flow or boundaries. Keep this brief for small changes.</p>
        #|<h3 id="area-1">AREA-1. Decision title</h3>
        #|<p>At this stage of the journey, explain the constraint, the chosen approach, why it fits and the alternatives considered. Include significant failure and recovery behavior. Distinguish observed behavior from proposed interfaces and assumptions. AREA is a 2 to 5 letter slug for the decision's area.</p>
        #|
        #|<h2 id="risks">Risks and trade-offs</h2>
        #|<table>
        #|<thead><tr><th>Risk</th><th>Mitigation</th></tr></thead>
        #|<tbody><tr><td>Known risk or limitation</td><td>How the design limits it</td></tr></tbody>
        #|</table>
        #|
        #|<h2 id="migration">Migration plan</h2>
        #|<p>Steps to deploy and the rollback strategy. Remove this section when it does not apply.</p>
        #|
        #|<h2 id="open-questions">Open questions</h2>
        #|<p>Unknowns that can safely be answered later. Remove this section when there are none.</p>
        #|
        #|</main>
        #|</body>
        #|</html>
        #|
      )
    Tasks =>
      (
        #|# Tasks
        #|
        #|## 1. First task group
        #|
        #|<!-- Add repository-local tracking links as required by AGENTS.md. -->
        #|
        #|- [ ] 1.1 Implement a thin end-to-end path and state how to verify it.
        #|- [ ] 1.2 Add this group's tests and documentation and verify them.
        #|
        #|## Workflow follow-up
        #|
        #|- Follow AGENTS.md for review, archive, tracker closure and release approval.
        #|
      )
    Notice =>
      (
        #|html-design OpenSpec extension
        #|
        #|Adapted from moonrockz/smithy and moonrockz/telescope html-design schemas.
        #|Telescope records the original FINOS adaptation at finos/morphir-moonbit,
        #|revision bd3adc52e6b8f6368fdaee50f76535799732f8d6, under Apache-2.0.
        #|
        #|morphir-moonbit - FINOS
        #|Copyright 2026 - FINOS info@finos.org
        #|This product includes software developed at the Fintech Open Source Foundation
        #|(https://www.finos.org/).
        #|
        #|OpenSpec spec-driven schema and Markdown templates are derived from
        #|Fission-AI/OpenSpec, distributed under the MIT license. Its license follows.
        #|
        #|MIT License
        #|
        #|Copyright (c) 2024 OpenSpec Contributors
        #|
        #|Permission is hereby granted, free of charge, to any person obtaining a copy
        #|of this software and associated documentation files (the "Software"), to deal
        #|in the Software without restriction, including without limitation the rights
        #|to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        #|copies of the Software, and to permit persons to whom the Software is
        #|furnished to do so, subject to the following conditions:
        #|
        #|The above copyright notice and this permission notice shall be included in all
        #|copies or substantial portions of the Software.
        #|
        #|THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        #|IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        #|FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        #|AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        #|LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        #|OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
        #|SOFTWARE.
        #|
      )
    License =>
      (
        #|                                 Apache License
        #|                           Version 2.0, January 2004
        #|                        http://www.apache.org/licenses/
        #|
        #|   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION
        #|
        #|   1. Definitions.
        #|
        #|      "License" shall mean the terms and conditions for use, reproduction,
        #|      and distribution as defined by Sections 1 through 9 of this document.
        #|
        #|      "Licensor" shall mean the copyright owner or entity authorized by
        #|      the copyright owner that is granting the License.
        #|
        #|      "Legal Entity" shall mean the union of the acting entity and all
        #|      other entities that control, are controlled by, or are under common
        #|      control with that entity. For the purposes of this definition,
        #|      "control" means (i) the power, direct or indirect, to cause the
        #|      direction or management of such entity, whether by contract or
        #|      otherwise, or (ii) ownership of fifty percent (50%) or more of the
        #|      outstanding shares, or (iii) beneficial ownership of such entity.
        #|
        #|      "You" (or "Your") shall mean an individual or Legal Entity
        #|      exercising permissions granted by this License.
        #|
        #|      "Source" form shall mean the preferred form for making modifications,
        #|      including but not limited to software source code, documentation
        #|      source, and configuration files.
        #|
        #|      "Object" form shall mean any form resulting from mechanical
        #|      transformation or translation of a Source form, including but
        #|      not limited to compiled object code, generated documentation,
        #|      and conversions to other media types.
        #|
        #|      "Work" shall mean the work of authorship, whether in Source or
        #|      Object form, made available under the License, as indicated by a
        #|      copyright notice that is included in or attached to the work
        #|      (an example is provided in the Appendix below).
        #|
        #|      "Derivative Works" shall mean any work, whether in Source or Object
        #|      form, that is based on (or derived from) the Work and for which the
        #|      editorial revisions, annotations, elaborations, or other modifications
        #|      represent, as a whole, an original work of authorship. For the purposes
        #|      of this License, Derivative Works shall not include works that remain
        #|      separable from, or merely link (or bind by name) to the interfaces of,
        #|      the Work and Derivative Works thereof.
        #|
        #|      "Contribution" shall mean any work of authorship, including
        #|      the original version of the Work and any modifications or additions
        #|      to that Work or Derivative Works thereof, that is intentionally
        #|      submitted to Licensor for inclusion in the Work by the copyright owner
        #|      or by an individual or Legal Entity authorized to submit on behalf of
        #|      the copyright owner. For the purposes of this definition, "submitted"
        #|      means any form of electronic, verbal, or written communication sent
        #|      to the Licensor or its representatives, including but not limited to
        #|      communication on electronic mailing lists, source code control systems,
        #|      and issue tracking systems that are managed by, or on behalf of, the
        #|      Licensor for the purpose of discussing and improving the Work, but
        #|      excluding communication that is conspicuously marked or otherwise
        #|      designated in writing by the copyright owner as "Not a Contribution."
        #|
        #|      "Contributor" shall mean Licensor and any individual or Legal Entity
        #|      on behalf of whom a Contribution has been received by Licensor and
        #|      subsequently incorporated within the Work.
        #|
        #|   2. Grant of Copyright License. Subject to the terms and conditions of
        #|      this License, each Contributor hereby grants to You a perpetual,
        #|      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
        #|      copyright license to reproduce, prepare Derivative Works of,
        #|      publicly display, publicly perform, sublicense, and distribute the
        #|      Work and such Derivative Works in Source or Object form.
        #|
        #|   3. Grant of Patent License. Subject to the terms and conditions of
        #|      this License, each Contributor hereby grants to You a perpetual,
        #|      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
        #|      (except as stated in this section) patent license to make, have made,
        #|      use, offer to sell, sell, import, and otherwise transfer the Work,
        #|      where such license applies only to those patent claims licensable
        #|      by such Contributor that are necessarily infringed by their
        #|      Contribution(s) alone or by combination of their Contribution(s)
        #|      with the Work to which such Contribution(s) was submitted. If You
        #|      institute patent litigation against any entity (including a
        #|      cross-claim or counterclaim in a lawsuit) alleging that the Work
        #|      or a Contribution incorporated within the Work constitutes direct
        #|      or contributory patent infringement, then any patent licenses
        #|      granted to You under this License for that Work shall terminate
        #|      as of the date such litigation is filed.
        #|
        #|   4. Redistribution. You may reproduce and distribute copies of the
        #|      Work or Derivative Works thereof in any medium, with or without
        #|      modifications, and in Source or Object form, provided that You
        #|      meet the following conditions:
        #|
        #|      (a) You must give any other recipients of the Work or
        #|          Derivative Works a copy of this License; and
        #|
        #|      (b) You must cause any modified files to carry prominent notices
        #|          stating that You changed the files; and
        #|
        #|      (c) You must retain, in the Source form of any Derivative Works
        #|          that You distribute, all copyright, patent, trademark, and
        #|          attribution notices from the Source form of the Work,
        #|          excluding those notices that do not pertain to any part of
        #|          the Derivative Works; and
        #|
        #|      (d) If the Work includes a "NOTICE" text file as part of its
        #|          distribution, then any Derivative Works that You distribute must
        #|          include a readable copy of the attribution notices contained
        #|          within such NOTICE file, excluding those notices that do not
        #|          pertain to any part of the Derivative Works, in at least one
        #|          of the following places: within a NOTICE text file distributed
        #|          as part of the Derivative Works; within the Source form or
        #|          documentation, if provided along with the Derivative Works; or,
        #|          within a display generated by the Derivative Works, if and
        #|          wherever such third-party notices normally appear. The contents
        #|          of the NOTICE file are for informational purposes only and
        #|          do not modify the License. You may add Your own attribution
        #|          notices within Derivative Works that You distribute, alongside
        #|          or as an addendum to the NOTICE text from the Work, provided
        #|          that such additional attribution notices cannot be construed
        #|          as modifying the License.
        #|
        #|      You may add Your own copyright statement to Your modifications and
        #|      may provide additional or different license terms and conditions
        #|      for use, reproduction, or distribution of Your modifications, or
        #|      for any such Derivative Works as a whole, provided Your use,
        #|      reproduction, and distribution of the Work otherwise complies with
        #|      the conditions stated in this License.
        #|
        #|   5. Submission of Contributions. Unless You explicitly state otherwise,
        #|      any Contribution intentionally submitted for inclusion in the Work
        #|      by You to the Licensor shall be under the terms and conditions of
        #|      this License, without any additional terms or conditions.
        #|      Notwithstanding the above, nothing herein shall supersede or modify
        #|      the terms of any separate license agreement you may have executed
        #|      with Licensor regarding such Contributions.
        #|
        #|   6. Trademarks. This License does not grant permission to use the trade
        #|      names, trademarks, service marks, or product names of the Licensor,
        #|      except as required for reasonable and customary use in describing the
        #|      origin of the Work and reproducing the content of the NOTICE file.
        #|
        #|   7. Disclaimer of Warranty. Unless required by applicable law or
        #|      agreed to in writing, Licensor provides the Work (and each
        #|      Contributor provides its Contributions) on an "AS IS" BASIS,
        #|      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
        #|      implied, including, without limitation, any warranties or conditions
        #|      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
        #|      PARTICULAR PURPOSE. You are solely responsible for determining the
        #|      appropriateness of using or redistributing the Work and assume any
        #|      risks associated with Your exercise of permissions under this License.
        #|
        #|   8. Limitation of Liability. In no event and under no legal theory,
        #|      whether in tort (including negligence), contract, or otherwise,
        #|      unless required by applicable law (such as deliberate and grossly
        #|      negligent acts) or agreed to in writing, shall any Contributor be
        #|      liable to You for damages, including any direct, indirect, special,
        #|      incidental, or consequential damages of any character arising as a
        #|      result of this License or out of the use or inability to use the
        #|      Work (including but not limited to damages for loss of goodwill,
        #|      work stoppage, computer failure or malfunction, or any and all
        #|      other commercial damages or losses), even if such Contributor
        #|      has been advised of the possibility of such damages.
        #|
        #|   9. Accepting Warranty or Additional Liability. While redistributing
        #|      the Work or Derivative Works thereof, You may choose to offer,
        #|      and charge a fee for, acceptance of support, warranty, indemnity,
        #|      or other liability obligations and/or rights consistent with this
        #|      License. However, in accepting such obligations, You may act only
        #|      on Your own behalf and on Your sole responsibility, not on behalf
        #|      of any other Contributor, and only if You agree to indemnify,
        #|      defend, and hold each Contributor harmless for any liability
        #|      incurred by, or claims asserted against, such Contributor by reason
        #|      of your accepting any such warranty or additional liability.
        #|
        #|   END OF TERMS AND CONDITIONS
        #|
        #|   APPENDIX: How to apply the Apache License to your work.
        #|
        #|      To apply the Apache License to your work, attach the following
        #|      boilerplate notice, with the fields enclosed by brackets "[]"
        #|      replaced with your own identifying information. (Don't include
        #|      the brackets!)  The text should be enclosed in the appropriate
        #|      comment syntax for the file format. We also recommend that a
        #|      file or class name and description of purpose be included on the
        #|      same "printed page" as the copyright notice for easier
        #|      identification within third-party archives.
        #|
        #|   Copyright [yyyy] [name of copyright owner]
        #|
        #|   Licensed under the Apache License, Version 2.0 (the "License");
        #|   you may not use this file except in compliance with the License.
        #|   You may obtain a copy of the License at
        #|
        #|       http://www.apache.org/licenses/LICENSE-2.0
        #|
        #|   Unless required by applicable law or agreed to in writing, software
        #|   distributed under the License is distributed on an "AS IS" BASIS,
        #|   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
        #|   See the License for the specific language governing permissions and
        #|   limitations under the License.
        #|
      )
  }
}
