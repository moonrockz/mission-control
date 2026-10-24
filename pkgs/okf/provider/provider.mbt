///|
/// Whether a store entry is a file or a directory.
pub(all) enum EntryKind {
  File
  Directory
} derive(Eq, Debug)

///|
/// One entry of a directory listing.
pub(all) struct StoreEntry {
  name : @okf.EntryName
  kind : EntryKind
} derive(Eq, Debug)

///|
/// Where a store error happened, relative to the store root. A store error
/// never names a host path.
pub(all) enum StoreLocation {
  FileAt(@okf.StorePath)
  DirectoryAt(@okf.StoreDir)
} derive(Eq, Debug)

///|
pub fn StoreLocation::to_string(self : StoreLocation) -> String {
  match self {
    FileAt(path) => path.to_string()
    DirectoryAt(dir) => if dir.is_root() { "." } else { dir.to_string() }
  }
}

///|
pub impl Show for StoreLocation with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
/// Raised by a document store.
pub(all) suberror StoreError {
  /// The file or directory does not exist.
  NotFound(StoreLocation)
  /// The store does not allow the operation at the location.
  PermissionDenied(StoreLocation)
  /// A path text that is not valid for the store, for example because it
  /// escapes the root.
  InvalidPath(String)
  /// Any other failure, with the location and a message.
  Failed(StoreLocation, String)
} derive(Eq, Debug)

///|
/// The root of a store, such as a host directory or a browser directory name.
/// It is not blank.
struct StoreRoot {
  text : String
} derive(Eq, Hash, Debug)

///|
/// Raised when a store root breaks its rule.
pub(all) suberror RootError {
  /// The root is empty or only white space.
  BlankRoot(String)
} derive(Eq, Debug)

///|
/// Checks a store root. A trailing `/` is removed, except from `/` itself.
pub fn StoreRoot::StoreRoot(text : String) -> StoreRoot raise RootError {
  if text.trim(chars=" \t").length() == 0 {
    raise BlankRoot(text)
  }
  let text = if text.length() > 1 && text.has_suffix("/") {
    text[:text.length() - 1].to_owned()
  } else {
    text
  }
  { text, }
}

///|
pub fn StoreRoot::to_string(self : StoreRoot) -> String {
  self.text
}

///|
pub impl Show for StoreRoot with fn output(self, logger) {
  logger.write_string(self.text)
}

///|
/// Reads and writes documents. Paths are relative to the root of the store and
/// never escape it. Implementations must list entries in a stable order.
pub(open) trait DocumentStore {
  /// The entries of a directory.
  async fn list(Self, @okf.StoreDir) -> Array[StoreEntry] raise StoreError
  async fn read_text(Self, @okf.StorePath) -> String raise StoreError
  async fn read_bytes(Self, @okf.StorePath) -> Bytes raise StoreError
  /// Writes text, and creates missing parent directories.
  async fn write_text(Self, @okf.StorePath, String) -> Unit raise StoreError
  /// Writes bytes, and creates missing parent directories.
  async fn write_bytes(Self, @okf.StorePath, Bytes) -> Unit raise StoreError
  /// Deletes a file. Deleting a missing file is not an error.
  async fn delete(Self, @okf.StorePath) -> Unit raise StoreError
  /// The modification time of a file, when the store knows it.
  async fn modified(Self, @okf.StorePath) -> @okf.Instant? raise StoreError
}

///|
/// Validates a path for a store: `/` and `\` are both separators, and a path
/// that escapes the root is refused.
pub fn safe_path(text : String) -> @okf.StorePath raise StoreError {
  @okf.StorePath(text) catch {
    _ => raise InvalidPath(text)
  }
}

///|
/// Reads every file under `under` into a document set. Markdown files are read
/// as text and other files as bytes; `assets=false` leaves other files out.
pub async fn load_set(
  store : &DocumentStore,
  under~ : @okf.StoreDir = @okf.StoreDir::root(),
  assets~ : Bool = true,
) -> @okf.DocumentSet raise StoreError {
  let entries : Array[@okf.FileEntry] = []
  async fn walk(dir : @okf.StoreDir) -> Unit raise StoreError {
    for entry in store.list(dir) {
      match entry.kind {
        Directory => walk(dir.child(entry.name))
        File => {
          let path = dir.file(entry.name)
          if @okf.is_markdown_name(entry.name.to_string()) {
            entries.push({ path, content: Text(store.read_text(path)), })
          } else if assets {
            entries.push({ path, content: Bytes(store.read_bytes(path)), })
          }
        }
      }
    }
  }
  walk(under)
  @okf.DocumentSet(entries)
}

///|
/// Discovers the bundles under `under` in a store.
pub async fn load(
  store : &DocumentStore,
  under~ : @okf.StoreDir = @okf.StoreDir::root(),
  options~ : @okf.Options = @okf.Options::default(),
  profiles~ : ArrayView[&@okf.Profile] = [],
) -> @okf.Knowledge raise StoreError {
  let set = load_set(store, under~)
  @okf.discover(set, under~, options~, profiles~)
}

///|
/// Loads the bundle at `root` in a store.
pub async fn load_bundle(
  store : &DocumentStore,
  root~ : @okf.StoreDir = @okf.StoreDir::root(),
  options~ : @okf.Options = @okf.Options::default(),
  profiles~ : ArrayView[&@okf.Profile] = [],
) -> @okf.Bundle raise StoreError {
  let set = load_set(store, under=root)
  @okf.load_bundle(set, root~, options~, profiles~)
}

///|
/// Writes each change of a plan to a store and returns the number of writes
/// and deletes. A plan never holds an update that changes nothing.
pub async fn apply(
  plan : @edit.EditPlan,
  store : &DocumentStore,
) -> Int32 raise StoreError {
  let mut count = 0
  for change in plan.changes() {
    match change {
      Create(path~, text~) | Update(path~, after=text, ..) =>
        store.write_text(path, text)
      CreateBinary(path~, bytes~) => store.write_bytes(path, bytes)
      Delete(path~) => store.delete(path)
    }
    count += 1
  }
  count
}

///|
/// Whether a derived index matches the knowledge it was built from.
pub(all) enum IndexStatus {
  /// The index was never built.
  Missing
  Fresh
  /// The index differs from the knowledge, with a reason.
  Stale(String)
} derive(Eq, Debug)

///|
/// The metadata that an index records at build time: a schema version of at
/// least 1 and a document count of at least 0.
pub struct IndexMetadata {
  schema_version : Int32
  built_at : @okf.Instant
  document_count : Int32
} derive(Eq, Debug)

///|
/// Checks index metadata. Raises `InvalidMetadata` for a schema version below
/// 1 or a negative document count.
pub fn IndexMetadata::IndexMetadata(
  schema_version~ : Int32,
  built_at~ : @okf.Instant,
  document_count~ : Int32,
) -> IndexMetadata raise IndexError {
  if schema_version < 1 || document_count < 0 {
    raise InvalidMetadata(schema_version~, document_count~)
  }
  { schema_version, built_at, document_count, }
}

///|
/// Raised by index and search providers.
pub(all) suberror IndexError {
  /// The index was never built.
  NotBuilt
  /// Index metadata with a schema version below 1 or a negative document count.
  InvalidMetadata(schema_version~ : Int32, document_count~ : Int32)
  /// Any other failure.
  IndexFailed(String)
} derive(Eq, Debug)

///|
/// A derived index over loaded knowledge. An implementation can keep it in
/// memory, or in a database such as SQLite or RocksDB.
pub(open) trait IndexProvider {
  /// Builds the index from the knowledge, recording the instant of `clock`.
  async fn build(Self, @okf.Knowledge, &@okf.Clock) -> IndexMetadata raise IndexError
  /// Compares the index with the knowledge.
  async fn status(Self, @okf.Knowledge) -> IndexStatus raise IndexError
  /// The metadata of the last build.
  async fn metadata(Self) -> IndexMetadata? raise IndexError
  /// The concepts that match every filter.
  async fn documents(Self, ArrayView[@okf.Filter]) -> Array[@okf.DocKey] raise IndexError
  /// The values of a facet with their counts.
  async fn facet(Self, @okf.Facet) -> Array[(String, Int32)] raise IndexError
  /// The links from a document.
  async fn links_from(Self, @okf.DocKey) -> Array[@okf.Edge] raise IndexError
  /// The resolved links to a document.
  async fn backlinks(Self, @okf.DocKey) -> Array[@okf.Edge] raise IndexError
  /// The outline of a document.
  async fn headings(Self, @okf.DocKey) -> Array[@okf.Heading] raise IndexError
  /// The `sources` of a document.
  async fn sources(Self, @okf.DocKey) -> Array[@okf.Source] raise IndexError
}

///|
/// Ranked search over an index.
pub(open) trait SearchProvider {
  async fn search(Self, @okf.SearchRequest) -> Array[@okf.SearchHit] raise IndexError
}

///|
/// A fingerprint of the documents of the knowledge, to detect changes.
pub fn fingerprint(knowledge : @okf.Knowledge) -> Map[@okf.DocKey, Int32] {
  let out : Map[@okf.DocKey, Int32] = Map([])
  for pair in knowledge.documents() {
    out[@okf.DocKey::of(pair.0, pair.1)] = pair.1.text().hash()
  }
  out
}

///|
pub extend EntryKind with Eq::{not_equal, equal}

///|
pub extend EntryKind with @debug.Debug::{to_repr}

///|
pub extend StoreEntry with Eq::{not_equal, equal}

///|
pub extend StoreEntry with @debug.Debug::{to_repr}

///|
pub extend StoreError with Eq::{not_equal, equal}

///|
pub extend StoreError with @debug.Debug::{to_repr}

///|
pub extend IndexStatus with Eq::{not_equal, equal}

///|
pub extend IndexStatus with @debug.Debug::{to_repr}

///|
pub extend IndexMetadata with Eq::{not_equal, equal}

///|
pub extend IndexMetadata with @debug.Debug::{to_repr}

///|
pub extend IndexError with Eq::{not_equal, equal}

///|
pub extend IndexError with @debug.Debug::{to_repr}

///|
pub extend StoreLocation with Eq::{not_equal, equal}

///|
pub extend StoreLocation with @debug.Debug::{to_repr}

///|
pub extend StoreLocation with Show::{output}

///|
pub extend StoreRoot with Eq::{not_equal, equal}

///|
pub extend StoreRoot with Hash::{hash, hash_combine}

///|
pub extend StoreRoot with @debug.Debug::{to_repr}

///|
pub extend RootError with Eq::{not_equal, equal}

///|
pub extend RootError with @debug.Debug::{to_repr}

///|
pub extend StoreRoot with Show::{output}
