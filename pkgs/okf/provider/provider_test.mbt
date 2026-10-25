///|
test "store root messages name no host path" {
  let root = @provider.StoreRoot("/srv/kb")
  assert_eq(
    root.relative_message("ENOENT: no such file, open '/srv/kb/a/b.md'"),
    "ENOENT: no such file, open 'a/b.md'",
  )
  assert_eq(root.relative_message("/srv/kb: missing"), ".: missing")
  // Text that only contains the root text does not change.
  assert_eq(
    root.relative_message("see /srv/kbx and /x/srv/kb/a.md"),
    "see /srv/kbx and /x/srv/kb/a.md",
  )
  let slash = @provider.StoreRoot("/")
  assert_eq(slash.relative_message("open '/a.md'"), "open 'a.md'")
  assert_eq(slash.relative_message("a/b c/d"), "a/b c/d")
  let short = @provider.StoreRoot("a")
  assert_eq(short.relative_message("open a/x.md (data)"), "open x.md (data)")
  assert_eq(short.relative_message("a bad path: a"), ". bad path: .")
}

///|
test "store root paths join without a double slash" {
  assert_eq(@provider.StoreRoot("/").join(["a.md"]), "/a.md")
  assert_eq(
    @provider.StoreRoot("/srv/kb/").join(["x", "a.md"]),
    "/srv/kb/x/a.md",
  )
  assert_eq(@provider.StoreRoot("kb").join([]), "kb")
}
