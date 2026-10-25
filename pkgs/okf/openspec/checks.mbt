///|
fn spec_docs(
  ctx : @okf.ValidationContext,
) -> Array[(@okf.Bundle, @okf.Document)] {
  ctx.knowledge
  .concepts()
  .iter()
  .filter(p => type_of(p.1) is Some(Specification | SpecDelta))
  .collect()
}

///|
fn all_requirements(model : SpecModel) -> Array[Requirement] {
  let out = model.requirements.iter().collect()
  for d in model.deltas {
    if d.op is (Added | Modified) {
      for r in d.requirements {
        out.push(r)
      }
    }
  }
  out
}

///|
/// The model of a spec document, when its capability is a valid name.
fn model_of(
  doc : @okf.Document,
  dialects : ArrayView[&@ears.Dialect],
) -> SpecModel? {
  capability_of(doc).map(cap => parse_spec(cap, doc.prose_lines(), dialects~))
}

///|
fn check_no_scenario(
  ctx : @okf.ValidationContext,
  dialects : ArrayView[&@ears.Dialect],
) -> Array[@okf.Issue] {
  let out = []
  for pair in spec_docs(ctx) {
    guard model_of(pair.1, dialects) is Some(model) else { continue }
    for r in all_requirements(model) {
      if r.scenarios.is_empty() {
        out.push(
          @okf.Issue::at(
            pair.0,
            pair.1,
            "the requirement `\{r.name}` has no scenario",
            line=r.line,
          ),
        )
      }
    }
  }
  out
}

///|
fn check_no_shall(
  ctx : @okf.ValidationContext,
  dialects : ArrayView[&@ears.Dialect],
) -> Array[@okf.Issue] {
  let out = []
  for pair in spec_docs(ctx) {
    guard model_of(pair.1, dialects) is Some(model) else { continue }
    for r in all_requirements(model) {
      if !r.text.contains("SHALL") && !r.text.contains("MUST") {
        out.push(
          @okf.Issue::at(
            pair.0,
            pair.1,
            "the requirement `\{r.name}` has no SHALL or MUST",
            line=r.line,
          ),
        )
      }
    }
  }
  out
}

///|
fn check_scenario_headings(ctx : @okf.ValidationContext) -> Array[@okf.Issue] {
  let out = []
  for pair in spec_docs(ctx) {
    for line in pair.1.prose_lines() {
      let t = line.1.trim(chars=" \t").to_owned()
      let wrong = match heading(t) {
        Some((level, text)) => level != 4 && text.has_prefix("Scenario:")
        None => t.has_prefix("- Scenario:") || t.has_prefix("**Scenario")
      }
      if wrong {
        out.push(
          @okf.Issue::at(
            pair.0,
            pair.1,
            "a scenario must use a `####` heading",
            line=line.0,
            hint="Write `#### Scenario: <name>`.",
          ),
        )
      }
    }
  }
  out
}

///|
/// The main spec of each capability.
fn main_specs(
  ctx : @okf.ValidationContext,
  dialects : ArrayView[&@ears.Dialect],
) -> Map[CapabilityPath, SpecModel] {
  let out : Map[CapabilityPath, SpecModel] = Map([])
  for pair in spec_docs(ctx) {
    if type_of(pair.1) is Some(Specification) {
      match model_of(pair.1, dialects) {
        Some(m) => out[m.capability] = m
        None => ()
      }
    }
  }
  out
}

///|
fn check_modified_unknown(
  ctx : @okf.ValidationContext,
  dialects : ArrayView[&@ears.Dialect],
) -> Array[@okf.Issue] {
  let mains = main_specs(ctx, dialects)
  let out = []
  for pair in spec_docs(ctx) {
    guard type_of(pair.1) is Some(SpecDelta) else { continue }
    guard model_of(pair.1, dialects) is Some(m) else { continue }
    guard mains.get(m.capability) is Some(main) else { continue }
    for d in m.deltas {
      if d.op is (Modified | Removed) {
        for r in d.requirements {
          if !main.requirements.iter().any(x => x.name == r.name) {
            out.push(
              @okf.Issue::at(
                pair.0,
                pair.1,
                "`\{r.name}` matches no requirement of `\{m.capability}`",
                line=r.line,
              ),
            )
          }
        }
      }
    }
  }
  out
}

///|
fn check_unknown_capability(
  ctx : @okf.ValidationContext,
  dialects : ArrayView[&@ears.Dialect],
) -> Array[@okf.Issue] {
  let mains = main_specs(ctx, dialects)
  let out = []
  for pair in spec_docs(ctx) {
    guard type_of(pair.1) is Some(SpecDelta) else { continue }
    guard model_of(pair.1, dialects) is Some(m) else { continue }
    if !mains.contains(m.capability) &&
      m.deltas.iter().any(d => !(d.op is Added)) {
      out.push(
        @okf.Issue::at(
          pair.0,
          pair.1,
          "the capability `\{m.capability}` does not exist, and the delta does not only add requirements",
        ),
      )
    }
  }
  out
}

///|
fn check_incomplete_renames(
  ctx : @okf.ValidationContext,
  dialects : ArrayView[&@ears.Dialect],
) -> Array[@okf.Issue] {
  let out = []
  for pair in spec_docs(ctx) {
    guard model_of(pair.1, dialects) is Some(m) else { continue }
    for d in m.deltas {
      for r in d.incomplete_renames {
        let issue = match r {
          MissingTo(from~, line~) =>
            @okf.Issue::at(
              pair.0,
              pair.1,
              "the rename of `\{from}` has no `TO:` line",
              line~,
              hint="Write `- TO: ### Requirement: <new name>` after the `FROM:` line.",
            )
          MissingFrom(to~, line~) =>
            @okf.Issue::at(
              pair.0,
              pair.1,
              "the rename to `\{to}` has no `FROM:` line",
              line~,
              hint="Write `- FROM: ### Requirement: <old name>` before the `TO:` line.",
            )
        }
        out.push(issue)
      }
    }
  }
  out
}

///|
/// The name keys that each OpenSpec type needs.
fn name_keys(t : OpenSpecType) -> Array[String] {
  match t {
    Specification => ["capability"]
    ChangeProposal | Design | TaskList => ["change"]
    SpecDelta => ["change", "capability"]
    RequirementConcept => ["capability", "requirement"]
    ScenarioConcept => ["capability", "requirement"]
  }
}

///|
fn check_invalid_names(
  ctx : @okf.ValidationContext,
  dialects : ArrayView[&@ears.Dialect],
) -> Array[@okf.Issue] {
  let out = []
  for pair in ctx.knowledge.concepts() {
    let (bundle, doc) = pair
    guard type_of(doc) is Some(t) else { continue }
    for key in name_keys(t) {
      let valid = match key {
        "capability" => capability_of(doc) is Some(_)
        "change" => change_of(doc) is Some(_)
        _ => requirement_of(doc, key) is Some(_)
      }
      guard !valid else { continue }
      let message = match doc.metadata().text(key) {
        Some(value) => "the `\{key}` value `\{value}` is not a valid name"
        None => "the \{t} concept has no `\{key}`"
      }
      out.push(
        @okf.Issue::at(bundle, doc, message, line?=doc.metadata().line_of(key)),
      )
    }
    match doc.metadata().text("state") {
      Some(value) if ChangeState::parse(value) is None =>
        out.push(
          @okf.Issue::at(
            bundle,
            doc,
            "the `state` value `\{value}` is not `active` or `archived`",
            line?=doc.metadata().line_of("state"),
          ),
        )
      _ => ()
    }
  }
  for pair in spec_docs(ctx) {
    guard model_of(pair.1, dialects) is Some(model) else { continue }
    for line in model.unnamed_requirements {
      out.push(
        @okf.Issue::at(
          pair.0,
          pair.1,
          "a requirement heading has no name",
          line~,
          hint="Write `### Requirement: <name>`.",
        ),
      )
    }
  }
  out
}

///|
/// A rule with a name that this package writes in code.
fn rule(
  name : String,
  check : (@okf.ValidationContext) -> Array[@okf.Issue],
  severity~ : @okf.Severity = Error,
) -> @okf.Rule {
  let name = @okf.RuleName(name) catch {
    _ => abort("an OpenSpec rule name is not kebab case: \{name}")
  }
  @okf.Rule(name, severity, check)
}

///|
/// The OpenSpec checks: the three that `openspec validate --strict` runs, the
/// two that OpenSpec runs only when it archives a change, two for content
/// that the view leaves out (incomplete renames and invalid names), and two
/// for EARS: a requirement sentence that is not EARS (a warning) and a lexicon
/// file that does not parse. Requirement texts are parsed with the dialects of
/// `profile`.
pub fn openspec_checks(
  profile~ : OpenSpecProfile = OpenSpecProfile(),
) -> @okf.RuleSet {
  let dialects = profile.dialects()
  @okf.RuleSet("openspec", [
    rule("openspec-requirement-no-scenario", ctx => {
      check_no_scenario(ctx, dialects)
    }),
    rule("openspec-requirement-no-shall", ctx => check_no_shall(ctx, dialects)),
    rule("openspec-scenario-heading", check_scenario_headings),
    rule("openspec-modified-unknown", ctx => {
      check_modified_unknown(ctx, dialects)
    }),
    rule("openspec-delta-unknown-capability", ctx => {
      check_unknown_capability(ctx, dialects)
    }),
    rule("openspec-rename-incomplete", ctx => {
      check_incomplete_renames(ctx, dialects)
    }),
    rule("openspec-invalid-name", ctx => check_invalid_names(ctx, dialects)),
    rule(
      "openspec-requirement-not-ears",
      ctx => check_not_ears(ctx, dialects),
      severity=Warning,
    ),
    rule("openspec-lexicon-invalid", ctx => check_lexicon(ctx, profile)),
  ])
}
