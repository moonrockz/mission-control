///|
/// A `FileSystemDirectoryHandle` of the File System Access API.
#external
pub type DirectoryHandle

///|
/// The settled result of a browser call.
#external
priv type CallResult

///|
extern "js" fn CallResult::ok(self : CallResult) -> Bool =
  #| (r) => r.ok

///|
extern "js" fn CallResult::code(self : CallResult) -> String =
  #| (r) => r.code || ""

///|
extern "js" fn CallResult::message(self : CallResult) -> String =
  #| (r) => r.message || ""

///|
extern "js" fn CallResult::text(self : CallResult) -> String =
  #| (r) => r.value

///|
extern "js" fn CallResult::bytes(self : CallResult) -> Bytes =
  #| (r) => r.value

///|
extern "js" fn CallResult::number(self : CallResult) -> Double =
  #| (r) => r.value

///|
extern "js" fn CallResult::found(self : CallResult) -> Bool =
  #| (r) => !!r.found

///|
extern "js" fn CallResult::handle(self : CallResult) -> DirectoryHandle =
  #| (r) => r.value

///|
extern "js" fn browser_call(
  root : DirectoryHandle,
  op : String,
  path : String,
  text : String,
  bytes : Bytes,
) -> @js_async.Promise[CallResult] =
  #| (root, op, path, text, bytes) => (async () => {
  #|   try {
  #|     const parts = path === "" ? [] : path.split("/");
  #|     const dirOf = async (segs, create) => {
  #|       let d = root;
  #|       for (const s of segs) d = await d.getDirectoryHandle(s, { create });
  #|       return d;
  #|     };
  #|     const parent = () => parts.slice(0, -1);
  #|     const name = () => parts[parts.length - 1];
  #|     switch (op) {
  #|       case "list": {
  #|         const d = await dirOf(parts, false);
  #|         const out = [];
  #|         for await (const [n, h] of d.entries()) out.push((h.kind === "directory" ? "d\t" : "f\t") + n);
  #|         return { ok: true, value: out.join("\u0000") };
  #|       }
  #|       case "readText": {
  #|         const fh = await (await dirOf(parent(), false)).getFileHandle(name());
  #|         return { ok: true, value: await (await fh.getFile()).text() };
  #|       }
  #|       case "readBytes": {
  #|         const fh = await (await dirOf(parent(), false)).getFileHandle(name());
  #|         return { ok: true, value: new Uint8Array(await (await fh.getFile()).arrayBuffer()) };
  #|       }
  #|       case "writeText":
  #|       case "writeBytes": {
  #|         const fh = await (await dirOf(parent(), true)).getFileHandle(name(), { create: true });
  #|         const w = await fh.createWritable();
  #|         await w.write(op === "writeText" ? text : bytes);
  #|         await w.close();
  #|         return { ok: true, value: null };
  #|       }
  #|       case "delete": {
  #|         try {
  #|           await (await dirOf(parent(), false)).removeEntry(name());
  #|         } catch (e) {
  #|           if (!e || (e.name !== "NotFoundError" && e.name !== "TypeMismatchError")) throw e;
  #|         }
  #|         return { ok: true, value: null };
  #|       }
  #|       case "openDir":
  #|         return { ok: true, value: await dirOf(parts, true) };
  #|       case "mtime": {
  #|         const fh = await (await dirOf(parent(), false)).getFileHandle(name());
  #|         return { ok: true, value: (await fh.getFile()).lastModified };
  #|       }
  #|     }
  #|     return { ok: false, code: "TypeError", message: "unknown operation " + op };
  #|   } catch (e) {
  #|     return { ok: false, code: (e && e.name) || "", message: String((e && e.message) || e) };
  #|   }
  #| })()

///|
extern "js" fn storage_root() -> @js_async.Promise[CallResult] =
  #| () => (async () => {
  #|   try {
  #|     return { ok: true, value: await globalThis.navigator.storage.getDirectory() };
  #|   } catch (e) {
  #|     return { ok: false, code: (e && e.name) || "", message: String((e && e.message) || e) };
  #|   }
  #| })()

///|
extern "js" fn picker() -> @js_async.Promise[CallResult] =
  #| () => (async () => {
  #|   try {
  #|     return { ok: true, value: await globalThis.showDirectoryPicker({ mode: "readwrite" }) };
  #|   } catch (e) {
  #|     return { ok: false, code: (e && e.name) || "", message: String((e && e.message) || e) };
  #|   }
  #| })()

///|
/// True when file handles have `createWritable()`. A stand-in handle says
/// whether it has one.
extern "js" fn has_create_writable(root : DirectoryHandle) -> Bool =
  #| (root) => {
  #|   if (root && typeof root.okfHasWritable === "boolean") return root.okfHasWritable;
  #|   return typeof globalThis.FileSystemFileHandle === "function" &&
  #|     typeof globalThis.FileSystemFileHandle.prototype.createWritable === "function";
  #| }

///|
/// True when this browser has `FileSystemFileHandle.createWritable()`.
pub extern "js" fn browser_has_create_writable() -> Bool =
  #| () => typeof globalThis.FileSystemFileHandle === "function" &&
  #|   typeof globalThis.FileSystemFileHandle.prototype.createWritable === "function"

///|
/// True when the handle is a stand-in with a sync writer in place of the worker.
extern "js" fn has_sync_writer(root : DirectoryHandle) -> Bool =
  #| (root) => !!(root && typeof root.okfSyncWriter === "function")

///|
/// The path of `root` below the origin private file system root, when `root`
/// is in that file system (`FileSystemDirectoryHandle.resolve`).
extern "js" fn origin_private_path(
  root : DirectoryHandle,
) -> @js_async.Promise[CallResult] =
  #| (root) => (async () => {
  #|   try {
  #|     const opfs = await globalThis.navigator.storage.getDirectory();
  #|     const parts = await opfs.resolve(root);
  #|     return parts === null ? { ok: true, found: false } : { ok: true, found: true, value: parts.join("/") };
  #|   } catch (e) {
  #|     return { ok: true, found: false };
  #|   }
  #| })()

///|
/// The code of the dedicated worker. It handles one write at a time. It opens
/// the origin private file system root itself, walks the segments, and
/// replaces the whole file in one sync access handle session: truncate, write,
/// flush and close. It closes the handle before it answers, so the page can
/// use the file at once. When a step fails, it closes the handle and removes a
/// file that it created.
let worker_code : String =
  #|let queue = Promise.resolve();
  #|const write = async ({ id, segments, name, kind, text, bytes }) => {
  #|  let dir = null;
  #|  let handle = null;
  #|  let existed = true;
  #|  try {
  #|    dir = await navigator.storage.getDirectory();
  #|    for (const s of segments) dir = await dir.getDirectoryHandle(s, { create: true });
  #|    try {
  #|      await dir.getFileHandle(name);
  #|    } catch (e) {
  #|      if (e && e.name === "NotFoundError") existed = false; else throw e;
  #|    }
  #|    const fh = await dir.getFileHandle(name, { create: true });
  #|    handle = await fh.createSyncAccessHandle();
  #|    const data = kind === "text" ? new TextEncoder().encode(text) : bytes;
  #|    await handle.truncate(0);
  #|    await handle.write(data, { at: 0 });
  #|    await handle.flush();
  #|    const done = handle;
  #|    handle = null;
  #|    await done.close();
  #|    self.postMessage({ id, ok: true, value: null });
  #|  } catch (e) {
  #|    if (handle) { try { await handle.close(); } catch (_) {} }
  #|    if (!existed && dir) { try { await dir.removeEntry(name); } catch (_) {} }
  #|    self.postMessage({ id, ok: false, code: (e && e.name) || "", message: String((e && e.message) || e) });
  #|  }
  #|};
  #|self.onmessage = (event) => { queue = queue.then(() => write(event.data)); };

///|
/// How long the page waits for one worker write, in milliseconds. A worker
/// that the browser stops sends no event, so a write that takes longer fails,
/// and the next write starts a new worker.
let worker_timeout_ms : Int32 = 120000

///|
/// Writes one file through the packaged worker, or through the sync writer of
/// a stand-in handle. The page starts the worker from a `blob:` URL at the
/// first worker write and reuses it. The worker is kept per worker code, so
/// two versions of this library on one page do not share a worker. A worker
/// that fails is stopped and forgotten, so the next write starts a new one.
extern "js" fn sync_write(
  root : DirectoryHandle,
  code : String,
  timeout_ms : Int32,
  segments : String,
  name : String,
  kind : String,
  text : String,
  bytes : Bytes,
) -> @js_async.Promise[CallResult] =
  #| (root, code, timeoutMs, segments, name, kind, text, bytes) => new Promise((resolve) => {
  #|   const segs = segments === "" ? [] : segments.split("/");
  #|   const failed = (e) => resolve({ ok: false, code: (e && e.name) || "", message: String((e && e.message) || e) });
  #|   if (root && typeof root.okfSyncWriter === "function") {
  #|     root.okfSyncWriter(segs, name, kind === "text" ? new TextEncoder().encode(text) : bytes)
  #|       .then(() => resolve({ ok: true, value: null }), failed);
  #|     return;
  #|   }
  #|   const csp = "a page with a Content Security Policy needs worker-src blob: for the write worker";
  #|   const g = globalThis;
  #|   const workers = g.okfSyncWorkers || (g.okfSyncWorkers = new Map());
  #|   let state = workers.get(code);
  #|   if (!state) {
  #|     let url = null;
  #|     try {
  #|       url = URL.createObjectURL(new Blob([code], { type: "text/javascript" }));
  #|       state = { worker: new Worker(url), url, pending: new Map(), next: 0 };
  #|     } catch (e) {
  #|       if (url) URL.revokeObjectURL(url);
  #|       resolve({ ok: false, code: (e && e.name) || "SecurityError", message: "cannot start the write worker: " + String((e && e.message) || e) + "; " + csp });
  #|       return;
  #|     }
  #|     const current = state;
  #|     const stop = (message) => {
  #|       for (const done of current.pending.values()) done({ ok: false, code: "WorkerError", message });
  #|       current.pending.clear();
  #|       current.worker.terminate();
  #|       URL.revokeObjectURL(current.url);
  #|       if (workers.get(code) === current) workers.delete(code);
  #|     };
  #|     current.stop = stop;
  #|     current.worker.onmessage = (event) => {
  #|       const done = current.pending.get(event.data.id);
  #|       if (done) { current.pending.delete(event.data.id); done(event.data); }
  #|     };
  #|     current.worker.onerror = (event) => {
  #|       if (event && event.preventDefault) event.preventDefault();
  #|       stop("the write worker failed or did not start (" + String((event && event.message) || "no detail") + "); " + csp);
  #|     };
  #|     current.worker.onmessageerror = () => stop("the write worker sent a message that cannot be read");
  #|     workers.set(code, current);
  #|   }
  #|   const current = state;
  #|   const id = ++current.next;
  #|   const timer = setTimeout(() => {
  #|     if (current.pending.has(id)) current.stop("the write worker did not answer within " + timeoutMs + " ms");
  #|   }, timeoutMs);
  #|   current.pending.set(id, (result) => { clearTimeout(timer); resolve(result); });
  #|   try {
  #|     current.worker.postMessage({ id, segments: segs, name, kind, text, bytes });
  #|   } catch (e) {
  #|     current.pending.delete(id);
  #|     clearTimeout(timer);
  #|     failed(e);
  #|   }
  #| })

///|
fn store_error(
  at : @provider.StoreLocation,
  result : CallResult,
) -> @provider.StoreError {
  match result.code() {
    "NotFoundError" | "TypeMismatchError" => NotFound(at)
    "NotAllowedError" | "SecurityError" | "NoModificationAllowedError" =>
      PermissionDenied(at)
    _ => Failed(at, result.message())
  }
}

///|
async fn settle(
  at : @provider.StoreLocation,
  promise : @js_async.Promise[CallResult],
) -> CallResult raise @provider.StoreError {
  let result = promise.wait() catch { e => raise Failed(at, e.to_string()) }
  if result.ok() {
    result
  } else {
    raise store_error(at, result)
  }
}

///|
/// The root of the origin private file system (`navigator.storage.getDirectory()`).
pub async fn origin_private_root() -> DirectoryHandle raise @provider.StoreError {
  settle(DirectoryAt(@okf.StoreDir::root()), storage_root()).handle()
}

///|
/// Asks the user to select a directory, with read and write access
/// (`showDirectoryPicker`). It needs a user gesture in the page.
pub async fn pick_directory() -> DirectoryHandle raise @provider.StoreError {
  settle(DirectoryAt(@okf.StoreDir::root()), picker()).handle()
}

///|
/// How a browser store writes files.
pub(all) enum WriteMethod {
  /// `createWritable()` when the browser has it, and the worker otherwise.
  Auto
  /// `FileSystemFileHandle.createWritable()` on the page.
  Writable
  /// A dedicated worker that writes with `createSyncAccessHandle()`. It needs
  /// a store on the origin private file system.
  SyncAccessWorker
} derive(Eq, Debug)

///|
/// The directory that the worker opens for a store.
priv enum WorkerRoot {
  /// A directory below the origin private file system root.
  OriginPrivate(@okf.StoreDir)
  /// A stand-in handle with a sync writer, for tests outside a browser.
  StandIn
}

///|
/// The write method that a store uses, once it is known.
priv enum Writer {
  UseWritable
  UseWorker(WorkerRoot)
}

///|
/// A main-thread operation of the store, converted to its JavaScript tag at
/// the FFI call only.
priv enum Op {
  List
  ReadText
  ReadBytes
  WriteText
  WriteBytes
  Delete
  Mtime
  OpenDir
}

///|
fn Op::tag(self : Op) -> String {
  match self {
    List => "list"
    ReadText => "readText"
    ReadBytes => "readBytes"
    WriteText => "writeText"
    WriteBytes => "writeBytes"
    Delete => "delete"
    Mtime => "mtime"
    OpenDir => "openDir"
  }
}

///|
/// A document store over a directory handle of the File System Access API.
/// The caller supplies the handle: the origin private file system root, or a
/// directory that the user selected. `origin_private` makes a store on a
/// directory below the origin private file system root.
struct BrowserStore {
  root : DirectoryHandle
  writes : WriteMethod
  /// The directory that the worker opens, when the store knows it.
  worker_root : WorkerRoot?
  /// The writer that the store chose at its first write.
  mut writer : Writer?
}

///|
/// A store over `root`. For worker writes, the store finds the path of `root`
/// below the origin private file system root at its first write. A directory
/// that the user selected is not in that file system, so worker writes to it
/// raise `InvalidPath`.
pub fn BrowserStore::BrowserStore(
  root : DirectoryHandle,
  writes~ : WriteMethod = Auto,
) -> BrowserStore {
  let worker_root = if has_sync_writer(root) { Some(StandIn) } else { None }
  { root, writes, worker_root, writer: None, }
}

///|
/// A store on the directory `path` below the origin private file system
/// root. It creates the directory when it is missing.
pub async fn BrowserStore::origin_private(
  path~ : @okf.StoreDir = @okf.StoreDir::root(),
  writes~ : WriteMethod = Auto,
) -> BrowserStore raise @provider.StoreError {
  let at = @provider.StoreLocation::DirectoryAt(path)
  let opfs = settle(at, storage_root()).handle()
  let root = settle(
    at,
    browser_call(opfs, OpenDir.tag(), path.to_string(), "", b""),
  ).handle()
  { root, writes, worker_root: Some(OriginPrivate(path)), writer: None, }
}

///|
/// The write method of the store.
pub fn BrowserStore::writes(self : BrowserStore) -> WriteMethod {
  self.writes
}

///|
async fn BrowserStore::call(
  self : BrowserStore,
  op : Op,
  at : @provider.StoreLocation,
  text~ : String = "",
  bytes~ : Bytes = b"",
) -> CallResult raise @provider.StoreError {
  let path = match at {
    FileAt(path) => path.to_string()
    DirectoryAt(dir) => dir.to_string()
  }
  settle(at, browser_call(self.root, op.tag(), path, text, bytes))
}

///|
/// Why a store refuses worker writes.
let worker_needs_origin_private : String = "worker writes need a directory in the origin private file system, and this handle is not in it; use createWritable() or a store from BrowserStore::origin_private"

///|
/// The writer that writes through the worker: the known worker directory, or
/// the path of the root below the origin private file system root.
async fn BrowserStore::worker_writer(
  self : BrowserStore,
  path : @okf.StorePath,
) -> Writer raise @provider.StoreError {
  match self.worker_root {
    Some(root) => return UseWorker(root)
    None => ()
  }
  let at = @provider.StoreLocation::FileAt(path)
  let found = settle(at, origin_private_path(self.root))
  guard found.found() else {
    raise InvalidPath("\{path}: \{worker_needs_origin_private}")
  }
  let dir = @okf.StoreDir(found.text()) catch {
    _ => raise InvalidPath("\{path}: \{worker_needs_origin_private}")
  }
  UseWorker(OriginPrivate(dir))
}

///|
/// The writer for the next write. The store chooses it once.
async fn BrowserStore::writer_for(
  self : BrowserStore,
  path : @okf.StorePath,
) -> Writer raise @provider.StoreError {
  match self.writer {
    Some(writer) => return writer
    None => ()
  }
  let writer = match self.writes {
    Writable => UseWritable
    SyncAccessWorker => self.worker_writer(path)
    Auto =>
      if has_create_writable(self.root) {
        UseWritable
      } else {
        self.worker_writer(path)
      }
  }
  self.writer = Some(writer)
  writer
}

///|
/// What a write puts in a file.
priv enum Content {
  TextContent(String)
  BytesContent(Bytes)
}

///|
/// Writes a file with the writer of the store.
async fn BrowserStore::write(
  self : BrowserStore,
  path : @okf.StorePath,
  content : Content,
) -> Unit raise @provider.StoreError {
  let at = @provider.StoreLocation::FileAt(path)
  match self.writer_for(path) {
    UseWritable =>
      match content {
        TextContent(text) => self.call(WriteText, at, text~) |> ignore
        BytesContent(bytes) => self.call(WriteBytes, at, bytes~) |> ignore
      }
    UseWorker(root) => {
      let segments = match root {
        OriginPrivate(dir) => {
          let all = dir.segments().iter().collect()
          for s in path.parent().segments() {
            all.push(s)
          }
          all
        }
        StandIn => path.parent().segments().iter().collect()
      }
      let (kind, text, bytes) = match content {
        TextContent(text) => ("text", text, b"")
        BytesContent(bytes) => ("bytes", "", bytes)
      }
      settle(
        at,
        sync_write(
          self.root,
          worker_code,
          worker_timeout_ms,
          segments.join("/"),
          path.name(),
          kind,
          text,
          bytes,
        ),
      )
      |> ignore
    }
  }
}

///|
pub impl @provider.DocumentStore for BrowserStore with fn list(self, dir) {
  let encoded = self.call(List, DirectoryAt(dir)).text()
  let out = []
  if encoded.length() > 0 {
    for item in encoded.split("\u0000") {
      let item = item.to_owned()
      let kind : @provider.EntryKind = if item.has_prefix("d\t") {
        Directory
      } else {
        File
      }
      // A browser name that is not one valid segment is not part of the store.
      let name = @okf.EntryName(item[2:].to_owned()) catch { _ => continue }
      out.push(@provider.StoreEntry::{ name, kind, })
    }
  }
  out.sort_by((a, b) => {
    @okf.lexical_compare(a.name.to_string(), b.name.to_string())
  })
  out
}

///|
pub impl @provider.DocumentStore for BrowserStore with fn read_text(self, path) {
  self.call(ReadText, FileAt(path)).text()
}

///|
pub impl @provider.DocumentStore for BrowserStore with fn read_bytes(self, path) {
  self.call(ReadBytes, FileAt(path)).bytes()
}

///|
pub impl @provider.DocumentStore for BrowserStore with fn write_text(
  self,
  path,
  text,
) {
  self.write(path, TextContent(text))
}

///|
pub impl @provider.DocumentStore for BrowserStore with fn write_bytes(
  self,
  path,
  bytes,
) {
  self.write(path, BytesContent(bytes))
}

///|
pub impl @provider.DocumentStore for BrowserStore with fn delete(self, path) {
  self.call(Delete, FileAt(path)) |> ignore
}

///|
pub impl @provider.DocumentStore for BrowserStore with fn modified(self, path) {
  let ms = self.call(Mtime, FileAt(path)).number()
  Some(@okf.Instant::of_millis(ms.to_int64()))
}

///|
pub extend BrowserStore with @provider.DocumentStore::{
  read_bytes,
  list,
  write_bytes,
  delete,
  modified,
  read_text,
  write_text,
}

///|
pub extend WriteMethod with Eq::{not_equal, equal}

///|
pub extend WriteMethod with @debug.Debug::{to_repr}
