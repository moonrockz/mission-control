///|
/// A register name, such as `decision`. It is not blank.
struct RegisterName {
  text : String
} derive(Eq, Hash, Debug)

///|
pub fn RegisterName::RegisterName(
  text : String,
) -> RegisterName raise ValueError {
  if text.iter().all(is_space_char) {
    raise BlankName(text)
  }
  { text, }
}

///|
pub fn RegisterName::to_string(self : RegisterName) -> String {
  self.text
}

///|
pub impl Show for RegisterName with fn output(self, logger) {
  logger.write_string(self.text)
}

///|
/// A state of a register, such as `Accepted`. It is not blank, and it is
/// compared exactly as written.
struct StateName {
  text : String
} derive(Eq, Hash, Debug)

///|
pub fn StateName::StateName(text : String) -> StateName raise ValueError {
  if text.iter().all(is_space_char) {
    raise BlankName(text)
  }
  { text, }
}

///|
pub fn StateName::to_string(self : StateName) -> String {
  self.text
}

///|
pub impl Show for StateName with fn output(self, logger) {
  logger.write_string(self.text)
}

///|
/// A record ID, such as `0042`. It is not blank.
struct RecordId {
  text : String
} derive(Eq, Hash, Debug)

///|
pub fn RecordId::RecordId(text : String) -> RecordId raise ValueError {
  if text.iter().all(is_space_char) {
    raise BlankName(text)
  }
  { text, }
}

///|
pub fn RecordId::to_string(self : RecordId) -> String {
  self.text
}

///|
pub impl Show for RecordId with fn output(self, logger) {
  logger.write_string(self.text)
}

///|
pub impl Compare for RecordId with fn compare(self, other) {
  lexical_compare(self.text, other.text)
}

///|
/// The width of a padded record ID: 1 to 9 digits.
struct IdWidth {
  value : Int32
} derive(Eq, Hash, Debug)

///|
pub fn IdWidth::IdWidth(value : Int32) -> IdWidth raise ValueError {
  if value < 1 || value > 9 {
    raise InvalidIdWidth(value)
  }
  { value, }
}

///|
/// The width 4, as in `0042`.
pub fn IdWidth::default() -> IdWidth {
  { value: 4, }
}

///|
pub fn IdWidth::to_int(self : IdWidth) -> Int32 {
  self.value
}

///|
/// How a register finds the ID of a record.
pub(all) enum IdRule {
  /// The leading digits of the file name, padded with zeros to the width.
  LeadingDigits(IdWidth)
  /// The value of a frontmatter key.
  FieldValue(FieldKey)
} derive(Eq, Debug)

///|
/// One record of a register: a typed view of one concept.
pub struct Record {
  register : RegisterName
  bundle : BundleLabel
  id : RecordId?
  state : StateName?
  document : Document
}

///|
pub fn Record::key(self : Record) -> DocKey {
  { bundle: self.bundle, path: self.document.path(), }
}

///|
/// The frontmatter of the record's concept.
/// The same record with another text of its document, such as the preview of
/// an edit. The ID and the state stay as they were, so a transition check on
/// the preview starts from the current state.
pub fn Record::with_document(self : Record, document : Document) -> Record {
  { ..self, document, }
}

///|
pub fn Record::metadata(self : Record) -> Metadata {
  self.document.metadata()
}

///|
/// A condition that a transition requires, such as a `reason` value. The name
/// is a label for reports.
pub(all) struct Obligation {
  name : String
  met : (Record) -> Bool
}

///|
/// An obligation that holds when the record has a non-empty value for `key`.
pub fn Obligation::requires_key(key : FieldKey) -> Obligation {
  {
    name: key.to_string(),
    met: r => r.metadata().text(key.to_string()) is Some(_),
  }
}

///|
/// An allowed change of state. An empty `from` allows any current state.
struct Transition {
  from : ReadOnlyArray[StateName]
  to : StateName
  obligations : ReadOnlyArray[Obligation]
}

///|
pub fn Transition::Transition(
  to : StateName,
  from~ : ArrayView[StateName] = [],
  obligations~ : ArrayView[Obligation] = [],
) -> Transition {
  {
    from: ReadOnlyArray::from_array(from.to_owned()),
    to,
    obligations: ReadOnlyArray::from_array(obligations.to_owned()),
  }
}

///|
pub fn Transition::from(self : Transition) -> ReadOnlyArray[StateName] {
  self.from
}

///|
pub fn Transition::to(self : Transition) -> StateName {
  self.to
}

///|
pub fn Transition::obligations(self : Transition) -> ReadOnlyArray[Obligation] {
  self.obligations
}

///|
/// A typed view of the concepts of one type, defined by a profile. Build it
/// with `Register::Register`, which checks its parts.
struct Register {
  name : RegisterName
  concept_type : ConceptType
  id_rule : IdRule
  state_key : FieldKey?
  states : ReadOnlyArray[StateName]
  transitions : ReadOnlyArray[Transition]
  supersedes_key : FieldKey?
  superseded_by_key : FieldKey?
  superseded_states : ReadOnlyArray[StateName]
  bundle_flag : FieldKey?
  fields : ReadOnlyArray[KeyDefinition]
}

///|
/// Builds a register. When `states` is not empty, every transition state and
/// every superseded state must be one of them; otherwise it raises
/// `UnknownState`.
pub fn Register::Register(
  name : RegisterName,
  concept_type : ConceptType,
  id_rule~ : IdRule = LeadingDigits(IdWidth::default()),
  state_key? : FieldKey,
  states~ : ArrayView[StateName] = [],
  transitions~ : ArrayView[Transition] = [],
  supersedes_key? : FieldKey,
  superseded_by_key? : FieldKey,
  superseded_states~ : ArrayView[StateName] = [],
  bundle_flag? : FieldKey,
  fields~ : ArrayView[KeyDefinition] = [],
) -> Register raise ValueError {
  let known = states.to_owned()
  if !known.is_empty() {
    let used : Array[StateName] = []
    for t in transitions {
      used.push(t.to)
      for f in t.from {
        used.push(f)
      }
    }
    for s in superseded_states {
      used.push(s)
    }
    for s in used {
      if !known.contains(s) {
        raise ValueError::UnknownState(
          register=name.to_string(),
          state=s.to_string(),
        )
      }
    }
  }
  {
    name,
    concept_type,
    id_rule,
    state_key,
    states: ReadOnlyArray::from_array(known),
    transitions: ReadOnlyArray::from_array(transitions.to_owned()),
    supersedes_key,
    superseded_by_key,
    superseded_states: ReadOnlyArray::from_array(superseded_states.to_owned()),
    bundle_flag,
    fields: ReadOnlyArray::from_array(fields.to_owned()),
  }
}

///|
pub fn Register::name(self : Register) -> RegisterName {
  self.name
}

///|
pub fn Register::concept_type(self : Register) -> ConceptType {
  self.concept_type
}

///|
pub fn Register::id_rule(self : Register) -> IdRule {
  self.id_rule
}

///|
pub fn Register::state_key(self : Register) -> FieldKey? {
  self.state_key
}

///|
pub fn Register::states(self : Register) -> ReadOnlyArray[StateName] {
  self.states
}

///|
pub fn Register::transitions(self : Register) -> ReadOnlyArray[Transition] {
  self.transitions
}

///|
pub fn Register::supersedes_key(self : Register) -> FieldKey? {
  self.supersedes_key
}

///|
pub fn Register::superseded_by_key(self : Register) -> FieldKey? {
  self.superseded_by_key
}

///|
pub fn Register::superseded_states(self : Register) -> ReadOnlyArray[StateName] {
  self.superseded_states
}

///|
pub fn Register::bundle_flag(self : Register) -> FieldKey? {
  self.bundle_flag
}

///|
pub fn Register::fields(self : Register) -> ReadOnlyArray[KeyDefinition] {
  self.fields
}

///|
/// Normalizes an ID: digits only, padded with zeros to `width`. Text that is
/// not all digits gives `None`.
pub fn normalize_id(text : String, width : IdWidth) -> RecordId? {
  let text = text.trim(chars=" \t").to_owned()
  if text.length() == 0 {
    return None
  }
  for c in text {
    if c < '0' || c > '9' {
      return None
    }
  }
  let mut i = 0
  while i < text.length() - 1 && text[i] == '0' {
    i += 1
  }
  let trimmed = text[i:].to_owned()
  let w = width.to_int()
  let padded = if trimmed.length() < w {
    "0".repeat(w - trimmed.length()) + trimmed
  } else {
    trimmed
  }
  Some({ text: padded, })
}

///|
fn leading_digits(name : String) -> String? {
  let mut i = 0
  while i < name.length() && name[i] >= '0' && name[i] <= '9' {
    i += 1
  }
  if i == 0 {
    None
  } else {
    Some(name[:i].to_owned())
  }
}

///|
/// True when the register applies to `bundle`: no bundle flag, or the root
/// index sets the flag to true.
pub fn Register::applies_to(self : Register, bundle : Bundle) -> Bool {
  match self.bundle_flag {
    None => true
    Some(flag) => bundle.config().bool(flag.to_string()) == Some(true)
  }
}

///|
/// The ID of a document under this register.
pub fn Register::record_id(self : Register, doc : Document) -> RecordId? {
  match self.id_rule {
    LeadingDigits(width) =>
      match leading_digits(doc.path().name()) {
        Some(digits) => normalize_id(digits, width)
        None => None
      }
    FieldValue(key) =>
      match doc.metadata().text(key.to_string()) {
        // A blank field gives no ID.
        Some(text) =>
          try RecordId(text) catch {
            _ => None
          } noraise {
            id => Some(id)
          }
        None => None
      }
  }
}

///|
/// The record ID for an ID that a user or a field gives, such as `42`.
pub fn Register::parse_id(self : Register, text : String) -> RecordId? {
  match self.id_rule {
    LeadingDigits(width) => normalize_id(text, width)
    FieldValue(_) =>
      if text.iter().all(is_space_char) {
        None
      } else {
        Some({ text, })
      }
  }
}

///|
fn Register::state_of(self : Register, doc : Document) -> StateName? {
  match self.state_key {
    Some(key) =>
      match doc.metadata().text(key.to_string()) {
        Some(text) if !text.iter().all(is_space_char) => Some({ text, })
        _ => None
      }
    None => None
  }
}

///|
/// The records of `bundle`: its concepts whose `type` equals the register
/// type, ignoring letter case.
pub fn Register::records(self : Register, bundle : Bundle) -> Array[Record] {
  guard self.applies_to(bundle) else { return [] }
  bundle
  .concepts()
  .iter()
  .filter(doc => doc.concept_type() == Some(self.concept_type))
  .map(doc => {
    register: self.name,
    bundle: bundle.label(),
    id: self.record_id(doc),
    state: self.state_of(doc),
    document: doc,
  })
  .collect()
}

///|
/// The records of every bundle where the register applies.
pub fn Register::all_records(
  self : Register,
  knowledge : Knowledge,
) -> Array[Record] {
  let out = []
  for bundle in knowledge.bundles() {
    for record in self.records(bundle) {
      out.push(record)
    }
  }
  out
}

///|
/// Finds records by ID (`42` or `0042`) or by a part of the file name.
pub fn Register::find(
  self : Register,
  records : ArrayView[Record],
  query : String,
) -> Lookup[Record] {
  match self.parse_id(query) {
    Some(id) => {
      let by_id = records.iter().filter(r => r.id == Some(id)).collect()
      if !by_id.is_empty() {
        return lookup_of(by_id)
      }
    }
    None => ()
  }
  let q = query.to_lower()
  lookup_of(
    records
    .iter()
    .filter(r => r.document.path().name().to_lower().contains(q))
    .collect(),
  )
}

///|
/// The IDs that more than one record has, with those records, sorted by ID.
pub fn Register::duplicates(
  _self : Register,
  records : ArrayView[Record],
) -> Array[(RecordId, ReadOnlyArray[Record])] {
  let groups : Map[RecordId, Array[Record]] = Map([])
  for record in records {
    match record.id {
      Some(id) =>
        match groups.get(id) {
          Some(list) => list.push(record)
          None => groups[id] = [record]
        }
      None => ()
    }
  }
  let out = []
  for id, list in groups {
    if list.length() > 1 {
      out.push((id, ReadOnlyArray::from_array(list)))
    }
  }
  out.sort_by((a, b) => a.0.compare(b.0))
  out
}

///|
/// Why a register refuses a transition.
pub(all) enum TransitionDenial {
  /// The target state is not a state of the register.
  UnknownState(StateName)
  /// No transition leads from the current state to the target state.
  NotAllowed(from~ : StateName?, to~ : StateName)
  /// The transition exists, but the obligations with these names are not met.
  Refused(ReadOnlyArray[String])
} derive(Eq, Debug)

///|
/// Checks whether `record` can move to state `to`: `Ok` when it can, else the
/// reason why not.
pub fn Register::check_transition(
  self : Register,
  record : Record,
  to : StateName,
) -> Result[Unit, TransitionDenial] {
  if !self.states.is_empty() && !self.states.contains(to) {
    return Err(UnknownState(to))
  }
  let candidates = self.transitions
    .iter()
    .filter(t => {
      t.to == to &&
      (
        t.from.is_empty() ||
        (match record.state {
          Some(s) => t.from.contains(s)
          None => false
        })
      )
    })
    .collect()
  match candidates {
    [] => Err(NotAllowed(from=record.state, to~))
    _ => {
      let mut best : Array[String]? = None
      for t in candidates {
        let unmet = t.obligations
          .iter()
          .filter(o => !(o.met)(record))
          .map(o => o.name)
          .collect()
        if unmet.is_empty() {
          return Ok(())
        }
        match best {
          Some(b) if b.length() <= unmet.length() => ()
          _ => best = Some(unmet)
        }
      }
      Err(Refused(ReadOnlyArray::from_array(best.unwrap_or([]))))
    }
  }
}

///|
/// A supersession problem.
pub(all) enum SupersessionIssue {
  /// A record in a superseded state names no successor.
  MissingSuccessor(Record)
  /// `superseded_by` names an ID that no record has.
  UnknownSuccessor(Record, RecordId)
  /// `supersedes` names an ID that no record has.
  UnknownPredecessor(Record, RecordId)
  /// Only one of the two records names the other.
  NotMutual(Record, Record)
}

///|
fn Register::ids_at(
  self : Register,
  record : Record,
  key : FieldKey?,
) -> Array[RecordId] {
  // Text that is not an ID of this register stays as written, so that the
  // checks report it as unknown. Blank text names no record.
  let id_of = (text : String) => {
    match self.parse_id(text) {
      Some(id) => Some(id)
      None =>
        try RecordId(text.trim(chars=" \t").to_owned()) catch {
          _ => None
        } noraise {
          id => Some(id)
        }
    }
  }
  match key {
    Some(k) => record.metadata().texts(k.to_string()).filter_map(id_of)
    None => []
  }
}

///|
/// Checks the supersession fields of `records`, which come from one bundle.
pub fn Register::supersession_issues(
  self : Register,
  records : ArrayView[Record],
) -> Array[SupersessionIssue] {
  let by_id : Map[RecordId, Record] = Map([])
  for r in records {
    match r.id {
      Some(id) => if !by_id.contains(id) { by_id[id] = r }
      None => ()
    }
  }
  let names = (r : Record, ids : Array[RecordId]) => {
    match r.id {
      Some(id) => ids.contains(id)
      None => false
    }
  }
  let out = []
  for r in records {
    let successors = self.ids_at(r, self.superseded_by_key)
    match r.state {
      Some(state) if self.superseded_states.contains(state) &&
        successors.is_empty() => out.push(MissingSuccessor(r))
      _ => ()
    }
    for s in successors {
      match by_id.get(s) {
        None => out.push(UnknownSuccessor(r, s))
        Some(next) =>
          if self.supersedes_key is Some(_) &&
            !names(r, self.ids_at(next, self.supersedes_key)) {
            out.push(NotMutual(r, next))
          }
      }
    }
    for p in self.ids_at(r, self.supersedes_key) {
      match by_id.get(p) {
        None => out.push(UnknownPredecessor(r, p))
        Some(prev) =>
          if self.superseded_by_key is Some(_) &&
            !names(r, self.ids_at(prev, self.superseded_by_key)) {
            out.push(NotMutual(prev, r))
          }
      }
    }
  }
  out
}

///|
/// The chain of successors of `record`, following `superseded_by`. A cycle ends the chain.
pub fn Register::successors(
  self : Register,
  records : ArrayView[Record],
  record : Record,
) -> Array[Record] {
  let out = []
  let seen : Array[RecordId] = match record.id {
    Some(id) => [id]
    None => []
  }
  let mut current = record
  while true {
    match self.ids_at(current, self.superseded_by_key) {
      [next_id, ..] => {
        if seen.contains(next_id) {
          break
        }
        match records.iter().find_first(r => r.id == Some(next_id)) {
          Some(next) => {
            out.push(next)
            seen.push(next_id)
            current = next
          }
          None => break
        }
      }
      [] => break
    }
  }
  out
}

///|
/// What a reference field names.
pub(all) enum ReferenceKind {
  /// A document: `bundle-label:/path.md`, or `/path.md` in the same bundle.
  DocumentRef
  /// Records of a register in the same bundle, by ID.
  RecordRef(register~ : RegisterName)
  /// A path or URL, resolved like a link.
  PathRef
} derive(Eq, Debug)

///|
/// A frontmatter field whose values name documents or records.
pub(all) struct ReferenceField {
  key : FieldKey
  kind : ReferenceKind
} derive(Eq, Debug)

///|
/// A template for new concepts of one type. The body can use `{{title}}`,
/// `{{description}}` and `{{type}}`.
pub(all) struct Template {
  concept_type : ConceptType
  body : String
} derive(Eq, Debug)

///|
pub extend RegisterName with Eq::{not_equal, equal}

///|
pub extend RegisterName with Hash::{hash, hash_combine}

///|
pub extend RegisterName with @debug.Debug::{to_repr}

///|
pub extend RegisterName with Show::{output}

///|
pub extend StateName with Eq::{not_equal, equal}

///|
pub extend StateName with Hash::{hash, hash_combine}

///|
pub extend StateName with @debug.Debug::{to_repr}

///|
pub extend StateName with Show::{output}

///|
pub extend RecordId with Eq::{not_equal, equal}

///|
pub extend RecordId with Hash::{hash, hash_combine}

///|
pub extend RecordId with @debug.Debug::{to_repr}

///|
pub extend RecordId with Show::{output}

///|
pub extend RecordId with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend IdWidth with Eq::{not_equal, equal}

///|
pub extend IdWidth with Hash::{hash, hash_combine}

///|
pub extend IdWidth with @debug.Debug::{to_repr}

///|
pub extend IdRule with Eq::{not_equal, equal}

///|
pub extend IdRule with @debug.Debug::{to_repr}

///|
pub extend TransitionDenial with Eq::{not_equal, equal}

///|
pub extend TransitionDenial with @debug.Debug::{to_repr}

///|
pub extend ReferenceKind with Eq::{not_equal, equal}

///|
pub extend ReferenceKind with @debug.Debug::{to_repr}

///|
pub extend ReferenceField with Eq::{not_equal, equal}

///|
pub extend ReferenceField with @debug.Debug::{to_repr}

///|
pub extend Template with Eq::{not_equal, equal}

///|
pub extend Template with @debug.Debug::{to_repr}
