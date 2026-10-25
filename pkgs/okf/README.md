# OKF

`moonrockz/okf` reads, queries, validates and edits knowledge bases in the
[Open Knowledge Format](https://github.com/GoogleCloudPlatform/open-knowledge-format)
(OKF v0.2): directories of Markdown concepts with YAML frontmatter. It is built
on [`moonrockz/mdc`](../mdc/README.md).

OKF does not define how to store, index, search or extend a knowledge base, so
this module keeps those concerns behind provider traits and a profile API.

## Packages

| Package | Contents | Targets |
| --- | --- | --- |
| `moonrockz/okf` | Document model, frontmatter, links, link graph, indexes, logs, queries, search, validation, profiles | all |
| `moonrockz/okf/edit` | Text edits that keep every other byte, and edit plans | all |
| `moonrockz/okf/provider` | Async `DocumentStore`, `IndexProvider` and `SearchProvider` traits, loading and plan application | all (async: native, wasm, js) |
| `moonrockz/okf/memory` | In-memory store, index and search providers | all (async: native, wasm, js) |
| `moonrockz/okf/conformance` | Conformance checks for new providers | native, wasm, js |
| `moonrockz/okf/fs` | File system store | native, wasm |
| `moonrockz/okf/fs/node` | File system store over `node:fs/promises` (Node.js 20.16+, Bun, Deno) | js |
| `moonrockz/okf/fs/browser` | Store over the File System Access API | js |
| `moonrockz/okf/idb` | Store over IndexedDB, for pages and workers in every browser | js |
| `moonrockz/okf/openspec` | OpenSpec profile, structured view, import and export | all |

## Load and query

The core is pure and synchronous. It works on a `DocumentSet` in memory, so it
runs on every target, including wasm-gc.

```moonbit
let set = @okf.DocumentSet::of_texts([
  ("kb/index.md", "---\nokf_version: \"0.2\"\n---\n"),
  ("kb/tables/orders.md", "---\ntype: BigQuery Table\ntitle: Orders\n---\nSee [customers](customers.md).\n"),
])
let knowledge = @okf.discover(set)            // every directory whose index.md has okf_version
let bundle = knowledge.bundles()[0]
let orders = bundle.concept(@okf.ConceptId("tables/orders")).unwrap()
orders.concept_type()                          // Some(ConceptType "BigQuery Table")
orders.links()                                 // body links with their origin and kind
let graph = @okf.Graph::build(knowledge)       // outbound links, backlinks, orphans, broken links
knowledge.filter([TypeIs(@okf.ConceptType("metric")), HasTag("finance")])
knowledge.facet(Type)                          // or Tags, Bundles, Field(@okf.FieldKey("owner"))
@okf.search_knowledge(knowledge, @okf.SearchRequest("revenue", limit=@okf.SearchLimit(10)))
```

### Domain types

Values with rules are types with smart constructors, so a value that breaks a
rule cannot exist. Parse raw text once, where it enters, and then pass the type.

| Type | Rule |
| --- | --- |
| `BundleLabel` | Segments joined with `/`; no segment is empty or has `:` or white space |
| `StoreDir`, `StorePath`, `BundlePath`, `EntryName` | No segment escapes the root; an entry name is one segment |
| `ConceptType` | Not blank; equal without letter case |
| `FieldKey` | A plain frontmatter key that edits can write |
| `RuleName` | Lower-case kebab case |
| `SearchLimit` | 1 to 1000 |
| `LogDate` | A real calendar date, `YYYY-MM-DD` |
| `RegisterName`, `StateName`, `RecordId`, `IdWidth` | Not blank; an ID width is 1 to 9 |

Each constructor raises a typed error (`ValueError` or `PathError`) that names
the input. Values that are valid by construction have constructors that cannot
fail, such as `StoreDir::root()`, `SearchLimit::default()` and
`LogDate::of_instant(instant)`. Fixed sets are enums: `OkfVersion`, `Facet`,
`ScanField`, `LinkOrigin`, `IndexHeading`, `LogHeading` and `FindingSubject`.
Free text, such as titles, descriptions and messages, stays a `String`.

Typed accessors cover every OKF v0.2 field: `sources`, `usage_window`,
`generated`, `verified` (a single mapping reads as a list), `status`,
`stale_after`, and the Attested Computation fields. `trust_tier()` derives the
tier from `verified`, and `is_stale(now)` compares `stale_after` with an instant
that the caller supplies. Unknown keys keep their source order, and every scalar
keeps its source text, so dates and timestamps stay as written.

`Options::default()` follows OKF v0.2. `Options::update` changes each known
difference between the specification and existing tools: the relative link base,
the status default, nested logs, date-only instants, the v0.1 field forms, and
whether index links count as backlinks.

## Validate

```moonbit
let report = @okf.validate(
  knowledge,
  [@okf.okf_v02_conformance(), @okf.advisory()],
  @okf.FixedClock::at("2026-10-23T00:00:00Z"),
  config=@okf.ValidationConfig(
    overrides=[(@okf.RuleName("link-broken"), Error)],
    disabled=[@okf.RuleName("duplicate-title")],
  ),
)
report.findings()      // sorted by severity, subject, line and rule
report.fails(strict=true)
```

A config that names a rule that no active rule set defines gives a
`validation-config-unknown-rule` warning, and a profile whose definitions break
a rule gives a `profile-invalid` error.

`okf_v02_conformance()` holds the OKF v0.2 section 11 rules. `advisory()` holds
rules that OKF tolerates, such as missing titles, broken links, stale concepts,
index coverage and description drift. The caller chooses their severities.

## Edit

Edits in `moonrockz/okf/edit` are pure: they take a text and return the new
text and whether it changed. They keep line endings, comments, key order and
quoting. Plans group edits until a caller applies them to a document set or a
store.

```moonbit
@edit.set_key(text, @okf.FieldKey("status"), "deprecated")
@edit.add_index_entry(index_text, @edit.SectionName("Metric"), @edit.IndexEntryLine("Revenue", "/metrics/revenue.md"))
@edit.add_log_entry(log_text, @okf.LogDate("2026-10-23"), "Added revenue.", label="Creation")
let plan = @edit.plan_add_concept(
  bundle, "/metrics/revenue.md", @okf.ConceptType("Metric"), "Revenue",
  "Net revenue per day", @okf.LogDate("2026-10-23"),
)
plan.render()          // a dry run
```

Raw YAML values are `RawYaml`, built with `RawYaml(text)`, `RawYaml::scalar`
or `RawYaml::list`. The planners raise one `PlanError` with a case for a
refused path, a failed edit and a refused transition.

## Stores, indexes and search

Storage, indexing and search are async traits in `moonrockz/okf/provider`.
`load(store)` reads documents into memory and then runs the core; `apply(plan,
store)` writes the changed documents.

| Runtime | Store |
| --- | --- |
| Tests, wasm-gc, any target | `@memory.MemoryStore` (its `snapshot()` is synchronous) |
| Native and wasm | `@fs.FsStore(@provider.StoreRoot(root))` |
| Node.js, Bun, Deno | `@node.NodeStore(@provider.StoreRoot(root))` |
| Browser, origin private file system | `@browser.BrowserStore::origin_private(path=@okf.StoreDir("kb"))` |
| Browser, a directory that the user selects | `@browser.BrowserStore(@browser.pick_directory())` |
| Browser or worker, IndexedDB | `@idb.IdbStore::open(database=@idb.DatabaseName("kb"))` |

MoonBit has one js target, so choose the Node.js or the browser store by the
package you import. A `StoreError` names a location relative to the store root
(`FileAt(StorePath)` or `DirectoryAt(StoreDir)`), never a host path, so every
store gives the same error for the same failure.

The browser store writes with one of three methods (`writes=`):

- `Writable` uses `FileSystemFileHandle.createWritable()` on the page.
- `SyncAccessWorker` sends each write to a dedicated worker that writes with
  `createSyncAccessHandle()`. The worker writes one file at a time, replaces
  the whole file in one session (truncate, write, flush, close), and closes the
  handle before it answers. When a step fails, it closes the handle and
  removes a file that it created. A failure after the truncate, such as a
  quota error during the write, can leave an existing file empty or partly
  written; `createWritable()` does not have this limit. The worker code is part
  of the package, so a page serves no extra file. One worker serves every store
  of the page. A worker that fails or does not answer within two minutes is
  stopped, and the next write starts a new one.
- The worker opens the origin private file system by itself, so worker writes
  need a store in that file system: a store from `origin_private`, or a store
  over `origin_private_root()` or a directory below it. A store over a
  directory that the user selected refuses worker writes with `InvalidPath`.
- `Auto`, the default, uses `createWritable()` when the browser has it, and the
  worker otherwise. The store chooses once, at its first write.

Safari 15.2 to 18 has no `createWritable()`, so `Auto` writes through the worker
there. Safari 26 has `createWritable()`; one report says that Safari 26.5 keeps a
temporary copy of each file that it writes, so `SyncAccessWorker` is a choice
there too. A page with a Content Security Policy needs `worker-src blob:` for the
worker; without it, a worker write fails with a store error that names
`worker-src blob:`. Reads, listings and deletes always run on the page.

`@idb.IdbStore` keeps each file in one record of an IndexedDB object store,
under its store path. A directory exists while a file is under it, and a file
cannot have the path of a directory or be under another file. Each write and
delete is one transaction, so a failed write, for example over the storage
quota, keeps the earlier content. When another connection upgrades or deletes
the database, the store opens its connection again at the next call. A browser can evict IndexedDB and origin
private data under storage pressure; for data that must stay, the application
can call `navigator.storage.persist()`. The library does not call it, because
the browser can show a prompt. `IdbStore::in_memory()` runs the same logic over
a map, for tests outside a browser.

`mise run test:browser` runs the store checks in Chromium, WebKit and Firefox.
WebKit in Playwright is close to Safari, but it is not the same browser.

`@memory.MemoryIndex` implements `IndexProvider` and
`SearchProvider` (BM25 over title, description, tags and body). A new provider,
for example over SQLite or RocksDB, proves its contract with
`@conformance.check_store`, `check_index` and `check_search`.

## Profiles

A profile adds conventions to OKF without changes to this module. Implement
`@okf.Profile`; every method has a default.

| Method | Adds |
| --- | --- |
| `vocabulary`, `bundle_keys` | Known frontmatter keys |
| `derive_metadata` | Metadata for a document without frontmatter |
| `registers` | Typed views of one concept type: record IDs, states, transitions with obligations, supersession |
| `reference_fields` | Fields whose values name documents or records |
| `templates` | Bodies for new concepts |
| `rule_sets`, `severities` | Validation rules and their preferred severities |
| `relations` | Links that a document implies |
| `options` | Preferred options |

`profile_conflicts` reports two profiles that define one key or register
differently. The tests hold a morphir reference profile, written with this API
only, that reproduces `morphir kb check` and `morphir kb decision list` on a copy
of the finos/morphir knowledge base.

## OpenSpec

`@openspec.OpenSpecProfile` reads an `openspec/` tree as a bundle. It derives
the types `Specification`, `Change` (the change's `proposal.md`), `Design`,
`Tasks` and `Spec Delta`, links changes to their capabilities, and adds checks:
the three that `openspec validate --strict` runs (a requirement without a
scenario, without `SHALL` or `MUST`, or with a wrong scenario heading) and two
that OpenSpec runs only at archive time (a `MODIFIED` or `REMOVED` requirement
that matches nothing, and a delta for a capability that does not exist). Two
more checks report content that the view leaves out: a rename with only a
`FROM:` or a `TO:` line, and a capability, change or requirement value that is
not a valid name, a requirement heading without a name, or a `state` that is
not `active` or `archived`. Export refuses a name that is not valid.
`@openspec.view(bundle)` gives requirements, scenarios,
deltas and tasks with typed names (`CapabilityPath`, `ChangeName`,
`RequirementName`, `TaskNumber`), types (`OpenSpecType`) and states
(`ChangeState`). Native bundles can also use `Requirement` and `Scenario`
concepts.

The profile parses each requirement text as EARS with `moonrockz/ears`: the
OpenSpec dialect (`SHALL` and `MUST`, the usual determiners, `it` and `they`,
the lead-in `otherwise`), the project lexicon file, and a lexicon in code. The
view gives each requirement its `sentences` and `sentence_diagnostics`, and a
pronoun refers to the system of an earlier sentence of the requirement.
`OpenSpecProfile::of_tree(set, root)` reads the project lexicon from
`ears.yaml` at the root of the tree; `OpenSpecProfile(lexicon=...)` takes one in
code. Pass the profile to `view(bundle, profile~)`.

```yaml
# openspec/ears.yaml
name: my-project
systems: [Mission Control, Text comparison]
lead_ins: [for each]
```

Two more checks cover EARS: `openspec-requirement-not-ears` (a warning) reports
a requirement sentence that does not parse, with its line and the reason, and
`openspec-lexicon-invalid` reports a lexicon file that does not parse; the
profile then parses with the other dialects. Archived changes are history, so
the EARS check skips them.

`import_openspec` plans a native OKF bundle from a tree, and `export_openspec`
plans the tree again; the round trip keeps every file.
