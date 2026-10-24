///|
/// A document store over a directory of the local file system, for the
/// native and wasm targets. Every path must resolve inside the root, following
/// symlinks; a path that leaves it is refused with `PermissionDenied`. Errors
/// name locations relative to the root, never host paths.
struct FsStore {
  root : @provider.StoreRoot
}

///|
/// A store rooted at the directory `root`.
pub fn FsStore::FsStore(root : @provider.StoreRoot) -> FsStore {
  { root, }
}

///|
pub fn FsStore::root(self : FsStore) -> @provider.StoreRoot {
  self.root
}

///|
fn FsStore::full(self : FsStore, segments : ArrayView[String]) -> String {
  if segments.is_empty() {
    self.root.to_string()
  } else {
    self.root.to_string() + "/" + segments.iter().collect().join("/")
  }
}

///|
fn FsStore::dir(self : FsStore, dir : @okf.StoreDir) -> String {
  self.full(dir.segments().iter().collect())
}

///|
fn FsStore::file(self : FsStore, path : @okf.StorePath) -> String {
  self.full(path.segments().iter().collect())
}

///|
/// A failure at `at`. The message has the root removed, so that it names no
/// host path.
fn FsStore::failed(
  self : FsStore,
  at : @provider.StoreLocation,
  error : Error,
) -> @provider.StoreError {
  let root = self.root.to_string()
  let message = error
    .to_string()
    .replace_all(old=root + "/", new="")
    .replace_all(old=root, new=".")
  Failed(at, message)
}

///|
async fn FsStore::exists(
  self : FsStore,
  at : @provider.StoreLocation,
  full : String,
) -> Bool raise @provider.StoreError {
  @fs.exists(full) catch {
    e => raise self.failed(at, e)
  }
}

///|
fn parent_of(path : String) -> String? {
  match path.rev_find("/") {
    Some(0) => Some("/")
    Some(i) => Some(path[:i].to_owned())
    None => None
  }
}

///|
/// The real path of the root.
async fn FsStore::real_root(
  self : FsStore,
) -> String raise @provider.StoreError {
  let at = @provider.StoreLocation::DirectoryAt(@okf.StoreDir::root())
  let root = self.root.to_string()
  if !self.exists(at, root) {
    raise NotFound(at)
  }
  @fs.realpath(root) catch {
    e => raise self.failed(at, e)
  }
}

///|
fn is_inside(real : String, root : String) -> Bool {
  real == root ||
  real.has_prefix(if root.has_suffix("/") { root } else { root + "/" })
}

///|
/// Refuses `full`, the host path of `at`, when it or its nearest existing
/// parent resolves outside the root after symlinks are followed.
async fn FsStore::confine(
  self : FsStore,
  at : @provider.StoreLocation,
  full : String,
) -> Unit raise @provider.StoreError {
  let root = self.real_root()
  let mut current = full
  while true {
    if self.exists(at, current) {
      let real = @fs.realpath(current) catch { e => raise self.failed(at, e) }
      if !is_inside(real, root) {
        raise PermissionDenied(at)
      }
      return
    }
    match parent_of(current) {
      Some(parent) if parent != current => current = parent
      _ => return
    }
  }
}

///|
pub impl @provider.DocumentStore for FsStore with fn list(self, dir) {
  let at = @provider.StoreLocation::DirectoryAt(dir)
  let full = self.dir(dir)
  if !self.exists(at, full) {
    raise NotFound(at)
  }
  self.confine(at, full)
  let root = self.real_root()
  let names = @fs.readdir(full, include_hidden=false, sort=true) catch {
    e => raise self.failed(at, e)
  }
  let out = []
  for name in names {
    // A host name that is not one valid segment is not part of the store.
    let entry = @okf.EntryName(name) catch { _ => continue }
    let child = full + "/" + name
    let child_at = @provider.StoreLocation::FileAt(dir.file(entry))
    let kind = @fs.kind(child, follow_symlink=false) catch {
      e => raise self.failed(child_at, e)
    }
    let kind = match kind {
      SymLink => {
        // A symlink is listed only when it resolves inside the root.
        guard self.exists(child_at, child) else { continue }
        let real = @fs.realpath(child) catch {
          e => raise self.failed(child_at, e)
        }
        guard is_inside(real, root) else { continue }
        @fs.kind(child) catch {
          e => raise self.failed(child_at, e)
        }
      }
      other => other
    }
    match kind {
      Directory =>
        out.push(@provider.StoreEntry::{ name: entry, kind: Directory, })
      Regular => out.push(@provider.StoreEntry::{ name: entry, kind: File, })
      _ => ()
    }
  }
  out.sort_by((a, b) => {
    @okf.lexical_compare(a.name.to_string(), b.name.to_string())
  })
  out
}

///|
pub impl @provider.DocumentStore for FsStore with fn read_text(self, path) {
  let at = @provider.StoreLocation::FileAt(path)
  let full = self.file(path)
  if !self.exists(at, full) {
    raise NotFound(at)
  }
  self.confine(at, full)
  let data = @fs.read_file(full) catch { e => raise self.failed(at, e) }
  data.text() catch {
    e => raise self.failed(at, e)
  }
}

///|
pub impl @provider.DocumentStore for FsStore with fn read_bytes(self, path) {
  let at = @provider.StoreLocation::FileAt(path)
  let full = self.file(path)
  if !self.exists(at, full) {
    raise NotFound(at)
  }
  self.confine(at, full)
  let data = @fs.read_file(full) catch { e => raise self.failed(at, e) }
  data.binary()
}

///|
async fn FsStore::prepare_write(
  self : FsStore,
  path : @okf.StorePath,
) -> String raise @provider.StoreError {
  let full = self.file(path)
  let parent = path.parent()
  if !parent.is_root() {
    let dir_at = @provider.StoreLocation::DirectoryAt(parent)
    let dir = self.dir(parent)
    self.confine(dir_at, dir)
    @fs.mkdir(dir, recursive=true, allow_exist=true) catch {
      e => raise self.failed(dir_at, e)
    }
  }
  self.confine(FileAt(path), full)
  full
}

///|
pub impl @provider.DocumentStore for FsStore with fn write_text(
  self,
  path,
  text,
) {
  let full = self.prepare_write(path)
  @fs.write_file(full, text, create_mode=CreateOrTruncate) catch {
    e => raise self.failed(FileAt(path), e)
  }
}

///|
pub impl @provider.DocumentStore for FsStore with fn write_bytes(
  self,
  path,
  bytes,
) {
  let full = self.prepare_write(path)
  @fs.write_file(full, bytes, create_mode=CreateOrTruncate) catch {
    e => raise self.failed(FileAt(path), e)
  }
}

///|
pub impl @provider.DocumentStore for FsStore with fn delete(self, path) {
  let at = @provider.StoreLocation::FileAt(path)
  let full = self.file(path)
  // Deleting a symlink removes the link, so only its directory must be inside.
  match parent_of(full) {
    Some(parent) => self.confine(at, parent)
    None => ()
  }
  let present = self.exists(at, full) ||
    (@fs.kind(full, follow_symlink=false) catch { _ => Unknown }) is SymLink
  if present {
    @fs.remove(full) catch {
      e => raise self.failed(at, e)
    }
  }
}

///|
pub impl @provider.DocumentStore for FsStore with fn modified(self, path) {
  let at = @provider.StoreLocation::FileAt(path)
  let full = self.file(path)
  if !self.exists(at, full) {
    raise NotFound(at)
  }
  self.confine(at, full)
  let (sec, nsec) = @fs.mtime(full) catch { e => raise self.failed(at, e) }
  Some(@okf.Instant::of_millis(sec * 1000L + (nsec / 1000000).to_int64()))
}

///|
pub extend FsStore with @provider.DocumentStore::{
  read_bytes,
  list,
  write_bytes,
  delete,
  modified,
  read_text,
  write_text,
}
