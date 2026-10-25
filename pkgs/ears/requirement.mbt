///|
pub(all) enum Pattern {
  Ubiquitous
  StateDriven
  EventDriven
  OptionalFeature
  UnwantedBehaviour
  Complex
} derive(Eq, Debug)

///|
/// The trigger of a requirement. Only the parser makes triggers, so the
/// condition is never empty and its white space is folded.
pub enum Trigger {
  /// A `When` clause.
  Event(String)
  /// An `If ... then` clause.
  Unwanted(String)
} derive(Eq, Debug)

///|
/// A clause keyword of EARS.
pub(all) enum Keyword {
  Where
  While
  When
  If
} derive(Eq, Hash, Debug)

///|
/// Every clause keyword, in the order that a sentence uses them. The parser
/// and the Markdown extraction use this one table.
pub let keywords : ReadOnlyArray[Keyword] = [Where, While, When, If]

///|
/// The keyword in lower case, as the parser matches it without letter case.
pub fn Keyword::word(self : Keyword) -> String {
  match self {
    Where => "where"
    While => "while"
    When => "when"
    If => "if"
  }
}

///|
/// The keyword in canonical case: `Where`, `While`, `When` or `If`.
pub fn Keyword::to_string(self : Keyword) -> String {
  match self {
    Where => "Where"
    While => "While"
    When => "When"
    If => "If"
  }
}

///|
pub impl Show for Keyword with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
/// Raised when an offset is not a position in a sentence.
pub(all) suberror PositionError {
  /// The offset is negative.
  NegativeOffset(Int32)
} derive(Eq, Debug)

///|
/// A place in the normalized sentence: the UTF-16 offset of a character,
/// counted from 0, or the length of the sentence for its end, such as the
/// place after a final `shall`.
struct SentencePosition {
  offset : Int32
} derive(Eq, Compare, Hash, Debug)

///|
pub fn SentencePosition::SentencePosition(
  offset : Int32,
) -> SentencePosition raise PositionError {
  if offset < 0 {
    raise NegativeOffset(offset)
  }
  { offset, }
}

///|
pub fn SentencePosition::offset(self : SentencePosition) -> Int32 {
  self.offset
}

///|
pub impl Show for SentencePosition with fn output(self, logger) {
  logger.write_object(self.offset)
}

///|
/// The modal verb of a requirement, such as `shall` or `must`, and whether
/// `not` follows it.
pub struct Modal {
  verb : Word
  negated : Bool
} derive(Eq, Debug)

///|
/// The subject of a requirement.
pub enum Subject {
  /// A determiner, such as `the` or `each`, and the system after it.
  Determined(opener~ : Word, system~ : String)
  /// A system noun of a dialect, such as a product name.
  Noun(String)
  /// A pronoun, such as `it`. Block parsing resolves it to the system of an
  /// earlier sentence.
  Pronoun(opener~ : Word, resolved~ : String?)
} derive(Eq, Debug)

///|
/// A validated EARS sentence. Only the parser can construct a requirement.
/// Free-text clauses retain their case and punctuation, with whitespace folded.
struct Requirement {
  lead_in : String?
  feature : String?
  preconditions : ReadOnlyArray[String]
  trigger : Trigger?
  subject : Subject
  modal : Modal
  response : String
} derive(Eq, Debug)

///|
/// The lead-in phrase before the clauses, such as `Otherwise` or
/// `For each document`, as written.
pub fn Requirement::lead_in(self : Requirement) -> String? {
  self.lead_in
}

///|
pub fn Requirement::feature(self : Requirement) -> String? {
  self.feature
}

///|
pub fn Requirement::preconditions(self : Requirement) -> ReadOnlyArray[String] {
  self.preconditions
}

///|
pub fn Requirement::trigger(self : Requirement) -> Trigger? {
  self.trigger
}

///|
pub fn Requirement::subject(self : Requirement) -> Subject {
  self.subject
}

///|
/// The subject opener as written: the determiner or the pronoun. A system
/// noun has none.
pub fn Requirement::opener(self : Requirement) -> Word? {
  match self.subject {
    Determined(opener~, ..) | Pronoun(opener~, ..) => Some(opener)
    Noun(_) => None
  }
}

///|
/// The system: the words after the determiner, the system noun, or the
/// system that a pronoun was resolved to. An unresolved pronoun has none.
pub fn Requirement::system(self : Requirement) -> String? {
  match self.subject {
    Determined(system~, ..) => Some(system)
    Noun(system) => Some(system)
    Pronoun(resolved~, ..) => resolved
  }
}

///|
/// The system that block parsing resolved a pronoun subject to.
pub fn Requirement::resolved_system(self : Requirement) -> String? {
  match self.subject {
    Pronoun(resolved~, ..) => resolved
    Determined(..) | Noun(_) => None
  }
}

///|
pub fn Requirement::modal(self : Requirement) -> Modal {
  self.modal
}

///|
pub fn Requirement::response(self : Requirement) -> String {
  self.response
}

///|
pub fn Requirement::pattern(self : Requirement) -> Pattern {
  let count = (if self.feature is Some(_) { 1 } else { 0 }) +
    self.preconditions.length() +
    (if self.trigger is Some(_) { 1 } else { 0 })
  if count > 1 {
    return Complex
  }
  if self.feature is Some(_) {
    return OptionalFeature
  }
  if !self.preconditions.is_empty() {
    return StateDriven
  }
  match self.trigger {
    Some(Event(_)) => EventDriven
    Some(Unwanted(_)) => UnwantedBehaviour
    None => Ubiquitous
  }
}

///|
/// A word in lower case, or with a capital first letter at the start of a
/// sentence.
fn canonical(word : String, at_start : Bool) -> String {
  let lower = word.to_lower()
  if at_start && lower.length() > 0 {
    lower[0:1].to_owned().to_upper() + lower[1:].to_owned()
  } else {
    lower
  }
}

///|
/// Render canonical keyword case and spacing: the lead-in and the clauses as
/// written, then the subject opener and the modal verb in lower case, with a
/// capital first letter at the start. Response punctuation is retained.
/// Parsing the text with the same dialects gives an equal requirement.
pub fn Requirement::to_string(self : Requirement) -> String {
  let clauses = []
  match self.lead_in {
    Some(lead_in) => clauses.push(lead_in)
    None => ()
  }
  if self.feature is Some(feature) {
    clauses.push("\{Where} " + feature)
  }
  for state in self.preconditions {
    clauses.push("\{While} " + state)
  }
  match self.trigger {
    Some(Event(event)) => clauses.push("\{When} " + event)
    Some(Unwanted(event)) => clauses.push("\{If} " + event)
    None => ()
  }
  let unwanted = self.trigger is Some(Unwanted(_))
  let at_start = clauses.is_empty()
  let subject = match self.subject {
    Determined(opener~, system~) =>
      canonical(opener.to_string(), at_start && !unwanted) + " " + system
    Noun(system) => system
    Pronoun(opener~, ..) => canonical(opener.to_string(), at_start && !unwanted)
  }
  let modal = self.modal.verb.lower() +
    (if self.modal.negated { " not" } else { "" })
  let head = if unwanted { "then " } else { "" }
  clauses.push(head + subject + " " + modal + " " + self.response)
  clauses.join(", ")
}

///|
/// Why a sentence is not an EARS requirement. Each case except
/// `EmptyRequirement` has the position in the normalized sentence where the
/// parse failed.
pub(all) suberror ParseError {
  /// The sentence is empty or white space.
  EmptyRequirement
  /// The system clause, `the <system> shall`, is missing at the position.
  ExpectedSystem(at~ : SentencePosition)
  /// The system clause from the position has no `shall`.
  MissingShall(at~ : SentencePosition)
  /// Nothing follows `shall` at the position.
  MissingResponse(at~ : SentencePosition)
  /// The clause of the keyword at the position is empty.
  EmptyClause(keyword~ : Keyword, at~ : SentencePosition)
  /// The clause at the position has no comma before the next clause.
  MissingSeparator(at~ : SentencePosition)
  /// The `If` clause at the position has no `then`.
  MissingThen(at~ : SentencePosition)
  /// The clause at the position is out of order.
  InvalidClauseOrder(at~ : SentencePosition)
  /// In a requirement block, the pronoun subject at the position has no
  /// earlier sentence with a system to refer to.
  UnresolvedPronoun(pronoun~ : Word, at~ : SentencePosition)
} derive(Eq, Debug)

///|
/// The position where the parse failed, or `None` for an empty sentence.
pub fn ParseError::position(self : ParseError) -> SentencePosition? {
  match self {
    EmptyRequirement => None
    ExpectedSystem(at~)
    | MissingShall(at~)
    | MissingResponse(at~)
    | EmptyClause(at~, ..)
    | MissingSeparator(at~)
    | MissingThen(at~)
    | InvalidClauseOrder(at~)
    | UnresolvedPronoun(at~, ..) => Some(at)
  }
}

///|
pub extend Pattern with Eq::{equal, not_equal}

///|
pub extend Pattern with @debug.Debug::{to_repr}

///|
pub extend Trigger with Eq::{equal, not_equal}

///|
pub extend Trigger with @debug.Debug::{to_repr}

///|
pub extend Requirement with Eq::{equal, not_equal}

///|
pub extend Requirement with @debug.Debug::{to_repr}

///|
pub extend ParseError with Eq::{equal, not_equal}

///|
pub extend ParseError with @debug.Debug::{to_repr}

///|
pub extend Keyword with Eq::{not_equal, equal}

///|
pub extend Keyword with Hash::{hash, hash_combine}

///|
pub extend Keyword with @debug.Debug::{to_repr}

///|
pub extend Keyword with Show::{output}

///|
pub extend PositionError with Eq::{not_equal, equal}

///|
pub extend PositionError with @debug.Debug::{to_repr}

///|
pub extend SentencePosition with Eq::{not_equal, equal}

///|
pub extend SentencePosition with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend SentencePosition with Hash::{hash, hash_combine}

///|
pub extend SentencePosition with @debug.Debug::{to_repr}

///|
pub extend SentencePosition with Show::{to_string, output}

///|
pub extend Modal with Eq::{equal, not_equal}

///|
pub extend Modal with @debug.Debug::{to_repr}

///|
pub extend Subject with Eq::{equal, not_equal}

///|
pub extend Subject with @debug.Debug::{to_repr}
