///|
/// The settled result of a Node.js call: `ok`, an error `code` such as
/// `ENOENT`, a `message`, and a `value`.
#external
priv type NodeResult

///|
extern "js" fn NodeResult::ok(self : NodeResult) -> Bool =
  #| (r) => r.ok

///|
extern "js" fn NodeResult::code(self : NodeResult) -> String =
  #| (r) => r.code || ""

///|
extern "js" fn NodeResult::message(self : NodeResult) -> String =
  #| (r) => r.message || ""

///|
extern "js" fn NodeResult::text(self : NodeResult) -> String =
  #| (r) => r.value

///|
extern "js" fn NodeResult::bytes(self : NodeResult) -> Bytes =
  #| (r) => new Uint8Array(r.value.buffer, r.value.byteOffset, r.value.byteLength)

///|
extern "js" fn NodeResult::number(self : NodeResult) -> Double =
  #| (r) => r.value

///|
/// True when the runtime gives the Node.js file system API through
/// `process.getBuiltinModule` (Node.js 20.16 or later, Bun and Deno).
pub extern "js" fn node_available() -> Bool =
  #| () => !!(globalThis.process && typeof globalThis.process.getBuiltinModule === "function")

///|
extern "js" fn node_call(
  root : String,
  op : String,
  path : String,
  text : String,
  bytes : Bytes,
) -> @js_async.Promise[NodeResult] =
  #| (root, op, path, text, bytes) => (async () => {
  #|   try {
  #|     const fs = globalThis.process.getBuiltinModule("node:fs/promises");
  #|     const p = globalThis.process.getBuiltinModule("node:path");
  #|     if (op === "mkdtemp") {
  #|       const os = globalThis.process.getBuiltinModule("node:os");
  #|       return { ok: true, value: await fs.mkdtemp(p.join(os.tmpdir(), path)) };
  #|     }
  #|     if (op === "rmdir") {
  #|       await fs.rm(path, { recursive: true, force: true });
  #|       return { ok: true, value: null };
  #|     }
  #|     // Every path must resolve inside the store root, following symlinks.
  #|     const rootReal = await fs.realpath(root);
  #|     const inside = (r) => r === rootReal || r.startsWith(rootReal + p.sep);
  #|     const outside = (target) => {
  #|       const e = new Error("the path leaves the store root: " + target);
  #|       e.code = "EACCES";
  #|       return e;
  #|     };
  #|     const confine = async (target) => {
  #|       let cur = target;
  #|       for (;;) {
  #|         let real;
  #|         try {
  #|           real = await fs.realpath(cur);
  #|         } catch (e) {
  #|           if (e && e.code === "ENOENT") {
  #|             const parent = p.dirname(cur);
  #|             if (parent === cur) return;
  #|             cur = parent;
  #|             continue;
  #|           }
  #|           throw e;
  #|         }
  #|         if (!inside(real)) throw outside(target);
  #|         return;
  #|       }
  #|     };
  #|     switch (op) {
  #|       case "list": {
  #|         await confine(path);
  #|         const entries = await fs.readdir(path, { withFileTypes: true });
  #|         const out = [];
  #|         for (const e of entries) {
  #|           const child = p.join(path, e.name);
  #|           if (e.isSymbolicLink()) {
  #|             let real;
  #|             try { real = await fs.realpath(child); } catch (_) { continue; }
  #|             if (!inside(real)) continue;
  #|             const st = await fs.stat(child);
  #|             out.push((st.isDirectory() ? "d\t" : "f\t") + e.name);
  #|           } else if (e.isDirectory()) out.push("d\t" + e.name);
  #|           else if (e.isFile()) out.push("f\t" + e.name);
  #|         }
  #|         return { ok: true, value: out.join("\u0000") };
  #|       }
  #|       case "readText": await confine(path); return { ok: true, value: await fs.readFile(path, "utf8") };
  #|       case "readBytes": await confine(path); return { ok: true, value: await fs.readFile(path) };
  #|       case "writeText":
  #|       case "writeBytes":
  #|         await confine(p.dirname(path));
  #|         await fs.mkdir(p.dirname(path), { recursive: true });
  #|         await confine(path);
  #|         if (op === "writeText") await fs.writeFile(path, text, "utf8");
  #|         else await fs.writeFile(path, bytes);
  #|         return { ok: true, value: null };
  #|       case "delete":
  #|         // Deleting a symlink removes the link, so only its directory must be inside.
  #|         await confine(p.dirname(path));
  #|         try { await fs.unlink(path); } catch (e) { if (e.code !== "ENOENT") throw e; }
  #|         return { ok: true, value: null };
  #|       case "mtime": await confine(path); return { ok: true, value: (await fs.stat(path)).mtimeMs };
  #|     }
  #|     return { ok: false, code: "EINVAL", message: "unknown operation " + op };
  #|   } catch (e) {
  #|     return { ok: false, code: (e && e.code) || "", message: String(e && e.message || e) };
  #|   }
  #| })()

///|
async fn call(
  op : String,
  path : String,
  at~ : @provider.StoreLocation = DirectoryAt(@okf.StoreDir::root()),
  root~ : String = "",
  text~ : String = "",
  bytes~ : Bytes = b"",
) -> NodeResult raise @provider.StoreError {
  if !node_available() {
    raise Failed(
      at, "the Node.js file system API is not available; it needs Node.js 20.16 or later",
    )
  }
  let result = node_call(root, op, path, text, bytes).wait() catch {
    e => raise Failed(at, without_root(e.to_string(), root))
  }
  if result.ok() {
    return result
  }
  match result.code() {
    "ENOENT" | "ENOTDIR" => raise NotFound(at)
    "EACCES" | "EPERM" | "EROFS" => raise PermissionDenied(at)
    _ => raise Failed(at, without_root(result.message(), root))
  }
}

///|
/// A message with the root removed, so that it names no host path.
fn without_root(message : String, root : String) -> String {
  if root.length() == 0 {
    message
  } else {
    message.replace_all(old=root + "/", new="").replace_all(old=root, new=".")
  }
}

///|
/// A document store over a directory, through the Node.js file system API.
/// Errors name locations relative to the root, never host paths.
struct NodeStore {
  root : @provider.StoreRoot
}

///|
pub fn NodeStore::NodeStore(root : @provider.StoreRoot) -> NodeStore {
  { root, }
}

///|
pub fn NodeStore::root(self : NodeStore) -> @provider.StoreRoot {
  self.root
}

///|
fn NodeStore::full(self : NodeStore, segments : ArrayView[String]) -> String {
  if segments.is_empty() {
    self.root.to_string()
  } else {
    self.root.to_string() + "/" + segments.iter().collect().join("/")
  }
}

///|
/// Runs an operation on the file at `path`.
async fn NodeStore::on_file(
  self : NodeStore,
  op : String,
  path : @okf.StorePath,
  text~ : String = "",
  bytes~ : Bytes = b"",
) -> NodeResult raise @provider.StoreError {
  call(
    op,
    self.full(path.segments().iter().collect()),
    at=FileAt(path),
    root=self.root.to_string(),
    text~,
    bytes~,
  )
}

///|
pub impl @provider.DocumentStore for NodeStore with fn list(self, dir) {
  let encoded = call(
    "list",
    self.full(dir.segments().iter().collect()),
    at=DirectoryAt(dir),
    root=self.root.to_string(),
  ).text()
  let out = []
  if encoded.length() > 0 {
    for item in encoded.split("\u0000") {
      let item = item.to_owned()
      let kind : @provider.EntryKind = if item.has_prefix("d\t") {
        Directory
      } else {
        File
      }
      // A host name that is not one valid segment is not part of the store.
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
pub impl @provider.DocumentStore for NodeStore with fn read_text(self, path) {
  self.on_file("readText", path).text()
}

///|
pub impl @provider.DocumentStore for NodeStore with fn read_bytes(self, path) {
  self.on_file("readBytes", path).bytes()
}

///|
pub impl @provider.DocumentStore for NodeStore with fn write_text(
  self,
  path,
  text,
) {
  self.on_file("writeText", path, text~) |> ignore
}

///|
pub impl @provider.DocumentStore for NodeStore with fn write_bytes(
  self,
  path,
  bytes,
) {
  self.on_file("writeBytes", path, bytes~) |> ignore
}

///|
pub impl @provider.DocumentStore for NodeStore with fn delete(self, path) {
  self.on_file("delete", path) |> ignore
}

///|
pub impl @provider.DocumentStore for NodeStore with fn modified(self, path) {
  let ms = self.on_file("mtime", path).number()
  Some(@okf.Instant::of_millis(ms.to_int64()))
}

///|
pub extend NodeStore with @provider.DocumentStore::{
  read_bytes,
  list,
  write_bytes,
  delete,
  modified,
  read_text,
  write_text,
}
