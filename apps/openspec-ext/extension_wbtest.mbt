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
test "repository paths reject empty text, NUL and line breaks" {
  for path in ["", "bad\npath", "bad\rpath", "bad\u{0000}path"] {
    let rejected = try {
      let _ = RepositoryPath(path)
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  assert_eq(
    RepositoryPath("../consumer with spaces").text(),
    "../consumer with spaces",
  )
  assert_eq(RepositoryPath(".").text(), ".")
}

///|
fn tool(version : String) -> Tool raise {
  Tool("moonrockz/mission-control-tools", @contracts.Version::Version(version))
}

///|
test "tool module names need owner/name with lower-case letters, digits and -" {
  let version = @contracts.Version::Version("0.1.0")
  for
    name in [
      "", "tools", "/tools", "owner/", "a/b/c", "Owner/tools", "owner/to ols", "owner/tools_x",
    ] {
    let rejected = try {
      let _ = Tool(name, version)
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  let t = Tool("a/b-2", version)
  assert_eq(t.module_name(), "a/b-2")
  assert_eq(t.name(), "b-2")
  assert_eq(tool("0.1.0").name(), "mission-control-tools")
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

///|
test "the bundle manages seven schema files and no script" {
  let paths = files().map(f => f.path())
  assert_eq(paths.length(), 7)
  assert_true(
    paths.iter().all(p => p.has_prefix("openspec/schemas/html-design/")),
  )
  for retired in retired_files() {
    assert_false(paths.contains(retired.path()))
  }
}

///|
test "format 2 lock records the tool and parses back" {
  let text = lock_text(tool("0.3.1"))
  guard @json.parse(text)
    is {
      "format": 2,
      "extension": "html-design",
      "tool": "moonrockz/mission-control-tools",
      "version": "0.3.1",
      "files": Object(hashes),
      ..
    } else {
    fail("unexpected lock: \{text}")
  }
  assert_eq(hashes.length(), 7)
  guard parse_lock(text) is Current(recorded, locked) else {
    fail("lock does not parse")
  }
  assert_true(recorded == tool("0.3.1"))
  assert_eq(
    locked.get(BundleFile::Schema.path()).map(d => d.text()),
    Some(digest(BundleFile::Schema.content()).text()),
  )
}

///|
test "format 1 locks parse as legacy and malformed locks do not parse" {
  let legacy = "{\"format\": 1, \"extension\": \"html-design\", \"module\": \"moonrockz/openspec-ext\", \"version\": \"0.1.0\", \"files\": {\"scripts/openspec-ext.mbtx\": \"\{"a".repeat(64)}\"}}"
  guard parse_lock(legacy) is Legacy(files) else {
    fail("legacy lock does not parse")
  }
  assert_eq(
    files.get("scripts/openspec-ext.mbtx").map(d => d.text()),
    Some("a".repeat(64)),
  )
  let good = lock_text(tool("0.1.0"))
  let cases : Array[(String, String)] = [
    ("", "the lock is not JSON"),
    ("{", "the lock is not JSON"),
    ("[]", "the lock has no valid field `format`"),
    ("{}", "the lock has no valid field `format`"),
    (
      good.replace(old="\"format\": 2", new="\"format\": 3"),
      "the lock format 3 is not 1 or 2",
    ),
    (
      good.replace(old="\"format\": 2", new="\"format\": \"2\""),
      "the lock format \"2\" is not 1 or 2",
    ),
    (
      good.replace(old="html-design\"", new="other\""),
      "the lock extension other is not html-design",
    ),
    (
      good.replace(old="\"version\": \"0.1.0\"", new="\"version\": \"0.1\""),
      "the lock version 0.1 is not X.Y.Z",
    ),
    (
      good.replace(old="moonrockz/mission-control-tools", new="Bad Tool"),
      "the lock tool Bad Tool is not owner/name",
    ),
    (
      good.replace(old="\"tool\"", new="\"module\""),
      "the lock has no valid field `tool`",
    ),
    (
      good.replace(old=digest(BundleFile::Notice.content()).text(), new="XYZ"),
      "the lock digest of openspec/schemas/html-design/NOTICE is not a SHA-256",
    ),
    (
      legacy.replace(old="moonrockz/openspec-ext", new="moonrockz/other"),
      "the format 1 lock module moonrockz/other is not moonrockz/openspec-ext",
    ),
    (
      legacy.replace(old="\"files\": {", new="\"other\": {"),
      "the lock has no valid field `files`",
    ),
  ]
  for case in cases {
    let message = try {
      let _ = parse_lock(case.0)
      "parsed"
    } catch {
      error => error.message()
    }
    assert_eq(message, case.1)
  }
}

///|
test "retired files are deleted only with the previous digest" {
  let recorded = "{\"format\": 1, \"extension\": \"html-design\", \"module\": \"moonrockz/openspec-ext\", \"version\": \"0.1.0\", \"files\": {\"scripts/openspec-ext.mbtx\": \"\{digest("old script").text()}\"}}"
  let previous = Some(parse_lock(recorded))
  assert_true(retirement(Script, None, previous) is Absent)
  assert_true(retirement(Script, Some("old script"), previous) is Delete)
  assert_true(retirement(Script, Some("edited script"), previous) is Edited)
  assert_true(retirement(ScriptFeature, Some("feature"), previous) is Unmanaged)
  assert_true(retirement(Script, Some("old script"), None) is Unmanaged)
}

///|
fn intact(file : BundleFile) -> String? {
  Some(file.content())
}

///|
test "problem messages keep the script texts" {
  let t = tool("0.1.0")
  let cases : Array[(Problem, String, String)] = [
    (UnsupportedLock, "unsupported-lock", "Unsupported extension lock"),
    (FileSet, "file-set", "Unexpected extension file set"),
    (
      MissingDigest(Design),
      "missing-digest",
      "Missing digest: openspec/schemas/html-design/templates/design.html",
    ),
    (
      Drift(Design),
      "drift",
      "Extension drift: openspec/schemas/html-design/templates/design.html",
    ),
    (Schema, "schema", "Default schema must be html-design"),
    (MissingFile(Config), "missing-file", "Missing file: openspec/config.yaml"),
    (
      ToolVersion(recorded=t, expected=tool("0.2.0")),
      "tool-version",
      "Extension lock records mission-control-tools 0.1.0; this is mission-control-tools 0.2.0. Run mission-control-tools openspec install.",
    ),
  ]
  for case in cases {
    assert_eq(case.0.code(), case.1)
    assert_eq(case.0.message(), case.2)
  }
}

///|
test "a matching snapshot has no problems at both levels" {
  let lock = Some(lock_text(tool("0.1.0")))
  let config = Some("schema: html-design\n")
  assert_eq(
    check_snapshot(lock~, config~, file=intact, level=Snapshot).length(),
    0,
  )
  assert_eq(
    check_snapshot(lock~, config~, file=intact, level=Bundle(tool("0.1.0"))).length(),
    0,
  )
}

///|
test "the snapshot level ignores the tool version and the bundle level reports it once" {
  let lock = Some(lock_text(tool("0.1.0")))
  let config = Some("schema: html-design\n")
  assert_eq(
    check_snapshot(lock~, config~, file=intact, level=Snapshot).length(),
    0,
  )
  let problems = check_snapshot(
    lock~,
    config~,
    file=intact,
    level=Bundle(tool("0.2.0")),
  )
  assert_eq(problems.map(p => p.code()), ["tool-version"])
}

///|
test "setup supports OpenSpec 1.14.3 and each 1.16 patch release" {
  for text in ["1.14.3", "1.16.0", "1.16.1", "1.16.9", "1.16.123"] {
    assert_eq(SupportedOpenSpec(text).version().to_string(), text)
  }
  for
    text in [
      "1.14.2", "1.14.4", "1.13.0", "1.15.0", "1.15.9", "1.17.0", "2.16.0", "0.16.0",
    ] {
    let refused = try {
      let _ = SupportedOpenSpec(text)
      None
    } catch {
      UnsupportedOpenSpec(version) => Some(version.to_string())
      InvalidOpenSpecVersion(_) => None
    }
    assert_eq(refused, Some(text))
  }
  for
    text in [
      "1.016.0", "1.16", "1.16.1.0", "1.16.1-beta.1", "v1.16.1", " 1.16.1", "1.16.1\n",
      "",
    ] {
    let refused = try {
      let _ = SupportedOpenSpec(text)
      None
    } catch {
      InvalidOpenSpecVersion(found) => Some(found)
      UnsupportedOpenSpec(_) => None
    }
    assert_eq(refused, Some(text))
  }
}

///|
test "the supported versions text comes from the support table" {
  assert_eq(supported_openspec, "1.14.3 or 1.16.x")
  assert_eq(
    supported_openspec,
    supported.iter().map(Support::text).join(" or "),
  )
  let message = (text : String) => {
    try {
      let _ = SupportedOpenSpec(text)
      ""
    } catch {
      error => error.message()
    }
  }
  assert_eq(message("1.15.0"), "OpenSpec 1.15.0 is not 1.14.3 or 1.16.x")
  assert_eq(message("1.16"), "OpenSpec version text is not X.Y.Z: 1.16")
}
