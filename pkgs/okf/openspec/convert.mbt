///|
/// Raised by the conversions between `openspec/` trees and native bundles.
pub(all) suberror ConvertError {
  /// A concept has a `capability`, `change` or `requirement` value that is not
  /// a valid name, so no safe path can be built from it.
  BadName(NameError)
  /// An index or log edit cannot apply.
  EditFailed(@edit.EditError)
} derive(Eq, Debug)

///|
/// The keys that import writes, in order, from the derived metadata.
let import_keys : Array[String] = [
  "type", "title", "description", "capability", "change", "state", "heading",
]

///|
fn description_of(doc : @okf.Document) -> String? {
  // The first paragraph line of `## Purpose` or `## Why`, else none.
  let lines = doc.prose_lines()
  let mut in_section = false
  for pair in lines {
    match heading(pair.1) {
      Some((2, text)) => in_section = text == "Purpose" || text == "Why"
      Some(_) => if in_section { break }
      None =>
        if in_section {
          let t = pair.1.trim(chars=" \t").to_owned()
          if t.length() > 0 && !t.has_prefix("<!--") {
            return Some(t)
          }
        }
    }
  }
  None
}

///|
/// The asset copies of a bundle into `target_root`.
fn asset_changes(
  set : @okf.DocumentSet,
  bundle : @okf.Bundle,
  target_root : @okf.StoreDir,
) -> Array[@edit.FileChange] {
  let out = []
  for asset in bundle.assets() {
    match set.get(bundle.store_path_of(asset)) {
      Some(entry) => {
        let path = target_root.resolve(asset)
        out.push(
          match entry.content {
            Bytes(bytes) => @edit.FileChange::CreateBinary(path~, bytes~)
            Text(text) => @edit.FileChange::Create(path~, text~)
          },
        )
      }
      None => ()
    }
  }
  out
}

///|
/// Plans the import of the `openspec/` tree at `source_root` of `set` into a
/// native OKF bundle at `target_root`: one concept for each specification,
/// change, design, task list and spec delta, with frontmatter and the
/// original body, plus a root `index.md` and a `log.md` dated `date`. Other
/// files, such as `.openspec.yaml`, are copied as assets.
pub fn import_openspec(
  set : @okf.DocumentSet,
  source_root : @okf.StoreDir,
  target_root : @okf.StoreDir,
  date : @okf.LogDate,
) -> @edit.EditPlan raise ConvertError {
  let profile : &@okf.Profile = OpenSpecProfile::{ }
  let bundle = @okf.load_bundle(set, root=source_root, profiles=[profile])
  let changes = []
  let entries : Array[(String, String, String, String?)] = []
  for doc in bundle.documents() {
    guard doc.is_derived() else { continue }
    let meta = doc.metadata()
    let lines = ["---"]
    for key in import_keys {
      let value = if key == "description" {
        description_of(doc)
      } else {
        meta.text(key)
      }
      match value {
        Some(v) => lines.push("\{key}: \{@edit.yaml_scalar(v)}")
        None => ()
      }
    }
    lines.push("---")
    let text = lines.join("\n") + "\n" + doc.text()
    changes.push(
      @edit.FileChange::Create(path=target_root.resolve(doc.path()), text~),
    )
    entries.push(
      (
        meta.concept_type().map(t => t.to_string()).unwrap_or(""),
        doc.display_title(),
        doc.path().to_string(),
        description_of(doc),
      ),
    )
  }
  for change in asset_changes(set, bundle, target_root) {
    changes.push(change)
  }
  let index = index_text(entries) catch { e => raise EditFailed(e) }
  changes.push(
    @edit.FileChange::Create(
      path=target_root.resolve(@okf.BundlePath::root_index()),
      text=index,
    ),
  )
  changes.push(
    @edit.FileChange::Create(
      path=target_root.resolve(@okf.BundlePath::root_log()),
      text="# Log\n\n## \{date}\n\n* **Creation**: Imported from OpenSpec.\n",
    ),
  )
  @edit.EditPlan(changes)
}

///|
fn index_text(
  entries : Array[(String, String, String, String?)],
) -> String raise @edit.EditError {
  let types = []
  for e in entries {
    if !types.contains(e.0) {
      types.push(e.0)
    }
  }
  types.sort_by(@okf.lexical_compare)
  let out = ["---", "okf_version: \"0.2\"", "---", ""]
  for t in types {
    out.push("# \{t}")
    out.push("")
    let items = entries.iter().filter(e => e.0 == t).collect()
    items.sort_by((a, b) => @okf.lexical_compare(a.2, b.2))
    for e in items {
      out.push(@edit.index_entry_line(e.1, e.2, description?=e.3))
    }
    out.push("")
  }
  out.join("\n")
}

///|
/// The bundle path of an OpenSpec file for a native concept, from its type
/// and its names. A concept without a name that its type needs has no path;
/// a name that is not valid raises `BadName`.
fn export_path(doc : @okf.Document) -> @okf.BundlePath? raise ConvertError {
  guard type_of(doc) is Some(t) else { return None }
  let meta = doc.metadata()
  let capability = match meta.text("capability") {
    Some(c) => Some(CapabilityPath(c) catch { e => raise BadName(e) })
    None => None
  }
  let change_dir = match meta.text("change") {
    Some(c) => {
      let c = ChangeName(c) catch { e => raise BadName(e) }
      Some(
        if meta.text("state").bind(ChangeState::parse) is Some(Archived) {
          "changes/archive/\{c}"
        } else {
          "changes/\{c}"
        },
      )
    }
    None => None
  }
  let text = match t {
    Specification => capability.map(c => "specs/\{c}/spec.md")
    ChangeProposal => change_dir.map(d => d + "/proposal.md")
    Design => change_dir.map(d => d + "/design.md")
    TaskList => change_dir.map(d => d + "/tasks.md")
    SpecDelta =>
      match (change_dir, capability) {
        (Some(d), Some(c)) => Some("\{d}/specs/\{c}/spec.md")
        _ => None
      }
    RequirementConcept | ScenarioConcept => None
  }
  // Safe names give paths that stay inside the bundle.
  text.bind(t => {
    try @okf.BundlePath(t) catch {
      _ => None
    } noraise {
      p => Some(p)
    }
  })
}

///|
/// Plans the export of the native OKF bundle at `source_root` of `set` into an
/// `openspec/` tree at `target_root`. Each OpenSpec concept becomes its file
/// without frontmatter; Requirement and Scenario concepts merge into their
/// capability spec, in order. Assets are copied; `index.md` and `log.md` are not.
pub fn export_openspec(
  set : @okf.DocumentSet,
  source_root : @okf.StoreDir,
  target_root : @okf.StoreDir,
) -> @edit.EditPlan raise ConvertError {
  let bundle = @okf.load_bundle(set, root=source_root)
  let changes = []
  let requirements = of_type(bundle, RequirementConcept)
  let scenarios = of_type(bundle, ScenarioConcept)
  for doc in bundle.concepts() {
    guard export_path(doc) is Some(rel) else { continue }
    let mut text = doc.body()
    if type_of(doc) is Some(Specification) {
      let cap = capability_of(doc)
      let extra = []
      for r in requirements {
        guard capability_of(r) == cap else { continue }
        guard requirement_of(r, "requirement") is Some(name) else { continue }
        extra.push(
          "### Requirement: \{name}\n" +
          r.body().trim_end(chars="\n").to_owned() +
          "\n",
        )
        for s in scenarios {
          if capability_of(s) == cap &&
            requirement_of(s, "requirement") == Some(name) {
            let sname = s
              .metadata()
              .text("scenario")
              .unwrap_or(s.display_title())
            extra.push(
              "#### Scenario: \{sname}\n" +
              s.body().trim_end(chars="\n").to_owned() +
              "\n",
            )
          }
        }
      }
      if !extra.is_empty() {
        let base = text.trim_end(chars="\n").to_owned()
        let needs_heading = !base.contains("## Requirements")
        text = base +
          "\n\n" +
          (if needs_heading { "## Requirements\n\n" } else { "" }) +
          extra.join("\n")
      }
    }
    changes.push(@edit.FileChange::Create(path=target_root.resolve(rel), text~))
  }
  for change in asset_changes(set, bundle, target_root) {
    changes.push(change)
  }
  @edit.EditPlan(changes)
}

///|
pub extend ConvertError with Eq::{not_equal, equal}

///|
pub extend ConvertError with @debug.Debug::{to_repr}
