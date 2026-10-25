///|
/// The keys of a lexicon file.
let lexicon_keys : Array[String] = [
  "name", "modals", "determiners", "pronouns", "systems", "lead_ins", "headings",
]

///|
/// The file line of the top-level `key:` line, or 1.
fn key_line(text : String, key : String) -> Int32 {
  for i, line in text.split("\n").collect() {
    if line.has_prefix(key + ":") {
      return i + 1
    }
  }
  1
}

///|
/// The file lines of the block list entries (`- ...`) under the top-level
/// `key:` line.
fn entry_lines(text : String, key : String) -> Array[Int32] {
  let lines = text.split("\n").collect()
  let out = []
  let first = key_line(text, key)
  for i in first..<lines.length() {
    let line = lines[i]
    let t = line.trim_start(chars=" \t")
    if t.length() == 0 || t.has_prefix("#") {
      continue
    }
    if line.length() == t.length() {
      // A line that is not indented ends the value.
      if !t.has_prefix("-") {
        break
      }
    }
    if t.has_prefix("- ") || t == "-" {
      out.push(i + 1)
    }
  }
  out
}

///|
/// The text entries of the list of `key`, each with its line.
fn text_entries(
  text : String,
  key : String,
  value : @yaml.Yaml,
) -> Array[(String, Int32)] raise LexiconError {
  let line = key_line(text, key)
  guard value is Array(items) else {
    raise WrongType(key~, line~, expected=List)
  }
  let lines = entry_lines(text, key)
  let out = []
  for i, item in items {
    let at = if lines.length() == items.length() { lines[i] } else { line }
    guard item is String(s) else {
      raise WrongType(key~, line=at, expected=Text)
    }
    out.push((s, at))
  }
  out
}

///|
fn words_of(
  text : String,
  key : String,
  value : @yaml.Yaml,
) -> Array[Word] raise LexiconError {
  text_entries(text, key, value).map(entry => {
    Word(entry.0) catch {
      e => raise InvalidEntry(key~, line=entry.1, error=e)
    }
  })
}

///|
fn phrases_of(
  text : String,
  key : String,
  value : @yaml.Yaml,
) -> Array[Phrase] raise LexiconError {
  text_entries(text, key, value).map(entry => {
    Phrase(entry.0) catch {
      e => raise InvalidEntry(key~, line=entry.1, error=e)
    }
  })
}

///|
fn headings_of(
  text : String,
  value : @yaml.Yaml,
) -> Array[HeadingRule] raise LexiconError {
  let key = "headings"
  let line = key_line(text, key)
  guard value is Array(items) else {
    raise WrongType(key~, line~, expected=List)
  }
  let lines = entry_lines(text, key)
  let out = []
  for i, item in items {
    let at = if lines.length() == items.length() { lines[i] } else { line }
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
        match @mdc.HeadingLevel::of_int(n.to_int()) {
          Some(level) => level
          None =>
            raise InvalidEntry(
              key~,
              line=at,
              error=InvalidHeadingLevel(n.to_int()),
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
  for key, _ in fields {
    if !lexicon_keys.contains(key) {
      raise UnknownKey(key~, line=key_line(text, key))
    }
  }
  let name = match fields.get("name") {
    None => "lexicon"
    Some(String(s)) => s
    Some(_) =>
      raise WrongType(key="name", line=key_line(text, "name"), expected=Text)
  }
  let words = (key : String) => {
    match fields.get(key) {
      Some(value) => words_of(text, key, value)
      None => []
    }
  }
  let phrases = (key : String) => {
    match fields.get(key) {
      Some(value) => phrases_of(text, key, value)
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
      Some(value) => headings_of(text, value)
      None => []
    },
  )
}
