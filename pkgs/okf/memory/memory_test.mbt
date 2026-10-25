///|
async test "the in-memory store meets the store contract" {
  @conformance.check_store(@memory.MemoryStore())
}

///|
async test "the in-memory store meets the contract under a prefix" {
  @conformance.check_store(
    @memory.MemoryStore(),
    prefix=@okf.StoreDir("kb/bundles"),
  )
}

///|
async test "the in-memory index meets the index contract" {
  @conformance.check_index(@memory.MemoryIndex())
}

///|
async test "the in-memory index meets the search contract" {
  let index = @memory.MemoryIndex()
  @conformance.check_search(index, k => {
    index.build_now(k, @okf.FixedClock::at("2026-10-23T00:00:00Z")) |> ignore
  })
}

///|
async test "a read-only store refuses writes" {
  let store = @memory.MemoryStore(read_only=true)
  let path = @okf.StorePath("a.md")
  let refused = try store.write_text(path, "x") catch {
    e => Some(e)
  } noraise {
    _ => None
  }
  assert_eq(refused, Some(@provider.PermissionDenied(FileAt(path))))
}

///|
test "in-memory contents are available synchronously" {
  let store = @memory.MemoryStore()
  store.put(@okf.StorePath("kb/index.md"), "---\nokf_version: \"0.2\"\n---\n")
  store.put(@okf.StorePath("kb/a.md"), "---\ntype: Note\n---\n")
  let knowledge = @okf.discover(store.snapshot())
  assert_eq(knowledge.bundles().length(), 1)
  assert_eq(knowledge.bundles()[0].concepts().length(), 1)
}
