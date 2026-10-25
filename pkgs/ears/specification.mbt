///|
/// Where a requirement or a diagnostic came from. A text range covers the
/// sentence or the line without surrounding white space; a Markdown range
/// covers the paragraph, including markup. Markdown paths resolve against the
/// retained MDC document. Ranges are absent if that document was parsed with
/// `locs=false`.
pub enum Origin {
  Text(@mdc.SourceRange)
  Markdown(path~ : @mdc.NodePath, span~ : @mdc.SourceRange?)
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
      collect_candidate(
        source[first:last].to_owned(),
        Text(range_from(source, first, last, line~, line_start~)),
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
/// white space or the end follows, outside backticks; closing brackets and
/// quote marks after the mark belong to the sentence. A blank line also ends
/// a sentence. A backtick with no closing backtick on its line is text.
fn sentence_ranges(text : String) -> Array[(Int32, Int32)] {
  let raw = []
  let n = text.length()
  let mut start = 0
  // The length of the backtick run that opened the code span, or 0 outside
  // code.
  let mut code_run = 0
  let closing = (c : UInt16) => {
    c == 41 || c == 93 || c == 34 || c == 39 || c == 0x201D || c == 0x2019
  }
  let mut i = 0
  while i < n {
    let c = text.code_unit_at(i)
    if c == 10 || c == 13 {
      code_run = 0
      // A blank line: a line break, optional white space, a line break.
      let mut j = i + 1
      if c == 13 && j < n && text.code_unit_at(j) == 10 {
        j += 1
      }
      let mut k = j
      while k < n && (text.code_unit_at(k) == 32 || text.code_unit_at(k) == 9) {
        k += 1
      }
      if k < n && (text.code_unit_at(k) == 10 || text.code_unit_at(k) == 13) {
        raw.push((start, i))
        start = k
        i = k
        continue
      }
    } else if c == 96 {
      // A run of backticks opens a code span only when a run of the same
      // length closes it on the same line, as in Markdown; an unclosed run is
      // text. Inside code, only a run of the opening length closes it.
      let mut run_end = i
      while run_end < n && text.code_unit_at(run_end) == 96 {
        run_end += 1
      }
      let run = run_end - i
      if code_run > 0 {
        if run == code_run {
          code_run = 0
        }
      } else {
        let mut j = run_end
        let mut closes = false
        while j < n &&
              !closes &&
              text.code_unit_at(j) != 10 &&
              text.code_unit_at(j) != 13 {
          if text.code_unit_at(j) == 96 {
            let mut k = j
            while k < n && text.code_unit_at(k) == 96 {
              k += 1
            }
            closes = k - j == run
            j = k
          } else {
            j += 1
          }
        }
        if closes {
          code_run = run
        }
      }
      i = run_end
      continue
    } else if code_run == 0 && (c == 46 || c == 63 || c == 33) {
      let mut end = i + 1
      while end < n && closing(text.code_unit_at(end)) {
        end += 1
      }
      if end == n || is_space(text.code_unit_at(end)) {
        raw.push((start, end))
        start = end
        i = end
        continue
      }
    }
    i += 1
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
/// The source range of `start..<end` in `text`, from the line of `start` and
/// the offset where that line starts. `start..<end` is not empty.
fn range_from(
  text : String,
  start : Int32,
  end : Int32,
  line~ : Int32,
  line_start~ : Int32,
) -> @mdc.SourceRange {
  let mut end_line = line
  let mut end_line_start = line_start
  let last = end - 1
  for i in start..<last {
    if is_line_break(text, i) {
      end_line += 1
      end_line_start = i + 1
    }
  }
  @mdc.SourceRange(
    start=@mdc.TextPosition(line~, column=start - line_start + 1),
    end=@mdc.TextPosition(line=end_line, column=last - end_line_start + 1),
    start_offset=start,
    end_offset=end,
  ) catch {
    _ => abort("a text range is not a source range")
  }
}

///|
/// Whether the code unit at `i` ends a line: a line feed, or a carriage return
/// that no line feed follows.
fn is_line_break(text : String, i : Int32) -> Bool {
  let c = text.code_unit_at(i)
  c == 10 ||
  (c == 13 && !(i + 1 < text.length() && text.code_unit_at(i + 1) == 10))
}

///|
/// The source range of `start..<end` in `text`.
fn range_in(text : String, start : Int32, end : Int32) -> @mdc.SourceRange {
  let mut line = 1
  let mut line_start = 0
  for i in 0..<start {
    if is_line_break(text, i) {
      line += 1
      line_start = i + 1
    }
  }
  range_from(text, start, end, line~, line_start~)
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
    Text(range_in(text, start, end))
  })
  {
    requirements: ReadOnlyArray::from_array(sentences.requirements),
    diagnostics: ReadOnlyArray::from_array(sentences.diagnostics),
    blocks: [],
    document: None,
  }
}

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
