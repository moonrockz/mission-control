///|
test "the version text parses and names the tools module" {
  assert_eq(version().to_string(), tools_version)
  assert_eq(tool().module_name(), "moonrockz/mission-control-tools")
  assert_eq(tool().name(), "mission-control-tools")
  inspect(version(), content="0.1.0")
}

///|
fn usage_error(args : Array[String]) -> String {
  try {
    let _ = parse(args[:])
    ""
  } catch {
    error => error.message()
  }
}

///|
test "help and version parse without a repository" {
  for args in [[], ["help"], ["--help"], ["-h"], ["openspec", "help"]] {
    assert_true(parse(args[:]) is Help)
  }
  assert_true(parse(["version"]) is Version(Text))
  assert_true(parse(["--version"]) is Version(Text))
  assert_true(parse(["version", "--json"]) is Version(JsonReport))
}

///|
test "openspec commands take options and one path in any order" {
  guard parse(["openspec", "check"]) is OpenSpec(Check(Snapshot, Text), path) else {
    fail("check")
  }
  assert_eq(path.text(), ".")
  guard parse(["openspec", "check", "../repo", "--json", "--bundle"])
    is OpenSpec(Check(Bundle, JsonReport), path) else {
    fail("check --bundle --json")
  }
  assert_eq(path.text(), "../repo")
  guard parse(["openspec", "install", "/tmp/x"]) is OpenSpec(Install, path) else {
    fail("install")
  }
  assert_eq(path.text(), "/tmp/x")
  assert_true(parse(["openspec", "setup"]) is OpenSpec(Setup, _))
}

///|
test "usage errors name the argument" {
  let cases : Array[(Array[String], String)] = [
    (["nope"], "unknown command 'nope'"),
    (["openspec"], "openspec needs a command: check, install or setup"),
    (["openspec", "lint"], "unknown command 'openspec lint'"),
    (["openspec", "install", "--force"], "unknown option '--force'"),
    (["openspec", "setup", "--json"], "unknown option '--json'"),
    (
      ["openspec", "check", "a", "b"],
      "expected at most one repository path, found 'b'",
    ),
    (
      ["openspec", "check", "--json", "--json"],
      "option '--json' is given more than one time",
    ),
    (["version", "extra"], "version takes no argument, found 'extra'"),
    (["version", "--bundle"], "unknown option '--bundle'"),
    (
      ["openspec", "check", ""],
      "Repository path must be nonempty and contain no NUL or line breaks",
    ),
  ]
  for case in cases {
    assert_eq(usage_error(case.0), case.1)
  }
}

///|
test "exit codes are 0, 1 and 2" {
  assert_eq(ExitCode::Success.to_int(), 0)
  assert_eq(ExitCode::Failure.to_int(), 1)
  assert_eq(ExitCode::Usage.to_int(), 2)
  let outcome = usage_outcome(UnknownCommand("nope"))
  assert_true(outcome.exit_code is Usage)
  assert_eq(outcome.stderr[0], "mission-control-tools: unknown command 'nope'")
  assert_eq(outcome.stderr[1], usage())
}

///|
test "version output in text and JSON" {
  assert_eq(version_outcome(Text).stdout, ["mission-control-tools 0.1.0"])
  assert_eq(version_outcome(JsonReport).stdout, [
    "{\"tool\":\"mission-control-tools\",\"version\":\"0.1.0\",\"bundle\":\"html-design\"}",
  ])
}

///|
/// Problems from a real check: an edited design template and, with `wrong_schema`, the old schema.
fn drift_problems(wrong_schema : Bool) -> Array[@extension.Problem] {
  @extension.check_snapshot(
    lock=Some(@extension.lock_text(tool())),
    config=Some(
      if wrong_schema {
        "schema: spec-driven\n"
      } else {
        "schema: html-design\n"
      },
    ),
    file=f => Some(if f is Design { "Local edit" } else { f.content() }),
    level=Snapshot,
  )
}

///|
test "check output keeps the script lines" {
  let ok = check_outcome("/repo", [], Snapshot, Text)
  assert_eq(ok.stdout, ["html-design snapshot: OK"])
  assert_true(ok.exit_code is Success)
  let failed = check_outcome("/repo", drift_problems(true), Snapshot, Text)
  assert_true(failed.exit_code is Failure)
  assert_eq(failed.stdout, [])
  assert_eq(failed.stderr, [
    "openspec-ext: Extension drift: openspec/schemas/html-design/templates/design.html",
    "openspec-ext: Default schema must be html-design",
  ])
  assert_eq(install_outcome().stdout, [
    "html-design: OK (mission-control-tools 0.1.0)",
  ])
}

///|
test "check JSON has the tool, the level, the repository and each problem" {
  let outcome = check_outcome(
    "/repo",
    drift_problems(false),
    Bundle,
    JsonReport,
  )
  assert_true(outcome.exit_code is Failure)
  assert_eq(outcome.stderr, [])
  let json = @json.parse(outcome.stdout[0])
  guard json
    is {
      "tool": "mission-control-tools",
      "version": "0.1.0",
      "command": "openspec check",
      "level": "bundle",
      "repository": "/repo",
      "ok": False,
      "problems": [
        {
          "code": "drift",
          "path": "openspec/schemas/html-design/templates/design.html",
          "message": "Extension drift: openspec/schemas/html-design/templates/design.html",
          ..
        },
      ],
      ..
    } else {
    fail("unexpected report: \{outcome.stdout[0]}")
  }
  let ok = @json.parse(
    check_outcome("/repo", [], Snapshot, JsonReport).stdout[0],
  )
  guard ok is { "ok": True, "level": "snapshot", "problems": [], .. } else {
    fail("unexpected report")
  }
}

///|
async test "execute installs and checks another directory, and reports JSON" {
  let root = @async_fs.tmpdir(prefix="mission-control-tools")
  defer @async_fs.rmdir(root, recursive=true)
  let repository = @extension.RepositoryPath(root)
  let installed = execute(OpenSpec(Install, repository))
  assert_eq(installed.stdout, ["html-design: OK (mission-control-tools 0.1.0)"])
  let checked = execute(OpenSpec(Check(Bundle, Text), repository))
  assert_eq(checked.stdout, ["html-design snapshot: OK"])
  @async_fs.write_file(
    "\{root}/openspec/schemas/html-design/templates/design.html",
    "Local edit",
  )
  let report = execute(OpenSpec(Check(Snapshot, JsonReport), repository))
  assert_true(report.exit_code is Failure)
  guard @json.parse(report.stdout[0])
    is { "ok": False, "problems": [{ "code": "drift", .. }], .. } else {
    fail("unexpected report: \{report.stdout[0]}")
  }
}

///|
async test "check --json reports a repository that cannot be read as JSON" {
  let missing = @extension.RepositoryPath("/no/such/mission-control-tools/repo")
  let report = execute(OpenSpec(Check(Bundle, JsonReport), missing))
  assert_true(report.exit_code is Failure)
  assert_eq(report.stderr, [])
  guard @json.parse(report.stdout[0])
    is {
      "ok": False,
      "level": "bundle",
      "repository": "/no/such/mission-control-tools/repo",
      "problems": [{ "code": "error", .. }],
      ..
    } else {
    fail("unexpected report: \{report.stdout[0]}")
  }
  let text = execute(OpenSpec(Check(Snapshot, Text), missing))
  assert_true(text.exit_code is Failure)
  assert_eq(text.stdout, [])
  assert_true(text.stderr[0].has_prefix("openspec-ext: "))
}
