///|
fn is_space(unit : UInt16) -> Bool {
  unit == 32 || (unit >= 9 && unit <= 13)
}

///|
fn normalize(source : String) -> String {
  let out = StringBuilder()
  let mut start = 0
  let mut pending_space = false
  for i = 0; i <= source.length(); i = i + 1 {
    if i == source.length() || is_space(source.code_unit_at(i)) {
      if i > start {
        if pending_space {
          out.write_string(" ")
        }
        out.write_string(source[start:i].to_owned())
        pending_space = true
      }
      start = i + 1
    }
  }
  out.to_string()
}

///|
fn starts_word(text : String, word : String) -> Bool {
  starts_word_at(text, 0, word)
}

///|
fn starts_word_at(text : String, at : Int32, word : String) -> Bool {
  let end = at + word.length()
  text.length() >= end &&
  text[at:end].to_owned().to_lower() == word &&
  (text.length() == end || text.code_unit_at(end) == 32)
}

///|
/// A word that starts a clause: a clause keyword, `then` or `the`.
priv enum ClauseWord {
  Clause(Keyword)
  Then
  The
} derive(Eq)

///|
fn clause_word(text : String) -> ClauseWord? {
  for keyword in keywords {
    if starts_word(text, keyword.word()) {
      return Some(Clause(keyword))
    }
  }
  if starts_word(text, "then") {
    Some(Then)
  } else if starts_word(text, "the") {
    Some(The)
  } else {
    None
  }
}

///|
fn starts_then_system(text : String, at : Int32) -> Bool {
  starts_word_at(text, at, "then") && starts_word_at(text, at + 5, "the")
}

///|
// A comma is structural only when a reserved clause keyword follows it.
// Ordinary commas in natural-language clauses remain part of that clause.
fn take_clause(
  text : String,
  unwanted : Bool,
  at~ : SentencePosition,
) -> (String, String) raise ParseError {
  let mut saw_incomplete_then = false
  for i in 0..<text.length() {
    if text.code_unit_at(i) == 44 {
      let rest = text[i + 1:].trim_start().to_owned()
      if clause_word(rest) is Some(word) {
        if unwanted && word == Then && !starts_then_system(rest, 0) {
          saw_incomplete_then = true
          continue
        }
        return (text[:i].trim_end().to_owned(), rest)
      }
    }
    if unwanted && text.code_unit_at(i) == 32 {
      if starts_word_at(text, i + 1, "then") {
        if starts_then_system(text, i + 1) {
          return (text[:i].trim_end().to_owned(), text[i + 1:].to_owned())
        }
        saw_incomplete_then = true
      }
    }
  }
  if unwanted {
    if saw_incomplete_then {
      raise ExpectedSystem(at~)
    }
    raise MissingThen(at~)
  }
  raise MissingSeparator(at~)
}

///|
/// Parse one sentence. Keywords are case-insensitive; clauses use comma
/// separators. IF requires THEN, with an optional comma before THEN.
/// Order: optional WHERE, zero or more WHILE, optional WHEN or IF, THE ... SHALL.
pub fn Requirement::Requirement(
  source : String,
) -> Requirement raise ParseError {
  let text = normalize(source)
  guard !text.is_empty() else { raise EmptyRequirement }
  // Each remaining text is a suffix of `text`, so its start is a position.
  let position_of = (rest : String) => {
    let p : SentencePosition = { offset: text.length() - rest.length(), }
    p
  }
  let mut rest = text
  let mut feature = None
  let states = []
  let mut trigger = None
  while !starts_word(rest, "the") {
    let at = position_of(rest)
    let keyword = match clause_word(rest) {
      Some(Clause(keyword)) => keyword
      Some(Then | The) => raise InvalidClauseOrder(at~)
      None => raise ExpectedSystem(at~)
    }
    let in_order = match keyword {
      Where => feature is None && states.is_empty() && trigger is None
      While | When | If => trigger is None
    }
    guard in_order else { raise InvalidClauseOrder(at~) }
    let payload = rest[keyword.word().length():].trim_start().to_owned()
    let (clause, next) = take_clause(payload, keyword == If, at~)
    guard !clause.is_empty() else { raise EmptyClause(keyword~, at~) }
    match keyword {
      Where => feature = Some(clause)
      While => states.push(clause)
      When => trigger = Some(Event(clause))
      If => trigger = Some(Unwanted(clause))
    }
    rest = if keyword == If {
      guard starts_word(next, "then") else { raise MissingThen(at~) }
      let after_then = next[4:].trim_start().to_owned()
      guard starts_word(after_then, "the") else {
        raise ExpectedSystem(at=position_of(after_then))
      }
      after_then
    } else {
      next
    }
  }
  let body = rest[3:].trim_start().to_owned()
  let mut shall_at = None
  for i = 0; i < body.length(); i = i + 1 {
    if (i == 0 || body.code_unit_at(i - 1) == 32) &&
      starts_word_at(body, i, "shall") {
      shall_at = Some(i)
      break
    }
  }
  guard shall_at is Some(at) else { raise MissingShall(at=position_of(body)) }
  let system = body[:at].trim_end().to_owned()
  guard !system.is_empty() else { raise ExpectedSystem(at=position_of(body)) }
  let after_shall = body[at + 5:].to_owned()
  let response = after_shall.trim_start().to_owned()
  guard !response.is_empty() && response != "." else {
    raise MissingResponse(at=position_of(after_shall))
  }
  {
    feature,
    preconditions: ReadOnlyArray::from_array(states[:]),
    trigger,
    system,
    response,
  }
}

///|
pub fn parse(source : String) -> Requirement raise ParseError {
  Requirement::Requirement(source)
}
