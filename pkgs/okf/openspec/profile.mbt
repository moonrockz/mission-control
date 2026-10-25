///|
/// What an OpenSpec path holds.
pub(all) enum Kind {
  SpecFile(capability~ : CapabilityPath)
  ProposalFile(change~ : ChangeName, state~ : ChangeState)
  DesignFile(change~ : ChangeName, state~ : ChangeState)
  TasksFile(change~ : ChangeName, state~ : ChangeState)
  DeltaFile(
    change~ : ChangeName,
    state~ : ChangeState,
    capability~ : CapabilityPath
  )
} derive(Eq, Debug)

///|
/// Classifies a path inside an `openspec/` tree. A path whose capability or
/// change part is not a valid name is not an OpenSpec file.
pub fn classify(path : @okf.BundlePath) -> Kind? {
  classify_parts(path) catch {
    _ => None
  }
}

///|
fn classify_parts(path : @okf.BundlePath) -> Kind? raise NameError {
  let s = path.segments().iter().collect()
  let n = s.length()
  if n >= 3 && s[0] == "specs" && s[n - 1] == "spec.md" {
    let capability = CapabilityPath(s[1:n - 1].to_owned().join("/"))
    return Some(SpecFile(capability~))
  }
  guard n >= 3 && s[0] == "changes" else { return None }
  let (state, rest) = if s[1] == "archive" && n >= 4 {
    (Archived, s[2:].to_owned())
  } else {
    (Active, s[1:].to_owned())
  }
  let m = rest.length()
  match rest[1:].to_owned() {
    ["proposal.md"] => Some(ProposalFile(change=ChangeName(rest[0]), state~))
    ["design.md"] => Some(DesignFile(change=ChangeName(rest[0]), state~))
    ["tasks.md"] => Some(TasksFile(change=ChangeName(rest[0]), state~))
    ["specs", .., "spec.md"] if m >= 4 =>
      Some(
        DeltaFile(
          change=ChangeName(rest[0]),
          state~,
          capability=CapabilityPath(rest[2:m - 1].to_owned().join("/")),
        ),
      )
    _ => None
  }
}

///|
fn first_heading(doc : @okf.Document) -> String? {
  for pair in doc.prose_lines() {
    match heading(pair.1) {
      Some((_, text)) => return Some(text)
      None => ()
    }
  }
  None
}

///|
/// The metadata that the profile derives for a file of an `openspec/` tree.
pub fn derived_fields(doc : @okf.Document) -> @okf.Fields? {
  let pairs : Array[(String, @okf.Value)] = []
  let text = (k : String, v : String) => pairs.push((k, Scalar(v)))
  let kind = (t : OpenSpecType) => text("type", t.to_string())
  match classify(doc.path()) {
    None => return None
    Some(SpecFile(capability~)) => {
      kind(Specification)
      text("title", capability.to_string())
      text("capability", capability.to_string())
    }
    Some(ProposalFile(change~, state~)) => {
      kind(ChangeProposal)
      text("title", change.to_string())
      text("change", change.to_string())
      text("state", state.to_string())
    }
    Some(DesignFile(change~, state~)) => {
      kind(Design)
      text("title", change.to_string() + " design")
      text("change", change.to_string())
      text("state", state.to_string())
    }
    Some(TasksFile(change~, state~)) => {
      kind(TaskList)
      text("title", change.to_string() + " tasks")
      text("change", change.to_string())
      text("state", state.to_string())
    }
    Some(DeltaFile(change~, state~, capability~)) => {
      kind(SpecDelta)
      text("title", change.to_string() + ": " + capability.to_string())
      text("change", change.to_string())
      text("capability", capability.to_string())
      text("state", state.to_string())
    }
  }
  match first_heading(doc) {
    Some(h) => pairs.push(("heading", Scalar(h)))
    None => ()
  }
  Some(@okf.Fields(pairs))
}

///|
/// The OpenSpec profile. It reads `openspec/` trees as OKF bundles, defines
/// native OKF types for OpenSpec content, links changes to capabilities, and
/// adds the OpenSpec checks.
pub(all) struct OpenSpecProfile {}

///|
pub impl @okf.Profile for OpenSpecProfile with fn name(_) {
  "openspec"
}

///|
pub impl @okf.Profile for OpenSpecProfile with fn vocabulary(_) {
  [
    @okf.KeyDefinition(
      @okf.FieldKey("capability"),
      description="The capability path, such as `okf/documents`.",
    ),
    @okf.KeyDefinition(@okf.FieldKey("change"), description="The change name."),
    @okf.KeyDefinition(
      @okf.FieldKey("state"),
      values=[Active.to_string(), Archived.to_string()],
      description="The state of a change.",
    ),
    @okf.KeyDefinition(
      @okf.FieldKey("requirement"),
      description="The requirement name of a Requirement or Scenario concept.",
    ),
    @okf.KeyDefinition(
      @okf.FieldKey("scenario"),
      description="The scenario name of a Scenario concept.",
    ),
    @okf.KeyDefinition(
      @okf.FieldKey("order"),
      description="The position of a Requirement or Scenario concept.",
    ),
    @okf.KeyDefinition(
      @okf.FieldKey("heading"),
      description="The first heading of the original file.",
    ),
  ]
}

///|
pub impl @okf.Profile for OpenSpecProfile with fn derive_metadata(_, doc) {
  derived_fields(doc)
}

///|
pub impl @okf.Profile for OpenSpecProfile with fn rule_sets(_) {
  [openspec_checks()]
}

///|
fn link_to(target : String) -> @okf.Link {
  @okf.Link("", target)
}

///|
fn spec_path(capability : CapabilityPath) -> String {
  "/specs/\{capability}/spec.md"
}

///|
/// The capability of a document, when its `capability` value is a valid name.
fn capability_of(doc : @okf.Document) -> CapabilityPath? {
  match doc.metadata().text("capability") {
    Some(text) =>
      try CapabilityPath(text) catch {
        _ => None
      } noraise {
        c => Some(c)
      }
    None => None
  }
}

///|
/// The change of a document, when its `change` value is a valid name.
fn change_of(doc : @okf.Document) -> ChangeName? {
  match doc.metadata().text("change") {
    Some(text) =>
      try ChangeName(text) catch {
        _ => None
      } noraise {
        c => Some(c)
      }
    None => None
  }
}

///|
/// The requirement name of a document under `key`, when it is valid.
fn requirement_of(doc : @okf.Document, key : String) -> RequirementName? {
  match doc.metadata().text(key) {
    Some(text) =>
      try RequirementName(text) catch {
        _ => None
      } noraise {
        r => Some(r)
      }
    None => None
  }
}

///|
pub impl @okf.Profile for OpenSpecProfile with fn relations(_, bundle, doc) {
  let out = []
  match type_of(doc) {
    Some(ChangeProposal) => {
      let dir = doc.path().directory()
      for other in bundle.documents() {
        let segs = other.path().segments()
        guard other.path() != doc.path() && segs.length() > dir.length() else {
          continue
        }
        let mut inside = true
        for i, s in dir {
          if segs[i] != s {
            inside = false
            break
          }
        }
        guard inside else { continue }
        match type_of(other) {
          Some(Design | TaskList) => out.push(link_to(other.path().to_string()))
          Some(SpecDelta) => {
            out.push(link_to(other.path().to_string()))
            match capability_of(other) {
              Some(cap) => out.push(link_to(spec_path(cap)))
              None => ()
            }
          }
          _ => ()
        }
      }
    }
    Some(SpecDelta | RequirementConcept | ScenarioConcept) =>
      match capability_of(doc) {
        Some(cap) => out.push(link_to(spec_path(cap)))
        None => ()
      }
    _ => ()
  }
  out
}

///|
/// The concepts of a type, sorted by `order` and then by path.
fn of_type(bundle : @okf.Bundle, t : OpenSpecType) -> Array[@okf.Document] {
  let docs = bundle
    .concepts()
    .iter()
    .filter(d => type_of(d) == Some(t))
    .collect()
  docs.sort_by((a, b) => {
    let oa = a.metadata().int("order").unwrap_or(0)
    let ob = b.metadata().int("order").unwrap_or(0)
    if oa != ob {
      oa.compare(ob)
    } else {
      a.path().compare(b.path())
    }
  })
  docs
}

///|
/// The structured OpenSpec view of a bundle, from an `openspec/` tree (with
/// this profile's derived metadata) or from a native bundle. A concept whose
/// capability, change or requirement value is not a valid name is left out;
/// validation reports it.
pub fn view(bundle : @okf.Bundle) -> OpenSpecView {
  let requirement_docs = of_type(bundle, RequirementConcept)
  let scenario_docs = of_type(bundle, ScenarioConcept)
  let specs = []
  for doc in of_type(bundle, Specification) {
    guard capability_of(doc) is Some(cap) else { continue }
    let model = parse_spec(cap, doc.prose_lines())
    let requirements = model.requirements.iter().collect()
    for r in requirement_docs {
      guard capability_of(r) == Some(cap) else { continue }
      guard requirement_of(r, "requirement") is Some(name) else { continue }
      // The requirement line is the line of its `requirement` key.
      guard r.metadata().line_of("requirement") is Some(line) else { continue }
      let parsed = parse_spec(
        cap,
        [(line, "### Requirement: " + name.to_string())] + r.prose_lines(),
      )
      for req in parsed.requirements {
        requirements.push(req)
      }
    }
    for s in scenario_docs {
      guard capability_of(s) == Some(cap) else { continue }
      guard requirement_of(s, "requirement") is Some(req_name) else { continue }
      let meta = s.metadata()
      let name = meta.text("scenario").unwrap_or(s.display_title())
      // The scenario line is the line of its `scenario` key, else of its
      // `requirement` key.
      let line = match meta.line_of("scenario") {
        Some(l) => Some(l)
        None => meta.line_of("requirement")
      }
      guard line is Some(line) else { continue }
      let parsed = parse_spec(
        cap,
        [
          (line, "### Requirement: " + req_name.to_string()),
          (line, "#### Scenario: " + name),
        ] +
        s.prose_lines(),
      )
      match requirements.search_by(r => r.name == req_name) {
        Some(i) => {
          let scenarios = requirements[i].scenarios.iter().collect()
          for req in parsed.requirements {
            for sc in req.scenarios {
              scenarios.push(sc)
            }
          }
          requirements[i] = { ..requirements[i], scenarios: frozen(scenarios), }
        }
        None => ()
      }
    }
    specs.push({ ..model, requirements: frozen(requirements), })
  }
  specs.sort_by((a, b) => a.capability.compare(b.capability))
  let changes = []
  for doc in of_type(bundle, ChangeProposal) {
    guard change_of(doc) is Some(name) else { continue }
    let state = doc
      .metadata()
      .text("state")
      .bind(ChangeState::parse)
      .unwrap_or(Active)
    let same = (d : @okf.Document) => change_of(d) == Some(name)
    let design = of_type(bundle, Design)
      .iter()
      .find_first(same)
      .map(d => d.body())
    let task_groups = match of_type(bundle, TaskList).iter().find_first(same) {
      Some(d) => parse_tasks(d.prose_lines())
      None => []
    }
    let deltas = []
    for d in of_type(bundle, SpecDelta) {
      guard same(d) else { continue }
      guard capability_of(d) is Some(cap) else { continue }
      deltas.push(parse_spec(cap, d.prose_lines()))
    }
    deltas.sort_by((a, b) => a.capability.compare(b.capability))
    changes.push({
      name,
      state,
      proposal: Some(doc.body()),
      design,
      task_groups: frozen(task_groups),
      deltas: frozen(deltas),
    })
  }
  changes.sort_by((a, b) => a.name.compare(b.name))
  { specs: frozen(specs), changes: frozen(changes), }
}

///|
fn zero_requirement(r : Requirement) -> Requirement {
  {
    ..r,
    line: 0,
    scenarios: frozen(r.scenarios.iter().map(s => { ..s, line: 0, }).collect()),
  }
}

///|
fn zero_spec(s : SpecModel) -> SpecModel {
  {
    ..s,
    requirements: frozen(s.requirements.iter().map(zero_requirement).collect()),
    deltas: frozen(
      s.deltas
      .iter()
      .map(d => {
        ..d,
        requirements: frozen(
          d.requirements.iter().map(zero_requirement).collect(),
        ),
        renames: frozen(d.renames.iter().map(r => { ..r, line: 0, }).collect()),
        incomplete_renames: frozen(
          d.incomplete_renames
          .iter()
          .map(r => {
            match r {
              MissingTo(from~, ..) => MissingTo(from~, line=0)
              MissingFrom(to~, ..) => MissingFrom(to~, line=0)
            }
          })
          .collect(),
        ),
      })
      .collect(),
    ),
  }
}

///|
/// The view without line numbers, for comparing forms whose lines differ.
pub fn OpenSpecView::without_lines(self : OpenSpecView) -> OpenSpecView {
  {
    specs: frozen(self.specs.iter().map(zero_spec).collect()),
    changes: frozen(
      self.changes
      .iter()
      .map(c => {
        ..c,
        deltas: frozen(c.deltas.iter().map(zero_spec).collect()),
        task_groups: frozen(
          c.task_groups
          .iter()
          .map(g => {
            ..g,
            tasks: frozen(g.tasks.iter().map(t => { ..t, line: 0, }).collect()),
          })
          .collect(),
        ),
      })
      .collect(),
    ),
  }
}

///|
pub extend Kind with Eq::{not_equal, equal}

///|
pub extend Kind with @debug.Debug::{to_repr}

///|
pub extend OpenSpecProfile with @moonrockz/okf.Profile::{
  name,
  options,
  relations,
  registers,
  templates,
  vocabulary,
  severities,
  reference_fields,
  bundle_keys,
  derive_metadata,
  rule_sets,
}
