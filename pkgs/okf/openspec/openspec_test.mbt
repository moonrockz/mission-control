///|
let spec_text : String =
  #|# okf/documents Specification
  #|
  #|## Purpose
  #|
  #|Read OKF bundles into immutable values.
  #|
  #|## Requirements
  #|
  #|### Requirement: Concept IDs
  #|The library SHALL give each concept a Concept ID.
  #|
  #|#### Scenario: Concept ID from path
  #|- **WHEN** a bundle holds `/tables/customers.md`
  #|- **THEN** the concept has the Concept ID `tables/customers`
  #|- **AND** the ID compares equal to the same path
  #|

///|
let delta_text : String =
  #|# Spec Delta
  #|
  #|## MODIFIED Requirements
  #|
  #|### Requirement: Concept IDs
  #|The library SHALL give each concept a Concept ID without `.md`.
  #|
  #|#### Scenario: Concept ID from path
  #|- **WHEN** a bundle holds `/a.md`
  #|- **THEN** the ID is `a`
  #|
  #|## RENAMED Requirements
  #|
  #|- FROM: `### Requirement: Old name`
  #|- TO: `### Requirement: New name`
  #|

///|
fn tree() -> @okf.DocumentSet raise {
  @okf.DocumentSet::of_texts([
    ("openspec/config.yaml", "schema: spec-driven\n"),
    ("openspec/specs/okf/documents/spec.md", spec_text),
    (
      "openspec/changes/fix-ids/proposal.md", "## Why\n\nIDs keep the extension.\n\n## What Changes\n\n- Drop `.md`.\n",
    ),
    (
      "openspec/changes/fix-ids/tasks.md", "## 1. IDs\n\n- [x] 1.1 Drop the extension\n- [ ] 1.2 Add a test\n",
    ),
    ("openspec/changes/fix-ids/.openspec.yaml", "schema: spec-driven\n"),
    ("openspec/changes/fix-ids/specs/okf/documents/spec.md", delta_text),
    (
      "openspec/changes/archive/2026-01-01-first/proposal.md", "## Why\n\nFirst.\n",
    ),
    (
      "openspec/changes/archive/2026-01-01-first/specs/okf/documents/spec.md", "## ADDED Requirements\n\n### Requirement: X\nIt SHALL work.\n\n#### Scenario: Y\n- **WHEN** a\n- **THEN** b\n",
    ),
  ])
}

///|
fn profiles() -> Array[&@okf.Profile] {
  [@openspec.OpenSpecProfile()]
}

///|
fn tree_bundle() -> @okf.Bundle raise {
  @okf.load_bundle(tree(), root=@okf.StoreDir("openspec"), profiles=profiles())
}

///|
test "paths classify into OpenSpec kinds" {
  let k = (p : String) => @openspec.classify(@okf.BundlePath(p))
  let cap = @openspec.CapabilityPath("okf/documents")
  let a = @openspec.ChangeName("a")
  assert_eq(k("/specs/okf/documents/spec.md"), Some(SpecFile(capability=cap)))
  assert_eq(
    k("/changes/a/proposal.md"),
    Some(ProposalFile(change=a, state=Active)),
  )
  assert_eq(
    k("/changes/archive/2026-x/design.md"),
    Some(DesignFile(change=@openspec.ChangeName("2026-x"), state=Archived)),
  )
  assert_eq(
    k("/changes/a/specs/okf/documents/spec.md"),
    Some(DeltaFile(change=a, state=Active, capability=cap)),
  )
  assert_eq(k("/project.md"), None)
  // A path part that is not a valid name is not an OpenSpec file.
  assert_eq(k("/changes/CON/proposal.md"), None)
}

///|
test "a tree loads as a bundle with derived types" {
  let b = tree_bundle()
  let types = b
    .concepts()
    .map(d => {
      (
        d.path().to_string(),
        d.concept_type().map(t => t.to_string()).unwrap_or(""),
      )
    })
  assert_eq(types, [
    ("/changes/archive/2026-01-01-first/proposal.md", "Change"),
    (
      "/changes/archive/2026-01-01-first/specs/okf/documents/spec.md", "Spec Delta",
    ),
    ("/changes/fix-ids/proposal.md", "Change"),
    ("/changes/fix-ids/specs/okf/documents/spec.md", "Spec Delta"),
    ("/changes/fix-ids/tasks.md", "Tasks"),
    ("/specs/okf/documents/spec.md", "Specification"),
  ])
  guard b.document(
      @okf.BundlePath("/changes/archive/2026-01-01-first/proposal.md"),
    )
    is Some(archived) else {
    fail("no archived change")
  }
  assert_eq(archived.metadata().text("state"), Some("archived"))
}

///|
test "requirements, scenarios, deltas and tasks parse" {
  let v = @openspec.view(tree_bundle())
  let spec = v.specs[0]
  assert_eq(spec.capability.to_string(), "okf/documents")
  assert_eq(spec.purpose, Some("Read OKF bundles into immutable values."))
  let r = spec.requirements[0]
  assert_eq(r.name.to_string(), "Concept IDs")
  assert_eq(r.text, "The library SHALL give each concept a Concept ID.")
  assert_eq(r.scenarios[0].name, "Concept ID from path")
  assert_eq(r.scenarios[0].when_.iter().collect(), [
    "a bundle holds `/tables/customers.md`",
  ])
  assert_eq(r.scenarios[0].then_.iter().collect(), [
    "the concept has the Concept ID `tables/customers`", "the ID compares equal to the same path",
  ])
  let fix_ids = @openspec.ChangeName("fix-ids")
  guard v.changes.iter().find_first(c => c.name == fix_ids) is Some(change) else {
    fail("no change")
  }
  assert_eq(change.state, Active)
  assert_eq(change.deltas[0].deltas.iter().map(d => d.op).collect(), [
    Modified,
    Renamed,
  ])
  assert_eq(
    change.deltas[0].deltas[1].renames
    .iter()
    .map(r => (r.from.to_string(), r.to.to_string()))
    .collect(),
    [("Old name", "New name")],
  )
  assert_eq(
    change.task_groups[0].tasks
    .iter()
    .map(t => (t.number.map(n => n.to_string()), t.done))
    .collect(),
    [(Some("1.1"), true), (Some("1.2"), false)],
  )
}

///|
test "changes link to their capabilities, so specs have backlinks" {
  let b = tree_bundle()
  let k = @okf.Knowledge([b])
  let g = @okf.Graph::build(k, profiles=profiles())
  let spec : @okf.DocKey = {
    bundle: @okf.BundleLabel("openspec"),
    path: @okf.BundlePath("/specs/okf/documents/spec.md"),
  }
  let from = g.linked_from(spec).map(key => key.path.to_string())
  assert_true(from.contains("/changes/fix-ids/proposal.md"))
  assert_true(from.contains("/changes/archive/2026-01-01-first/proposal.md"))
  let change : @okf.DocKey = {
    bundle: @okf.BundleLabel("openspec"),
    path: @okf.BundlePath("/changes/fix-ids/proposal.md"),
  }
  let targets = g.outbound(change).map(e => e.link.destination)
  assert_true(targets.contains("/changes/fix-ids/tasks.md"))
}

///|
fn findings(set : @okf.DocumentSet) -> Array[String] raise {
  let b = @okf.load_bundle(
    set,
    root=@okf.StoreDir("openspec"),
    profiles=profiles(),
  )
  let report = @okf.validate(
    @okf.Knowledge([b]),
    [],
    @okf.FixedClock(@okf.Instant::of_millis(0L)),
    profiles=profiles(),
  )
  report.findings().map(f => f.rule.to_string()).iter().collect()
}

///|
test "the OpenSpec checks pass on a valid tree" {
  assert_eq(findings(tree()), [])
}

///|
test "the OpenSpec checks find each problem" {
  let bad = tree()
    .with_entry({
      path: @okf.StorePath("openspec/changes/bad/specs/okf/documents/spec.md"),
      content: Text(
        "## MODIFIED Requirements\n\n### Requirement: Missing\nIt works.\n\n### Scenario: Wrong level\n- **WHEN** a\n- **THEN** b\n",
      ),
    })
    .with_entry({
      path: @okf.StorePath("openspec/changes/bad/specs/nothing/spec.md"),
      content: Text(
        "## REMOVED Requirements\n\n### Requirement: Gone\nIt SHALL go.\n\n#### Scenario: Z\n- **WHEN** a\n- **THEN** b\n",
      ),
    })
  let rules = findings(bad)
  assert_true(rules.contains("openspec-requirement-no-scenario"))
  assert_true(rules.contains("openspec-requirement-no-shall"))
  assert_true(rules.contains("openspec-scenario-heading"))
  assert_true(rules.contains("openspec-modified-unknown"))
  assert_true(rules.contains("openspec-delta-unknown-capability"))
}

///|
test "import creates native concepts, an index and a log" {
  let plan = @openspec.import_openspec(
    tree(),
    @okf.StoreDir("openspec"),
    @okf.StoreDir("kb"),
    @okf.LogDate("2026-10-23"),
  )
  let paths = plan.changes().map(c => c.path().to_string()).iter().collect()
  assert_true(paths.contains("kb/specs/okf/documents/spec.md"))
  assert_true(paths.contains("kb/changes/fix-ids/proposal.md"))
  assert_true(paths.contains("kb/changes/fix-ids/.openspec.yaml"))
  assert_true(paths.contains("kb/index.md"))
  assert_true(paths.contains("kb/log.md"))
  let set = plan.apply_to(@okf.DocumentSet([]))
  guard set.get(@okf.StorePath("kb/index.md")) is Some(index) else {
    fail("no index")
  }
  assert_true(
    index.content.text().has_prefix("---\nokf_version: \"0.2\"\n---\n"),
  )
  let native = @okf.discover(set)
  assert_eq(native.bundles().length(), 1)
  let report = @okf.validate(
    native,
    [@okf.okf_v02_conformance()],
    @okf.FixedClock(@okf.Instant::of_millis(0L)),
  )
  assert_eq(report.count(Error), 0)
}

///|
test "native and tree forms give the same view, and the round trip keeps every file" {
  let original = tree()
  let imported = @openspec.import_openspec(
    original,
    @okf.StoreDir("openspec"),
    @okf.StoreDir("kb"),
    @okf.LogDate("2026-10-23"),
  ).apply_to(@okf.DocumentSet([]))
  let native = @okf.load_bundle(imported, root=@okf.StoreDir("kb"))
  let tree_view = @openspec.view(tree_bundle())
  assert_eq(@openspec.view(native).without_lines(), tree_view.without_lines())
  let exported = @openspec.export_openspec(
    imported,
    @okf.StoreDir("kb"),
    @okf.StoreDir("openspec"),
  ).apply_to(@okf.DocumentSet([]))
  assert_eq(
    exported.entries().map(e => (e.path.to_string(), e.content.text())),
    original.entries().map(e => (e.path.to_string(), e.content.text())),
  )
}

///|
test "export merges native Requirement and Scenario concepts" {
  let set = @okf.DocumentSet::of_texts([
    ("kb/index.md", "---\nokf_version: \"0.2\"\n---\n"),
    (
      "kb/specs/a.md", "---\ntype: Specification\ncapability: a\n---\n# a Specification\n\n## Purpose\n\nA thing.\n",
    ),
    (
      "kb/reqs/r1.md", "---\ntype: Requirement\ncapability: a\nrequirement: Works\norder: 1\n---\nIt SHALL work.\n",
    ),
    (
      "kb/reqs/s1.md", "---\ntype: Scenario\ncapability: a\nrequirement: Works\nscenario: Simple\n---\n- **WHEN** used\n- **THEN** it works\n",
    ),
  ])
  let native = @okf.load_bundle(set, root=@okf.StoreDir("kb"))
  let v = @openspec.view(native)
  assert_eq(
    v.specs[0].requirements
    .iter()
    .map(r => (r.name.to_string(), r.scenarios.length()))
    .collect(),
    [("Works", 1)],
  )
  let out = @openspec.export_openspec(
    set,
    @okf.StoreDir("kb"),
    @okf.StoreDir::root(),
  ).apply_to(@okf.DocumentSet([]))
  guard out.get(@okf.StorePath("specs/a/spec.md")) is Some(spec) else {
    fail("no spec")
  }
  assert_eq(
    spec.content.text(),
    "# a Specification\n\n## Purpose\n\nA thing.\n\n## Requirements\n\n### Requirement: Works\nIt SHALL work.\n\n#### Scenario: Simple\n- **WHEN** used\n- **THEN** it works\n",
  )
}

///|
test "import and export keep binary assets byte for byte" {
  let png = b"\x89PNG\r\n\x1a\n\x00\xfe\xff"
  let original = tree().with_entry({
    path: @okf.StorePath("openspec/changes/fix-ids/diagram.png"),
    content: Bytes(png),
  })
  let imported = @openspec.import_openspec(
    original,
    @okf.StoreDir("openspec"),
    @okf.StoreDir("kb"),
    @okf.LogDate("2026-10-23"),
  ).apply_to(@okf.DocumentSet([]))
  assert_eq(
    imported
    .get(@okf.StorePath("kb/changes/fix-ids/diagram.png"))
    .map(e => e.content),
    Some(Bytes(png)),
  )
  let exported = @openspec.export_openspec(
    imported,
    @okf.StoreDir("kb"),
    @okf.StoreDir("openspec"),
  ).apply_to(@okf.DocumentSet([]))
  assert_eq(
    exported
    .get(@okf.StorePath("openspec/changes/fix-ids/diagram.png"))
    .map(e => e.content),
    Some(Bytes(png)),
  )
}

///|
test "export refuses capability and change names that leave the target" {
  for
    bad in [
      ("capability", "../../evil"),
      ("capability", "a//b"),
      ("change", "../x"),
      ("change", "a/b"),
    ] {
    let (key, value) = bad
    let concept = if key == "capability" {
      "---\ntype: Specification\ncapability: \{value}\n---\n# x\n"
    } else {
      "---\ntype: Change\nchange: \{value}\n---\n## Why\n"
    }
    let set = @okf.DocumentSet::of_texts([
      ("kb/index.md", "---\nokf_version: \"0.2\"\n---\n"),
      ("kb/x.md", concept),
    ])
    let refused = try
      @openspec.export_openspec(set, @okf.StoreDir("kb"), @okf.StoreDir("out"))
    catch {
      @openspec.BadName(InvalidName(key=k, value=v)) => k == key && v == value
      _ => false
    } noraise {
      _ => false
    }
    assert_true(refused, msg=value)
  }
}

///|
fn name_error(f : () -> Unit raise @openspec.NameError) -> String? {
  try f() catch {
    InvalidName(key~, ..) => Some(key)
  } noraise {
    _ => None
  }
}

///|
test "OpenSpec names keep their rules" {
  assert_eq(
    name_error(() => @openspec.CapabilityPath("okf/documents") |> ignore),
    None,
  )
  for bad in ["", "a//b", "../x", "a/.", "a/CON", "a:b"] {
    assert_eq(
      name_error(() => @openspec.CapabilityPath(bad) |> ignore),
      Some("capability"),
      msg=bad,
    )
  }
  assert_eq(name_error(() => @openspec.ChangeName("add-x") |> ignore), None)
  for bad in ["", "a/b", "..", "x.", "nul"] {
    assert_eq(
      name_error(() => @openspec.ChangeName(bad) |> ignore),
      Some("change"),
      msg=bad,
    )
  }
  assert_eq(
    @openspec.RequirementName("  Typed names ").to_string(),
    "Typed names",
  )
  for bad in ["", "  ", "a\nb"] {
    assert_eq(
      name_error(() => @openspec.RequirementName(bad) |> ignore),
      Some("requirement"),
      msg=bad,
    )
  }
  for bad in ["", "0", "1.", ".1", "1..2", "1.0", "a", "1234567890"] {
    assert_eq(
      name_error(() => @openspec.TaskNumber(bad) |> ignore),
      Some("task"),
      msg=bad,
    )
  }
  assert_true(@openspec.TaskNumber("1.2") < @openspec.TaskNumber("1.10"))
  assert_true(@openspec.TaskNumber("1") < @openspec.TaskNumber("1.1"))
  assert_eq(@openspec.TaskNumber("999999999").parts().iter().collect(), [
    999999999,
  ])
}

///|
test "an archived change has the archived state, and a task without a number has none" {
  let v = @openspec.view(tree_bundle())
  let first = @openspec.ChangeName("2026-01-01-first")
  guard v.changes.iter().find_first(c => c.name == first) is Some(change) else {
    fail("no archived change")
  }
  assert_eq(change.state, Archived)
  let groups = @openspec.parse_tasks([(1, "- [ ] Write the docs")])
  assert_eq(groups[0].tasks[0].number, None)
  assert_eq(groups[0].tasks[0].text, "Write the docs")
}

///|
test "a rename without TO gives no rename and a finding" {
  let set = tree()
    .with_entry({
      path: @okf.StorePath("openspec/changes/half/proposal.md"),
      content: Text("## Why\n\nHalf a rename.\n"),
    })
    .with_entry({
      path: @okf.StorePath("openspec/changes/half/specs/okf/documents/spec.md"),
      content: Text(
        "## RENAMED Requirements\n\n- FROM: `### Requirement: Concept IDs`\n",
      ),
    })
  let b = @okf.load_bundle(
    set,
    root=@okf.StoreDir("openspec"),
    profiles=profiles(),
  )
  let half = @openspec.ChangeName("half")
  guard @openspec.view(b).changes.iter().find_first(c => c.name == half)
    is Some(change) else {
    fail("no change")
  }
  let section = change.deltas[0].deltas[0]
  assert_eq(section.renames.length(), 0)
  assert_eq(section.incomplete_renames.length(), 1)
  assert_eq(findings(set), ["openspec-rename-incomplete"])
}

///|
test "a native concept with an invalid name is left out of the view and reported" {
  let set = @okf.DocumentSet::of_texts([
    ("kb/index.md", "---\nokf_version: \"0.2\"\n---\n"),
    ("kb/x.md", "---\ntype: Specification\ncapability: ../x\n---\n# x\n"),
  ])
  let b = @okf.load_bundle(set, root=@okf.StoreDir("kb"), profiles=profiles())
  assert_eq(@openspec.view(b).specs.length(), 0)
  let report = @okf.validate(
    @okf.Knowledge([b]),
    [],
    @okf.FixedClock(@okf.Instant::of_millis(0L)),
    profiles=profiles(),
  )
  assert_eq(report.findings().map(f => f.rule.to_string()).iter().collect(), [
    "openspec-invalid-name",
  ])
}

///|
test "export refuses names that a Windows file system cannot hold" {
  for value in ["x.", "x ", "CON", "com1.txt", "nul"] {
    let set = @okf.DocumentSet::of_texts([
      ("kb/index.md", "---\nokf_version: \"0.2\"\n---\n"),
      ("kb/x.md", "---\ntype: Change\nchange: \"\{value}\"\n---\n## Why\n"),
    ])
    let refused = try
      @openspec.export_openspec(set, @okf.StoreDir("kb"), @okf.StoreDir("out"))
    catch {
      @openspec.BadName(_) => true
      _ => false
    } noraise {
      _ => false
    }
    assert_true(refused, msg=value)
  }
}

///|
test "requirement headings keep backticks, and a heading without a name is no requirement" {
  let model = @openspec.parse_spec(@openspec.CapabilityPath("a"), [
    (1, "## Requirements"),
    (2, "### Requirement: Parse `okf_version`"),
    (3, "It SHALL parse."),
    (4, "### Requirement:"),
    (5, "Orphan text."),
    (6, "#### Scenario: Orphan"),
    (7, "- **WHEN** a"),
    (8, "- **THEN** b"),
  ])
  assert_eq(
    model.requirements
    .iter()
    .map(r => (r.name.to_string(), r.text, r.scenarios.length(), r.line))
    .collect(),
    [("Parse `okf_version`", "It SHALL parse.", 0, 2)],
  )
  assert_eq(model.unnamed_requirements.iter().collect(), [4])
  let set = tree()
    .with_entry({
      path: @okf.StorePath("openspec/changes/blank/proposal.md"),
      content: Text("## Why\n\nA blank heading.\n"),
    })
    .with_entry({
      path: @okf.StorePath("openspec/changes/blank/specs/okf/documents/spec.md"),
      content: Text(
        "## ADDED Requirements\n\n### Requirement:\nIt SHALL work.\n\n#### Scenario: Y\n- **WHEN** a\n- **THEN** b\n",
      ),
    })
  assert_eq(findings(set), ["openspec-invalid-name"])
}

///|
test "a Scenario concept attaches to a requirement name with backticks" {
  let set = @okf.DocumentSet::of_texts([
    ("kb/index.md", "---\nokf_version: \"0.2\"\n---\n"),
    (
      "kb/specs/a.md", "---\ntype: Specification\ncapability: a\n---\n## Requirements\n\n### Requirement: Parse `x`\nIt SHALL parse.\n",
    ),
    (
      "kb/s1.md", "---\ntype: Scenario\ncapability: a\nrequirement: Parse `x`\nscenario: Simple\n---\n- **WHEN** used\n- **THEN** it parses\n",
    ),
  ])
  let native = @okf.load_bundle(set, root=@okf.StoreDir("kb"))
  let req = @openspec.view(native).specs[0].requirements[0]
  assert_eq(req.name.to_string(), "Parse `x`")
  assert_eq(req.scenarios.iter().map(s => (s.name, s.line)).collect(), [
    ("Simple", 5),
  ])
}

///|
test "an invalid change state and a missing name are reported" {
  let set = @okf.DocumentSet::of_texts([
    ("kb/index.md", "---\nokf_version: \"0.2\"\n---\n"),
    ("kb/c.md", "---\ntype: Change\nchange: c\nstate: done\n---\n## Why\n"),
    ("kb/s.md", "---\ntype: Specification\n---\n# s\n"),
  ])
  let b = @okf.load_bundle(set, root=@okf.StoreDir("kb"), profiles=profiles())
  let report = @okf.validate(
    @okf.Knowledge([b]),
    [],
    @okf.FixedClock(@okf.Instant::of_millis(0L)),
    profiles=profiles(),
  )
  assert_eq(
    report
    .findings()
    .map(f => (f.rule.to_string(), f.line, f.message))
    .iter()
    .collect(),
    [
      (
        "openspec-invalid-name",
        Some(4),
        "the `state` value `done` is not `active` or `archived`",
      ),
      (
        "openspec-invalid-name",
        None,
        "the Specification concept has no `capability`",
      ),
    ],
  )
}

///|
test "export refuses an invalid requirement name instead of dropping it" {
  let set = @okf.DocumentSet::of_texts([
    ("kb/index.md", "---\nokf_version: \"0.2\"\n---\n"),
    ("kb/a.md", "---\ntype: Specification\ncapability: a\n---\n# a\n"),
    (
      "kb/r.md", "---\ntype: Requirement\ncapability: a\nrequirement: \"  \"\n---\nIt SHALL work.\n",
    ),
  ])
  let refused = try
    @openspec.export_openspec(set, @okf.StoreDir("kb"), @okf.StoreDir("out"))
  catch {
    @openspec.BadName(InvalidName(key~, ..)) => key == "requirement"
    _ => false
  } noraise {
    _ => false
  }
  assert_true(refused)
}

///|
test "task numbers are normalized, and tasks before a heading have no group heading" {
  let a = @openspec.TaskNumber("01.2")
  let b = @openspec.TaskNumber("1.2")
  assert_eq(a, b)
  assert_eq(a.compare(b), 0)
  assert_eq(a.to_string(), "1.2")
  let groups = @openspec.parse_tasks([
    (1, "- [ ] 1.1 First"),
    (2, "## 2. Later"),
    (3, "- [ ] 2.1 Second"),
  ])
  assert_eq(groups.map(g => g.heading), [None, Some("2. Later")])
}

///|
/// A tree with one capability whose requirement has the text `text`.
fn ears_tree(text : String, lexicon? : String) -> @okf.DocumentSet raise {
  let spec = "# a Specification\n\n## Purpose\n\nA thing.\n\n## Requirements\n\n### Requirement: Listing\n\{text}\n\n#### Scenario: List\n- **WHEN** a caller lists\n- **THEN** the store lists\n"
  let files = [("openspec/specs/a/spec.md", spec)]
  match lexicon {
    Some(l) => files.push(("openspec/ears.yaml", l))
    None => ()
  }
  @okf.DocumentSet::of_texts(files)
}

///|
fn ears_findings(
  set : @okf.DocumentSet,
  profile : @openspec.OpenSpecProfile,
) -> Array[(String, String, Int32?)] raise {
  let profiles : Array[&@okf.Profile] = [profile]
  let b = @okf.load_bundle(set, root=@okf.StoreDir("openspec"), profiles~)
  @okf.validate(
    @okf.Knowledge([b]),
    [],
    @okf.FixedClock(@okf.Instant::of_millis(0L)),
    profiles~,
  )
  .findings()
  .map(f => (f.rule.to_string(), f.subject.path_text().unwrap_or(""), f.line))
  .iter()
  .collect()
}

///|
test "the view gives the EARS sentences of each requirement" {
  let set = ears_tree("The store SHALL list files. It SHALL sort them by path.")
  let profile = @openspec.OpenSpecProfile::of_tree(
    set,
    @okf.StoreDir("openspec"),
  )
  let b = @okf.load_bundle(set, root=@okf.StoreDir("openspec"), profiles=[
    profile,
  ])
  let r = @openspec.view(b, profile~).specs[0].requirements[0]
  assert_eq(r.sentences.length(), 2)
  assert_eq(r.sentence_diagnostics.length(), 0)
  assert_eq(r.sentences[1].requirement().resolved_system(), Some("store"))
  assert_eq(r.text_lines.iter().collect(), [10])
}

///|
test "a project lexicon file and a lexicon in code add words" {
  let text = "Mission Control SHALL publish one version."
  let with_file = ears_tree(text, lexicon="systems: [Mission Control]\n")
  let profile = @openspec.OpenSpecProfile::of_tree(
    with_file,
    @okf.StoreDir("openspec"),
  )
  assert_eq(ears_findings(with_file, profile), [])
  let without = ears_tree(text)
  assert_eq(
    ears_findings(
      without,
      @openspec.OpenSpecProfile::of_tree(without, @okf.StoreDir("openspec")),
    ).map(f => f.0),
    ["openspec-requirement-not-ears"],
  )
  let in_code = @openspec.OpenSpecProfile(
    lexicon=@ears.Lexicon(systems=[@ears.Phrase("Mission Control")]),
  )
  assert_eq(ears_findings(without, in_code), [])
}

///|
test "an invalid lexicon file is reported, and requirements still parse" {
  let set = ears_tree(
    "The store SHALL list files. It SHALL sort them by path.",
    lexicon="systems: [\n",
  )
  let profile = @openspec.OpenSpecProfile::of_tree(
    set,
    @okf.StoreDir("openspec"),
  )
  assert_true(profile.lexicon_error() is Some(InvalidLexiconFile(..)))
  let findings = ears_findings(set, profile)
  assert_eq(findings.map(f => (f.0, f.1)), [
    ("openspec-lexicon-invalid", "/ears.yaml"),
  ])
  let b = @okf.load_bundle(set, root=@okf.StoreDir("openspec"), profiles=[
    profile,
  ])
  assert_eq(
    @openspec.view(b, profile~).specs[0].requirements[0].sentences.length(),
    2,
  )
}

///|
test "a sentence that is not EARS is reported with its line" {
  let set = ears_tree(
    "The store SHALL list files.\nFast responses are important.",
  )
  let profile = @openspec.OpenSpecProfile::of_tree(
    set,
    @okf.StoreDir("openspec"),
  )
  assert_eq(ears_findings(set, profile), [
    ("openspec-requirement-not-ears", "/specs/a/spec.md", Some(11)),
  ])
}

///|
test "finding lines follow the file after a fenced block, and list markers are read" {
  let text = "The store SHALL list files.\n\n```text\na\nb\n```\n\nFast responses are important.\n\n- The store SHALL sort them.\n\n**The store** SHALL keep them."
  let set = ears_tree(text)
  let profile = @openspec.OpenSpecProfile::of_tree(
    set,
    @okf.StoreDir("openspec"),
  )
  let findings = ears_findings(set, profile)
  assert_eq(findings.map(f => (f.0, f.2)), [
    ("openspec-requirement-not-ears", Some(17)),
  ])
}

///|
test "an invalid lexicon file under a root that no bundle has is still reported" {
  let set = ears_tree("The store SHALL list files.", lexicon="systems: [\n")
  let profile = @openspec.OpenSpecProfile::of_tree(
    set,
    @okf.StoreDir("openspec"),
  )
  let profiles : Array[&@okf.Profile] = [profile]
  let b = @okf.load_bundle(set, root=@okf.StoreDir("openspec/specs"), profiles~)
  let findings = @okf.validate(
    @okf.Knowledge([b]),
    [],
    @okf.FixedClock(@okf.Instant::of_millis(0L)),
    profiles~,
  ).findings()
  assert_true(
    findings
    .iter()
    .any(f => {
      f.rule.to_string() == "openspec-lexicon-invalid" &&
      f.subject.path_text() == Some("openspec/ears.yaml")
    }),
  )
}
