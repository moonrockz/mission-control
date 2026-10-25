///|
/// Publishes the results of the browser checks for the Playwright test.
extern "js" fn publish(result : String) -> Unit =
  #| (result) => { globalThis.okfBrowserResult = result; }

///|
/// Runs the store conformance checks in the page, each in its own directory
/// of the origin private file system or its own IndexedDB database: the
/// browser store with each write method, the IndexedDB store, and two
/// IndexedDB databases that share no file. Publishes
/// one `name=result` line for each check, where the result is `ok`,
/// `skipped: <reason>` or `failed: <error>`.
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
  let lines = [
    "writable=" + writable,
    "worker=" + worker,
    "auto=" + auto,
    "idb=" + idb,
    "idb-separate=" + idb_separate,
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
async fn check(make : async () -> @browser.BrowserStore) -> String {
  @conformance.check_store(make()) catch {
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
