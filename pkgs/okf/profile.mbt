///|
/// A frontmatter key that a profile defines.
pub(all) struct KeyDefinition {
  key : FieldKey
  /// The allowed values, or empty for any value.
  values : ReadOnlyArray[String]
  description : String
} derive(Eq, Debug)

///|
pub fn KeyDefinition::KeyDefinition(
  key : FieldKey,
  values~ : ArrayView[String] = [],
  description~ : String = "",
) -> KeyDefinition {
  { key, values: ReadOnlyArray::from_array(values.to_owned()), description, }
}

///|
/// A profile extends OKF with conventions: vocabulary, derived metadata,
/// registers, references, templates and rules. Every method has a default, so
/// a profile implements only what it adds. The methods that define keys,
/// registers, references, templates, rules and severities can raise
/// `ValueError`; validation then reports the profile as invalid.
pub(open) trait Profile {
  /// The profile name, used in reports.
  fn name(Self) -> String
  /// Concept frontmatter keys that this profile defines.
  fn vocabulary(Self) -> Array[KeyDefinition] raise ValueError = _
  /// Root index frontmatter keys that turn on profile behavior for a bundle.
  fn bundle_keys(Self) -> Array[KeyDefinition] raise ValueError = _
  /// Metadata for a document without frontmatter, from its path and body.
  fn derive_metadata(Self, Document) -> Fields? = _
  /// Typed views of concepts of one type.
  fn registers(Self) -> Array[Register] raise ValueError = _
  /// Frontmatter fields whose values name documents.
  fn reference_fields(Self) -> Array[ReferenceField] raise ValueError = _
  /// Templates for new concepts.
  fn templates(Self) -> Array[Template] raise ValueError = _
  /// Rule sets that validation runs.
  fn rule_sets(Self) -> Array[RuleSet] raise ValueError = _
  /// Options that this profile prefers. The caller's options win.
  fn options(Self) -> Options? = _
  /// Links that the profile adds to the graph for a document, such as links
  /// that its path or frontmatter implies.
  fn relations(Self, Bundle, Document) -> Array[Link] = _
  /// Rule severities that this profile prefers. The caller's config wins.
  fn severities(Self) -> Array[(RuleName, Severity)] raise ValueError = _
}

///|
impl Profile with fn relations(_, _, _) {
  []
}

///|
impl Profile with fn vocabulary(_) {
  []
}

///|
impl Profile with fn bundle_keys(_) {
  []
}

///|
impl Profile with fn derive_metadata(_, _) {
  None
}

///|
impl Profile with fn registers(_) {
  []
}

///|
impl Profile with fn reference_fields(_) {
  []
}

///|
impl Profile with fn templates(_) {
  []
}

///|
impl Profile with fn rule_sets(_) {
  []
}

///|
impl Profile with fn options(_) {
  None
}

///|
/// The first derived metadata from `profiles`, in order.
fn derive_with(profiles : ArrayView[&Profile], doc : Document) -> Fields? {
  for profile in profiles {
    match profile.derive_metadata(doc) {
      Some(fields) => return Some(fields)
      None => ()
    }
  }
  None
}

///|
pub extend KeyDefinition with Eq::{not_equal, equal}

///|
pub extend KeyDefinition with @debug.Debug::{to_repr}

///|
/// Two profiles that define the same key or register differently.
pub(all) enum ProfileConflict {
  /// Two profiles define the frontmatter key with different values.
  KeyConflict(key~ : FieldKey, first~ : String, second~ : String)
  /// Two profiles define a register for the same concept type differently.
  RegisterConflict(
    concept_type~ : ConceptType,
    first~ : String,
    second~ : String
  )
  /// A profile definition breaks a rule of a value type.
  ProfileInvalid(profile~ : String, error~ : ValueError)
} derive(Eq, Debug)

///|
fn same_register(a : Register, b : Register) -> Bool {
  a.name == b.name &&
  a.id_rule == b.id_rule &&
  a.state_key == b.state_key &&
  a.states == b.states &&
  a.supersedes_key == b.supersedes_key &&
  a.superseded_by_key == b.superseded_by_key &&
  a.bundle_flag == b.bundle_flag
}

///|
/// The conflicts between `profiles`, and the profiles whose definitions break
/// a rule. The library never selects one definition in silence; a caller
/// reports the conflicts or removes a profile.
pub fn profile_conflicts(
  profiles : ArrayView[&Profile],
) -> Array[ProfileConflict] {
  let out = []
  let keys : Map[FieldKey, (String, KeyDefinition)] = Map([])
  let registers : Map[ConceptType, (String, Register)] = Map([])
  let register_names : Array[RegisterName] = []
  let references : Array[(String, ReferenceField)] = []
  for profile in profiles {
    let name = profile.name()
    try {
      for def in profile.vocabulary() {
        match keys.get(def.key) {
          Some((first, other)) if other.values != def.values =>
            out.push(KeyConflict(key=def.key, first~, second=name))
          Some(_) => ()
          None => keys[def.key] = (name, def)
        }
      }
      for register in profile.registers() {
        register_names.push(register.name)
        match registers.get(register.concept_type) {
          Some((first, other)) if !same_register(other, register) =>
            out.push(
              RegisterConflict(
                concept_type=register.concept_type,
                first~,
                second=name,
              ),
            )
          Some(_) => ()
          None => registers[register.concept_type] = (name, register)
        }
      }
      for field in profile.reference_fields() {
        references.push((name, field))
      }
      profile.bundle_keys() |> ignore
      profile.templates() |> ignore
      profile.rule_sets() |> ignore
      profile.severities() |> ignore
    } catch {
      e => out.push(ProfileInvalid(profile=name, error=e))
    }
  }
  // A reference field must name a register that some profile defines.
  for pair in references {
    match pair.1.kind {
      RecordRef(register~) if !register_names.contains(register) =>
        out.push(
          ProfileInvalid(
            profile=pair.0,
            error=UnknownRegister(register=register.to_string()),
          ),
        )
      _ => ()
    }
  }
  out
}

///|
/// The options to load with: the caller's options when given, else the
/// options of the first profile that has some, else the OKF v0.2 defaults.
pub fn effective_options(
  profiles : ArrayView[&Profile],
  caller? : Options,
) -> Options {
  match caller {
    Some(o) => o
    None => {
      for profile in profiles {
        match profile.options() {
          Some(o) => return o
          None => ()
        }
      }
      Options::default()
    }
  }
}

///|
/// Every register of `profiles`.
pub fn registers_of(
  profiles : ArrayView[&Profile],
) -> Array[Register] raise ValueError {
  let out = []
  for profile in profiles {
    for r in profile.registers() {
      out.push(r)
    }
  }
  out
}

///|
pub extend ProfileConflict with Eq::{not_equal, equal}

///|
pub extend ProfileConflict with @debug.Debug::{to_repr}

///|
impl Profile with fn severities(_) {
  []
}
