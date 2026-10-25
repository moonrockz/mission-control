///|
/// A half-open UTF-16 range in the original input, with a one-based start
/// line and column. Markdown ranges cover the paragraph, including markup.
struct SourceSpan {
  start : Int32
  end : Int32
  line : Int32
  column : Int32
} derive(Eq, Debug)

///|
pub fn SourceSpan::start(self : SourceSpan) -> Int32 {
  self.start
}

///|
pub fn SourceSpan::end(self : SourceSpan) -> Int32 {
  self.end
}

///|
pub fn SourceSpan::line(self : SourceSpan) -> Int32 {
  self.line
}

///|
pub fn SourceSpan::column(self : SourceSpan) -> Int32 {
  self.column
}

///|
/// Markdown paths resolve against the retained MDC document. Locations are
/// absent if that document was parsed with `locs=false`.
pub enum Origin {
  Text(SourceSpan)
  Markdown(path~ : @mdc.NodePath, span~ : SourceSpan?)
} derive(Eq, Debug)

///|
struct Occurrence {
  requirement : Requirement
  origin : Origin
} derive(Eq, Debug)

///|
pub fn Occurrence::requirement(self : Occurrence) -> Requirement {
  self.requirement
}

///|
pub fn Occurrence::origin(self : Occurrence) -> Origin {
  self.origin
}

///|
struct Diagnostic {
  text : String
  error : ParseError
  origin : Origin
} derive(Eq, Debug)

///|
pub fn Diagnostic::text(self : Diagnostic) -> String {
  self.text
}

///|
pub fn Diagnostic::error(self : Diagnostic) -> ParseError {
  self.error
}

///|
pub fn Diagnostic::origin(self : Diagnostic) -> Origin {
  self.origin
}

///|
/// A requirement block: the requirements and diagnostics under one Markdown
/// requirement heading. The name is the rest of the heading text, free text.
struct RequirementBlock {
  name : String
  heading : @mdc.SourceRange?
  requirements : ReadOnlyArray[Occurrence]
  diagnostics : ReadOnlyArray[Diagnostic]
} derive(Debug)

///|
pub fn RequirementBlock::name(self : RequirementBlock) -> String {
  self.name
}

///|
/// The source range of the heading, when the document has locations.
pub fn RequirementBlock::heading(self : RequirementBlock) -> @mdc.SourceRange? {
  self.heading
}

///|
pub fn RequirementBlock::requirements(
  self : RequirementBlock,
) -> ReadOnlyArray[Occurrence] {
  self.requirements
}

///|
pub fn RequirementBlock::diagnostics(
  self : RequirementBlock,
) -> ReadOnlyArray[Diagnostic] {
  self.diagnostics
}

///|
/// An immutable extraction result. Syntax errors do not discard valid siblings.
/// The Markdown constructor retains its MDC document and frontmatter. With
/// Markdown requirement headings, `blocks()` gives the blocks, and
/// `requirements()` and `diagnostics()` list the contents of every block.
struct Specification {
  requirements : ReadOnlyArray[Occurrence]
  diagnostics : ReadOnlyArray[Diagnostic]
  blocks : ReadOnlyArray[RequirementBlock]
  document : @mdc.Document?
} derive(Debug)

///|
pub fn Specification::requirements(
  self : Specification,
) -> ReadOnlyArray[Occurrence] {
  self.requirements
}

///|
pub fn Specification::diagnostics(
  self : Specification,
) -> ReadOnlyArray[Diagnostic] {
  self.diagnostics
}

///|
pub fn Specification::document(self : Specification) -> @mdc.Document? {
  self.document
}

///|
/// The requirement blocks, in source order. Without heading rules, none.
pub fn Specification::blocks(
  self : Specification,
) -> ReadOnlyArray[RequirementBlock] {
  self.blocks
}

///|
fn collect_candidate(
  text : String,
  origin : Origin,
  requirements : Array[Occurrence],
  diagnostics : Array[Diagnostic],
  vocabulary : Vocabulary,
) -> Unit {
  let requirement = parse_sentence(text, vocabulary).requirement catch {
      error => {
        diagnostics.push({ text, error, origin, })
        return
      }
    }
  requirements.push({ requirement, origin, })
}

///|
/// Parse one requirement per nonblank line, with the vocabulary of
/// `dialects`. Every nonblank line is checked. Accept LF, CRLF, CR and a
/// leading BOM. Spans exclude indentation/newlines.
pub fn parse_text(
  source : String,
  dialects~ : ArrayView[&Dialect] = [],
) -> Specification {
  let vocabulary = Vocabulary::of(dialects)
  let requirements = []
  let diagnostics = []
  let mut offset = if source.has_prefix("\u{FEFF}") { 1 } else { 0 }
  let mut line = 1
  let mut line_start = 0
  while offset < source.length() {
    let mut end = offset
    while end < source.length() &&
          source.code_unit_at(end) != 10 &&
          source.code_unit_at(end) != 13 {
      end += 1
    }
    let mut first = offset
    let mut last = end
    while first < last && is_space(source.code_unit_at(first)) {
      first += 1
    }
    while last > first && is_space(source.code_unit_at(last - 1)) {
      last -= 1
    }
    if first < last {
      let span = SourceSpan::{
        start: first,
        end: last,
        line,
        column: first - line_start + 1,
      }
      collect_candidate(
        source[first:last].to_owned(),
        Text(span),
        requirements,
        diagnostics,
        vocabulary,
      )
    }
    offset = end
    if offset < source.length() {
      offset += 1
      if source.code_unit_at(end) == 13 &&
        offset < source.length() &&
        source.code_unit_at(offset) == 10 {
        offset += 1
      }
    }
    line += 1
    line_start = offset
  }
  {
    requirements: ReadOnlyArray::from_array(requirements[:]),
    diagnostics: ReadOnlyArray::from_array(diagnostics[:]),
    blocks: [],
    document: None,
  }
}

///|
/// The ranges of the sentences of `text`, without surrounding white space. A
/// sentence ends at a full stop, a question mark or an exclamation mark that
/// white space or the end follows, outside backticks.
fn sentence_ranges(text : String) -> Array[(Int32, Int32)] {
  let raw = []
  let n = text.length()
  let mut start = 0
  let mut in_code = false
  for i in 0..<n {
    let c = text.code_unit_at(i)
    if c == 96 {
      in_code = !in_code
    } else if !in_code &&
      (c == 46 || c == 63 || c == 33) &&
      (i + 1 == n || is_space(text.code_unit_at(i + 1))) {
      raw.push((start, i + 1))
      start = i + 1
    }
  }
  if start < n {
    raw.push((start, n))
  }
  let out = []
  for range in raw {
    let mut first = range.0
    let mut last = range.1
    while first < last && is_space(text.code_unit_at(first)) {
      first += 1
    }
    while last > first && is_space(text.code_unit_at(last - 1)) {
      last -= 1
    }
    if first < last {
      out.push((first, last))
    }
  }
  out
}

///|
/// The sentences of a block so far: their requirements and diagnostics, and
/// the last system that a pronoun can refer to.
priv struct Sentences {
  requirements : Array[Occurrence]
  diagnostics : Array[Diagnostic]
  mut last_system : String?
}

///|
fn Sentences::new() -> Sentences {
  { requirements: [], diagnostics: [], last_system: None, }
}

///|
/// Parses each sentence of `text`. A pronoun subject refers to the system of
/// the nearest earlier sentence that has one; without one, the requirement
/// stays, with an `UnresolvedPronoun` diagnostic.
fn Sentences::add(
  self : Sentences,
  text : String,
  vocabulary : Vocabulary,
  origin_of : (Int32, Int32) -> Origin,
) -> Unit {
  for range in sentence_ranges(text) {
    let sentence = text[range.0:range.1].to_owned()
    let origin = origin_of(range.0, range.1)
    let parsed = parse_sentence(sentence, vocabulary) catch {
      error => {
        self.diagnostics.push({ text: sentence, error, origin, })
        continue
      }
    }
    let requirement = match parsed.requirement.subject {
      Pronoun(opener~, resolved=None) =>
        match self.last_system {
          Some(system) =>
            {
              ..parsed.requirement,
              subject: Pronoun(opener~, resolved=Some(system)),
            }
          None => {
            self.diagnostics.push({
              text: sentence,
              error: UnresolvedPronoun(pronoun=opener, at=parsed.subject_at),
              origin,
            })
            parsed.requirement
          }
        }
      _ => parsed.requirement
    }
    match requirement.system() {
      Some(system) => self.last_system = Some(system)
      None => ()
    }
    self.requirements.push({ requirement, origin, })
  }
}

///|
/// The text span of `start..<end` in `text`, with its line and column.
fn span_in(text : String, start : Int32, end : Int32) -> SourceSpan {
  let mut line = 1
  let mut line_start = 0
  for i in 0..<start {
    let c = text.code_unit_at(i)
    if c == 10 ||
      (c == 13 && !(i + 1 < start && text.code_unit_at(i + 1) == 10)) {
      line += 1
      line_start = i + 1
    }
  }
  { start, end, line, column: start - line_start + 1, }
}

///|
/// Parse a requirement block: split it into sentences, parse each with the
/// vocabulary of `dialects`, and resolve a pronoun subject to the system of
/// the nearest earlier sentence. Spans are relative to `text`.
pub fn parse_block(
  text : String,
  dialects~ : ArrayView[&Dialect] = [],
) -> Specification {
  let vocabulary = Vocabulary::of(dialects)
  let sentences = Sentences::new()
  sentences.add(text, vocabulary, (start, end) => {
    Text(span_in(text, start, end))
  })
  {
    requirements: ReadOnlyArray::from_array(sentences.requirements),
    diagnostics: ReadOnlyArray::from_array(sentences.diagnostics),
    blocks: [],
    document: None,
  }
}

///|
pub extend SourceSpan with Eq::{equal, not_equal}

///|
pub extend SourceSpan with @debug.Debug::{to_repr}

///|
pub extend Origin with Eq::{equal, not_equal}

///|
pub extend Origin with @debug.Debug::{to_repr}

///|
pub extend Occurrence with Eq::{equal, not_equal}

///|
pub extend Occurrence with @debug.Debug::{to_repr}

///|
pub extend Diagnostic with Eq::{equal, not_equal}

///|
pub extend Diagnostic with @debug.Debug::{to_repr}

///|
pub extend Specification with @debug.Debug::{to_repr}

///|
pub extend RequirementBlock with @debug.Debug::{to_repr}
