///|
/// The keys of a lexicon file.
let lexicon_keys : Array[String] = [
  "name", "modals", "determiners", "pronouns", "systems", "lead_ins", "headings",
]

///|
/// The file lines of a top-level key: the line of the key, and the line of
/// each item when its value is a list.
priv struct KeyLines {
  key : Int32
  items : Array[Int32]
}

///|
/// Collects the file lines of the top-level keys from the events of the YAML
/// parser, so that flow lists, quoted keys and block scalars give the lines
/// of their own items.
priv struct LineReader {
  lines : Map[String, KeyLines]
  /// How many collections are open: 1 inside the top-level mapping.
  mut depth : Int32
  /// The top-level key whose value is read.
  mut key : String?
  /// The value of the key is a list.
  mut in_list : Bool
}

///|
impl @yaml.MarkedEventReceiver for LineReader with fn on_event(
  self,
  event,
  mark,
) {
  let item = () => {
    if self.depth == 2 && self.in_list {
      if self.key is Some(key) && self.lines.get(key) is Some(lines) {
        lines.items.push(mark.line)
      }
    }
  }
  match event {
    Scalar(value~, ..) if self.depth == 1 =>
      match self.key {
        None => {
          self.lines.set(value, { key: mark.line, items: [], })
          self.key = Some(value)
        }
        Some(_) => self.key = None
      }
    Alias(..) if self.depth == 1 => self.key = None
    Scalar(..) | Alias(..) => item()
    SequenceStart(..) | MappingStart(..) => {
      item()
      if self.depth == 1 {
        self.in_list = event is SequenceStart(..)
      }
      self.depth += 1
    }
    SequenceEnd | MappingEnd => {
      self.depth -= 1
      if self.depth == 1 {
        self.key = None
      }
    }
    _ => ()
  }
}

///|
/// The file lines of the top-level keys of `text`. A key that the parser
/// does not reach has no lines.
fn key_lines(text : String) -> Map[String, KeyLines] {
  let reader = { lines: {}, depth: 0, key: None, in_list: false, }
  @yaml.Parser::new(text).load(reader, false) catch {
    _ => ()
  }
  reader.lines
}

///|
/// The file line of the top-level `key`, or 1.
fn key_line(lines : Map[String, KeyLines], key : String) -> Int32 {
  match lines.get(key) {
    Some(found) => found.key
    None => 1
  }
}

///|
/// The file line of each of the `count` items of the list of `key`. An item
/// whose line is not known has the line of the key.
fn item_lines(
  lines : Map[String, KeyLines],
  key : String,
  count : Int32,
) -> Array[Int32] {
  match lines.get(key) {
    Some(found) if found.items.length() == count => found.items
    _ => Array::make(count, key_line(lines, key))
  }
}

///|
/// The text entries of the list of `key`, each with its line.
fn text_entries(
  lines : Map[String, KeyLines],
  key : String,
  value : @yaml.Yaml,
) -> Array[(String, Int32)] raise LexiconError {
  guard value is Array(items) else {
    raise WrongType(key~, line=key_line(lines, key), expected=List)
  }
  let at_lines = item_lines(lines, key, items.length())
  let out = []
  for i, item in items {
    let at = at_lines[i]
    guard item is String(s) else {
      raise WrongType(key~, line=at, expected=Text)
    }
    out.push((s, at))
  }
  out
}

///|
fn words_of(
  lines : Map[String, KeyLines],
  key : String,
  value : @yaml.Yaml,
) -> Array[Word] raise LexiconError {
  text_entries(lines, key, value).map(entry => {
    Word(entry.0) catch {
      e => raise InvalidEntry(key~, line=entry.1, error=e)
    }
  })
}

///|
fn phrases_of(
  lines : Map[String, KeyLines],
  key : String,
  value : @yaml.Yaml,
) -> Array[Phrase] raise LexiconError {
  text_entries(lines, key, value).map(entry => {
    Phrase(entry.0) catch {
      e => raise InvalidEntry(key~, line=entry.1, error=e)
    }
  })
}

///|
fn headings_of(
  lines : Map[String, KeyLines],
  value : @yaml.Yaml,
) -> Array[HeadingRule] raise LexiconError {
  let key = "headings"
  guard value is Array(items) else {
    raise WrongType(key~, line=key_line(lines, key), expected=List)
  }
  let at_lines = item_lines(lines, key, items.length())
  let out = []
  for i, item in items {
    let at = at_lines[i]
    guard item is Map(fields) else {
      raise WrongType(key~, line=at, expected=Mapping)
    }
    for name, _ in fields {
      if name != "level" && name != "prefix" {
        raise UnknownKey(key="headings." + name, line=at)
      }
    }
    let level = match fields.get("level") {
      Some(Integer(n)) =>
        match
          (if n >= 1L && n <= 6L {
            @mdc.HeadingLevel::of_int(n.to_int())
          } else {
            None
          }) {
          Some(level) => level
          None =>
            raise InvalidEntry(
              key~,
              line=at,
              error=InvalidHeadingLevel(
                if n > 2147483647L {
                  2147483647
                } else if n < -2147483648L {
                  -2147483648
                } else {
                  n.to_int()
                },
              ),
            )
        }
      _ => raise WrongType(key="headings.level", line=at, expected=Number)
    }
    let prefix = match fields.get("prefix") {
      Some(String(s)) =>
        HeadingPrefix(s) catch {
          e => raise InvalidEntry(key~, line=at, error=e)
        }
      _ => raise WrongType(key="headings.prefix", line=at, expected=Text)
    }
    out.push(HeadingRule(level, prefix))
  }
  out
}

///|
/// Parses a lexicon file: a YAML mapping with the keys `name`, `modals`,
/// `determiners`, `pronouns`, `systems`, `lead_ins` and `headings`. Each key
/// is optional. A list key holds a list of texts; `headings` holds a list of
/// mappings with `level` (1 to 6) and `prefix`. An unknown key, a value of
/// the wrong kind and an invalid entry raise `LexiconError` with the line.
/// It reads no file: the caller gives the text.
pub fn Lexicon::from_yaml(text : String) -> Lexicon raise LexiconError {
  let frontmatter = @mdc.Frontmatter::Frontmatter(text) catch {
    InvalidYaml(at~, message~) =>
      raise InvalidLexiconFile(line=at.line(), message~)
    NotAMapping =>
      raise InvalidLexiconFile(
        line=1,
        message="a lexicon file is a YAML mapping",
      )
    MultipleDocuments(..) =>
      raise InvalidLexiconFile(
        line=1,
        message="a lexicon file has one YAML document",
      )
  }
  guard frontmatter.value() is Map(fields) else {
    raise InvalidLexiconFile(line=1, message="a lexicon file is a YAML mapping")
  }
  let lines = key_lines(text)
  for key, _ in fields {
    if !lexicon_keys.contains(key) {
      raise UnknownKey(key~, line=key_line(lines, key))
    }
  }
  let name = match fields.get("name") {
    None => "lexicon"
    Some(String(s)) => s
    Some(_) =>
      raise WrongType(key="name", line=key_line(lines, "name"), expected=Text)
  }
  let words = (key : String) => {
    match fields.get(key) {
      Some(value) => words_of(lines, key, value)
      None => []
    }
  }
  let phrases = (key : String) => {
    match fields.get(key) {
      Some(value) => phrases_of(lines, key, value)
      None => []
    }
  }
  Lexicon(
    name~,
    modals=words("modals"),
    determiners=words("determiners"),
    pronouns=words("pronouns"),
    systems=phrases("systems"),
    lead_ins=phrases("lead_ins"),
    headings=match fields.get("headings") {
      Some(value) => headings_of(lines, value)
      None => []
    },
  )
}
