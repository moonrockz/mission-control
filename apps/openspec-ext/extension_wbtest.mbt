///|
test "config migration preserves project rules and comments" {
  let original = "# Project policy\nschema: spec-driven\ncontext: |\n  Keep local rules.\nrules:\n  tasks:\n    - Test changes.\n"
  let migrated = configure(original)
  assert_eq(
    migrated,
    original.replace(old="schema: spec-driven", new="schema: html-design"),
  )
  assert_eq(configure(migrated), migrated)
  assert_eq(
    configure("---\ncontext: hello\n"),
    "---\nschema: html-design\ncontext: hello\n",
  )
}

///|
test "invalid or complex configs are refused" {
  for
    source in [
      "[broken", "- list\n", "schema: old\n---\nschema: other\n", "{schema: old, context: hello}",
    ] {
    let rejected = try {
      let _ = configure(source)
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "path boundary and command usage reject invalid input" {
  for path in ["", "bad\npath", "bad\rpath", "bad\u{0000}path"] {
    let rejected = try {
      let _ = RepositoryPath(path)
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  let _ = RepositoryPath("../consumer with spaces")
  for args in [["unknown"], ["install", "--force"], ["check", ".", "extra"]] {
    let rejected = try {
      let _ = parse_command(args[:])
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  assert_true(parse_command(["install"]) is Repository(Install, _))
  assert_true(parse_command(["check", "../repo"]) is Repository(Check, _))
  assert_true(parse_command(["setup"]) is Repository(Setup, _))
}

///|
test "owned files update but local edits and unowned files conflict" {
  let file = BundleFile::Design
  assert_true(can_replace(file, None, None))
  assert_true(can_replace(file, Some(file.content()), None))
  assert_false(can_replace(file, Some("local design"), None))
  assert_true(can_replace(file, Some("old design"), Some(digest("old design"))))
  assert_false(
    can_replace(file, Some("local design"), Some(digest("old design"))),
  )
  assert_eq(
    digest("abc").text(),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}

///|
test "lock digests reject wrong length, uppercase and nonhex input" {
  for
    text in ["", "0".repeat(63), "0".repeat(65), "A".repeat(64), "g".repeat(64)] {
    let rejected = try {
      let _ = FileDigest(text)
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  assert_eq(FileDigest("0".repeat(64)).text(), "0".repeat(64))
  assert_eq(FileDigest("f".repeat(64)).text(), "f".repeat(64))
}
