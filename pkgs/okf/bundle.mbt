///|
/// An OKF bundle: a directory tree of Markdown documents and other files.
struct Bundle {
  root : StoreDir
  label : BundleLabel
  documents : ReadOnlyArray[Document]
  by_path : Map[BundlePath, Int32]
  assets : ReadOnlyArray[BundlePath]
  ignored_logs : ReadOnlyArray[BundlePath]
  options : Options
}

///|
/// Loads the bundle whose root is the directory `root` of a document set.
/// Each Markdown file under the root becomes a document; other files become
/// assets. Without `label`, the label is the name of the root directory, or
/// `.` for the store root.
pub fn load_bundle(
  set : DocumentSet,
  root~ : StoreDir = StoreDir::root(),
  label? : BundleLabel,
  options~ : Options = Options::default(),
  profiles~ : ArrayView[&Profile] = [],
) -> Bundle {
  let documents : Array[Document] = []
  let assets : Array[BundlePath] = []
  let ignored : Array[BundlePath] = []
  for entry in set.entries() {
    guard root.contains(entry.path) else { continue }
    let rel = entry.path
      .segments()
      .exact_view(start=root.segments().length())
      .to_owned()
    let path = BundlePath::of_segments(rel)
    if !is_markdown_name(path.name()) ||
      profiles.iter().any(p => p.treats_as_asset(path)) {
      assets.push(path)
      continue
    }
    if options.nested_logs is RootOnly &&
      kind_of(path) is Log &&
      path.depth() > 0 {
      ignored.push(path)
      continue
    }
    let doc = Document(path, entry.path, entry.content.text())
    let doc = if doc.has_frontmatter_block() {
      doc
    } else {
      match derive_with(profiles, doc) {
        Some(fields) => doc.with_derived(fields)
        None => doc
      }
    }
    documents.push(doc)
  }
  let by_path : Map[BundlePath, Int32] = Map([])
  for i, doc in documents {
    by_path[doc.path()] = i
  }
  let label = match label {
    Some(l) => l
    None => BundleLabel::of_parts([], root.name().unwrap_or("."))
  }
  {
    root,
    label,
    documents: ReadOnlyArray::from_array(documents),
    by_path,
    assets: ReadOnlyArray::from_array(assets),
    ignored_logs: ReadOnlyArray::from_array(ignored),
    options,
  }
}

///|
/// The store directory of the bundle root.
pub fn Bundle::root(self : Bundle) -> StoreDir {
  self.root
}

///|
/// The bundle label: its group and its name, such as `morphir/ir`.
pub fn Bundle::label(self : Bundle) -> BundleLabel {
  self.label
}

///|
/// The bundle name, the last segment of its label.
pub fn Bundle::name(self : Bundle) -> String {
  self.label.name()
}

///|
/// The grouping directories between the discovery root and the bundle.
pub fn Bundle::group(self : Bundle) -> ReadOnlyArray[String] {
  self.label.group()
}

///|
/// The options that the bundle was loaded with.
pub fn Bundle::options(self : Bundle) -> Options {
  self.options
}

///|
/// Every document, sorted by path.
pub fn Bundle::documents(self : Bundle) -> ReadOnlyArray[Document] {
  self.documents
}

///|
pub fn Bundle::concepts(self : Bundle) -> Array[Document] {
  self.documents.iter().filter(d => d.kind() is Concept).collect()
}

///|
/// The root index and the sub-indexes.
pub fn Bundle::indexes(self : Bundle) -> Array[Document] {
  self.documents.iter().filter(d => d.kind().is_index()).collect()
}

///|
pub fn Bundle::logs(self : Bundle) -> Array[Document] {
  self.documents.iter().filter(d => d.kind() is Log).collect()
}

///|
pub fn Bundle::root_index(self : Bundle) -> Document? {
  self.documents.iter().find_first(d => d.kind() is RootIndex)
}

///|
/// The bundle-root `log.md`.
pub fn Bundle::root_log(self : Bundle) -> Document? {
  self.documents
  .iter()
  .find_first(d => d.kind() is Log && d.path().depth() == 0)
}

///|
/// Non-Markdown files.
pub fn Bundle::assets(self : Bundle) -> ReadOnlyArray[BundlePath] {
  self.assets
}

///|
/// Nested `log.md` files that the `RootOnly` option left out.
pub fn Bundle::ignored_logs(self : Bundle) -> ReadOnlyArray[BundlePath] {
  self.ignored_logs
}

///|
pub fn Bundle::document(self : Bundle, path : BundlePath) -> Document? {
  match self.by_path.get(path) {
    Some(i) => Some(self.documents[i])
    None => None
  }
}

///|
/// The concept with this Concept ID.
pub fn Bundle::concept(self : Bundle, id : ConceptId) -> Document? {
  match self.document(id.to_path()) {
    Some(doc) if doc.kind() is Concept => Some(doc)
    _ => None
  }
}

///|
/// The root index frontmatter: `okf_version` and profile bundle keys.
pub fn Bundle::config(self : Bundle) -> Metadata {
  match self.root_index() {
    Some(doc) => doc.metadata()
    None => Metadata::empty()
  }
}

///|
/// The `okf_version` of the root index.
pub fn Bundle::okf_version(self : Bundle) -> OkfVersion? {
  self.config().text("okf_version").map(OkfVersion::parse)
}

///|
/// True when this library knows the declared OKF version, or none is declared.
pub fn Bundle::knows_version(self : Bundle) -> Bool {
  match self.okf_version() {
    Some(v) => v.is_known()
    None => true
  }
}

///|
/// The store path of a bundle path.
pub fn Bundle::store_path_of(self : Bundle, path : BundlePath) -> StorePath {
  let segments = self.root.segments().iter().collect()
  for s in path.segments() {
    segments.push(s)
  }
  StorePath::of_segments(segments)
}

///|
/// The bundle path of a store path, when it is inside this bundle.
pub fn Bundle::bundle_path_of(self : Bundle, path : StorePath) -> BundlePath? {
  if self.root.contains(path) {
    Some(
      BundlePath::of_segments(
        path
        .segments()
        .exact_view(start=self.root.segments().length())
        .to_owned(),
      ),
    )
  } else {
    None
  }
}
