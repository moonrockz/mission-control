///|
/// One `log.md` entry, such as `* **Update**: Added revenue metric.`
pub(all) struct LogEntry {
  /// The bold first word, such as `Update`, when it is present.
  label : String?
  text : String
  line : Int32
} derive(Eq, Debug)

///|
/// The heading of a `log.md` section.
pub(all) enum LogHeading {
  /// A calendar date, `YYYY-MM-DD`.
  Dated(LogDate)
  /// Any other heading text.
  Undated(String)
} derive(Eq, Debug)

///|
/// The heading as written.
pub fn LogHeading::to_string(self : LogHeading) -> String {
  match self {
    Dated(date) => date.to_string()
    Undated(text) => text
  }
}

///|
pub impl Show for LogHeading with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
fn LogHeading::parse(text : String) -> LogHeading {
  try LogDate(text) catch {
    _ => Undated(text)
  } noraise {
    date => Dated(date)
  }
}

///|
/// One `log.md` section, from one `##` heading to the next.
pub struct LogSection {
  heading : LogHeading
  line : Int32
  entries : ReadOnlyArray[LogEntry]
} derive(Eq, Debug)

///|
/// The parsed body of a `log.md` (OKF v0.2, section 9).
pub struct LogModel {
  sections : ReadOnlyArray[LogSection]
} derive(Eq, Debug)

///|
fn parse_log_entry(line : String, number : Int32) -> LogEntry? {
  let t = line.trim_start(chars=" \t").to_owned()
  guard t.length() >= 2 && (t[0] == '*' || t[0] == '-') && t[1] == ' ' else {
    return None
  }
  let t = t[2:].trim(chars=" \t").to_owned()
  if t.has_prefix("**") {
    match t[2:].find("**") {
      Some(end) => {
        let label = t[2:2 + end].trim_end(chars=":").to_owned()
        let rest = t[4 + end:]
          .trim_start(chars=":")
          .trim(chars=" \t")
          .to_owned()
        return Some({ label: Some(label), text: rest, line: number, })
      }
      None => ()
    }
  }
  Some({ label: None, text: t, line: number, })
}

///|
/// Parses the body of a log document. Each `##` heading starts a section.
pub fn Document::log_model(self : Document) -> LogModel {
  let heads : Array[(LogHeading, Int32)] = []
  let entries : Array[Array[LogEntry]] = []
  for pair in body_lines(self) {
    let (number, line) = pair
    match parse_heading_line(line) {
      Some((level, text)) if level.to_int() == 2 => {
        heads.push((LogHeading::parse(text), number))
        entries.push([])
      }
      Some(_) => ()
      None =>
        match (entries.last(), parse_log_entry(line, number)) {
          (Some(list), Some(entry)) => list.push(entry)
          _ => ()
        }
    }
  }
  let sections = heads.mapi((i, head) => {
    heading: head.0,
    line: head.1,
    entries: ReadOnlyArray::from_array(entries[i]),
  })
  { sections: ReadOnlyArray::from_array(sections), }
}

///|
/// The first pair of dated sections that are not newest first, if any. The
/// order comes from the dates, not from the heading text.
pub fn LogModel::order_problem(self : LogModel) -> (LogSection, LogSection)? {
  for i in 1..<self.sections.length() {
    let a = self.sections[i - 1]
    let b = self.sections[i]
    match (a.heading, b.heading) {
      (Dated(da), Dated(db)) if da < db => return Some((a, b))
      _ => ()
    }
  }
  None
}

///|
/// The sections whose heading is not a `YYYY-MM-DD` date.
pub fn LogModel::undated_sections(self : LogModel) -> Array[LogSection] {
  self.sections.iter().filter(s => s.heading is Undated(_)).collect()
}

///|
/// A region of a document that starts at a marker comment, such as
/// `<!-- kb:sources -->`, and runs to the end of the document.
pub(all) struct Region {
  marker : String
  /// The text before the marker line, including the marker line.
  preamble : String
  /// The text after the marker line.
  content : String
  /// The file line of the marker.
  line : Int32
} derive(Eq, Debug)

///|
/// The comment form of a marker name: `<!-- name -->`.
pub fn marker_comment(name : String) -> String {
  "<!-- \{name} -->"
}

///|
/// Finds the region that the marker `<!-- name -->` starts.
pub fn find_region(text : String, name : String) -> Region? {
  let marker = marker_comment(name)
  for i, line in split_lines(text) {
    if line.text.trim(chars=" \t") == marker {
      let end = line.start + line.text.length() + line.ending.length()
      return Some({
        marker: name,
        preamble: text[:end].to_owned(),
        content: text[end:].to_owned(),
        line: i + 1,
      })
    }
  }
  None
}

///|
pub extend LogEntry with Eq::{not_equal, equal}

///|
pub extend LogEntry with @debug.Debug::{to_repr}

///|
pub extend LogSection with Eq::{not_equal, equal}

///|
pub extend LogSection with @debug.Debug::{to_repr}

///|
pub extend LogModel with Eq::{not_equal, equal}

///|
pub extend LogModel with @debug.Debug::{to_repr}

///|
pub extend Region with Eq::{not_equal, equal}

///|
pub extend Region with @debug.Debug::{to_repr}

///|
pub extend LogHeading with Eq::{not_equal, equal}

///|
pub extend LogHeading with @debug.Debug::{to_repr}

///|
pub extend LogHeading with Show::{output}
