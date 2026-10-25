///|
// Flatten inline presentation only. Destinations, raw HTML and image alt text
// cannot introduce requirement words. Code spans in a sentence remain text.
fn paragraph_text(node : @mdc.Node, code_marks~ : Bool = false) -> String {
  let out = StringBuilder()
  @mdc.walk(node, node => {
    if node is Inline(view) {
      match view.kind() {
        Text(text~) => out.write_string(text)
        CodeSpan(code~) =>
          // Block parsing keeps the backticks, so that a full stop in code
          // does not end a sentence.
          if code_marks {
            out.write_string("`" + code + "`")
          } else {
            out.write_string(code)
          }
        Break => out.write_string(" ")
        Autolink =>
          if view.to_cmark() is Autolink({ v, .. }) {
            out.write_string(v.link.v)
          }
        ExtMathSpan(tex~) => out.write_string(tex)
        Image | RawHtml => return SkipChildren
        _ => ()
      }
    }
    Continue
  })
  out.to_string()
}

///|
fn is_candidate(text : String, vocabulary : Vocabulary) -> Bool {
  for keyword in keywords {
    if starts_word(text, keyword.word()) {
      return true
    }
  }
  let starts = vocabulary.starts_subject(text) ||
    lead_in_at_start(text, vocabulary) is Some(_)
  starts &&
  text
  .split(" ")
  .any(word => {
    let word = word.to_owned().to_lower()
    word == "shall" ||
    word == "should" ||
    word == "must" ||
    vocabulary.modals.contains(word)
  })
}

///|
/// The source range of a block view, when the document has locations.
fn view_span(
  document : @mdc.Document,
  view : @mdc.BlockView,
) -> @mdc.SourceRange? {
  document.source_range(view.location())
}

///|
/// A requirement block that the Markdown walk is filling.
priv struct BlockBuilder {
  name : String
  heading : @mdc.SourceRange?
  sentences : Sentences
}

///|
/// Extract requirements from an MDC document with the vocabulary of
/// `dialects`.
///
/// Without heading rules, extract one sentence per paragraph, including
/// paragraphs in lists and blockquotes. Wrapped lines and inline formatting
/// form a single sentence. Skip headings, code, HTML, tables, footnotes and
/// frontmatter. Non-EARS prose is ignored; malformed candidates become
/// diagnostics.
///
/// With heading rules, each heading that matches a rule starts a requirement
/// block, named by the rest of the heading text. The paragraphs after it, up
/// to the next heading of any level, are split into sentences, and a pronoun
/// subject refers to the system of the nearest earlier sentence of the block.
/// Each sentence has the source span of its paragraph. No reparsing occurs.
pub fn from_mdc(
  document : @mdc.Document,
  dialects~ : ArrayView[&Dialect] = [],
) -> Specification {
  let vocabulary = Vocabulary::of(dialects)
  if !vocabulary.headings.is_empty() {
    return blocks_of(document, vocabulary)
  }
  let requirements = []
  let diagnostics = []
  @mdc.walk_cursor(document.root(), cursor => {
    if cursor.node() is Block(view) {
      match view.kind() {
        Paragraph => {
          let text = normalize(paragraph_text(cursor.node()))
          if is_candidate(text, vocabulary) {
            collect_candidate(
              text,
              Markdown(path=cursor.path(), span=view_span(document, view)),
              requirements,
              diagnostics,
              vocabulary,
            )
          }
          return SkipChildren
        }
        Heading(_) | CodeBlock | HtmlBlock | ExtTable | ExtFootnoteDefinition =>
          return SkipChildren
        _ => ()
      }
    }
    Continue
  })
  {
    requirements: ReadOnlyArray::from_array(requirements[:]),
    diagnostics: ReadOnlyArray::from_array(diagnostics[:]),
    blocks: [],
    document: Some(document),
  }
}

///|
/// The requirement blocks of a document, by the heading rules of the
/// vocabulary.
fn blocks_of(
  document : @mdc.Document,
  vocabulary : Vocabulary,
) -> Specification {
  let blocks : Array[RequirementBlock] = []
  let mut current : BlockBuilder? = None
  let close = () => {
    match current {
      Some(b) =>
        blocks.push({
          name: b.name,
          heading: b.heading,
          requirements: ReadOnlyArray::from_array(b.sentences.requirements),
          diagnostics: ReadOnlyArray::from_array(b.sentences.diagnostics),
        })
      None => ()
    }
    current = None
  }
  @mdc.walk_cursor(document.root(), cursor => {
    if cursor.node() is Block(view) {
      match view.kind() {
        Heading(level~) => {
          close()
          let text = normalize(paragraph_text(cursor.node()))
          for rule in vocabulary.headings {
            match rule.name_of(level, text) {
              Some(name) => {
                current = Some({
                  name,
                  heading: document.source_range(view.location()),
                  sentences: Sentences::new(),
                })
                break
              }
              None => ()
            }
          }
          return SkipChildren
        }
        Paragraph => {
          match current {
            Some(b) => {
              let text = normalize(
                paragraph_text(cursor.node(), code_marks=true),
              )
              let origin = Markdown(
                path=cursor.path(),
                span=view_span(document, view),
              )
              b.sentences.add(text, vocabulary, (_, _) => origin)
            }
            None => ()
          }
          return SkipChildren
        }
        CodeBlock | HtmlBlock | ExtTable | ExtFootnoteDefinition =>
          return SkipChildren
        _ => ()
      }
    }
    Continue
  })
  close()
  let requirements = []
  let diagnostics = []
  for b in blocks {
    for r in b.requirements {
      requirements.push(r)
    }
    for d in b.diagnostics {
      diagnostics.push(d)
    }
  }
  {
    requirements: ReadOnlyArray::from_array(requirements),
    diagnostics: ReadOnlyArray::from_array(diagnostics),
    blocks: ReadOnlyArray::from_array(blocks),
    document: Some(document),
  }
}

///|
/// Parse Markdown with optional YAML frontmatter, then extract EARS sentences
/// with the vocabulary of `dialects`.
/// Invalid frontmatter raises MDC's ParseError. EARS errors are diagnostics.
pub fn parse_markdown(
  source : String,
  strict~ : Bool = true,
  file~ : String = "",
  dialects~ : ArrayView[&Dialect] = [],
) -> Specification raise @mdc.ParseError {
  from_mdc(@mdc.Document::Document(source, strict~, file~), dialects~)
}
