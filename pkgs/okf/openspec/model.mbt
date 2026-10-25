///|
/// One OpenSpec scenario: `#### Scenario: name` with its WHEN, THEN and AND
/// clauses. The name and the clauses are free text.
pub struct Scenario {
  name : String
  when_ : ReadOnlyArray[String]
  then_ : ReadOnlyArray[String]
  line : Int32
} derive(Eq, Debug)

///|
/// One OpenSpec requirement: `### Requirement: name`, its text and its
/// scenarios, and the EARS sentences of its text.
pub struct Requirement {
  name : RequirementName
  text : String
  scenarios : ReadOnlyArray[Scenario]
  line : Int32
  /// The file line of the first line of the text, when there is text.
  text_line : Int32?
  /// The EARS requirements of the text, one for each sentence that parses.
  sentences : ReadOnlyArray[@ears.Occurrence]
  /// The sentences of the text that do not parse as EARS. Their spans are
  /// relative to the text.
  sentence_diagnostics : ReadOnlyArray[@ears.Diagnostic]
} derive(Eq, Debug)

///|
/// A delta operation of a change spec.
pub(all) enum DeltaOp {
  Added
  Modified
  Removed
  Renamed
} derive(Eq, Debug)

///|
/// One complete rename of a `RENAMED Requirements` section: a `FROM:` line and
/// the `TO:` line after it.
pub struct Rename {
  from : RequirementName
  to : RequirementName
  /// The file line of the `FROM:` line.
  line : Int32
} derive(Eq, Debug)

///|
/// A rename with one part only. The view gives no rename for it, and
/// validation reports it.
pub(all) enum IncompleteRename {
  /// A `FROM:` line without a `TO:` line after it.
  MissingTo(from~ : RequirementName, line~ : Int32)
  /// A `TO:` line without a `FROM:` line before it.
  MissingFrom(to~ : RequirementName, line~ : Int32)
} derive(Eq, Debug)

///|
/// One delta section: `## ADDED Requirements` and so on.
pub struct DeltaSection {
  op : DeltaOp
  requirements : ReadOnlyArray[Requirement]
  /// For `RENAMED`: the complete renames.
  renames : ReadOnlyArray[Rename]
  /// For `RENAMED`: the renames with one part only.
  incomplete_renames : ReadOnlyArray[IncompleteRename]
} derive(Eq, Debug)

///|
/// The structured content of one spec file: a main specification, or a delta.
pub struct SpecModel {
  capability : CapabilityPath
  purpose : String?
  /// The requirements of a main spec (`## Requirements`).
  requirements : ReadOnlyArray[Requirement]
  /// The delta sections of a change spec.
  deltas : ReadOnlyArray[DeltaSection]
  /// The file lines of `### Requirement:` headings without a name. The view
  /// gives no requirement for them, and validation reports them.
  unnamed_requirements : ReadOnlyArray[Int32]
} derive(Eq, Debug)

///|
/// One task of a `tasks.md`: `- [ ] 1.1 text`. A task without a number has
/// no number.
pub struct Task {
  number : TaskNumber?
  text : String
  done : Bool
  line : Int32
} derive(Eq, Debug)

///|
/// One `## N. Group` of a `tasks.md`. Tasks before the first `##` heading
/// form a group without a heading.
pub struct TaskGroup {
  heading : String?
  tasks : ReadOnlyArray[Task]
} derive(Eq, Debug)

///|
/// One OpenSpec change.
pub struct Change {
  name : ChangeName
  state : ChangeState
  proposal : String?
  design : String?
  task_groups : ReadOnlyArray[TaskGroup]
  deltas : ReadOnlyArray[SpecModel]
} derive(Eq, Debug)

///|
/// The structured view of OpenSpec content.
pub struct OpenSpecView {
  specs : ReadOnlyArray[SpecModel]
  changes : ReadOnlyArray[Change]
} derive(Eq, Debug)

///|
fn[T] frozen(items : Array[T]) -> ReadOnlyArray[T] {
  ReadOnlyArray::from_array(items)
}

///|
fn heading(line : String) -> (Int32, String)? {
  let t = line.trim_start(chars=" ").to_owned()
  let mut level = 0
  while level < t.length() && t[level] == '#' {
    level += 1
  }
  if level == 0 || level > 6 || (level < t.length() && t[level] != ' ') {
    None
  } else {
    Some((level, t[level:].trim(chars=" \t").to_owned()))
  }
}

///|
fn after_prefix(text : String, prefix : String) -> String? {
  if text.has_prefix(prefix) {
    Some(text[prefix.length():].trim(chars=" \t").to_owned())
  } else {
    None
  }
}

///|
/// A clause bullet: `- **WHEN** text` gives ("WHEN", "text").
fn clause(line : String) -> (String, String)? {
  let t = line.trim(chars=" \t").to_owned()
  guard t.has_prefix("- **") || t.has_prefix("* **") else { return None }
  let rest = t[4:].to_owned()
  guard rest.find("**") is Some(end) else { return None }
  let word = rest[:end].trim_end(chars=":").to_owned().to_upper()
  Some((word, rest[end + 2:].trim_start(chars=": \t").to_owned()))
}

///|
fn delta_op(text : String) -> DeltaOp? {
  match text.to_upper() {
    "ADDED REQUIREMENTS" => Some(Added)
    "MODIFIED REQUIREMENTS" => Some(Modified)
    "REMOVED REQUIREMENTS" => Some(Removed)
    "RENAMED REQUIREMENTS" => Some(Renamed)
    _ => None
  }
}

///|
/// The name of a `Requirement: name` heading text. Backticks are part of the
/// name.
fn heading_requirement(text : String) -> RequirementName? {
  try RequirementName(text["Requirement:".length():].to_owned()) catch {
    _ => None
  } noraise {
    n => Some(n)
  }
}

///|
/// The requirement name of a `FROM:` or `TO:` line, which can wrap the
/// heading in backticks.
fn requirement_name(text : String) -> RequirementName? {
  let t = text.trim(chars=" \t`").to_owned()
  let name = match after_prefix(t, "### Requirement:") {
    Some(n) => n
    None => after_prefix(t, "Requirement:").unwrap_or(t)
  }
  try RequirementName(name) catch {
    _ => None
  } noraise {
    n => Some(n)
  }
}

///|
priv struct ScenarioBuilder {
  name : String
  when_ : Array[String]
  then_ : Array[String]
  line : Int32
}

///|
priv struct RequirementBuilder {
  name : RequirementName
  text : Array[String]
  scenarios : Array[Scenario]
  line : Int32
  mut text_line : Int32?
}

///|
priv struct DeltaBuilder {
  op : DeltaOp
  requirements : Array[Requirement]
  renames : Array[Rename]
  incomplete : Array[IncompleteRename]
  mut pending_from : (RequirementName, Int32)?
}

///|
fn DeltaBuilder::close_rename(self : DeltaBuilder) -> Unit {
  match self.pending_from {
    Some((from, line)) => self.incomplete.push(MissingTo(from~, line~))
    None => ()
  }
  self.pending_from = None
}

///|
fn DeltaBuilder::build(self : DeltaBuilder) -> DeltaSection {
  self.close_rename()
  {
    op: self.op,
    requirements: frozen(self.requirements),
    renames: frozen(self.renames),
    incomplete_renames: frozen(self.incomplete),
  }
}

///|
/// Parses an OpenSpec spec body (main or delta) from (file line, text) pairs.
/// A requirement heading without a name is not a requirement: its text and
/// scenarios belong to no requirement, and the model keeps its line.
pub fn parse_spec(
  capability : CapabilityPath,
  lines : ArrayView[(Int32, String)],
  dialects? : ArrayView[&@ears.Dialect],
) -> SpecModel {
  let default_dialects : Array[&@ears.Dialect] = [@ears.openspec_dialect()]
  let dialects = match dialects {
    Some(d) => d
    None => default_dialects[:]
  }
  let requirements : Array[Requirement] = []
  let unnamed : Array[Int32] = []
  let deltas : Array[DeltaBuilder] = []
  let mut purpose : String? = None
  let mut in_purpose = false
  let purpose_lines : Array[String] = []
  let mut current_delta : DeltaBuilder? = None
  let mut current_req : RequirementBuilder? = None
  let mut current_scenario : ScenarioBuilder? = None
  let mut last_clause = ""
  let flush_scenario = () => {
    match (current_scenario, current_req) {
      (Some(s), Some(r)) =>
        r.scenarios.push({
          name: s.name,
          when_: frozen(s.when_),
          then_: frozen(s.then_),
          line: s.line,
        })
      _ => ()
    }
    current_scenario = None
  }
  let flush_req = () => {
    flush_scenario()
    match current_req {
      Some(r) => {
        let text = r.text.join("\n").trim(chars="\n ").to_owned()
        let ears = @ears.parse_block(text, dialects~)
        let req : Requirement = {
          name: r.name,
          text,
          scenarios: frozen(r.scenarios),
          line: r.line,
          text_line: r.text_line,
          sentences: ears.requirements(),
          sentence_diagnostics: ears.diagnostics(),
        }
        match current_delta {
          Some(d) => d.requirements.push(req)
          None => requirements.push(req)
        }
      }
      None => ()
    }
    current_req = None
  }
  for pair in lines {
    let (number, line) = pair
    match heading(line) {
      Some((2, text)) => {
        flush_req()
        if in_purpose {
          purpose = Some(purpose_lines.join("\n").trim(chars="\n ").to_owned())
          in_purpose = false
        }
        match delta_op(text) {
          Some(op) => {
            let d : DeltaBuilder = {
              op,
              requirements: [],
              renames: [],
              incomplete: [],
              pending_from: None,
            }
            deltas.push(d)
            current_delta = Some(d)
          }
          None => {
            current_delta = None
            if text.to_lower() == "purpose" {
              in_purpose = true
            }
          }
        }
      }
      Some((3, text)) if text.has_prefix("Requirement:") => {
        flush_req()
        match heading_requirement(text) {
          Some(name) =>
            current_req = Some({
              name,
              text: [],
              scenarios: [],
              line: number,
              text_line: None,
            })
          None => unnamed.push(number)
        }
      }
      Some((4, text)) if text.has_prefix("Scenario:") => {
        flush_scenario()
        current_scenario = Some({
          name: text["Scenario:".length():].trim(chars=" \t").to_owned(),
          when_: [],
          then_: [],
          line: number,
        })
      }
      Some((1, _)) => flush_req()
      _ => {
        if in_purpose {
          purpose_lines.push(line)
          continue
        }
        match current_delta {
          Some(d) if d.op is Renamed => {
            let t = line.trim(chars=" \t-").to_owned()
            match after_prefix(t, "FROM:") {
              Some(from) =>
                match requirement_name(from) {
                  Some(name) => {
                    d.close_rename()
                    d.pending_from = Some((name, number))
                  }
                  None => ()
                }
              None =>
                match after_prefix(t, "TO:").bind(requirement_name) {
                  Some(to) =>
                    match d.pending_from {
                      Some((from, from_line)) => {
                        d.renames.push({ from, to, line: from_line, })
                        d.pending_from = None
                      }
                      None => d.incomplete.push(MissingFrom(to~, line=number))
                    }
                  None => ()
                }
            }
          }
          _ => ()
        }
        match current_scenario {
          Some(s) =>
            match clause(line) {
              Some((word, text)) => {
                let word = if word == "AND" { last_clause } else { word }
                if word == "WHEN" || word == "GIVEN" {
                  s.when_.push(text)
                  last_clause = "WHEN"
                } else if word == "THEN" {
                  s.then_.push(text)
                  last_clause = "THEN"
                }
              }
              None => ()
            }
          None =>
            match current_req {
              Some(r) => {
                if r.text_line is None && line.trim(chars=" \t").length() > 0 {
                  r.text_line = Some(number)
                }
                r.text.push(line)
              }
              None => ()
            }
        }
      }
    }
  }
  flush_req()
  if in_purpose {
    purpose = Some(purpose_lines.join("\n").trim(chars="\n ").to_owned())
  }
  {
    capability,
    purpose,
    requirements: frozen(requirements),
    deltas: frozen(deltas.map(d => d.build())),
    unnamed_requirements: frozen(unnamed),
  }
}

///|
/// Parses a `tasks.md` body from (file line, text) pairs.
pub fn parse_tasks(lines : ArrayView[(Int32, String)]) -> Array[TaskGroup] {
  let groups : Array[(String?, Array[Task])] = []
  for pair in lines {
    let (number, line) = pair
    match heading(line) {
      Some((2, text)) => groups.push((Some(text), []))
      _ => {
        let t = line.trim_start(chars=" \t").to_owned()
        guard t.length() > 6 &&
          (t.has_prefix("- [") || t.has_prefix("* [")) &&
          t[4] == ']' else {
          continue
        }
        let mark = t[3:4].to_owned()
        let done = mark.trim(chars=" ").to_lower() == "x"
        let rest = t[5:].trim(chars=" \t").to_owned()
        let (num, text) = match rest.find(" ") {
          Some(i) =>
            try TaskNumber(rest[:i].to_owned()) catch {
              _ => (None, rest)
            } noraise {
              n => (Some(n), rest[i + 1:].trim(chars=" \t").to_owned())
            }
          None => (None, rest)
        }
        let task : Task = { number: num, text, done, line: number, }
        match groups.last() {
          Some(g) => g.1.push(task)
          None => groups.push((None, [task]))
        }
      }
    }
  }
  groups.map(g => { heading: g.0, tasks: frozen(g.1), })
}

///|
pub extend Scenario with Eq::{not_equal, equal}

///|
pub extend Scenario with @debug.Debug::{to_repr}

///|
pub extend Requirement with Eq::{not_equal, equal}

///|
pub extend Requirement with @debug.Debug::{to_repr}

///|
pub extend DeltaOp with Eq::{not_equal, equal}

///|
pub extend DeltaOp with @debug.Debug::{to_repr}

///|
pub extend DeltaSection with Eq::{not_equal, equal}

///|
pub extend DeltaSection with @debug.Debug::{to_repr}

///|
pub extend SpecModel with Eq::{not_equal, equal}

///|
pub extend SpecModel with @debug.Debug::{to_repr}

///|
pub extend Task with Eq::{not_equal, equal}

///|
pub extend Task with @debug.Debug::{to_repr}

///|
pub extend TaskGroup with Eq::{not_equal, equal}

///|
pub extend TaskGroup with @debug.Debug::{to_repr}

///|
pub extend Change with Eq::{not_equal, equal}

///|
pub extend Change with @debug.Debug::{to_repr}

///|
pub extend OpenSpecView with Eq::{not_equal, equal}

///|
pub extend OpenSpecView with @debug.Debug::{to_repr}

///|
pub extend Rename with Eq::{not_equal, equal}

///|
pub extend Rename with @debug.Debug::{to_repr}

///|
pub extend IncompleteRename with Eq::{not_equal, equal}

///|
pub extend IncompleteRename with @debug.Debug::{to_repr}
