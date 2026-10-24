///|
/// The result of a lookup that can match nothing, one item or several items.
pub(all) enum Lookup[T] {
  NotFound
  Found(T)
  Ambiguous(ReadOnlyArray[T])
} derive(Eq, Debug)

///|
pub fn[T] Lookup::to_option(self : Lookup[T]) -> T? {
  match self {
    Found(x) => Some(x)
    _ => None
  }
}

///|
fn[T] lookup_of(items : Array[T]) -> Lookup[T] {
  match items {
    [] => NotFound
    [x] => Found(x)
    _ => Ambiguous(ReadOnlyArray::from_array(items))
  }
}

///|
/// A set of bundles found under one directory, and the Markdown files that
/// belong to no bundle.
struct Knowledge {
  bundles : ReadOnlyArray[Bundle]
  strays : ReadOnlyArray[StorePath]
  options : Options
}

///|
/// Knowledge with the given bundles.
pub fn Knowledge::Knowledge(
  bundles : ArrayView[Bundle],
  strays~ : ArrayView[StorePath] = [],
  options~ : Options = Options::default(),
) -> Knowledge {
  {
    bundles: ReadOnlyArray::from_array(bundles.to_owned()),
    strays: ReadOnlyArray::from_array(strays.to_owned()),
    options,
  }
}

///|
/// Finds each bundle under the directory `under`: each directory whose
/// `index.md` frontmatter contains `okf_version`. It does not look for bundles
/// inside a bundle. Markdown files outside every bundle, except `README.md`,
/// are strays.
pub fn discover(
  set : DocumentSet,
  under~ : StoreDir = StoreDir::root(),
  options~ : Options = Options::default(),
  profiles~ : ArrayView[&Profile] = [],
) -> Knowledge {
  let roots : Array[StoreDir] = []
  for entry in set.entries() {
    guard under.contains(entry.path) else { continue }
    guard entry.path.name().to_lower() == "index.md" else { continue }
    let header = split_header(entry.content.text())
    let declares = match header.shape {
      Block(raw~) => scan_entries(raw).any(e => e.key == "okf_version")
      _ => false
    }
    if declares {
      roots.push(entry.path.parent())
    }
  }
  // Outer roots first, so that a bundle inside a bundle is skipped.
  roots.sort_by((a, b) => {
    let (la, lb) = (a.segments().length(), b.segments().length())
    if la != lb {
      la.compare(lb)
    } else {
      a.compare(b)
    }
  })
  let accepted : Array[StoreDir] = []
  for root in roots {
    if !accepted.any(outer => outer != root && outer.encloses(root)) {
      accepted.push(root)
    }
  }
  accepted.sort()
  let depth = under.segments().length()
  let bundles = accepted.map(root => {
    let segments = root.segments()
    // A bundle at the discovery root, or one level below it, has no group.
    let group = if segments.length() <= depth + 1 {
      []
    } else {
      segments.exact_view(start=depth, end=segments.length() - 1).to_owned()
    }
    let name = root.name().unwrap_or(".")
    load_bundle(
      set,
      root~,
      label=BundleLabel::of_parts(group, name),
      options~,
      profiles~,
    )
  })
  let strays = []
  for entry in set.entries() {
    guard under.contains(entry.path) else { continue }
    guard is_markdown_name(entry.path.name()) else { continue }
    guard entry.path.name().to_lower() != "readme.md" else { continue }
    if !accepted.any(root => root.contains(entry.path)) {
      strays.push(entry.path)
    }
  }
  Knowledge(bundles, strays~, options~)
}

///|
pub fn Knowledge::bundles(self : Knowledge) -> ReadOnlyArray[Bundle] {
  self.bundles
}

///|
pub fn Knowledge::strays(self : Knowledge) -> ReadOnlyArray[StorePath] {
  self.strays
}

///|
pub fn Knowledge::options(self : Knowledge) -> Options {
  self.options
}

///|
/// Finds a bundle by its full label, or by its name when the label is bare and
/// no bundle has it as a full label.
pub fn Knowledge::bundle(
  self : Knowledge,
  label : BundleLabel,
) -> Lookup[Bundle] {
  let exact = self.bundles.iter().filter(b => b.label() == label).collect()
  if !exact.is_empty() || !label.is_bare() {
    return lookup_of(exact)
  }
  lookup_of(self.bundles.iter().filter(b => b.name() == label.name()).collect())
}

///|
/// Every concept of every bundle, with its bundle.
pub fn Knowledge::concepts(self : Knowledge) -> Array[(Bundle, Document)] {
  let out = []
  for bundle in self.bundles {
    for doc in bundle.concepts() {
      out.push((bundle, doc))
    }
  }
  out
}

///|
/// Every document of every bundle, with its bundle.
pub fn Knowledge::documents(self : Knowledge) -> Array[(Bundle, Document)] {
  let out = []
  for bundle in self.bundles {
    for doc in bundle.documents() {
      out.push((bundle, doc))
    }
  }
  out
}

///|
/// The bundle that contains a store path, if any. The innermost bundle wins.
pub fn Knowledge::bundle_at(self : Knowledge, path : StorePath) -> Bundle? {
  let mut best : Bundle? = None
  for bundle in self.bundles {
    if bundle.root().contains(path) {
      match best {
        Some(b) if b.root().segments().length() >=
          bundle.root().segments().length() => ()
        _ => best = Some(bundle)
      }
    }
  }
  best
}

///|
/// The document at a store path, with its bundle.
pub fn Knowledge::document_at(
  self : Knowledge,
  path : StorePath,
) -> (Bundle, Document)? {
  match self.bundle_at(path) {
    Some(bundle) =>
      match bundle.bundle_path_of(path) {
        Some(rel) =>
          match bundle.document(rel) {
            Some(doc) => Some((bundle, doc))
            None => None
          }
        None => None
      }
    None => None
  }
}

///|
/// A document key: the bundle label and the bundle path.
pub(all) struct DocKey {
  bundle : BundleLabel
  path : BundlePath
} derive(Eq, Hash, Debug)

///|
pub impl Compare for DocKey with fn compare(self, other) {
  let c = self.bundle.compare(other.bundle)
  if c != 0 {
    c
  } else {
    self.path.compare(other.path)
  }
}

///|
pub fn DocKey::of(bundle : Bundle, doc : Document) -> DocKey {
  { bundle: bundle.label(), path: doc.path(), }
}

///|
pub fn DocKey::to_string(self : DocKey) -> String {
  self.bundle.to_string() + ":" + self.path.to_string()
}

///|
/// The document for a key. The bundle label must match exactly.
pub fn Knowledge::document(self : Knowledge, key : DocKey) -> Document? {
  match self.bundles.iter().find_first(b => b.label() == key.bundle) {
    Some(bundle) => bundle.document(key.path)
    None => None
  }
}

///|
pub extend Lookup with Eq::{not_equal, equal}

///|
pub extend Lookup with @debug.Debug::{to_repr}

///|
pub extend DocKey with Eq::{not_equal, equal}

///|

///|
pub extend DocKey with Hash::{hash, hash_combine}

///|
pub extend DocKey with @debug.Debug::{to_repr}

///|
pub extend DocKey with Compare::{op_lt, op_le, op_ge, compare, op_gt}
