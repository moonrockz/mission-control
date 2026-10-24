///|
/// A reference profile for the finos/morphir knowledge base, built only with
/// the public `moonrockz/okf` profile API. The library does not ship it.
priv struct MorphirProfile {}

///|
fn states(names : Array[String]) -> Array[@okf.StateName] raise @okf.ValueError {
  names.map(n => @okf.StateName(n))
}

///|
fn key(text : String) -> @okf.FieldKey raise @okf.ValueError {
  @okf.FieldKey(text)
}

///|
fn transition(
  to : String,
  from~ : Array[String] = [],
  requires~ : Array[String] = [],
) -> @okf.Transition raise @okf.ValueError {
  @okf.Transition(
    @okf.StateName(to),
    from=states(from),
    obligations=requires.map(k => @okf.Obligation::requires_key(key(k))),
  )
}

///|
fn decision_register() -> @okf.Register raise @okf.ValueError {
  @okf.Register(
    @okf.RegisterName("decision"),
    @okf.ConceptType("Decision Record"),
    id_rule=LeadingDigits(@okf.IdWidth(4)),
    state_key=key("state"),
    states=states(["Proposed", "Accepted", "Superseded", "Withdrawn"]),
    transitions=[
      transition("Accepted", from=["Proposed"]),
      transition("Superseded", from=["Accepted"], requires=["superseded_by"]),
      transition("Withdrawn", from=["Proposed", "Accepted"], requires=["reason"]),
    ],
    supersedes_key=key("supersedes"),
    superseded_by_key=key("superseded_by"),
    superseded_states=states(["Superseded"]),
  )
}

///|
fn intent_register() -> @okf.Register raise @okf.ValueError {
  @okf.Register(
    @okf.RegisterName("intent"),
    @okf.ConceptType("Intent"),
    id_rule=LeadingDigits(@okf.IdWidth(4)),
    state_key=key("state"),
    states=states([
      "Backlog", "Refinement", "InProgress", "Released", "Cancelled", "Superseded",
    ]),
    transitions=[
      transition("Refinement", from=["Backlog"]),
      transition("InProgress", from=["Backlog", "Refinement"]),
      transition("Released", from=["InProgress"], requires=["capability"]),
      transition("Cancelled", from=["Backlog", "Refinement", "InProgress"], requires=[
        "reason",
      ]),
      transition("Superseded", requires=["superseded_by"]),
    ],
    superseded_by_key=key("superseded_by"),
    superseded_states=states(["Superseded"]),
    bundle_flag=key("intent"),
  )
}

///|
let morphir_concept_keys : Array[String] = [
  "state", "kind", "breaking", "created", "state_since", "issue", "capability", "superseded_by",
  "reason", "artifacts", "implementation_baselines", "decided", "supersedes",
]

///|
let morphir_bundle_keys : Array[String] = [
  "title", "description", "intent", "system", "capability_bundle", "stale_after_days",
  "sync", "kb_upstream",
]

///|
fn issue_for(
  record : @okf.Record,
  message : String,
  hint? : String,
) -> @okf.Issue {
  @okf.Issue::in_bundle(record.key(), message, hint?)
}

///|
/// The decision records of each bundle. The register parts are constants, so
/// they always build.
fn decision_records(ctx : @okf.ValidationContext) -> Array[Array[@okf.Record]] {
  let register = decision_register() catch { _ => return [] }
  ctx.knowledge.bundles().iter().map(b => register.records(b)).collect()
}

///|
fn is_date(text : String) -> Bool {
  @okf.Instant::parse(text, date_only=true) is Some(_) && text.length() == 10
}

///|
fn rule(
  name : String,
  severity : @okf.Severity,
  check : (@okf.ValidationContext) -> Array[@okf.Issue],
) -> @okf.Rule raise @okf.ValueError {
  @okf.Rule(@okf.RuleName(name), severity, check)
}

///|
fn decision_rules() -> @okf.RuleSet raise @okf.ValueError {
  let register = decision_register()
  let withdrawn = @okf.StateName("Withdrawn")
  @okf.RuleSet("morphir-decisions", [
    rule("decision-no-id", Error, ctx => {
      let out = []
      for records in decision_records(ctx) {
        for r in records {
          if r.id is None {
            out.push(
              issue_for(
                r, "decision record filename does not start with a numeric id",
              ),
            )
          }
        }
      }
      out
    }),
    rule("decision-state-unknown", Error, ctx => {
      let out = []
      for records in decision_records(ctx) {
        for r in records {
          match r.state {
            None => out.push(issue_for(r, "decision record has no `state`"))
            Some(s) if !register.states().contains(s) =>
              out.push(issue_for(r, "`state: \{s}` is not a known state"))
            _ => ()
          }
        }
      }
      out
    }),
    rule("decision-decided-missing", Warning, ctx => {
      let out = []
      for records in decision_records(ctx) {
        for r in records {
          if !is_date(r.metadata().text("decided").unwrap_or("")) {
            out.push(
              issue_for(
                r, "decision record has no valid `decided` date (YYYY-MM-DD)",
              ),
            )
          }
        }
      }
      out
    }),
    rule("decision-withdrawn-no-reason", Error, ctx => {
      let out = []
      for records in decision_records(ctx) {
        for r in records {
          if r.state == Some(withdrawn) && r.metadata().text("reason") is None {
            out.push(issue_for(r, "Withdrawn decision has no `reason`"))
          }
        }
      }
      out
    }),
    rule("decision-duplicate-id", Error, ctx => {
      let out = []
      for records in decision_records(ctx) {
        for dup in register.duplicates(records) {
          for r in dup.1 {
            out.push(
              issue_for(
                r,
                "decision id `\{dup.0}` is used by \{dup.1.length()} records in \{r.bundle}",
              ),
            )
          }
        }
      }
      out
    }),
    rule("decision-supersession", Error, ctx => {
      let out = []
      for records in decision_records(ctx) {
        for i in register.supersession_issues(records) {
          match i {
            MissingSuccessor(r) =>
              out.push(
                issue_for(r, "Superseded decision has no `superseded_by`"),
              )
            UnknownSuccessor(r, id) =>
              out.push(
                issue_for(r, "`superseded_by: \{id}` names no decision record"),
              )
            UnknownPredecessor(r, id) =>
              out.push(
                issue_for(r, "`supersedes: \{id}` names no decision record"),
              )
            NotMutual(a, b) => {
              let x = a.id.map(i => i.to_string()).unwrap_or("")
              let y = b.id.map(i => i.to_string()).unwrap_or("")
              out.push(issue_for(a, "\{x} and \{y} do not name each other"))
            }
          }
        }
      }
      out
    }),
  ])
}

///|
fn readme_rules() -> @okf.RuleSet raise @okf.ValueError {
  @okf.RuleSet("morphir-layout", [
    rule("readme-in-bundle", Error, ctx => {
      let out = []
      for pair in ctx.knowledge.concepts() {
        if pair.1.path().name() == "README.md" {
          out.push(@okf.Issue::at(pair.0, pair.1, "README.md inside a bundle"))
        }
      }
      out
    }),
  ])
}

///|
impl @okf.Profile for MorphirProfile with fn name(_) {
  "morphir"
}

///|
impl @okf.Profile for MorphirProfile with fn vocabulary(_) {
  morphir_concept_keys.map(k => @okf.KeyDefinition(key(k)))
}

///|
impl @okf.Profile for MorphirProfile with fn bundle_keys(_) {
  morphir_bundle_keys.map(k => @okf.KeyDefinition(key(k)))
}

///|
impl @okf.Profile for MorphirProfile with fn registers(_) {
  [decision_register(), intent_register()]
}

///|
impl @okf.Profile for MorphirProfile with fn reference_fields(_) {
  [{ key: key("capability"), kind: DocumentRef, }]
}

///|
impl @okf.Profile for MorphirProfile with fn rule_sets(_) {
  [decision_rules(), readme_rules()]
}

///|
impl @okf.Profile for MorphirProfile with fn severities(_) {
  [
    (@okf.RuleName("link-broken"), Error),
    (@okf.RuleName("link-escapes-bundle"), Error),
    (@okf.RuleName("stray-markdown"), Error),
  ]
}

///|
impl @okf.Profile for MorphirProfile with fn options(_) {
  Some(
    @okf.Options::default().update(
      status_default=None,
      nested_logs=RootOnly,
      date_only_instants=true,
    ),
  )
}

///|
fn morphir_profiles() -> Array[&@okf.Profile] {
  [MorphirProfile::{ }]
}

///|
fn morphir_profiled_knowledge() -> @okf.Knowledge raise {
  let profiles = morphir_profiles()
  @okf.discover(
    load_fixture("okf-fixtures/morphir/kb"),
    under=@okf.StoreDir("bundles"),
    options=@okf.effective_options(profiles),
    profiles~,
  )
}

///|
test "the morphir profile lists the same decision records as kb decision list" {
  let knowledge = morphir_profiled_knowledge()
  guard read_golden("decision-list.json") is Array(golden) else {
    fail("bad golden")
  }
  let expected = golden.map(d => {
    guard d
      is {
        "id": String(id),
        "bundle": String(bundle),
        "path": String(path),
        "state": String(state),
        "decided": decided,
        "title": String(title),
        ..
      } else {
      fail("bad decision")
    }
    let decided = match decided {
      String(s) => s
      _ => ""
    }
    (bundle, id, path, state, decided, title)
  })
  let actual = []
  for record in decision_register().all_records(knowledge) {
    actual.push(
      (
        record.bundle.to_string(),
        record.id.map(i => i.to_string()).unwrap_or(""),
        record.document.path().to_string(),
        record.state.map(s => s.to_string()).unwrap_or(""),
        record.metadata().text("decided").unwrap_or(""),
        record.document.display_title(),
      ),
    )
  }
  expected.sort()
  actual.sort()
  assert_eq(actual, expected)
}

///|
test "the morphir profile reproduces kb check exactly" {
  let profiles = morphir_profiles()
  let knowledge = morphir_profiled_knowledge()
  let report = @okf.validate(
    knowledge,
    [@okf.okf_v02_conformance(), @okf.advisory()],
    @okf.FixedClock::at("2026-10-23T00:00:00Z"),
    profiles~,
  )
  let rows = []
  for f in report.findings() {
    rows.push(
      (
        f.severity.to_string(),
        f.rule.to_string(),
        morphir_path(f.subject),
        f.line.unwrap_or(0),
      ),
    )
  }
  rows.sort()
  assert_eq(rows, golden_findings(["link-broken", "index-description-drift"]))
  assert_eq(report.count(Error), 32)
  assert_eq(report.count(Warning), 1)
  assert_eq(report.count(Info), 0)
}

///|
test "the morphir profile composes without conflicts" {
  assert_eq(@okf.profile_conflicts(morphir_profiles()), [])
}

///|
fn intent_bundle() -> @okf.Bundle raise {
  let profiles = morphir_profiles()
  @okf.load_bundle(
    @okf.DocumentSet::of_texts([
      ("index.md", "---\nokf_version: \"0.2\"\nintent: true\n---\n# Intent\n"),
      (
        "0001-add-okf.md", "---\ntype: Intent\ntitle: Add OKF\nstate: Backlog\n---\n",
      ),
      (
        "0002-ship-okf.md", "---\ntype: Intent\ntitle: Ship OKF\nstate: InProgress\n---\n",
      ),
      ("caps/okf.md", "---\ntype: Capability\ntitle: OKF\n---\n"),
    ]),
    options=@okf.effective_options(profiles),
    profiles~,
  )
}

///|
test "the intent register applies only to bundles with the intent flag" {
  let b = intent_bundle()
  let register = intent_register()
  assert_eq(register.records(b).length(), 2)
  let other = @okf.load_bundle(
    @okf.DocumentSet::of_texts([
      ("0001-x.md", "---\ntype: Intent\nstate: Backlog\n---\n"),
    ]),
  )
  assert_eq(register.records(other).length(), 0)
}

///|
test "intent transitions: allowed, refused for an obligation, not allowed" {
  let b = intent_bundle()
  let register = intent_register()
  let records = register.records(b)
  guard register.find(records, "1") is Found(backlog) else { fail("no 0001") }
  guard register.find(records, "0002") is Found(in_progress) else {
    fail("no 0002")
  }
  let released = @okf.StateName("Released")
  assert_eq(
    register.check_transition(backlog, @okf.StateName("Refinement")),
    Allowed,
  )
  guard register.check_transition(in_progress, released) is Refused(names) else {
    fail("not refused")
  }
  assert_eq(names.iter().collect(), ["capability"])
  assert_eq(
    register.check_transition(backlog, released),
    NotAllowed(from=Some(@okf.StateName("Backlog")), to=released),
  )
}
