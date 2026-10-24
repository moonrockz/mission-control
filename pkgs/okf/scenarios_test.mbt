///|
fn set_of(files : Array[(String, String)]) -> @okf.DocumentSet raise {
  @okf.DocumentSet::of_texts(files)
}

///|
test "GitHub source URL parts" {
  let p = @okf.GitHubSource(
    "https://github.com/finos/morphir/blob/ab8d5c91/spec/ir.md",
  )
  assert_eq(
    (p.org(), p.repo(), p.commit().to_string(), p.path()),
    ("finos", "morphir", "ab8d5c91", "spec/ir.md"),
  )
  let errors = [
    "https://github.com/finos/morphir/blob/main/x.md", "https://gitlab.com/a/b/blob/ab8d5c91/x.md",
    "https://github.com/finos/morphir/blob/ab8d5c91/", "https://github.com//morphir/blob/ab8d5c91/x.md",
    "https://github.com/finos/morphir/blob/ab8d5c/x.md",
  ].map(url => {
    let e = try @okf.GitHubSource(url) catch {
      e => e
    } noraise {
      _ => fail("parsed \{url}")
    }
    match e {
      NotGitHub(_) => "not-github"
      MissingPart(_) => "missing-part"
      NotACommit(_) => "not-a-commit"
    }
  })
  assert_eq(errors, [
    "not-a-commit", "not-github", "missing-part", "missing-part", "not-a-commit",
  ])
  // 7 and 40 hexadecimal characters are the limits.
  assert_eq(@okf.CommitSha("abcdef0").to_string(), "abcdef0")
  let forty = "a".repeat(40)
  assert_eq(@okf.CommitSha(forty).to_string(), forty)
  let too_long = try @okf.CommitSha("a".repeat(41)) catch {
    _ => None
  } noraise {
    c => Some(c)
  }
  assert_eq(too_long, None)
}

///|
test "document references parse labels and paths at the boundary" {
  let same = @okf.DocRef("/tables/orders.md")
  assert_eq(same.bundle(), None)
  assert_eq(same.path().to_string(), "/tables/orders.md")
  let other = @okf.DocRef("morphir/ir:/names.md")
  assert_eq(other.bundle().map(l => l.to_string()), Some("morphir/ir"))
  let kinds = ["names.md", ":/names.md", "Bad Label:/names.md", "ir:/../x.md"].map(text => {
      let e = try @okf.DocRef(text) catch {
        e => e
      } noraise {
        _ => fail("parsed \{text}")
      }
      match e {
        NotADocRef(_) => "not-a-ref"
        BadLabel(..) => "bad-label"
        BadPath(..) => "bad-path"
      }
    },
  )
  assert_eq(kinds, ["not-a-ref", "not-a-ref", "bad-label", "bad-path"])
}

///|
test "typed references: a source that points to a concept, and an unresolved one" {
  let k = @okf.discover(
    set_of([
      ("index.md", "---\nokf_version: \"0.2\"\n---\n"),
      ("references/ga4-docs.md", "---\ntype: Reference\n---\n"),
      (
        "tables/events.md", "---\ntype: Table\nsources:\n  - resource: /references/ga4-docs.md\n  - resource: /references/missing.md\n  - resource: all queries in project X\n---\n",
      ),
    ]),
  )
  let b = k.bundles()[0]
  guard b.document(@okf.BundlePath("/tables/events.md")) is Some(doc) else {
    fail("no doc")
  }
  let refs = @okf.typed_references(k, b, doc)
  assert_eq(refs.map(r => r.is_resolved()), [true, false, true])
  assert_true(refs[0].target is ToDocument(_))
  assert_true(refs[2].target is FreeText(_))
}

///|
test "a cross-bundle link resolves and gives a backlink" {
  let k = @okf.discover(
    set_of([
      ("bundles/morphir/ir/index.md", "---\nokf_version: \"0.2\"\n---\n"),
      ("bundles/morphir/ir/names.md", "---\ntype: Design Note\n---\n"),
      ("bundles/morphir/cli/index.md", "---\nokf_version: \"0.2\"\n---\n"),
      (
        "bundles/morphir/cli/use.md", "---\ntype: Design Note\n---\nSee [names](../ir/names.md).\n",
      ),
    ]),
    under=@okf.StoreDir("bundles"),
  )
  let g = @okf.Graph::build(k)
  let names : @okf.DocKey = {
    bundle: @okf.BundleLabel("morphir/ir"),
    path: @okf.BundlePath("/names.md"),
  }
  assert_eq(g.linked_from(names).map(key => key.to_string()), [
    "morphir/cli:/use.md",
  ])
}

///|
test "a resolver that knows files outside the bundle" {
  let set = set_of([
    ("kb/index.md", "---\nokf_version: \"0.2\"\n---\n"),
    ("kb/a.md", "---\ntype: Note\n---\nSee [spec](../spec/x.md).\n"),
  ])
  let k = @okf.discover(set)
  assert_eq(@okf.Graph::build(k).broken().length(), 1)
  let resolver : &@okf.LinkResolver = @okf.PathListResolver([
    @okf.StorePath("spec/x.md"),
  ])
  assert_eq(@okf.Graph::build(k, resolver~).broken().length(), 0)
}

///|
test "an ambiguous bare bundle name" {
  let k = @okf.discover(
    set_of([
      ("morphir/ir/index.md", "---\nokf_version: \"0.2\"\n---\n"),
      ("finos/ir/index.md", "---\nokf_version: \"0.2\"\n---\n"),
    ]),
  )
  guard k.bundle(@okf.BundleLabel("ir")) is Ambiguous(list) else {
    fail("expected an ambiguous lookup")
  }
  assert_eq(list.map(b => b.label().to_string()), ["finos/ir", "morphir/ir"])
  assert_true(k.bundle(@okf.BundleLabel("morphir/ir")) is Found(_))
}

///|
test "padded record IDs and duplicate IDs" {
  let reg = @okf.Register(
    @okf.RegisterName("decision"),
    @okf.ConceptType("Decision Record"),
  )
  let b = @okf.load_bundle(
    set_of([
      ("decisions/42-use-yaml.md", "---\ntype: Decision Record\n---\n"),
      ("decisions/0042-also.md", "---\ntype: Decision Record\n---\n"),
      ("decisions/7-other.md", "---\ntype: decision record\n---\n"),
    ]),
  )
  let records = reg.records(b)
  assert_eq(records.map(r => r.id.map(i => i.to_string()).unwrap_or("")), [
    "0042", "0042", "0007",
  ])
  assert_eq(reg.duplicates(records).map(d => (d.0.to_string(), d.1.length())), [
    ("0042", 2),
  ])
  assert_true(reg.find(records, "42") is Ambiguous(_))
}

///|
priv struct NamedOnly {}

///|
impl @okf.Profile for NamedOnly with fn name(_) {
  "named-only"
}

///|
priv struct StateProfile {
  values : Array[String]
}

///|
impl @okf.Profile for StateProfile with fn name(self) {
  "state-" + self.values.join("-")
}

///|
impl @okf.Profile for StateProfile with fn vocabulary(self) {
  [@okf.KeyDefinition(@okf.FieldKey("state"), values=self.values)]
}

///|
test "an empty profile changes nothing, and conflicting profiles are reported" {
  let set = set_of([
    ("a.md", "---\ntype: Note\n---\n"),
    ("b.md", "# No frontmatter\n"),
  ])
  let plain = @okf.load_bundle(set)
  let with_profile = @okf.load_bundle(set, profiles=[NamedOnly::{ }])
  assert_eq(
    with_profile.documents().map(d => d.metadata().keys()),
    plain.documents().map(d => d.metadata().keys()),
  )
  let a : &@okf.Profile = StateProfile::{ values: ["open", "closed"], }
  let b : &@okf.Profile = StateProfile::{ values: ["Backlog"], }
  assert_eq(@okf.profile_conflicts([a, b]), [
    KeyConflict(
      key=@okf.FieldKey("state"),
      first="state-open-closed",
      second="state-Backlog",
    ),
  ])
  assert_eq(@okf.profile_conflicts([a, a]), [])
}

///|
test "findings carry their fields and keep a stable order" {
  let k = @okf.discover(
    set_of([
      ("index.md", "---\nokf_version: \"0.2\"\n---\n"),
      ("tables/orders.md", "---\ntitle: Orders\n---\n"),
      ("tables/index.md", "---\ntitle: bad\n---\n"),
      ("log.md", "# Log\n\n## Yesterday\n"),
    ]),
  )
  let clock = @okf.FixedClock(@okf.Instant::of_millis(0L))
  let first = @okf.validate(k, [@okf.okf_v02_conformance()], clock)
  let second = @okf.validate(k, [@okf.okf_v02_conformance()], clock)
  assert_eq(first.findings(), second.findings())
  let rows = first
    .findings()
    .map(f => {
      (f.severity.to_string(), f.rule.to_string(), f.subject.path_text())
    })
    .iter()
    .collect()
  assert_eq(rows, [
    ("error", "log-undated-section", "/log.md"),
    ("error", "subindex-has-frontmatter", "/tables/index.md"),
    ("error", "concept-missing-type", "/tables/orders.md"),
  ])
}

///|
test "a generated root index keeps okf_version" {
  let b = @okf.load_bundle(
    set_of([
      ("index.md", "---\nokf_version: \"0.2\"\n---\n"),
      ("a.md", "---\ntype: Note\ntitle: A\n---\n"),
      ("sub/b.md", "---\ntype: Note\n---\n"),
    ]),
  )
  assert_eq(
    @okf.generate_index(b, describe=_ => Some("More notes")),
    "---\nokf_version: \"0.2\"\n---\n\n# Note\n\n* [A](a.md)\n\n# Subdirectories\n\n* [sub](sub/index.md) - More notes\n",
  )
}

///|
test "root-only logs report nested logs as ignored" {
  let set = set_of([("log.md", "# Log\n"), ("tables/log.md", "# Log\n")])
  let options = @okf.Options::default().update(nested_logs=RootOnly)
  let b = @okf.load_bundle(set, options~)
  assert_eq(b.logs().map(d => d.path().to_string()), ["/log.md"])
  assert_eq(b.ignored_logs().map(p => p.to_string()).iter().collect(), [
    "/tables/log.md",
  ])
  assert_eq(@okf.load_bundle(set).logs().length(), 2)
}

///|
test "v0.1 timestamp reads as generated.at only with the option" {
  let m = @okf.Metadata("type: A\ntimestamp: 2026-06-12T00:00:00Z\n")
  assert_eq(m.generated(), None)
  let v01 = @okf.Options::default().update(v01_fields=true)
  assert_eq(
    m.generated(options=v01).map(g => g.at),
    Some(Some("2026-06-12T00:00:00Z")),
  )
}

///|
test "derived metadata is marked and does not change the text" {
  let set = set_of([("specs/a/spec.md", "# a Specification\n")])
  let b = @okf.load_bundle(set, profiles=[TypeFromPath::{ }])
  guard b.document(@okf.BundlePath("/specs/a/spec.md")) is Some(doc) else {
    fail("no doc")
  }
  assert_eq(doc.concept_type().map(t => t.to_string()), Some("Specification"))
  assert_true(doc.is_derived())
  assert_eq(doc.text(), "# a Specification\n")
}

///|
priv struct TypeFromPath {}

///|
impl @okf.Profile for TypeFromPath with fn name(_) {
  "type-from-path"
}

///|
impl @okf.Profile for TypeFromPath with fn derive_metadata(_, doc) {
  if doc.path().name() == "spec.md" {
    Some(@okf.Fields([("type", Scalar("Specification"))]))
  } else {
    None
  }
}

///|
test "a bundle at the discovery root has no group" {
  let root = @okf.discover(
    set_of([("index.md", "---\nokf_version: \"0.2\"\n---\n")]),
  )
  assert_eq(
    root
    .bundles()
    .map(b => (b.label().to_string(), b.group().length()))
    .iter()
    .collect(),
    [(".", 0)],
  )
  let under = @okf.discover(
    set_of([
      ("kb/index.md", "---\nokf_version: \"0.2\"\n---\n"),
      ("kb/a.md", "---\ntype: A\n---\n"),
    ]),
    under=@okf.StoreDir("kb"),
  )
  assert_eq(
    under
    .bundles()
    .map(b => (b.label().to_string(), b.concepts().length()))
    .iter()
    .collect(),
    [("kb", 1)],
  )
}

///|
test "a concept named like an index is not an index for orphan checks" {
  let k = @okf.discover(
    set_of([
      ("index.md", "---\nokf_version: \"0.2\"\n---\n"),
      ("reindex.md", "---\ntype: Note\n---\nSee [a](/a.md).\n"),
      ("a.md", "---\ntype: Note\n---\n"),
    ]),
  )
  let orphans = @okf.Graph::build(k).orphans(k).map(key => key.path.to_string())
  assert_eq(orphans, ["/reindex.md"])
}

///|
test "a log heading that is not a real date is undated" {
  let b = @okf.load_bundle(
    set_of([
      ("log.md", "# Log\n\n## 2026-13-45\n\n## 2026-02-30\n\n## 2026-10-23\n"),
    ]),
  )
  guard b.root_log() is Some(log) else { fail("no log") }
  assert_eq(
    log.log_model().undated_sections().map(s => s.heading.to_string()),
    ["2026-13-45", "2026-02-30"],
  )
}

///|
priv struct BrokenProfile {}

///|
impl @okf.Profile for BrokenProfile with fn name(_) {
  "broken"
}

///|
impl @okf.Profile for BrokenProfile with fn severities(_) {
  [(@okf.RuleName("Not Kebab"), Warning)]
}

///|
priv struct DanglingRef {}

///|
impl @okf.Profile for DanglingRef with fn name(_) {
  "dangling"
}

///|
impl @okf.Profile for DanglingRef with fn reference_fields(_) {
  [
    {
      key: @okf.FieldKey("decision"),
      kind: RecordRef(register=@okf.RegisterName("decision")),
    },
  ]
}

///|
test "validation reports invalid profiles and unknown config rule names" {
  let k = @okf.discover(
    set_of([("index.md", "---\nokf_version: \"0.2\"\n---\n")]),
  )
  let clock = @okf.FixedClock(@okf.Instant::of_millis(0L))
  let config = @okf.ValidationConfig(
    overrides=[(@okf.RuleName("no-such-rule"), Info)],
    disabled=[@okf.RuleName("concept-missing-type")],
  )
  let report = @okf.validate(k, [@okf.okf_v02_conformance()], clock, config~, profiles=[
    BrokenProfile::{ },
  ])
  let rows = report
    .findings()
    .map(f => (f.severity.to_string(), f.rule.to_string(), f.subject))
    .iter()
    .collect()
  assert_eq(rows, [
    ("error", "profile-invalid", ProfileSubject("broken")),
    ("warn", "validation-config-unknown-rule", ConfigSubject),
  ])
  let conflicts = @okf.profile_conflicts([DanglingRef::{ }])
  assert_eq(conflicts.length(), 1)
  assert_true(
    conflicts[0]
    is ProfileInvalid(
      profile="dangling",
      error=UnknownRegister(register="decision")
    ),
  )
}
