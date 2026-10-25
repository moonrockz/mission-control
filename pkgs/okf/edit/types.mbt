///|
/// A raw YAML value for a frontmatter key: one line, or a first line and
/// indented continuation lines, so that it cannot add keys or close the
/// frontmatter block.
struct RawYaml {
  text : String
} derive(Eq, Hash, Debug)

///|
/// Checks a raw YAML value. Raises `InvalidValue` when a later line is not
/// indented.
pub fn RawYaml::RawYaml(text : String) -> RawYaml raise EditError {
  for i, line in @okf.split_lines(text) {
    if i == 0 {
      continue
    }
    let t = line.text
    if t.length() > 0 && !t.has_prefix(" ") && !t.has_prefix("\t") {
      raise InvalidValue(text)
    }
  }
  { text, }
}

///|
/// A scalar, quoted when YAML needs it. Quoting escapes line breaks, so the
/// value is always one line.
pub fn RawYaml::scalar(value : String) -> RawYaml {
  { text: yaml_scalar(value), }
}

///|
/// A list of scalars in flow form, `[a, b]`.
pub fn RawYaml::list(values : ArrayView[String]) -> RawYaml {
  { text: "[" + values.iter().map(yaml_scalar).collect().join(", ") + "]", }
}

///|
pub fn RawYaml::to_string(self : RawYaml) -> String {
  self.text
}

///|
pub impl Show for RawYaml with fn output(self, logger) {
  logger.write_string(self.text)
}

///|
/// The heading text of an index section: one line that is not blank.
struct SectionName {
  text : String
} derive(Eq, Hash, Debug)

///|
/// Checks a section name. Raises `LineBreak` for a line break and `BlankText`
/// for a blank text.
pub fn SectionName::SectionName(text : String) -> SectionName raise EditError {
  check_one_line("section", text)
  if text.trim(chars=" \t").length() == 0 {
    raise BlankText(field="section", text~)
  }
  { text, }
}

///|
pub fn SectionName::to_string(self : SectionName) -> String {
  self.text
}

///|
pub impl Show for SectionName with fn output(self, logger) {
  logger.write_string(self.text)
}

///|
/// The line of an index entry: `* [title](destination) - description`. The
/// title, the destination and the description are each one line, so the
/// entry is one line.
struct IndexEntryLine {
  text : String
} derive(Eq, Hash, Debug)

///|
/// Builds an index entry line. Raises `LineBreak` when a part has a line
/// break. A blank description gives no ` - description` part.
pub fn IndexEntryLine::IndexEntryLine(
  title : String,
  destination : String,
  description? : String,
) -> IndexEntryLine raise EditError {
  check_one_line("title", title)
  check_one_line("destination", destination)
  match description {
    Some(d) => check_one_line("description", d)
    None => ()
  }
  let text = match description {
    Some(d) if d.length() > 0 => "* [\{title}](\{destination}) - \{d}"
    _ => "* [\{title}](\{destination})"
  }
  { text, }
}

///|
pub fn IndexEntryLine::to_string(self : IndexEntryLine) -> String {
  self.text
}

///|
pub impl Show for IndexEntryLine with fn output(self, logger) {
  logger.write_string(self.text)
}

///|
/// Why a new concept path is refused.
pub(all) enum PathRefusal {
  /// The file name is `index.md` or `log.md`.
  ReservedName(String)
  /// The path leaves the bundle.
  EscapesBundle(String)
  /// A document already exists at the path.
  AlreadyExists(String)
  /// The path does not end with `.md`.
  NotMarkdown(String)
} derive(Eq, Debug)

///|
/// Why a register transition is refused.
pub(all) enum TransitionRefusal {
  /// The register refuses the transition.
  Refused(@okf.TransitionDenial)
  /// The register has no state key, so it has no transitions.
  NoStateKey(register~ : @okf.RegisterName)
  /// An extra key is the state key, which would replace the checked state.
  StateKeyInExtra(@okf.FieldKey)
  /// The edit would leave frontmatter that does not parse.
  PreviewInvalid(@okf.MetadataError)
} derive(Debug)

///|
/// Raised by the planners. One error covers every way that a plan can fail.
pub(all) suberror PlanError {
  /// The path of a new concept is refused.
  PathRefused(PathRefusal)
  /// A text edit cannot apply.
  EditFailed(EditError)
  /// A register refuses a transition.
  TransitionRefused(TransitionRefusal)
} derive(Debug)

///|
pub extend RawYaml with Eq::{not_equal, equal}

///|
pub extend RawYaml with Hash::{hash, hash_combine}

///|
pub extend RawYaml with @debug.Debug::{to_repr}

///|
pub extend RawYaml with Show::{output}

///|
pub extend SectionName with Eq::{not_equal, equal}

///|
pub extend SectionName with Hash::{hash, hash_combine}

///|
pub extend SectionName with @debug.Debug::{to_repr}

///|
pub extend SectionName with Show::{output}

///|
pub extend PathRefusal with Eq::{not_equal, equal}

///|
pub extend PathRefusal with @debug.Debug::{to_repr}

///|
pub extend TransitionRefusal with @debug.Debug::{to_repr}

///|
pub extend PlanError with @debug.Debug::{to_repr}

///|
pub extend IndexEntryLine with Eq::{not_equal, equal}

///|
pub extend IndexEntryLine with Hash::{hash, hash_combine}

///|
pub extend IndexEntryLine with @debug.Debug::{to_repr}

///|
pub extend IndexEntryLine with Show::{output}
