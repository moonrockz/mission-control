///|
/// Publishes the results of the browser checks for the Playwright test.
extern "js" fn publish(result : String) -> Unit =
  #| (result) => { globalThis.okfBrowserResult = result; }

///|
/// Runs the store conformance checks in the page, each in its own directory
/// of the origin private file system or its own IndexedDB database: the
/// browser store with each write method and on the root handle, worker writes
/// in a row and at the same time, the IndexedDB store, two IndexedDB databases
/// that share no file, and an IndexedDB store whose database another store
/// upgrades. Publishes one `name=result` line for each check, where the result
/// is `ok`, `skipped: <reason>` or `failed: <error>`.
async fn main {
  let worker = check(() => {
    @browser.BrowserStore::origin_private(
      path=@okf.StoreDir("okf-worker"),
      writes=SyncAccessWorker,
    )
  })
  let auto = check(() => {
    @browser.BrowserStore::origin_private(path=@okf.StoreDir("okf-auto"))
  })
  let writable = writable_check()
  let idb = idb_check()
  let idb_separate = idb_separate_check()
  let root_worker = check(
    () => {
      @browser.BrowserStore(
        @browser.origin_private_root(),
        writes=SyncAccessWorker,
      )
    },
    prefix=@okf.StoreDir("okf-root-worker"),
  )
  let worker_sequence = worker_sequence_check()
  let idb_reopen = idb_reopen_check()
  let lines = [
    "writable=" + writable,
    "worker=" + worker,
    "auto=" + auto,
    "idb=" + idb,
    "idb-separate=" + idb_separate,
    "root-worker=" + root_worker,
    "worker-sequence=" + worker_sequence,
    "idb-reopen=" + idb_reopen,
  ]
  publish(lines.join("\n"))
}

///|
/// The browser store with `createWritable()`, or a skip in a browser that
/// does not have it.
async fn writable_check() -> String {
  guard @browser.browser_has_create_writable() else {
    return "skipped: this browser has no createWritable()"
  }
  check(() => {
    @browser.BrowserStore::origin_private(
      path=@okf.StoreDir("okf-writable"),
      writes=Writable,
    )
  })
}

///|
async fn check(
  make : async () -> @browser.BrowserStore,
  prefix~ : @okf.StoreDir = @okf.StoreDir::root(),
) -> String {
  @conformance.check_store(make(), prefix~) catch {
    e => return "failed: " + describe(e)
  }
  "ok"
}

///|
async fn idb_check() -> String {
  try {
    let store = @idb.IdbStore::open(
      database=@idb.DatabaseName("okf-conformance"),
    )
    @conformance.check_store(store)
  } catch {
    e => return "failed: " + describe(e)
  }
  "ok"
}

///|
/// Two IndexedDB stores with different database names share no file.
async fn idb_separate_check() -> String {
  try {
    let one = @idb.IdbStore::open(database=@idb.DatabaseName("okf-one"))
    let two = @idb.IdbStore::open(database=@idb.DatabaseName("okf-two"))
    one.write_text(@okf.StorePath("kb/a.md"), "# A")
    if two.list(@okf.StoreDir::root()).length() != 0 {
      return "failed: a write to okf-one appears in okf-two"
    }
  } catch {
    e => return "failed: " + describe(e)
  }
  "ok"
}

///|
/// Worker writes: a delete right after a write, and three writes to one file
/// at the same time, which must all succeed and keep the last content.
async fn worker_sequence_check() -> String {
  try {
    let store = @browser.BrowserStore::origin_private(
      path=@okf.StoreDir("okf-sequence"),
      writes=SyncAccessWorker,
    )
    let path = @okf.StorePath("a.md")
    store.write_text(path, "# A")
    store.delete(path)
    if store.list(@okf.StoreDir::root()).length() != 0 {
      return "failed: the delete after a write left the file"
    }
    @async.with_task_group(group => {
      for i in 0..<3 {
        group.spawn_bg(() => store.write_text(path, "v\{i}"))
      }
    })
    let last = store.read_text(path)
    if last != "v2" {
      return "failed: parallel writes left \{last}"
    }
  } catch {
    e => return "failed: " + describe(e)
  }
  "ok"
}

///|
/// A store whose database another store upgrades, to add its object store,
/// opens its connection again and keeps working.
async fn idb_reopen_check() -> String {
  try {
    let database = @idb.DatabaseName("okf-shared")
    let first = @idb.IdbStore::open(
      database~,
      object_store=@idb.ObjectStoreName("files"),
    )
    first.write_text(@okf.StorePath("a.md"), "# A")
    let second = @idb.IdbStore::open(
      database~,
      object_store=@idb.ObjectStoreName("other"),
    )
    second.write_text(@okf.StorePath("b.md"), "# B")
    first.write_text(@okf.StorePath("c.md"), "# C")
    let names = first.list(@okf.StoreDir::root()).map(e => e.name.to_string())
    if names != ["a.md", "c.md"] {
      return "failed: the first store lists \{names.join(", ")}"
    }
  } catch {
    e => return "failed: " + describe(e)
  }
  "ok"
}

///|
/// The case and the details of a check failure.
fn describe(error : Error) -> String {
  match error {
    @provider.Failed(at, message) => "Failed at \{at}: \{message}"
    @provider.NotFound(at) => "NotFound at \{at}"
    @provider.PermissionDenied(at) => "PermissionDenied at \{at}"
    @provider.InvalidPath(message) => "InvalidPath: \{message}"
    _ => error.to_string()
  }
}
