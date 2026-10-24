///|
/// The severity of a finding. Errors sort first.
pub(all) enum Severity {
  Error
  Warning
  Info
} derive(Eq, Compare, Hash, Debug)

///|
/// The short form of a severity, as reports print it: `error`, `warn` or `info`.
pub fn Severity::to_string(self : Severity) -> String {
  match self {
    Error => "error"
    Warning => "warn"
    Info => "info"
  }
}

///|
/// What a finding is about.
pub(all) enum FindingSubject {
  /// A document of a bundle.
  InBundle(BundleLabel, BundlePath)
  /// A Markdown file outside every bundle.
  Stray(StorePath)
  /// A profile, by name, for a profile definition that breaks a rule.
  ProfileSubject(String)
  /// The validation config.
  ConfigSubject
} derive(Eq, Debug)

///|
/// The bundle label of the subject, when it is a document of a bundle.
pub fn FindingSubject::bundle(self : FindingSubject) -> BundleLabel? {
  match self {
    InBundle(label, _) => Some(label)
    _ => None
  }
}

///|
/// The path text of the subject: a bundle path, a store path, or `""`.
pub fn FindingSubject::path_text(self : FindingSubject) -> String {
  match self {
    InBundle(_, path) => path.to_string()
    Stray(path) => path.to_string()
    ProfileSubject(_) | ConfigSubject => ""
  }
}

///|
fn FindingSubject::sort_key(self : FindingSubject) -> (Int32, String, String) {
  match self {
    ConfigSubject => (0, "", "")
    ProfileSubject(name) => (1, name, "")
    InBundle(label, path) => (2, label.to_string(), path.to_string())
    Stray(path) => (3, "", path.to_string())
  }
}

///|
/// One validation result. Only `validate` makes findings.
pub struct Finding {
  severity : Severity
  rule : RuleName
  subject : FindingSubject
  line : Int32?
  message : String
  hint : String?
} derive(Eq, Debug)

///|
/// What a rule reports. Validation adds the rule name and the severity.
pub struct Issue {
  subject : FindingSubject
  line : Int32?
  message : String
  hint : String?
} derive(Eq, Debug)

///|
/// An issue about one document of a bundle.
pub fn Issue::at(
  bundle : Bundle,
  doc : Document,
  message : String,
  line? : Int32,
  hint? : String,
) -> Issue {
  { subject: InBundle(bundle.label(), doc.path()), line, message, hint, }
}

///|
/// An issue about a document of a bundle, by its key.
pub fn Issue::in_bundle(
  key : DocKey,
  message : String,
  line? : Int32,
  hint? : String,
) -> Issue {
  { subject: InBundle(key.bundle, key.path), line, message, hint, }
}

///|
/// An issue about a Markdown file outside every bundle.
pub fn Issue::stray(
  path : StorePath,
  message : String,
  hint? : String,
) -> Issue {
  { subject: Stray(path), line: None, message, hint, }
}

///|
/// The inputs that every rule can read.
pub struct ValidationContext {
  knowledge : Knowledge
  graph : Graph
  now : Instant
  options : Options
  vocabulary : Vocabulary
  profiles : ReadOnlyArray[&Profile]
}

///|
/// One named check with a default severity.
struct Rule {
  name : RuleName
  severity : Severity
  check : (ValidationContext) -> Array[Issue]
}

///|
pub fn Rule::Rule(
  name : RuleName,
  severity : Severity,
  check : (ValidationContext) -> Array[Issue],
) -> Rule {
  { name, severity, check, }
}

///|
pub fn Rule::name(self : Rule) -> RuleName {
  self.name
}

///|
pub fn Rule::severity(self : Rule) -> Severity {
  self.severity
}

///|
/// A named group of rules. The name is a label for reports.
struct RuleSet {
  name : String
  rules : ReadOnlyArray[Rule]
}

///|
pub fn RuleSet::RuleSet(name : String, rules : ArrayView[Rule]) -> RuleSet {
  { name, rules: ReadOnlyArray::from_array(rules.to_owned()), }
}

///|
pub fn RuleSet::name(self : RuleSet) -> String {
  self.name
}

///|
pub fn RuleSet::rules(self : RuleSet) -> ReadOnlyArray[Rule] {
  self.rules
}

///|
/// How a caller adjusts validation. The config keeps its own copies, so later
/// changes to the arrays that built it do not change it.
struct ValidationConfig {
  overrides : ReadOnlyArray[(RuleName, Severity)]
  disabled : ReadOnlyArray[RuleName]
}

///|
pub fn ValidationConfig::ValidationConfig(
  overrides~ : ArrayView[(RuleName, Severity)] = [],
  disabled~ : ArrayView[RuleName] = [],
) -> ValidationConfig {
  {
    overrides: ReadOnlyArray::from_array(overrides.to_owned()),
    disabled: ReadOnlyArray::from_array(disabled.to_owned()),
  }
}

///|
/// The severity changes, by rule name.
pub fn ValidationConfig::overrides(
  self : ValidationConfig,
) -> ReadOnlyArray[(RuleName, Severity)] {
  self.overrides
}

///|
/// The rules that do not run.
pub fn ValidationConfig::disabled(
  self : ValidationConfig,
) -> ReadOnlyArray[RuleName] {
  self.disabled
}

///|
fn ValidationConfig::override_of(
  self : ValidationConfig,
  name : RuleName,
) -> Severity? {
  self.overrides.iter().find_first(p => p.0 == name).map(p => p.1)
}

///|
/// The sorted findings of one validation run.
struct Report {
  findings : ReadOnlyArray[Finding]
}

///|
fn severity_rank(s : Severity) -> Int32 {
  match s {
    Error => 0
    Warning => 1
    Info => 2
  }
}

///|
fn compare_findings(a : Finding, b : Finding) -> Int32 {
  let c = severity_rank(a.severity).compare(severity_rank(b.severity))
  if c != 0 {
    return c
  }
  let (ka, kb) = (a.subject.sort_key(), b.subject.sort_key())
  let c = ka.0.compare(kb.0)
  if c != 0 {
    return c
  }
  let c = lexical_compare(ka.1, kb.1)
  if c != 0 {
    return c
  }
  let c = lexical_compare(ka.2, kb.2)
  if c != 0 {
    return c
  }
  let c = a.line.unwrap_or(0).compare(b.line.unwrap_or(0))
  if c != 0 {
    return c
  }
  let c = a.rule.compare(b.rule)
  if c != 0 {
    return c
  }
  lexical_compare(a.message, b.message)
}

///|
/// A report from findings, sorted by severity, subject (bundle label, then
/// path), line and rule.
fn Report::of_findings(findings : ArrayView[Finding]) -> Report {
  let sorted = findings.to_owned()
  sorted.sort_by(compare_findings)
  { findings: ReadOnlyArray::from_array(sorted), }
}

///|
pub fn Report::findings(self : Report) -> ReadOnlyArray[Finding] {
  self.findings
}

///|
pub fn Report::count(self : Report, severity : Severity) -> Int32 {
  self.findings.iter().filter(f => f.severity == severity).count()
}

///|
/// True when the result fails: any error, or any warning in strict mode.
pub fn Report::fails(self : Report, strict~ : Bool = false) -> Bool {
  self.count(Error) > 0 || (strict && self.count(Warning) > 0)
}

///|
/// The findings of one rule.
pub fn Report::of_rule(self : Report, rule : RuleName) -> Array[Finding] {
  self.findings.iter().filter(f => f.rule == rule).collect()
}

///|
/// A rule name that this library defines, written in code.
fn builtin_rule(text : String) -> RuleName {
  { text, }
}

///|
/// Runs the rule sets over the knowledge and returns the sorted findings. A
/// profile whose definitions break a rule gives a `profile-invalid` error, and
/// a config that names a rule that no active rule set defines gives a
/// `validation-config-unknown-rule` warning.
pub fn validate(
  knowledge : Knowledge,
  rule_sets : ArrayView[RuleSet],
  clock : &Clock,
  config~ : ValidationConfig = ValidationConfig(),
  resolver? : &LinkResolver,
  profiles~ : ArrayView[&Profile] = [],
) -> Report {
  let graph = Graph::build(knowledge, resolver?, profiles~)
  let context = {
    knowledge,
    graph,
    now: clock.now(),
    options: knowledge.options(),
    vocabulary: Vocabulary::of_profiles(profiles),
    profiles: ReadOnlyArray::from_array(profiles.to_owned()),
  }
  let findings : Array[Finding] = []
  let sets = rule_sets.to_owned()
  let profile_severity : Array[(RuleName, Severity)] = []
  for profile in profiles {
    try {
      for set in profile.rule_sets() {
        sets.push(set)
      }
      for pair in profile.severities() {
        if !profile_severity.any(p => p.0 == pair.0) {
          profile_severity.push(pair)
        }
      }
    } catch {
      e =>
        findings.push({
          severity: Error,
          rule: builtin_rule("profile-invalid"),
          subject: ProfileSubject(profile.name()),
          line: None,
          message: "the profile \{profile.name()} has an invalid definition: \{@debug.to_string(e)}",
          hint: None,
        })
    }
  }
  let known : Array[RuleName] = []
  for set in sets {
    for rule in set.rules {
      known.push(rule.name)
      guard !config.disabled.contains(rule.name) else { continue }
      let severity = match config.override_of(rule.name) {
        Some(s) => s
        None =>
          profile_severity
          .iter()
          .find_first(p => p.0 == rule.name)
          .map(p => p.1)
          .unwrap_or(rule.severity)
      }
      for issue in (rule.check)(context) {
        findings.push({
          severity,
          rule: rule.name,
          subject: issue.subject,
          line: issue.line,
          message: issue.message,
          hint: issue.hint,
        })
      }
    }
  }
  let named = config.overrides.iter().map(p => p.0).collect()
  for name in config.disabled {
    named.push(name)
  }
  for name in named {
    if !known.contains(name) {
      findings.push({
        severity: Warning,
        rule: builtin_rule("validation-config-unknown-rule"),
        subject: ConfigSubject,
        line: None,
        message: "the validation config names `\{name}`, which no active rule set defines",
        hint: None,
      })
    }
  }
  Report::of_findings(findings)
}

///|
/// The keys that validation treats as known: OKF keys and profile keys.
struct Vocabulary {
  concept_keys : Map[String, String]
  bundle_keys : Map[String, String]
}

///|
/// The OKF vocabulary plus the vocabulary of each profile. The value of each
/// key is the name of the profile that defines it, or `okf`. A profile whose
/// definitions break a rule adds no keys; `validate` reports it.
pub fn Vocabulary::of_profiles(profiles : ArrayView[&Profile]) -> Vocabulary {
  let concept_keys : Map[String, String] = Map([])
  for key in okf_concept_keys {
    concept_keys[key] = "okf"
  }
  let bundle_keys : Map[String, String] = Map([])
  bundle_keys["okf_version"] = "okf"
  for profile in profiles {
    let defs = profile.vocabulary() catch { _ => [] }
    for def in defs {
      let key = def.key.to_string()
      if !concept_keys.contains(key) {
        concept_keys[key] = profile.name()
      }
    }
    let defs = profile.bundle_keys() catch { _ => [] }
    for def in defs {
      let key = def.key.to_string()
      if !bundle_keys.contains(key) {
        bundle_keys[key] = profile.name()
      }
    }
  }
  { concept_keys, bundle_keys, }
}

///|
/// True when the key is an OKF or profile concept key.
pub fn Vocabulary::knows(self : Vocabulary, key : String) -> Bool {
  self.concept_keys.contains(key)
}

///|
/// True when the key is an OKF or profile root index key.
pub fn Vocabulary::knows_bundle_key(self : Vocabulary, key : String) -> Bool {
  self.bundle_keys.contains(key)
}

///|
pub extend Severity with Eq::{not_equal, equal}

///|
pub extend Severity with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend Severity with Hash::{hash, hash_combine}

///|
pub extend Severity with @debug.Debug::{to_repr}

///|
pub extend FindingSubject with Eq::{not_equal, equal}

///|
pub extend FindingSubject with @debug.Debug::{to_repr}

///|
pub extend Finding with Eq::{not_equal, equal}

///|
pub extend Finding with @debug.Debug::{to_repr}

///|
pub extend Issue with Eq::{not_equal, equal}

///|
pub extend Issue with @debug.Debug::{to_repr}
