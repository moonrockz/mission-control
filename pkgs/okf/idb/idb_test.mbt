///|
test "IndexedDB names are not empty" {
  assert_eq(@idb.DatabaseName("kb").to_string(), "kb")
  assert_eq(@idb.DatabaseName::default().to_string(), "okf")
  assert_eq(@idb.ObjectStoreName(" ").to_string(), " ")
  assert_eq(@idb.ObjectStoreName::default().to_string(), "files")
  let database = try @idb.DatabaseName("") catch {
    e => Some(e)
  } noraise {
    _ => None
  }
  assert_eq(database, Some(Empty(field="database")))
  let store = try @idb.ObjectStoreName("") catch {
    e => Some(e)
  } noraise {
    _ => None
  }
  assert_eq(store, Some(Empty(field="object store")))
}

///|
async test "the IndexedDB store meets the store contract with the in-memory adapter" {
  @conformance.check_store(@idb.IdbStore::in_memory())
  @conformance.check_store(
    @idb.IdbStore::in_memory(),
    prefix=@okf.StoreDir("okf-conformance"),
  )
}

///|
async test "listings derive directories, and a directory disappears with its last file" {
  let store = @idb.IdbStore::in_memory()
  store.write_text(@okf.StorePath("kb/index.md"), "# Index")
  store.write_text(@okf.StorePath("kb/old/a.md"), "# Old")
  store.write_text(@okf.StorePath("kbx/b.md"), "# Other")
  let names = (dir : String) => {
    store
    .list(@okf.StoreDir(dir))
    .map(e => (e.name.to_string(), e.kind is Directory))
  }
  assert_eq(names("kb"), [("index.md", false), ("old", true)])
  assert_eq(names(""), [("kb", true), ("kbx", true)])
  store.delete(@okf.StorePath("kb/old/a.md"))
  assert_eq(names("kb"), [("index.md", false)])
  let old = @okf.StoreDir("kb/old")
  let gone : @provider.StoreError? = try store.list(old) catch {
    e => Some(e)
  } noraise {
    _ => None
  }
  assert_eq(gone, Some(@provider.NotFound(DirectoryAt(old))))
}

///|
async test "separate stores do not share files" {
  let one = @idb.IdbStore::in_memory()
  let two = @idb.IdbStore::in_memory()
  one.write_text(@okf.StorePath("kb/a.md"), "# A")
  assert_eq(two.list(@okf.StoreDir::root()).length(), 0)
}

///|
async test "a write over the quota fails for its path and keeps the earlier content" {
  let store = @idb.IdbStore::in_memory(quota_bytes=40)
  let path = @okf.StorePath("a.md")
  store.write_text(path, "# Small")
  let failed = try
    store.write_text(path, "# A text that is far too long for the quota")
  catch {
    Failed(at, message) => at == FileAt(path) && message.contains("quota")
    _ => false
  } noraise {
    _ => false
  }
  assert_true(failed)
  assert_eq(store.read_text(path), "# Small")
}

///|
async test "a bundle loads after writes" {
  let store = @idb.IdbStore::in_memory()
  store.write_text(
    @okf.StorePath("kb/index.md"),
    "---\nokf_version: \"0.2\"\n---\n",
  )
  store.write_text(@okf.StorePath("kb/a.md"), "---\ntype: Note\n---\n# A\n")
  let bundle = @provider.load_bundle(store, root=@okf.StoreDir("kb"))
  assert_eq(bundle.documents().length(), 2)
}
