///|
async test "the browser store meets the store contract on a stand-in handle" {
  @conformance.check_store(
    @browser.BrowserStore(@browser.memory_directory_handle(true)),
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
