///|
/// The kind of a YAML value that a lexicon key needs.
pub(all) enum ValueKind {
  Text
  List
  Mapping
  Number
} derive(Eq, Debug)

///|
/// Raised when a lexicon value breaks a rule.
pub(all) suberror LexiconError {
  /// A word that is empty, or that has white space, a comma or a full stop.
  InvalidWord(String)
  /// A phrase that is empty, that has a comma, a full stop or a line break,
  /// or whose words are not separated by single spaces.
  InvalidPhrase(String)
  /// A heading prefix that is empty or that has a line break.
  InvalidHeadingPrefix(String)
  /// A heading level outside 1 to 6.
  InvalidHeadingLevel(Int32)
  /// The lexicon file is not YAML, or not a YAML mapping.
  InvalidLexiconFile(line~ : Int32, message~ : String)
  /// A key that a lexicon file does not have.
  UnknownKey(key~ : String, line~ : Int32)
  /// A value of `key` that is not of the kind that the key needs.
  WrongType(key~ : String, line~ : Int32, expected~ : ValueKind)
  /// An entry of `key` that breaks the rule of its kind.
  InvalidEntry(key~ : String, line~ : Int32, error~ : LexiconError)
} derive(Eq, Debug)

///|
fn has_space_char(text : String) -> Bool {
  text.iter().any(c => c == ' ' || c == '\t' || c == '\n' || c == '\r')
}

///|
/// One vocabulary word, such as a modal verb, a determiner or a pronoun: not
/// empty, with no white space, comma or full stop. A word keeps its text as
/// written and compares without letter case.
struct Word {
  text : String
}

///|
pub fn Word::Word(text : String) -> Word raise LexiconError {
  if text.is_empty() ||
    has_space_char(text) ||
    text.contains(",") ||
    text.contains(".") {
    raise InvalidWord(text)
  }
  { text, }
}

///|
/// The word as written.
pub fn Word::to_string(self : Word) -> String {
  self.text
}

///|
/// The word in lower case, as the parser matches it.
pub fn Word::lower(self : Word) -> String {
  self.text.to_lower()
}

///|
pub impl Eq for Word with fn equal(self, other) {
  self.lower() == other.lower()
}

///|
pub impl Hash for Word with fn hash_combine(self, hasher) {
  hasher.combine(self.lower())
}

///|
pub impl Show for Word with fn output(self, logger) {
  logger.write_string(self.text)
}

///|
pub impl @debug.Debug for Word with fn to_repr(self) {
  @debug.Repr::string(self.text)
}

///|
/// A word that the library writes in code.
fn known_word(text : String) -> Word {
  { text, }
}

///|
/// One or more words separated by single spaces, such as a system noun or a
/// lead-in phrase, with no comma, full stop or line break. A phrase keeps its
/// text as written and compares without letter case.
struct Phrase {
  text : String
}

///|
pub fn Phrase::Phrase(text : String) -> Phrase raise LexiconError {
  let words = text.split(" ").collect()
  let ok = !text.is_empty() &&
    words.iter().all(w => w.length() > 0) &&
    !text.contains("\t") &&
    !text.contains("\n") &&
    !text.contains("\r") &&
    !text.contains(",") &&
    !text.contains(".")
  if !ok {
    raise InvalidPhrase(text)
  }
  { text, }
}

///|
/// The phrase as written.
pub fn Phrase::to_string(self : Phrase) -> String {
  self.text
}

///|
/// The phrase in lower case, as the parser matches it.
pub fn Phrase::lower(self : Phrase) -> String {
  self.text.to_lower()
}

///|
pub impl Eq for Phrase with fn equal(self, other) {
  self.lower() == other.lower()
}

///|
pub impl Hash for Phrase with fn hash_combine(self, hasher) {
  hasher.combine(self.lower())
}

///|
pub impl Show for Phrase with fn output(self, logger) {
  logger.write_string(self.text)
}

///|
pub impl @debug.Debug for Phrase with fn to_repr(self) {
  @debug.Repr::string(self.text)
}

///|
/// The start of a Markdown heading text that marks a requirement, such as
/// `Requirement:`: not empty, with no line break.
struct HeadingPrefix {
  text : String
} derive(Eq, Hash, Debug)

///|
pub fn HeadingPrefix::HeadingPrefix(
  text : String,
) -> HeadingPrefix raise LexiconError {
  if text.is_empty() || text.contains("\n") || text.contains("\r") {
    raise InvalidHeadingPrefix(text)
  }
  { text, }
}

///|
pub fn HeadingPrefix::to_string(self : HeadingPrefix) -> String {
  self.text
}

///|
/// A Markdown heading that starts a requirement block: a heading of `level`
/// whose text starts with `prefix`, with letter case. The rest of the text
/// names the block.
struct HeadingRule {
  level : @mdc.HeadingLevel
  prefix : HeadingPrefix
} derive(Eq, Hash, Debug)

///|
pub fn HeadingRule::HeadingRule(
  level : @mdc.HeadingLevel,
  prefix : HeadingPrefix,
) -> HeadingRule {
  { level, prefix, }
}

///|
pub fn HeadingRule::level(self : HeadingRule) -> @mdc.HeadingLevel {
  self.level
}

///|
pub fn HeadingRule::prefix(self : HeadingRule) -> HeadingPrefix {
  self.prefix
}

///|
/// The block name of a heading text that matches the rule.
fn HeadingRule::name_of(
  self : HeadingRule,
  level : @mdc.HeadingLevel,
  text : String,
) -> String? {
  guard level == self.level && text.has_prefix(self.prefix.text) else {
    return None
  }
  Some(text[self.prefix.text.length():].trim(chars=" \t").to_owned())
}

///|
/// A dialect adds vocabulary to the EARS grammar: modal verbs, subject
/// openers (determiners and pronouns), system nouns, lead-in phrases and
/// Markdown requirement headings. Every method except `name` has a default,
/// so a dialect gives only what it adds. Several dialects combine: the parser
/// uses the union of their vocabularies.
pub(open) trait Dialect {
  /// The dialect name, used in reports.
  fn name(Self) -> String
  /// Modal verbs besides `shall`, such as `must`.
  fn modals(Self) -> Array[Word] = _
  /// Determiners that can start a subject besides `the`, such as `each`.
  fn determiners(Self) -> Array[Word] = _
  /// Pronouns that stand for a system, such as `it`.
  fn pronouns(Self) -> Array[Word] = _
  /// System nouns that start a subject without a determiner, such as a
  /// product name.
  fn system_nouns(Self) -> Array[Phrase] = _
  /// Phrases that can come before the clauses of a sentence, such as
  /// `otherwise`.
  fn lead_ins(Self) -> Array[Phrase] = _
  /// Markdown headings that start a requirement block.
  fn headings(Self) -> Array[HeadingRule] = _
}

///|
impl Dialect with fn modals(_) {
  []
}

///|
impl Dialect with fn determiners(_) {
  []
}

///|
impl Dialect with fn pronouns(_) {
  []
}

///|
impl Dialect with fn system_nouns(_) {
  []
}

///|
impl Dialect with fn lead_ins(_) {
  []
}

///|
impl Dialect with fn headings(_) {
  []
}

///|
/// A dialect defined as data: a name and lists of vocabulary. A caller
/// builds one in code or reads one from a lexicon file with
/// `Lexicon::from_yaml`.
struct Lexicon {
  name : String
  modals : ReadOnlyArray[Word]
  determiners : ReadOnlyArray[Word]
  pronouns : ReadOnlyArray[Word]
  systems : ReadOnlyArray[Phrase]
  lead_ins : ReadOnlyArray[Phrase]
  headings : ReadOnlyArray[HeadingRule]
} derive(Eq, Debug)

///|
/// A lexicon. The name is free text for reports.
pub fn Lexicon::Lexicon(
  name~ : String = "lexicon",
  modals~ : ArrayView[Word] = [],
  determiners~ : ArrayView[Word] = [],
  pronouns~ : ArrayView[Word] = [],
  systems~ : ArrayView[Phrase] = [],
  lead_ins~ : ArrayView[Phrase] = [],
  headings~ : ArrayView[HeadingRule] = [],
) -> Lexicon {
  {
    name,
    modals: ReadOnlyArray::from_array(modals.to_owned()),
    determiners: ReadOnlyArray::from_array(determiners.to_owned()),
    pronouns: ReadOnlyArray::from_array(pronouns.to_owned()),
    systems: ReadOnlyArray::from_array(systems.to_owned()),
    lead_ins: ReadOnlyArray::from_array(lead_ins.to_owned()),
    headings: ReadOnlyArray::from_array(headings.to_owned()),
  }
}

///|
pub impl Dialect for Lexicon with fn name(self) {
  self.name
}

///|
pub impl Dialect for Lexicon with fn modals(self) {
  self.modals.iter().collect()
}

///|
pub impl Dialect for Lexicon with fn determiners(self) {
  self.determiners.iter().collect()
}

///|
pub impl Dialect for Lexicon with fn pronouns(self) {
  self.pronouns.iter().collect()
}

///|
pub impl Dialect for Lexicon with fn system_nouns(self) {
  self.systems.iter().collect()
}

///|
pub impl Dialect for Lexicon with fn lead_ins(self) {
  self.lead_ins.iter().collect()
}

///|
pub impl Dialect for Lexicon with fn headings(self) {
  self.headings.iter().collect()
}

///|
/// The OpenSpec dialect: the modal verbs `shall` and `must`, the usual
/// determiners and pronouns, the lead-in `otherwise`, and the heading rule
/// `### Requirement:`. Project words belong in a project lexicon.
pub fn openspec_dialect() -> Lexicon {
  let words = (texts : Array[String]) => texts.map(known_word)
  Lexicon(
    name="openspec",
    modals=words(["shall", "must"]),
    determiners=words([
      "a", "an", "each", "every", "any", "these", "those", "this", "that", "its",
      "their",
    ]),
    pronouns=words(["it", "they"]),
    lead_ins=[{ text: "otherwise", }],
    headings=[{ level: H3, prefix: { text: "Requirement:", }, }],
  )
}

///|
/// The merged vocabulary of the active dialects, in lower case. `shall` and
/// `the` are always there. Phrases are sorted longest first, so that the
/// longest match wins.
priv struct Vocabulary {
  modals : Array[String]
  determiners : Array[String]
  pronouns : Array[String]
  systems : Array[String]
  lead_ins : Array[String]
  headings : Array[HeadingRule]
}

///|
fn add_unique(out : Array[String], text : String) -> Unit {
  if !out.contains(text) {
    out.push(text)
  }
}

///|
fn longest_first(items : Array[String]) -> Array[String] {
  let out = items.copy()
  out.sort_by((a, b) => {
    let c = b.length().compare(a.length())
    if c != 0 {
      c
    } else {
      a.compare(b)
    }
  })
  out
}

///|
fn Vocabulary::of(dialects : ArrayView[&Dialect]) -> Vocabulary {
  let modals = ["shall"]
  let determiners = ["the"]
  let pronouns = []
  let systems = []
  let lead_ins = []
  let headings : Array[HeadingRule] = []
  for d in dialects {
    for w in d.modals() {
      add_unique(modals, w.lower())
    }
    for w in d.determiners() {
      add_unique(determiners, w.lower())
    }
    for w in d.pronouns() {
      add_unique(pronouns, w.lower())
    }
    for p in d.system_nouns() {
      add_unique(systems, p.lower())
    }
    for p in d.lead_ins() {
      add_unique(lead_ins, p.lower())
    }
    for h in d.headings() {
      if !headings.contains(h) {
        headings.push(h)
      }
    }
  }
  {
    modals,
    determiners,
    pronouns,
    systems: longest_first(systems),
    lead_ins: longest_first(lead_ins),
    headings,
  }
}

///|
/// The vocabulary of strict EARS: `shall` and `the` only.
fn Vocabulary::strict() -> Vocabulary {
  Vocabulary::of([])
}

///|
/// The length of the first item of `items` that starts `text` as whole
/// words, or `None`.
fn match_at_start(text : String, items : Array[String]) -> Int32? {
  for item in items {
    if starts_word(text, item) {
      return Some(item.length())
    }
  }
  None
}

///|
/// The kind of subject that starts `text`, with the length of its first part.
priv enum SubjectStart {
  StartsNoun(Int32)
  StartsPronoun(Int32)
  StartsDeterminer(Int32)
}

///|
fn Vocabulary::subject_at_start(
  self : Vocabulary,
  text : String,
) -> SubjectStart? {
  match match_at_start(text, self.systems) {
    Some(n) => return Some(StartsNoun(n))
    None => ()
  }
  match match_at_start(text, self.pronouns) {
    Some(n) => return Some(StartsPronoun(n))
    None => ()
  }
  match match_at_start(text, self.determiners) {
    Some(n) => Some(StartsDeterminer(n))
    None => None
  }
}

///|
fn Vocabulary::starts_subject(self : Vocabulary, text : String) -> Bool {
  self.subject_at_start(text) is Some(_)
}

///|
/// The modal verb that starts at `at` in `text` as a whole word, with its
/// length.
fn Vocabulary::modal_at(self : Vocabulary, text : String, at : Int32) -> Int32? {
  for m in self.modals {
    if starts_word_at(text, at, m) {
      return Some(m.length())
    }
  }
  None
}

///|
pub extend ValueKind with Eq::{not_equal, equal}

///|
pub extend ValueKind with @debug.Debug::{to_repr}

///|
pub extend LexiconError with Eq::{not_equal, equal}

///|
pub extend LexiconError with @debug.Debug::{to_repr}

///|
pub extend Word with Eq::{not_equal, equal}

///|
pub extend Word with Hash::{hash, hash_combine}

///|
pub extend Word with Show::{output}

///|
pub extend Word with @debug.Debug::{to_repr}

///|
pub extend Phrase with Eq::{not_equal, equal}

///|
pub extend Phrase with Hash::{hash, hash_combine}

///|
pub extend Phrase with Show::{output}

///|
pub extend Phrase with @debug.Debug::{to_repr}

///|
pub extend HeadingPrefix with Eq::{not_equal, equal}

///|
pub extend HeadingPrefix with Hash::{hash, hash_combine}

///|
pub extend HeadingPrefix with @debug.Debug::{to_repr}

///|
pub extend HeadingRule with Eq::{not_equal, equal}

///|
pub extend HeadingRule with Hash::{hash, hash_combine}

///|
pub extend HeadingRule with @debug.Debug::{to_repr}

///|
pub extend Lexicon with Eq::{not_equal, equal}

///|
pub extend Lexicon with @debug.Debug::{to_repr}

///|
pub extend Lexicon with Dialect::{
  name,
  headings,
  modals,
  pronouns,
  lead_ins,
  determiners,
  system_nouns,
}
