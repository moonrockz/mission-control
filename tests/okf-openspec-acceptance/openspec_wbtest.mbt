///|
/// Reads the files under `dir` (relative to the tests module) into a document
/// set, with paths that start with `prefix`.
fn read_tree(dir : String, prefix : String) -> @okf.DocumentSet raise {
  let entries = []
  fn walk(rel : String) raise {
    let full = if rel == "" { dir } else { dir + "/" + rel }
    let names = @fs.read_dir(full).to_owned()
    names.sort()
    for name in names {
      let child = if rel == "" { name } else { rel + "/" + name }
      if @fs.is_dir(dir + "/" + child) {
        walk(child)
      } else {
        entries.push(@okf.FileEntry::{
          path: @okf.StorePath(prefix + "/" + child),
          content: @okf.FileContent::Text(
            @fs.read_file_to_string(dir + "/" + child),
          ),
        })
      }
    }
  }
  walk("")
  @okf.DocumentSet(entries)
}

///|
fn repository_tree() -> @okf.DocumentSet raise {
  read_tree("../openspec", "openspec")
}

///|
fn profiles() -> Array[&@okf.Profile] {
  [@openspec.OpenSpecProfile::{ }]
}

///|
test "this repository's OpenSpec tree loads as a bundle" {
  let b = @okf.load_bundle(
    repository_tree(),
    root=@okf.StoreDir("openspec"),
    profiles=profiles(),
  )
  let v = @openspec.view(b)
  // The OKF change is archived under a dated name.
  guard v.changes
    .iter()
    .find_first(c => c.name.to_string().has_suffix("add-okf-module"))
    is Some(change) else {
    fail("no add-okf-module change")
  }
  assert_eq(change.state, Archived)
  let deltas = change.deltas.iter().map(d => d.capability.to_string()).collect()
  assert_true(deltas.contains("okf/documents"))
  assert_true(deltas.contains("okf/openspec"))
  assert_true(change.task_groups.length() >= 10)
  let providers = @openspec.CapabilityPath("okf/providers")
  guard v.specs.iter().find_first(s => s.capability == providers) is Some(p) else {
    fail("no providers spec")
  }
  assert_true(p.requirements.length() >= 13)
}

///|
test "the OpenSpec checks report nothing for this repository's tree" {
  let b = @okf.load_bundle(
    repository_tree(),
    root=@okf.StoreDir("openspec"),
    profiles=profiles(),
  )
  let report = @okf.validate(
    @okf.Knowledge([b]),
    [@okf.okf_v02_conformance()],
    @okf.FixedClock(@okf.Instant::of_millis(0L)),
    profiles=profiles(),
  )
  assert_eq(
    report
    .findings()
    .map(f => f.rule.to_string() + " " + f.subject.path_text().unwrap_or(""))
    .iter()
    .collect(),
    [],
  )
}

///|
test "importing and exporting this repository's tree keeps every file" {
  let original = repository_tree()
  let imported = @openspec.import_openspec(
    original,
    @okf.StoreDir("openspec"),
    @okf.StoreDir("kb"),
    @okf.LogDate("2026-10-23"),
  ).apply_to(@okf.DocumentSet([]))
  let native = @okf.load_bundle(imported, root=@okf.StoreDir("kb"))
  let tree = @okf.load_bundle(
    original,
    root=@okf.StoreDir("openspec"),
    profiles=profiles(),
  )
  assert_eq(
    @openspec.view(native).without_lines(),
    @openspec.view(tree).without_lines(),
  )
  let exported = @openspec.export_openspec(
    imported,
    @okf.StoreDir("kb"),
    @okf.StoreDir("openspec"),
  ).apply_to(@okf.DocumentSet([]))
  let keep = (set : @okf.DocumentSet) => {
    set
    .entries()
    .iter()
    .filter(e => !e.path.name().has_prefix("."))
    .map(e => (e.path.to_string(), e.content.text()))
    .collect()
  }
  assert_eq(keep(exported), keep(original))
}
