///|
/// Raised when a text breaks the rules of an OKF value type. Each case names
/// the input.
pub(all) suberror ValueError {
  /// A bundle label with an empty segment, or a segment with `/`, `:` or white space.
  InvalidLabel(String)
  /// A concept type that is empty or only white space.
  BlankConceptType(String)
  /// A frontmatter key that is not a plain key: a letter, a digit or `_`
  /// first, then letters, digits, `_`, `.` or `-`.
  InvalidFieldKey(String)
  /// A rule name that is not lower-case kebab case: letters, digits and single
  /// `-` between them.
  InvalidRuleName(String)
  /// A search limit outside 1 to `max_search_limit`.
  InvalidSearchLimit(Int32)
  /// A heading level outside 1 to 6.
  InvalidHeadingLevel(Int32)
  /// A date that is not a real calendar date in the form `YYYY-MM-DD`.
  InvalidDate(String)
  /// A text that is not an ISO 8601 instant or a `YYYY-MM-DD` date.
  InvalidInstant(String)
  /// A register, state or record name that is empty or only white space.
  BlankName(String)
  /// A record ID width outside 1 to 9.
  InvalidIdWidth(Int32)
  /// A register transition or superseded state that names a state the
  /// register does not have.
  UnknownState(register~ : String, state~ : String)
  /// A reference field that names a register that no profile defines.
  UnknownRegister(register~ : String)
} derive(Eq, Debug)

///|
fn is_space_char(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
/// A bundle label: its group segments and its name, joined with `/`, such as
/// `morphir/ir`. No segment is empty or holds `/`, `:` or white space.
struct BundleLabel {
  segments : ReadOnlyArray[String]
} derive(Eq, Hash, Debug)

///|
/// Parses a bundle label such as `morphir/ir`, or a bare name such as `ir`.
pub fn BundleLabel::BundleLabel(text : String) -> BundleLabel raise ValueError {
  let segments = text.split("/").map(s => s.to_owned()).collect()
  for s in segments {
    if s.length() == 0 || s.contains(":") || s.iter().any(is_space_char) {
      raise InvalidLabel(text)
    }
  }
  { segments: ReadOnlyArray::from_array(segments), }
}

///|
/// The label of a bundle from its group directories and its directory name.
/// Directory names come from store paths, so they are valid segments.
fn BundleLabel::of_parts(
  group : ArrayView[String],
  name : String,
) -> BundleLabel {
  let segments = group.to_owned()
  segments.push(name)
  { segments: ReadOnlyArray::from_array(segments), }
}

///|
/// The last segment, the bundle name.
pub fn BundleLabel::name(self : BundleLabel) -> String {
  self.segments[self.segments.length() - 1]
}

///|
/// The segments before the name.
pub fn BundleLabel::group(self : BundleLabel) -> ReadOnlyArray[String] {
  ReadOnlyArray::from_array(
    self.segments.exact_view(end=self.segments.length() - 1).to_owned(),
  )
}

///|
/// True when the label has only a name, so it can match a bundle by name.
pub fn BundleLabel::is_bare(self : BundleLabel) -> Bool {
  self.segments.length() == 1
}

///|
pub fn BundleLabel::to_string(self : BundleLabel) -> String {
  self.segments.join("/")
}

///|
pub impl Show for BundleLabel with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
pub impl Compare for BundleLabel with fn compare(self, other) {
  lexical_compare(self.to_string(), other.to_string())
}

///|
/// A directory below the root of a document set or store, given as segments.
/// The root itself has no segments. No segment is empty, `.` or `..`.
struct StoreDir {
  segments : ReadOnlyArray[String]
} derive(Eq, Hash, Debug)

///|
/// Parses a directory path such as `kb/bundles`. `/` and `\` are both
/// separators; `""` is the root. A path that escapes the root is refused.
pub fn StoreDir::StoreDir(text : String) -> StoreDir raise PathError {
  let normalized = normalize_path(text)
  if normalized.above > 0 {
    raise EscapesRoot(text)
  }
  { segments: normalized.segments, }
}

///|
/// The root directory.
pub fn StoreDir::root() -> StoreDir {
  { segments: ReadOnlyArray::from_array([]), }
}

///|
fn StoreDir::of_segments(segments : ArrayView[String]) -> StoreDir {
  { segments: ReadOnlyArray::from_array(segments.to_owned()), }
}

///|
pub fn StoreDir::segments(self : StoreDir) -> ReadOnlyArray[String] {
  self.segments
}

///|
pub fn StoreDir::is_root(self : StoreDir) -> Bool {
  self.segments.is_empty()
}

///|
/// The last segment, or `None` for the root.
pub fn StoreDir::name(self : StoreDir) -> String? {
  self.segments.last()
}

///|
/// The child directory with the name of one entry, such as a listed directory.
pub fn StoreDir::child(self : StoreDir, entry : EntryName) -> StoreDir {
  let segments = self.segments.iter().collect()
  segments.push(entry.to_string())
  { segments: ReadOnlyArray::from_array(segments), }
}

///|
/// The path of the file `entry` in this directory.
pub fn StoreDir::file(self : StoreDir, entry : EntryName) -> StorePath {
  let segments = self.segments.iter().collect()
  segments.push(entry.to_string())
  StorePath::of_segments(segments)
}

///|
/// The store path of a bundle path, with this directory as the bundle root.
pub fn StoreDir::resolve(self : StoreDir, path : BundlePath) -> StorePath {
  let segments = self.segments.iter().collect()
  for segment in path.segments() {
    segments.push(segment)
  }
  StorePath::of_segments(segments)
}

///|
/// True when `path` is inside this directory, at any depth.
pub fn StoreDir::contains(self : StoreDir, path : StorePath) -> Bool {
  path.is_under(self)
}

///|
/// True when `other` is this directory or below it.
pub fn StoreDir::encloses(self : StoreDir, other : StoreDir) -> Bool {
  if self.segments.length() > other.segments.length() {
    return false
  }
  for i, s in self.segments {
    if other.segments[i] != s {
      return false
    }
  }
  true
}

///|
pub fn StoreDir::to_string(self : StoreDir) -> String {
  self.segments.join("/")
}

///|
pub impl Show for StoreDir with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
pub impl Compare for StoreDir with fn compare(self, other) {
  compare_segments(self.segments, other.segments)
}

///|
/// One name in a directory listing: one segment that is not empty, `.` or
/// `..` and has no `/` or `\`.
struct EntryName {
  text : String
} derive(Eq, Hash, Debug)

///|
pub fn EntryName::EntryName(text : String) -> EntryName raise PathError {
  if text.length() == 0 || text == "." || text == ".." {
    raise EmptyPath(text)
  }
  if text.contains("/") || text.contains("\\") {
    raise EscapesRoot(text)
  }
  { text, }
}

///|
pub fn EntryName::to_string(self : EntryName) -> String {
  self.text
}

///|
pub impl Show for EntryName with fn output(self, logger) {
  logger.write_string(self.text)
}

///|
/// An OKF concept `type`, such as `Decision Record`. It is not blank, and two
/// concept types are equal when they differ only in letter case.
struct ConceptType {
  text : String
} derive(Debug)

///|
pub fn ConceptType::ConceptType(text : String) -> ConceptType raise ValueError {
  if text.iter().all(is_space_char) {
    raise BlankConceptType(text)
  }
  { text, }
}

///|
/// The type as written.
pub fn ConceptType::to_string(self : ConceptType) -> String {
  self.text
}

///|
pub impl Eq for ConceptType with fn equal(self, other) {
  self.text.to_lower() == other.text.to_lower()
}

///|
pub impl Hash for ConceptType with fn hash_combine(self, hasher) {
  hasher.combine_string(self.text.to_lower())
}

///|
pub impl Show for ConceptType with fn output(self, logger) {
  logger.write_string(self.text)
}

///|
pub impl Compare for ConceptType with fn compare(self, other) {
  lexical_compare(self.text.to_lower(), other.text.to_lower())
}

///|
fn is_key_char(c : Char, first : Bool) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '_' ||
  (!first && (c == '.' || c == '-'))
}

///|
/// A plain frontmatter key that edits can write and profiles can define: a
/// letter, a digit or `_` first, then letters, digits, `_`, `.` or `-`. Reading
/// metadata takes any YAML key as text.
struct FieldKey {
  text : String
} derive(Eq, Hash, Debug)

///|
pub fn FieldKey::FieldKey(text : String) -> FieldKey raise ValueError {
  let chars = text.to_array()
  let mut ok = chars.length() > 0
  for i, c in chars {
    if !is_key_char(c, i == 0) {
      ok = false
    }
  }
  if !ok {
    raise InvalidFieldKey(text)
  }
  { text, }
}

///|
pub fn FieldKey::to_string(self : FieldKey) -> String {
  self.text
}

///|
pub impl Show for FieldKey with fn output(self, logger) {
  logger.write_string(self.text)
}

///|
pub impl Compare for FieldKey with fn compare(self, other) {
  lexical_compare(self.text, other.text)
}

///|
/// The name of a validation rule, in lower-case kebab case, such as `link-broken`.
struct RuleName {
  text : String
} derive(Eq, Hash, Debug)

///|
pub fn RuleName::RuleName(text : String) -> RuleName raise ValueError {
  let ok = text.length() > 0 &&
    !text.has_prefix("-") &&
    !text.has_suffix("-") &&
    !text.contains("--") &&
    text
    .iter()
    .all(c => (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-')
  if !ok {
    raise InvalidRuleName(text)
  }
  { text, }
}

///|
pub fn RuleName::to_string(self : RuleName) -> String {
  self.text
}

///|
pub impl Show for RuleName with fn output(self, logger) {
  logger.write_string(self.text)
}

///|
pub impl Compare for RuleName with fn compare(self, other) {
  lexical_compare(self.text, other.text)
}

///|
/// The largest search limit.
pub let max_search_limit : Int32 = 1000

///|
/// The number of results that a search request may give: 1 to `max_search_limit`.
struct SearchLimit {
  value : Int32
} derive(Eq, Hash, Debug)

///|
pub fn SearchLimit::SearchLimit(value : Int32) -> SearchLimit raise ValueError {
  if value < 1 || value > max_search_limit {
    raise InvalidSearchLimit(value)
  }
  { value, }
}

///|
/// The default limit, 20.
pub fn SearchLimit::default() -> SearchLimit {
  { value: 20, }
}

///|
pub fn SearchLimit::to_int(self : SearchLimit) -> Int32 {
  self.value
}

///|
/// A heading level from 1 to 6.
struct HeadingLevel {
  value : Int32
} derive(Eq, Hash, Compare, Debug)

///|
pub fn HeadingLevel::HeadingLevel(
  value : Int32,
) -> HeadingLevel raise ValueError {
  if value < 1 || value > 6 {
    raise InvalidHeadingLevel(value)
  }
  { value, }
}

///|
/// A level that a Markdown parser gave. CommonMark levels are 1 to 6; a value
/// outside that range is clamped.
fn HeadingLevel::of_parser(level : Int32) -> HeadingLevel {
  { value: if level < 1 { 1 } else if level > 6 { 6 } else { level }, }
}

///|
pub fn HeadingLevel::to_int(self : HeadingLevel) -> Int32 {
  self.value
}

///|
pub impl Show for HeadingLevel with fn output(self, logger) {
  logger.write_object(self.value)
}

///|
/// A calendar date in the form `YYYY-MM-DD`, as log headings and log edits use.
struct LogDate {
  text : String
  instant : Instant
} derive(Eq, Hash, Debug)

///|
/// Parses a real calendar date written exactly as `YYYY-MM-DD`.
pub fn LogDate::LogDate(text : String) -> LogDate raise ValueError {
  match Instant::parse_date(text) {
    Some(instant) => { text, instant, }
    None => raise InvalidDate(text)
  }
}

///|
/// The UTC calendar date of an instant.
pub fn LogDate::of_instant(instant : Instant) -> LogDate {
  let text = instant.date_text()
  { text, instant: Instant::parse_date(text).unwrap_or(instant), }
}

///|
pub fn LogDate::to_string(self : LogDate) -> String {
  self.text
}

///|
/// The start of the date in UTC.
pub fn LogDate::instant(self : LogDate) -> Instant {
  self.instant
}

///|
pub impl Show for LogDate with fn output(self, logger) {
  logger.write_string(self.text)
}

///|
pub impl Compare for LogDate with fn compare(self, other) {
  self.instant.compare(other.instant)
}

///|
/// The OKF version that a bundle declares in its root index. Only
/// `OkfVersion::parse` makes values, so `Unknown` never holds a known version.
pub enum OkfVersion {
  V01
  V02
  /// A version that this library does not know, with its text.
  Unknown(String)
} derive(Eq, Debug)

///|
pub fn OkfVersion::parse(text : String) -> OkfVersion {
  match text {
    "0.1" => V01
    "0.2" => V02
    _ => Unknown(text)
  }
}

///|
pub fn OkfVersion::to_string(self : OkfVersion) -> String {
  match self {
    V01 => "0.1"
    V02 => "0.2"
    Unknown(text) => text
  }
}

///|
pub fn OkfVersion::is_known(self : OkfVersion) -> Bool {
  !(self is Unknown(_))
}

///|
pub extend ValueError with Eq::{not_equal, equal}

///|
pub extend ValueError with @debug.Debug::{to_repr}

///|
pub extend BundleLabel with Eq::{not_equal, equal}

///|
pub extend BundleLabel with Hash::{hash, hash_combine}

///|
pub extend BundleLabel with @debug.Debug::{to_repr}

///|
pub extend BundleLabel with Show::{output}

///|
pub extend BundleLabel with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend StoreDir with Eq::{not_equal, equal}

///|
pub extend StoreDir with Hash::{hash, hash_combine}

///|
pub extend StoreDir with @debug.Debug::{to_repr}

///|
pub extend StoreDir with Show::{output}

///|
pub extend StoreDir with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend EntryName with Eq::{not_equal, equal}

///|
pub extend EntryName with Hash::{hash, hash_combine}

///|
pub extend EntryName with @debug.Debug::{to_repr}

///|
pub extend EntryName with Show::{output}

///|
pub extend ConceptType with @debug.Debug::{to_repr}

///|
pub extend ConceptType with Eq::{not_equal, equal}

///|
pub extend ConceptType with Hash::{hash, hash_combine}

///|
pub extend ConceptType with Show::{output}

///|
pub extend ConceptType with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend FieldKey with Eq::{not_equal, equal}

///|
pub extend FieldKey with Hash::{hash, hash_combine}

///|
pub extend FieldKey with @debug.Debug::{to_repr}

///|
pub extend FieldKey with Show::{output}

///|
pub extend FieldKey with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend RuleName with Eq::{not_equal, equal}

///|
pub extend RuleName with Hash::{hash, hash_combine}

///|
pub extend RuleName with @debug.Debug::{to_repr}

///|
pub extend RuleName with Show::{output}

///|
pub extend RuleName with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend SearchLimit with Eq::{not_equal, equal}

///|
pub extend SearchLimit with Hash::{hash, hash_combine}

///|
pub extend SearchLimit with @debug.Debug::{to_repr}

///|
pub extend HeadingLevel with Eq::{not_equal, equal}

///|
pub extend HeadingLevel with Hash::{hash, hash_combine}

///|
pub extend HeadingLevel with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend HeadingLevel with @debug.Debug::{to_repr}

///|
pub extend LogDate with Eq::{not_equal, equal}

///|
pub extend LogDate with Hash::{hash, hash_combine}

///|
pub extend LogDate with @debug.Debug::{to_repr}

///|
pub extend LogDate with Show::{output}

///|
pub extend LogDate with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend OkfVersion with Eq::{not_equal, equal}

///|
pub extend OkfVersion with @debug.Debug::{to_repr}

///|
pub extend HeadingLevel with Show::{to_string, output}
