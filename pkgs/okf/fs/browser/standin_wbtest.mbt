///|
/// Whether a stand-in handle allows writes and deletes.
priv enum Access {
  ReadWrite
  /// Writes and deletes fail with `NotAllowedError`, as with a read-only
  /// handle.
  ReadOnly
}

///|
/// The browser that a stand-in handle stands for.
priv enum StandInKind {
  /// A browser with `createWritable()` and the worker.
  Modern
  /// A browser without `createWritable()`, such as Safari 18. The stand-in
  /// has a sync writer that takes the place of the worker.
  NoWritable
  /// A directory that the user selected: `createWritable()`, and no worker.
  Picked
}

///|
/// The writer of one stand-in write.
priv enum StandInWriter {
  WritableWrite
  SyncWrite
} derive(Eq, Debug)

///|
/// An in-memory stand-in for a `FileSystemDirectoryHandle`, for tests outside
/// a browser.
fn memory_directory_handle(
  access~ : Access = ReadWrite,
  kind~ : StandInKind = Modern,
) -> DirectoryHandle {
  memory_handle(access is ReadWrite, !(kind is NoWritable), kind is Picked)
}

///|
extern "js" fn stand_in_log_length(handle : DirectoryHandle) -> Int32 =
  #| (handle) => handle.okfLog.length

///|
extern "js" fn stand_in_log_is_sync(
  handle : DirectoryHandle,
  i : Int32,
) -> Bool =
  #| (handle, i) => handle.okfLog[i] === "sync"

///|
/// The writers that a stand-in handle saw, in order.
fn stand_in_writes(handle : DirectoryHandle) -> Array[StandInWriter] {
  Array::makei(stand_in_log_length(handle), i => {
    if stand_in_log_is_sync(handle, i) {
      SyncWrite
    } else {
      WritableWrite
    }
  })
}

///|
/// Makes the sync writer of a stand-in handle fail for files named `name`, as
/// a browser does when it cannot open a sync access handle.
extern "js" fn fail_sync_writes(
  handle : DirectoryHandle,
  name : String,
) -> Unit =
  #| (handle, name) => { handle.okfFailSync.add(name); }

///|
extern "js" fn memory_handle(
  writable : Bool,
  with_writable : Bool,
  picked : Bool,
) -> DirectoryHandle =
  #| (writable, withWritable, picked) => {
  #|   const log = [];
  #|   const fail = (name, message) => { const e = new Error(message); e.name = name; throw e; };
  #|   const makeFile = (name) => ({ kind: "file", name, data: new Uint8Array(), lastModified: Date.now() });
  #|   const fileHandle = (node) => ({
  #|     kind: "file", name: node.name,
  #|     async getFile() {
  #|       const data = node.data;
  #|       return {
  #|         lastModified: node.lastModified,
  #|         async text() { return new TextDecoder().decode(data); },
  #|         async arrayBuffer() { return data.slice().buffer; },
  #|       };
  #|     },
  #|     ...(withWritable ? {
  #|       async createWritable() {
  #|         if (!writable) fail("NotAllowedError", "read-only handle");
  #|         let pending = new Uint8Array();
  #|         return {
  #|           async write(chunk) {
  #|             pending = typeof chunk === "string" ? new TextEncoder().encode(chunk) : new Uint8Array(chunk);
  #|           },
  #|           async close() { node.data = pending; node.lastModified = Date.now(); log.push("writable"); },
  #|         };
  #|       },
  #|     } : {}),
  #|   });
  #|   const dirHandle = (node) => ({
  #|     kind: "directory", name: node.name,
  #|     async getDirectoryHandle(name, opts) {
  #|       let child = node.children.get(name);
  #|       if (!child) {
  #|         if (!(opts && opts.create)) fail("NotFoundError", name);
  #|         if (!writable) fail("NotAllowedError", "read-only handle");
  #|         child = { kind: "directory", name, children: new Map() };
  #|         node.children.set(name, child);
  #|       }
  #|       if (child.kind !== "directory") fail("TypeMismatchError", name);
  #|       return dirHandle(child);
  #|     },
  #|     async getFileHandle(name, opts) {
  #|       let child = node.children.get(name);
  #|       if (!child) {
  #|         if (!(opts && opts.create)) fail("NotFoundError", name);
  #|         if (!writable) fail("NotAllowedError", "read-only handle");
  #|         child = makeFile(name);
  #|         node.children.set(name, child);
  #|       }
  #|       if (child.kind !== "file") fail("TypeMismatchError", name);
  #|       return fileHandle(child);
  #|     },
  #|     async removeEntry(name) {
  #|       if (!node.children.has(name)) fail("NotFoundError", name);
  #|       if (!writable) fail("NotAllowedError", "read-only handle");
  #|       node.children.delete(name);
  #|     },
  #|     async *entries() {
  #|       for (const [name, child] of node.children) {
  #|         yield [name, child.kind === "directory" ? dirHandle(child) : fileHandle(child)];
  #|       }
  #|     },
  #|   });
  #|   const rootNode = { kind: "directory", name: "", children: new Map() };
  #|   const root = dirHandle(rootNode);
  #|   root.okfHasWritable = withWritable;
  #|   root.okfFailSync = new Set();
  #|   root.okfLog = log;
  #|   if (!picked) {
  #|     // The worker protocol on the stand-in: walk, open, replace, close.
  #|     root.okfSyncWriter = async (segments, name, data) => {
  #|       if (!writable) fail("NotAllowedError", "read-only handle");
  #|       let dir = root;
  #|       for (const s of segments) dir = await dir.getDirectoryHandle(s, { create: true });
  #|       const parent = segments.reduce((n, s) => n.children.get(s), rootNode);
  #|       const existed = parent.children.has(name);
  #|       await dir.getFileHandle(name, { create: true });
  #|       const node = parent.children.get(name);
  #|       if (root.okfFailSync.has(name)) {
  #|         if (!existed) parent.children.delete(name);
  #|         fail("InvalidStateError", "cannot open a sync access handle for " + name);
  #|       }
  #|       node.data = new Uint8Array(data);
  #|       node.lastModified = Date.now();
  #|       log.push("sync");
  #|     };
  #|   }
  #|   return root;
  #| }
