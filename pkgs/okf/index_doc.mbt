///|
/// One entry of an `index.md` section: `* [Title](link) - description`.
pub(all) struct IndexEntry {
  text : String
  destination : String
  description : String?
  /// The file line, counted from 1.
  line : Int32
} derive(Eq, Debug)

///|
/// The heading of an index section.
pub(all) enum IndexHeading {
  /// The lines before the first heading.
  Preamble
  /// A heading line with its text and level.
  Titled(String, HeadingLevel)
} derive(Eq, Debug)

///|
/// One section of an `index.md`: a heading with its entries and other lines.
pub struct IndexSection {
  heading : IndexHeading
  /// The file line of the heading, or of the body start for the preamble.
  line : Int32
  entries : ReadOnlyArray[IndexEntry]
  /// Lines that are not entries, such as prose.
  text : ReadOnlyArray[String]
} derive(Eq, Debug)

///|
/// The heading text, or `None` for the preamble.
pub fn IndexSection::title(self : IndexSection) -> String? {
  match self.heading {
    Preamble => None
    Titled(text, _) => Some(text)
  }
}

///|
/// The parsed body of an `index.md` (OKF v0.2, section 8).
pub struct IndexModel {
  sections : ReadOnlyArray[IndexSection]
} derive(Eq, Debug)

///|
/// Every entry, in document order.
pub fn IndexModel::entries(self : IndexModel) -> Array[IndexEntry] {
  let out = []
  for section in self.sections {
    for entry in section.entries {
      out.push(entry)
    }
  }
  out
}

///|
/// The section with this heading.
pub fn IndexModel::section(
  self : IndexModel,
  heading : String,
) -> IndexSection? {
  self.sections.iter().find_first(s => s.title() == Some(heading))
}

///|
/// Parses an ATX heading line, `## Text`.
fn parse_heading_line(line : String) -> (HeadingLevel, String)? {
  let trimmed = line.trim_start(chars=" ").to_owned()
  if line.length() - trimmed.length() > 3 {
    return None
  }
  let mut level = 0
  while level < trimmed.length() && trimmed[level] == '#' {
    level += 1
  }
  if level == 0 || level > 6 {
    return None
  }
  if level < trimmed.length() && trimmed[level] != ' ' && trimmed[level] != '\t' {
    return None
  }
  let text = trimmed[level:].trim(chars=" \t").to_owned()
  // A closing sequence of `#` characters is not part of the text.
  let text = text.trim_end(chars="#").trim_end(chars=" \t").to_owned()
  // The loop above keeps the level from 1 to 6.
  Some(({ value: level, }, text))
}

///|
/// Parses an index entry line: a list item that starts with a link, then an
/// optional ` - `, ` — ` or `: ` and a description.
pub fn parse_index_entry(
  line : String,
  line_number~ : Int32 = 0,
) -> IndexEntry? {
  let t = line.trim_start(chars=" \t").to_owned()
  guard t.length() >= 2 &&
    (t[0] == '*' || t[0] == '-' || t[0] == '+') &&
    t[1] == ' ' else {
    return None
  }
  let t = t[2:].trim_start(chars=" \t").to_owned()
  guard t.has_prefix("[") else { return None }
  // Find the `](` that closes the link text, allowing nested brackets.
  let mut depth = 0
  let mut close = -1
  for i in 0..<t.length() {
    let c = t[i]
    if c == '[' {
      depth += 1
    } else if c == ']' {
      depth -= 1
      if depth == 0 {
        close = i
        break
      }
    }
  }
  guard close > 0 && close + 1 < t.length() && t[close + 1] == '(' else {
    return None
  }
  let text = t[1:close].to_owned()
  let rest = t[close + 2:].to_owned()
  guard rest.find(")") is Some(end) else { return None }
  let destination = rest[:end].trim(chars=" \t").to_owned()
  // Strip an optional title: `(dest "title")`.
  let destination = match destination.find(" ") {
    Some(i) => destination[:i].to_owned()
    None => destination
  }
  let tail = rest[end + 1:].trim(chars=" \t").to_owned()
  let description = if tail.length() == 0 {
    None
  } else {
    let mut d = tail
    for sep in ["- ", "— ", "– ", ": "] {
      if d.has_prefix(sep) {
        d = d[sep.length():].to_owned()
        break
      }
    }
    if d == "-" || d == "—" {
      d = ""
    }
    let d = d.trim(chars=" \t").to_owned()
    if d.length() == 0 {
      None
    } else {
      Some(d)
    }
  }
  Some({ text, destination, description, line: line_number, })
}

///|
/// The body lines of a document with their file line numbers, without the
/// lines inside fenced code blocks.

///|
/// The body lines of a document with their file line numbers, without the
/// lines inside fenced code blocks.
pub fn Document::prose_lines(self : Document) -> Array[(Int32, String)] {
  body_lines(self)
}

///|
fn body_lines(doc : Document) -> Array[(Int32, String)] {
  let out = []
  let mut fence : String? = None
  for i, line in split_lines(doc.body()) {
    let number = doc.body_line() + i
    let t = line.text.trim_start(chars=" ").to_owned()
    match fence {
      Some(marker) => {
        if t.has_prefix(marker) {
          fence = None
        }
        continue
      }
      None =>
        if t.has_prefix("```") || t.has_prefix("~~~") {
          fence = Some(t[:3].to_owned())
          continue
        }
    }
    out.push((number, line.text))
  }
  out
}

///|
/// Parses the body of an index document.
pub fn Document::index_model(self : Document) -> IndexModel {
  let sections : Array[IndexSection] = []
  let mut heading = Preamble
  let mut start = self.body_line()
  let entries : Array[IndexEntry] = []
  let text : Array[String] = []
  let flush = () => {
    if heading is Titled(_, _) || !entries.is_empty() || !text.is_empty() {
      sections.push({
        heading,
        line: start,
        entries: ReadOnlyArray::from_array(entries.copy()),
        text: ReadOnlyArray::from_array(text.copy()),
      })
    }
    entries.clear()
    text.clear()
  }
  for pair in body_lines(self) {
    let (number, line) = pair
    match parse_heading_line(line) {
      Some((level, title)) => {
        flush()
        heading = Titled(title, level)
        start = number
      }
      None =>
        match parse_index_entry(line, line_number=number) {
          Some(entry) => entries.push(entry)
          None => if line.trim(chars=" \t").length() > 0 { text.push(line) }
        }
    }
  }
  flush()
  { sections: ReadOnlyArray::from_array(sections), }
}

///|
/// Normalizes a description for drift checks: lower case, single spaces, and
/// no trailing full stop.
pub fn normalize_description(text : String) -> String {
  let words = text
    .to_lower()
    .split(" ")
    .flat_map(w => w.split("\t"))
    .map(w => w.to_owned())
    .filter(w => w.length() > 0)
    .collect()
  let joined = words.join(" ")
  if joined.has_suffix(".") {
    joined[:joined.length() - 1].to_owned()
  } else {
    joined
  }
}

///|
/// The index entries of a bundle that link to `target`, with their index documents.
pub fn Bundle::index_entries_for(
  self : Bundle,
  target : BundlePath,
) -> Array[(Document, IndexEntry)] {
  let out = []
  for index in self.indexes() {
    for entry in index.index_model().entries() {
      let link = body_link(entry.text, entry.destination, entry.line)
      match resolve_link(self, index, link) {
        StoreTarget(path~, escapes=false, ..) =>
          if self.bundle_path_of(path) == Some(target) {
            out.push((index, entry))
          }
        _ => ()
      }
    }
  }
  out
}

///|
/// A coverage gap: a concept that no index of its bundle links to.
pub fn Bundle::unindexed_concepts(self : Bundle) -> Array[Document] {
  let covered : Map[BundlePath, Bool] = Map([])
  for index in self.indexes() {
    for entry in index.index_model().entries() {
      let link = body_link(entry.text, entry.destination, entry.line)
      match resolve_link(self, index, link) {
        StoreTarget(path~, escapes=false, ..) =>
          match self.bundle_path_of(path) {
            Some(rel) => covered[rel] = true
            None => ()
          }
        _ => ()
      }
    }
  }
  self.concepts().iter().filter(c => !covered.contains(c.path())).collect()
}

///|
/// One description drift: an index entry whose description differs from the
/// `description` of its concept.
pub(all) struct Drift {
  index : Document
  entry : IndexEntry
  concept : Document
  expected : String
}

///|
/// The index entries whose description differs from their concept.
pub fn Bundle::description_drift(self : Bundle) -> Array[Drift] {
  let out = []
  for index in self.indexes() {
    for entry in index.index_model().entries() {
      let link = body_link(entry.text, entry.destination, entry.line)
      match resolve_link(self, index, link) {
        StoreTarget(path~, escapes=false, ..) =>
          match self.bundle_path_of(path) {
            Some(rel) =>
              match self.document(rel) {
                Some(concept) if concept.is_concept() =>
                  match (concept.metadata().description(), entry.description) {
                    (Some(expected), Some(actual)) =>
                      if normalize_description(expected) !=
                        normalize_description(actual) {
                        out.push({ index, entry, concept, expected, })
                      }
                    (Some(expected), None) =>
                      out.push({ index, entry, concept, expected, })
                    _ => ()
                  }
                _ => ()
              }
            None => ()
          }
        _ => ()
      }
    }
  }
  out
}

///|
/// Generates the content of the `index.md` for the bundle directory `dir`:
/// its concepts grouped by `type` (sorted by type, then by title ignoring
/// case), and a `Subdirectories` section. `describe` gives the description of
/// a subdirectory. The root index keeps the `okf_version` of the bundle.
pub fn generate_index(
  bundle : Bundle,
  dir~ : StoreDir = StoreDir::root(),
  describe~ : (StoreDir) -> String? = _ => None,
) -> String {
  let base = dir
  let dir = dir.segments()
  let groups : Array[(IndexGroup, Array[(String, String, String?)])] = []
  let add = (group : IndexGroup, entry : (String, String, String?)) => {
    // Concept types group by their exact text, so `Decision` and `decision`
    // stay separate sections.
    let same = (g : IndexGroup) => {
      g.heading() == group.heading() && g.rank() == group.rank()
    }
    match groups.search_by(g => same(g.0)) {
      Some(i) => groups[i].1.push(entry)
      None => groups.push((group, [entry]))
    }
  }
  let subdirs : Array[EntryName] = []
  for doc in bundle.documents() {
    let segments = doc.path().segments()
    let n = segments.length()
    guard n > dir.length() else { continue }
    let mut inside = true
    for i, s in dir {
      if segments[i] != s {
        inside = false
        break
      }
    }
    guard inside else { continue }
    if n == dir.length() + 1 {
      guard !doc.kind().is_index() && !(doc.kind() is Log) else { continue }
      let group = match doc.concept_type() {
        Some(t) => Typed(t)
        None => Untyped
      }
      add(
        group,
        (doc.display_title(), doc.path().name(), doc.metadata().description()),
      )
    } else {
      // A segment of a bundle path is always a valid entry name.
      let child = EntryName(segments[dir.length()]) catch { _ => continue }
      if !subdirs.contains(child) {
        subdirs.push(child)
      }
    }
  }
  subdirs.sort_by((a, b) => lexical_compare(a.to_string(), b.to_string()))
  for child in subdirs {
    let name = child.to_string()
    add(Subdirectories, (name, name + "/index.md", describe(base.child(child))))
  }
  // Sections sort by heading text, as the reference generator does; a concept
  // type and a group with the same heading stay separate sections.
  groups.sort_by((a, b) => {
    let c = lexical_compare(a.0.heading(), b.0.heading())
    if c != 0 {
      c
    } else {
      a.0.rank().compare(b.0.rank())
    }
  })
  let sections = groups.map(group => {
    let entries = group.1
    entries.sort_by((a, b) => lexical_compare(a.0.to_lower(), b.0.to_lower()))
    let lines = ["# \{group.0.heading()}", ""]
    for e in entries {
      let suffix = match e.2 {
        Some(d) => " - " + d
        None => ""
      }
      lines.push("* [\{e.0}](\{e.1})\{suffix}")
    }
    lines.join("\n")
  })
  let body = sections.join("\n\n") + "\n"
  if dir.is_empty() {
    match bundle.okf_version() {
      Some(v) => "---\nokf_version: \"\{v.to_string()}\"\n---\n\n" + body
      None => body
    }
  } else {
    body
  }
}

///|
pub extend IndexEntry with Eq::{not_equal, equal}

///|
pub extend IndexEntry with @debug.Debug::{to_repr}

///|
pub extend IndexSection with Eq::{not_equal, equal}

///|
pub extend IndexSection with @debug.Debug::{to_repr}

///|
pub extend IndexModel with Eq::{not_equal, equal}

///|
pub extend IndexModel with @debug.Debug::{to_repr}

///|
/// A section of a generated index.
pub(all) enum IndexGroup {
  /// The concepts of one type.
  Typed(ConceptType)
  /// The concepts without a type, under `Other`.
  Untyped
  /// The subdirectories.
  Subdirectories
} derive(Eq, Debug)

///|
/// The heading text of the section.
pub fn IndexGroup::heading(self : IndexGroup) -> String {
  match self {
    Typed(t) => t.to_string()
    Untyped => "Other"
    Subdirectories => "Subdirectories"
  }
}

///|
fn IndexGroup::rank(self : IndexGroup) -> Int32 {
  match self {
    Typed(_) => 0
    Untyped => 1
    Subdirectories => 2
  }
}

///|
pub extend IndexGroup with Eq::{not_equal, equal}

///|
pub extend IndexGroup with @debug.Debug::{to_repr}

///|
pub extend IndexHeading with Eq::{not_equal, equal}

///|
pub extend IndexHeading with @debug.Debug::{to_repr}
