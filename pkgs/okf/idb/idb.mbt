///|
/// A key-value adapter with `get`, `put`, `delete` and `keys`: IndexedDB, or
/// a map in memory for tests outside a browser.
#external
priv type Adapter

///|
/// The settled result of an adapter call.
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
extern "js" fn CallResult::adapter(self : CallResult) -> Adapter =
  #| (r) => r.value

///|
/// Opens or creates the database and its object store, and gives the
/// IndexedDB adapter. A database that lacks the object store is opened again
/// at the next version, which creates it.
extern "js" fn open_indexed_db(
  database : String,
  object_store : String,
) -> @js_async.Promise[CallResult] =
  #| (database, store) => new Promise((resolve) => {
  #|   const failed = (e) => resolve({ ok: false, code: (e && e.name) || "Error", message: String((e && e.message) || e) });
  #|   const adapter = (db) => {
  #|     const tx = (mode, act) => new Promise((done, fail) => {
  #|       const t = db.transaction(store, mode);
  #|       const req = act(t.objectStore(store));
  #|       let result;
  #|       if (req) req.onsuccess = () => { result = req.result; };
  #|       t.oncomplete = () => done(result);
  #|       t.onerror = () => fail(t.error);
  #|       t.onabort = () => fail(t.error || { name: "AbortError", message: "the transaction was aborted" });
  #|     });
  #|     return {
  #|       get: (key) => tx("readonly", (os) => os.get(key)),
  #|       put: (key, value) => tx("readwrite", (os) => os.put(value, key)),
  #|       delete: (key) => tx("readwrite", (os) => os.delete(key)),
  #|       keys: (lower, upper) => tx("readonly", (os) =>
  #|         os.getAllKeys(lower === null ? undefined : IDBKeyRange.bound(lower, upper, false, true))),
  #|     };
  #|   };
  #|   const open = (version) => {
  #|     let req;
  #|     try {
  #|       req = version === undefined ? globalThis.indexedDB.open(database) : globalThis.indexedDB.open(database, version);
  #|     } catch (e) {
  #|       failed(e);
  #|       return;
  #|     }
  #|     req.onupgradeneeded = () => {
  #|       const db = req.result;
  #|       if (!db.objectStoreNames.contains(store)) db.createObjectStore(store);
  #|     };
  #|     req.onblocked = () => failed({ name: "BlockedError", message: "another connection blocks the database" });
  #|     req.onerror = () => failed(req.error);
  #|     req.onsuccess = () => {
  #|       const db = req.result;
  #|       if (!db.objectStoreNames.contains(store)) {
  #|         const next = db.version + 1;
  #|         db.close();
  #|         open(next);
  #|         return;
  #|       }
  #|       db.onversionchange = () => db.close();
  #|       resolve({ ok: true, value: adapter(db) });
  #|     };
  #|   };
  #|   open(undefined);
  #| })

///|
/// An adapter over a map in memory. A write that would make the stored data
/// larger than `quota` bytes fails with `QuotaExceededError` and changes
/// nothing; a negative quota is no limit.
extern "js" fn memory_adapter(quota : Int32) -> Adapter =
  #| (quota) => {
  #|   const map = new Map();
  #|   const size = (r) => r.kind === "text" ? r.data.length * 2 : r.data.byteLength;
  #|   return {
  #|     get: async (key) => map.get(key),
  #|     put: async (key, value) => {
  #|       let total = size(value);
  #|       for (const [k, v] of map) if (k !== key) total += size(v);
  #|       if (quota >= 0 && total > quota) {
  #|         const e = new Error("the write needs " + total + " bytes and the quota is " + quota);
  #|         e.name = "QuotaExceededError";
  #|         throw e;
  #|       }
  #|       map.set(key, value);
  #|     },
  #|     delete: async (key) => { map.delete(key); },
  #|     keys: async (lower, upper) =>
  #|       [...map.keys()].filter((k) => lower === null || (k >= lower && k < upper)).sort(),
  #|   };
  #| }

///|
/// Runs one store operation on the adapter. Each write and delete is one
/// adapter call, so a failed operation changes nothing.
extern "js" fn idb_call(
  adapter : Adapter,
  op : String,
  key : String,
  text : String,
  bytes : Bytes,
  lower : String,
  upper : String,
) -> @js_async.Promise[CallResult] =
  #| (adapter, op, key, text, bytes, lower, upper) => (async () => {
  #|   const missing = () => { const e = new Error(key); e.name = "NotFoundError"; throw e; };
  #|   try {
  #|     switch (op) {
  #|       case "keys": {
  #|         const keys = await adapter.keys(lower === "" ? null : lower, upper);
  #|         return { ok: true, value: keys.join("\u0000") };
  #|       }
  #|       case "readText": {
  #|         const r = await adapter.get(key);
  #|         if (r === undefined) missing();
  #|         return { ok: true, value: r.kind === "text" ? r.data : new TextDecoder().decode(r.data) };
  #|       }
  #|       case "readBytes": {
  #|         const r = await adapter.get(key);
  #|         if (r === undefined) missing();
  #|         return { ok: true, value: r.kind === "bytes" ? new Uint8Array(r.data) : new TextEncoder().encode(r.data) };
  #|       }
  #|       case "mtime": {
  #|         const r = await adapter.get(key);
  #|         if (r === undefined) missing();
  #|         return { ok: true, value: r.modified };
  #|       }
  #|       case "writeText":
  #|         await adapter.put(key, { kind: "text", data: text, modified: Date.now() });
  #|         return { ok: true, value: null };
  #|       case "writeBytes":
  #|         await adapter.put(key, { kind: "bytes", data: new Uint8Array(bytes), modified: Date.now() });
  #|         return { ok: true, value: null };
  #|       case "delete":
  #|         await adapter.delete(key);
  #|         return { ok: true, value: null };
  #|     }
  #|     return { ok: false, code: "TypeError", message: "unknown operation " + op };
  #|   } catch (e) {
  #|     return { ok: false, code: (e && e.name) || "", message: String((e && e.message) || e) };
  #|   }
  #| })()

///|
/// A store operation, converted to its JavaScript tag at the FFI call only.
priv enum Op {
  Keys
  ReadText
  ReadBytes
  Mtime
  WriteText
  WriteBytes
  Delete
}

///|
fn Op::tag(self : Op) -> String {
  match self {
    Keys => "keys"
    ReadText => "readText"
    ReadBytes => "readBytes"
    Mtime => "mtime"
    WriteText => "writeText"
    WriteBytes => "writeBytes"
    Delete => "delete"
  }
}

///|
fn store_error(
  at : @provider.StoreLocation,
  result : CallResult,
) -> @provider.StoreError {
  match result.code() {
    "NotFoundError" => NotFound(at)
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
/// A document store that keeps each file in one IndexedDB record, under its
/// store path. Directories follow from the paths of the files: a directory
/// exists while a file is under it.
struct IdbStore {
  adapter : Adapter
}

///|
/// Opens or creates the database and the object store. A blocked or failed
/// open raises `Failed` for the root, with the database name.
pub async fn IdbStore::open(
  database~ : DatabaseName = DatabaseName::default(),
  object_store~ : ObjectStoreName = ObjectStoreName::default(),
) -> IdbStore raise @provider.StoreError {
  let at = @provider.StoreLocation::DirectoryAt(@okf.StoreDir::root())
  let result = open_indexed_db(database.to_string(), object_store.to_string()).wait() catch {
    e => raise Failed(at, "cannot open the database \{database}: \{e}")
  }
  guard result.ok() else {
    raise Failed(
      at,
      "cannot open the database \{database}: \{result.message()}",
    )
  }
  { adapter: result.adapter(), }
}

///|
/// A store over a map in memory, with the same listing and error logic, for
/// tests outside a browser. `quota_bytes` limits the stored data, as a browser
/// quota does; without it there is no limit.
pub fn IdbStore::in_memory(quota_bytes? : Int32) -> IdbStore {
  { adapter: memory_adapter(quota_bytes.unwrap_or(-1)), }
}

///|
async fn IdbStore::call(
  self : IdbStore,
  op : Op,
  at : @provider.StoreLocation,
  text~ : String = "",
  bytes~ : Bytes = b"",
  lower~ : String = "",
  upper~ : String = "",
) -> CallResult raise @provider.StoreError {
  let key = match at {
    FileAt(path) => path.to_string()
    DirectoryAt(dir) => dir.to_string()
  }
  settle(at, idb_call(self.adapter, op.tag(), key, text, bytes, lower, upper))
}

///|
pub impl @provider.DocumentStore for IdbStore with fn list(self, dir) {
  // The keys under `dir`: from `dir/` up to, but not including, `dir/￿`.
  let prefix = if dir.is_root() { "" } else { dir.to_string() + "/" }
  let (lower, upper) = if dir.is_root() {
    ("", "")
  } else {
    (prefix, prefix + "\u{FFFF}")
  }
  let encoded = self.call(Keys, DirectoryAt(dir), lower~, upper~).text()
  let out : Array[@provider.StoreEntry] = []
  let seen : Map[String, Bool] = Map([])
  if encoded.length() > 0 {
    for key in encoded.split("\u0000") {
      let rest = key[prefix.length():].to_owned()
      let (segment, kind) : (String, @provider.EntryKind) = match
        rest.find("/") {
        Some(i) => (rest[:i].to_owned(), Directory)
        None => (rest, File)
      }
      guard !seen.contains(segment) else { continue }
      seen[segment] = true
      // A key segment that is not one valid entry name is not part of the store.
      let name = @okf.EntryName(segment) catch { _ => continue }
      out.push({ name, kind, })
    }
  }
  if out.is_empty() && !dir.is_root() {
    raise NotFound(DirectoryAt(dir))
  }
  out.sort_by((a, b) => {
    @okf.lexical_compare(a.name.to_string(), b.name.to_string())
  })
  out
}

///|
pub impl @provider.DocumentStore for IdbStore with fn read_text(self, path) {
  self.call(ReadText, FileAt(path)).text()
}

///|
pub impl @provider.DocumentStore for IdbStore with fn read_bytes(self, path) {
  self.call(ReadBytes, FileAt(path)).bytes()
}

///|
pub impl @provider.DocumentStore for IdbStore with fn write_text(
  self,
  path,
  text,
) {
  self.call(WriteText, FileAt(path), text~) |> ignore
}

///|
pub impl @provider.DocumentStore for IdbStore with fn write_bytes(
  self,
  path,
  bytes,
) {
  self.call(WriteBytes, FileAt(path), bytes~) |> ignore
}

///|
pub impl @provider.DocumentStore for IdbStore with fn delete(self, path) {
  self.call(Delete, FileAt(path)) |> ignore
}

///|
pub impl @provider.DocumentStore for IdbStore with fn modified(self, path) {
  let ms = self.call(Mtime, FileAt(path)).number()
  Some(@okf.Instant::of_millis(ms.to_int64()))
}

///|
pub extend IdbStore with @provider.DocumentStore::{
  read_bytes,
  list,
  write_bytes,
  delete,
  modified,
  read_text,
  write_text,
}
