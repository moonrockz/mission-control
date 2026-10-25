///|
/// Raised when a text is not a valid OpenSpec name.
pub(all) suberror NameError {
  /// A value of `key` (`capability`, `change`, `requirement` or `task`) that
  /// breaks the rules of its name type. The rules are on each type.
  InvalidName(key~ : String, value~ : String)
} derive(Eq, Debug)

///|
/// True when `part` is a safe OpenSpec path segment: not empty, not `.` or
/// `..`, does not start or end with `.`, does not end with a space, is not a
/// Windows device name such as `CON`, and has no control character and none of
/// `\ / : * ? " < > |`.
fn is_safe_segment(part : StringView) -> Bool {
  part.length() > 0 &&
  part != "." &&
  part != ".." &&
  !part.has_prefix(".") &&
  !part.has_suffix(".") &&
  !part.has_suffix(" ") &&
  !is_windows_device(part.to_owned()) &&
  part.iter().all(c => c.to_int() >= 32 && !"\\/:*?\"<>|".contains_char(c))
}

///|
/// True for a Windows device name, such as `CON` or `com1.txt`, which a Windows
/// file system cannot use as a file name.
fn is_windows_device(part : String) -> Bool {
  let stem = match part.find(".") {
    Some(i) => part[:i].to_owned()
    None => part
  }
  let upper = stem.to_upper()
  ["CON", "PRN", "AUX", "NUL"].contains(upper) ||
  (
    upper.length() == 4 &&
    (upper.has_prefix("COM") || upper.has_prefix("LPT")) &&
    upper[3] >= '1' &&
    upper[3] <= '9'
  )
}

///|
/// A capability path such as `okf/documents`: one or more safe segments
/// joined with `/`, so that a path built from it stays inside its directory.
struct CapabilityPath {
  text : String
} derive(Eq, Hash, Debug)

///|
pub fn CapabilityPath::CapabilityPath(
  text : String,
) -> CapabilityPath raise NameError {
  if !text.split("/").all(is_safe_segment) {
    raise InvalidName(key="capability", value=text)
  }
  { text, }
}

///|
pub fn CapabilityPath::to_string(self : CapabilityPath) -> String {
  self.text
}

///|
pub impl Show for CapabilityPath with fn output(self, logger) {
  logger.write_string(self.text)
}

///|
pub impl Compare for CapabilityPath with fn compare(self, other) {
  @okf.lexical_compare(self.text, other.text)
}

///|
/// A change name such as `add-okf-module`: one safe segment.
struct ChangeName {
  text : String
} derive(Eq, Hash, Debug)

///|
pub fn ChangeName::ChangeName(text : String) -> ChangeName raise NameError {
  if !is_safe_segment(text) {
    raise InvalidName(key="change", value=text)
  }
  { text, }
}

///|
pub fn ChangeName::to_string(self : ChangeName) -> String {
  self.text
}

///|
pub impl Show for ChangeName with fn output(self, logger) {
  logger.write_string(self.text)
}

///|
pub impl Compare for ChangeName with fn compare(self, other) {
  @okf.lexical_compare(self.text, other.text)
}

///|
/// A requirement name: one line that is not blank, without surrounding white
/// space.
struct RequirementName {
  text : String
} derive(Eq, Hash, Debug)

///|
/// Parses a requirement name. Surrounding spaces and tabs are removed.
pub fn RequirementName::RequirementName(
  text : String,
) -> RequirementName raise NameError {
  let t = text.trim(chars=" \t").to_owned()
  if t.length() == 0 || t.contains("\n") || t.contains("\r") {
    raise InvalidName(key="requirement", value=text)
  }
  { text: t, }
}

///|
pub fn RequirementName::to_string(self : RequirementName) -> String {
  self.text
}

///|
pub impl Show for RequirementName with fn output(self, logger) {
  logger.write_string(self.text)
}

///|
/// A task number such as `1.2`: dot-separated positive integers. Task numbers
/// order by their numbers, so `1.2` comes before `1.10`. The text is
/// normalized, so `01.2` and `1.2` are the same number.
struct TaskNumber {
  parts : ReadOnlyArray[Int32]
  text : String
} derive(Eq, Hash, Debug)

///|
pub fn TaskNumber::TaskNumber(text : String) -> TaskNumber raise NameError {
  let parts = []
  for part in text.split(".") {
    let ok = part.length() > 0 &&
      part.length() <= 9 &&
      part.iter().all(c => c >= '0' && c <= '9')
    guard ok else { raise InvalidName(key="task", value=text) }
    // At most nine digits, so the value fits in an `Int`.
    let mut n = 0
    for c in part {
      n = n * 10 + (c.to_int() - '0'.to_int())
    }
    guard n > 0 else { raise InvalidName(key="task", value=text) }
    parts.push(n)
  }
  let text = parts.map(n => n.to_string()).join(".")
  { parts: ReadOnlyArray::from_array(parts), text, }
}

///|
/// The numbers, such as `[1, 2]` for `1.2`.
pub fn TaskNumber::parts(self : TaskNumber) -> ReadOnlyArray[Int32] {
  self.parts
}

///|
pub fn TaskNumber::to_string(self : TaskNumber) -> String {
  self.text
}

///|
pub impl Show for TaskNumber with fn output(self, logger) {
  logger.write_string(self.text)
}

///|
pub impl Compare for TaskNumber with fn compare(self, other) {
  let n = if self.parts.length() < other.parts.length() {
    self.parts.length()
  } else {
    other.parts.length()
  }
  for i in 0..<n {
    let c = self.parts[i].compare(other.parts[i])
    if c != 0 {
      return c
    }
  }
  self.parts.length().compare(other.parts.length())
}

///|
/// The OKF types that the OpenSpec profile defines.
pub(all) enum OpenSpecType {
  Specification
  ChangeProposal
  Design
  TaskList
  SpecDelta
  RequirementConcept
  ScenarioConcept
} derive(Eq, Hash, Debug)

///|
/// Every OpenSpec type, in a fixed order.
pub let openspec_types : ReadOnlyArray[OpenSpecType] = [
  Specification,
  ChangeProposal,
  Design,
  TaskList,
  SpecDelta,
  RequirementConcept,
  ScenarioConcept,
]

///|
/// The concept type text, such as `Spec Delta`.
pub fn OpenSpecType::to_string(self : OpenSpecType) -> String {
  match self {
    Specification => "Specification"
    ChangeProposal => "Change"
    Design => "Design"
    TaskList => "Tasks"
    SpecDelta => "Spec Delta"
    RequirementConcept => "Requirement"
    ScenarioConcept => "Scenario"
  }
}

///|
pub impl Show for OpenSpecType with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
/// The OKF concept type of this OpenSpec type.
pub fn OpenSpecType::concept_type(self : OpenSpecType) -> @okf.ConceptType {
  @okf.ConceptType(
    // Each text above is not blank.
    self.to_string(),
  ) catch {
    _ => abort("an OpenSpec type text is blank")
  }
}

///|
/// The OpenSpec type of a concept type, ignoring letter case.
pub fn OpenSpecType::of_concept_type(t : @okf.ConceptType) -> OpenSpecType? {
  openspec_types.iter().find_first(o => o.concept_type() == t)
}

///|
/// The OpenSpec type of a document, from its concept type.
fn type_of(doc : @okf.Document) -> OpenSpecType? {
  doc.concept_type().bind(OpenSpecType::of_concept_type)
}

///|
/// The state of a change.
pub(all) enum ChangeState {
  Active
  Archived
} derive(Eq, Hash, Debug)

///|
pub fn ChangeState::to_string(self : ChangeState) -> String {
  match self {
    Active => "active"
    Archived => "archived"
  }
}

///|
pub impl Show for ChangeState with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
/// Parses `active` or `archived`.
pub fn ChangeState::parse(text : String) -> ChangeState? {
  match text {
    "active" => Some(Active)
    "archived" => Some(Archived)
    _ => None
  }
}

///|
pub extend NameError with Eq::{not_equal, equal}

///|
pub extend NameError with @debug.Debug::{to_repr}

///|
pub extend CapabilityPath with Eq::{not_equal, equal}

///|
pub extend CapabilityPath with Hash::{hash, hash_combine}

///|
pub extend CapabilityPath with @debug.Debug::{to_repr}

///|
pub extend CapabilityPath with Show::{output}

///|
pub extend CapabilityPath with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend ChangeName with Eq::{not_equal, equal}

///|
pub extend ChangeName with Hash::{hash, hash_combine}

///|
pub extend ChangeName with @debug.Debug::{to_repr}

///|
pub extend ChangeName with Show::{output}

///|
pub extend ChangeName with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend RequirementName with Eq::{not_equal, equal}

///|
pub extend RequirementName with Hash::{hash, hash_combine}

///|
pub extend RequirementName with @debug.Debug::{to_repr}

///|
pub extend RequirementName with Show::{output}

///|
pub extend TaskNumber with Eq::{not_equal, equal}

///|
pub extend TaskNumber with Hash::{hash, hash_combine}

///|
pub extend TaskNumber with @debug.Debug::{to_repr}

///|
pub extend TaskNumber with Show::{output}

///|
pub extend TaskNumber with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend OpenSpecType with Eq::{not_equal, equal}

///|
pub extend OpenSpecType with Hash::{hash, hash_combine}

///|
pub extend OpenSpecType with @debug.Debug::{to_repr}

///|
pub extend OpenSpecType with Show::{output}

///|
pub extend ChangeState with Eq::{not_equal, equal}

///|
pub extend ChangeState with Hash::{hash, hash_combine}

///|
pub extend ChangeState with @debug.Debug::{to_repr}

///|
pub extend ChangeState with Show::{output}
