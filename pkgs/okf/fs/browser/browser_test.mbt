///|
async test "the browser store meets the store contract with each write method" {
  for
    writes in [
      @browser.WriteMethod::Writable,
      @browser.WriteMethod::SyncAccessWorker,
      @browser.WriteMethod::Auto,
    ] {
    @conformance.check_store(
      @browser.BrowserStore(@browser.memory_directory_handle(true), writes~),
    )
  }
  // Without createWritable, as in Safari 18.
  @conformance.check_store(
    @browser.BrowserStore(
      @browser.memory_directory_handle(true, with_writable=false),
    ),
  )
}

///|
async test "the browser store reports a permission error and writes nothing" {
  let store = @browser.BrowserStore(@browser.memory_directory_handle(false))
  let path = @okf.StorePath("a.md")
  let denied = try store.write_text(path, "x") catch {
    e => Some(e)
  } noraise {
    _ => None
  }
  assert_eq(denied, Some(@provider.PermissionDenied(FileAt(path))))
  assert_eq(store.list(@okf.StoreDir::root()).length(), 0)
}

///|
async test "automatic selection uses createWritable when it exists, and the worker otherwise" {
  let with_handle = @browser.memory_directory_handle(true)
  let store = @browser.BrowserStore(with_handle)
  assert_eq(store.writes(), Auto)
  store.write_text(@okf.StorePath("a.md"), "# A")
  store.write_text(@okf.StorePath("b/c.md"), "# C")
  assert_eq(@browser.stand_in_writes(with_handle), "writable,writable")
  let without = @browser.memory_directory_handle(true, with_writable=false)
  let store = @browser.BrowserStore(without)
  store.write_text(@okf.StorePath("a.md"), "# A")
  store.write_bytes(@okf.StorePath("b/c.bin"), b"\x01")
  assert_eq(@browser.stand_in_writes(without), "sync,sync")
  assert_eq(store.read_text(@okf.StorePath("a.md")), "# A")
  assert_eq(store.read_bytes(@okf.StorePath("b/c.bin")), b"\x01")
}

///|
async test "the worker method writes through the worker when createWritable exists" {
  let handle = @browser.memory_directory_handle(true)
  let store = @browser.BrowserStore(handle, writes=SyncAccessWorker)
  store.write_text(@okf.StorePath("a.md"), "# A")
  assert_eq(@browser.stand_in_writes(handle), "sync")
}

///|
async test "the worker method is refused for a picked directory" {
  let handle = @browser.memory_directory_handle(true, picked=true)
  let store = @browser.BrowserStore(handle, writes=SyncAccessWorker)
  let path = @okf.StorePath("a.md")
  let refused = try store.write_text(path, "x") catch {
    InvalidPath(message) => Some(message)
    _ => None
  } noraise {
    _ => None
  }
  guard refused is Some(message) else { fail("not refused") }
  assert_true(message.contains("origin private file system"))
  assert_true(message.contains("BrowserStore::origin_private"))
  assert_eq(store.list(@okf.StoreDir::root()).length(), 0)
}

///|
async test "a worker write replaces the whole content" {
  let handle = @browser.memory_directory_handle(true, with_writable=false)
  let store = @browser.BrowserStore(handle)
  let path = @okf.StorePath("kb/a.md")
  store.write_text(path, "# A much longer text than the new one\n")
  store.write_text(path, "# New")
  assert_eq(store.read_text(path), "# New")
}

///|
async test "a failed worker write reports a store error and leaves no partial file" {
  let handle = @browser.memory_directory_handle(true, with_writable=false)
  let store = @browser.BrowserStore(handle)
  store.write_text(@okf.StorePath("kept.md"), "# Kept")
  @browser.fail_sync_writes(handle, "new.md")
  @browser.fail_sync_writes(handle, "kept.md")
  for name in ["new.md", "kept.md"] {
    let path = @okf.StorePath(name)
    let failed = try store.write_text(path, "# Partial") catch {
      Failed(at, message) => at == FileAt(path) && message.contains(name)
      _ => false
    } noraise {
      _ => false
    }
    assert_true(failed, msg=name)
  }
  let names = store.list(@okf.StoreDir::root()).map(e => e.name.to_string())
  assert_eq(names, ["kept.md"])
  assert_eq(store.read_text(@okf.StorePath("kept.md")), "# Kept")
}
