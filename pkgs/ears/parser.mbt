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
/// A word that starts a clause: a clause keyword, `then`, or a subject.
priv enum ClauseWord {
  Clause(Keyword)
  Then
  SubjectWord
}

///|
fn clause_word(text : String, vocabulary : Vocabulary) -> ClauseWord? {
  for keyword in keywords {
    if starts_word(text, keyword.word()) {
      return Some(Clause(keyword))
    }
  }
  if starts_word(text, "then") {
    Some(Then)
  } else if vocabulary.starts_subject(text) {
    Some(SubjectWord)
  } else {
    None
  }
}

///|
fn starts_then_system(
  text : String,
  at : Int32,
  vocabulary : Vocabulary,
) -> Bool {
  starts_word_at(text, at, "then") &&
  text.length() > at + 5 &&
  vocabulary.starts_subject(text[at + 5:].to_owned())
}

///|
// A comma is structural only when a reserved clause keyword follows it.
// Ordinary commas in natural-language clauses remain part of that clause.
// With a dialect, a comma that a subject word follows ends the clause only
// when it is the last such comma before the modal verb, and an `If` clause
// ignores such commas, because it ends at `then`.
fn take_clause(
  text : String,
  unwanted : Bool,
  vocabulary : Vocabulary,
  at~ : SentencePosition,
) -> (String, String) raise ParseError {
  let mut saw_incomplete_then = false
  let mut subject_comma : Int32? = None
  let split = (i : Int32) => {
    (text[:i].trim_end().to_owned(), text[i + 1:].trim_start().to_owned())
  }
  for i in 0..<text.length() {
    if vocabulary.extended &&
      subject_comma is Some(c) &&
      text.code_unit_at(i - 1) == 32 &&
      vocabulary.modal_at(text, i) is Some(_) {
      return split(c)
    }
    if text.code_unit_at(i) == 44 {
      let rest = text[i + 1:].trim_start().to_owned()
      match clause_word(rest, vocabulary) {
        Some(Then) if unwanted && !starts_then_system(rest, 0, vocabulary) => {
          saw_incomplete_then = true
          continue
        }
        Some(SubjectWord) if vocabulary.extended => {
          if !unwanted {
            subject_comma = Some(i)
          }
          continue
        }
        Some(_) => return split(i)
        None => ()
      }
    }
    if unwanted && text.code_unit_at(i) == 32 {
      if starts_word_at(text, i + 1, "then") {
        if starts_then_system(text, i + 1, vocabulary) {
          return (text[:i].trim_end().to_owned(), text[i + 1:].to_owned())
        }
        saw_incomplete_then = true
      }
    }
  }
  match subject_comma {
    Some(c) => return split(c)
    None => ()
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
/// The length of the lead-in phrase that starts `text`, followed by a space,
/// a comma or the end.
fn lead_in_at_start(text : String, vocabulary : Vocabulary) -> Int32? {
  for phrase in vocabulary.lead_ins {
    let n = phrase.length()
    if text.length() >= n &&
      text[:n].to_owned().to_lower() == phrase &&
      (
        text.length() == n ||
        text.code_unit_at(n) == 32 ||
        text.code_unit_at(n) == 44
      ) {
      return Some(n)
    }
  }
  None
}

///|
/// The lead-in phrase at the start of `text`, when a dialect gives one: up to
/// the first comma or space after the phrase that a clause keyword or a
/// subject follows, and never past the modal verb. Gives the lead-in and the
/// rest.
fn take_lead_in(text : String, vocabulary : Vocabulary) -> (String?, String) {
  guard lead_in_at_start(text, vocabulary) is Some(length) else {
    return (None, text)
  }
  for i in length..<text.length() {
    let c = text.code_unit_at(i)
    guard c == 44 || c == 32 else { continue }
    let rest = text[i + 1:].trim_start().to_owned()
    if vocabulary.modal_at(rest, 0) is Some(_) {
      break
    }
    if clause_word(rest, vocabulary) is Some(_) {
      return (Some(text[:i].trim_end().to_owned()), rest)
    }
  }
  (None, text)
}

///|
/// A parsed sentence and the position of its subject.
priv struct Parsed {
  requirement : Requirement
  subject_at : SentencePosition
}

///|
/// Parses one sentence with a vocabulary. See `Requirement::Requirement` for
/// the strict grammar; the vocabulary adds lead-ins, subject openers, system
/// nouns and modal verbs.
fn parse_sentence(
  source : String,
  vocabulary : Vocabulary,
) -> Parsed raise ParseError {
  let text = normalize(source)
  guard !text.is_empty() else { raise EmptyRequirement }
  // Each remaining text is a suffix of `text`, so its start is a position.
  let position_of = (rest : String) => {
    let p : SentencePosition = { offset: text.length() - rest.length(), }
    p
  }
  let (lead_in, after_lead_in) = take_lead_in(text, vocabulary)
  let mut rest = after_lead_in
  let mut feature = None
  let states = []
  let mut trigger = None
  while !vocabulary.starts_subject(rest) {
    let at = position_of(rest)
    let keyword = match clause_word(rest, vocabulary) {
      Some(Clause(keyword)) => keyword
      Some(Then | SubjectWord) => raise InvalidClauseOrder(at~)
      None => raise ExpectedSystem(at~)
    }
    let in_order = match keyword {
      Where => feature is None && states.is_empty() && trigger is None
      While | When | If => trigger is None
    }
    guard in_order else { raise InvalidClauseOrder(at~) }
    let payload = rest[keyword.word().length():].trim_start().to_owned()
    let (clause, next) = take_clause(payload, keyword == If, vocabulary, at~)
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
      guard vocabulary.starts_subject(after_then) else {
        raise ExpectedSystem(at=position_of(after_then))
      }
      after_then
    } else {
      next
    }
  }
  let subject_at = position_of(rest)
  // The subject, and the text from its modal verb on.
  let (subject, from_modal) : (Subject, String) = match
    vocabulary.subject_at_start(rest) {
    Some(StartsNoun(n)) => {
      let after = rest[n:].trim_start().to_owned()
      guard vocabulary.modal_at(after, 0) is Some(_) else {
        raise MissingShall(at=position_of(after))
      }
      (Noun(rest[:n].to_owned()), after)
    }
    Some(StartsPronoun(n)) => {
      let after = rest[n:].trim_start().to_owned()
      guard vocabulary.modal_at(after, 0) is Some(_) else {
        raise MissingShall(at=position_of(after))
      }
      (Pronoun(opener={ text: rest[:n].to_owned(), }, resolved=None), after)
    }
    Some(StartsDeterminer(n)) => {
      let body = rest[n:].trim_start().to_owned()
      let mut modal_at = None
      for i = 0; i < body.length(); i = i + 1 {
        if (i == 0 || body.code_unit_at(i - 1) == 32) &&
          vocabulary.modal_at(body, i) is Some(_) {
          modal_at = Some(i)
          break
        }
      }
      guard modal_at is Some(at) else {
        raise MissingShall(at=position_of(body))
      }
      let system = body[:at].trim_end().to_owned()
      guard !system.is_empty() else {
        raise ExpectedSystem(at=position_of(body))
      }
      (
        Determined(opener={ text: rest[:n].to_owned(), }, system~),
        body[at:].to_owned(),
      )
    }
    None => raise ExpectedSystem(at=subject_at)
  }
  let verb_length = vocabulary.modal_at(from_modal, 0).unwrap_or(0)
  let verb : Word = { text: from_modal[:verb_length].to_owned(), }
  // Strict EARS keeps `not` in the response, as before dialects.
  let negated = vocabulary.extended &&
    starts_word_at(from_modal, verb_length + 1, "not")
  let after_modal = if negated {
    from_modal[verb_length + 4:].to_owned()
  } else {
    from_modal[verb_length:].to_owned()
  }
  let response = after_modal.trim_start().to_owned()
  guard !response.is_empty() && response != "." else {
    raise MissingResponse(at=position_of(after_modal))
  }
  {
    requirement: {
      lead_in,
      feature,
      preconditions: ReadOnlyArray::from_array(states[:]),
      trigger,
      subject,
      modal: { verb, negated, },
      response,
    },
    subject_at,
  }
}

///|
/// Parse one sentence in strict EARS. Keywords are case-insensitive; clauses
/// use comma separators. IF requires THEN, with an optional comma before THEN.
/// Order: optional WHERE, zero or more WHILE, optional WHEN or IF, THE ... SHALL.
pub fn Requirement::Requirement(
  source : String,
) -> Requirement raise ParseError {
  parse_sentence(source, Vocabulary::strict()).requirement
}

///|
/// Parse one sentence with the vocabulary of `dialects`. Without a dialect,
/// it is the strict grammar of `Requirement::Requirement`.
pub fn parse(
  source : String,
  dialects~ : ArrayView[&Dialect] = [],
) -> Requirement raise ParseError {
  parse_sentence(source, Vocabulary::of(dialects)).requirement
}
