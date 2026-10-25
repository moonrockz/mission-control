///|
test "version prints the contract version" {
  inspect(@contracts.version(), content="0.1.0")
  guard run(["version"]) is Text(text) else { panic() }
  assert_eq(text, "mission-control " + @contracts.version().to_string())
}

///|
test "help is the default" {
  guard run([]) is Text(text) else { panic() }
  assert_true(text.has_prefix("Usage: mission-control"))
}

///|
test "an unknown command is rejected with the usage exit code" {
  let result = run(["nope"])
  guard result is Unknown(command) else { panic() }
  inspect(command, content="nope")
  assert_eq(result.exit_code().to_int(), 2)
  assert_eq(run(["version"]).exit_code().to_int(), 0)
}

///|
test "the usage lists every command" {
  assert_eq(
    usage(),
    "Usage: mission-control <command>\n\nCommands:\n  help       Print this help\n  version    Print the version",
  )
}

///|
test "exit codes run from 0 to 255" {
  assert_eq(ExitCode::success().to_int(), 0)
  assert_eq(ExitCode::failure().to_int(), 1)
  assert_eq(ExitCode::usage().to_int(), 2)
  assert_eq(ExitCode::ExitCode(0).to_int(), 0)
  assert_eq(ExitCode::ExitCode(255).to_int(), 255)
  for value in [-1, 256] {
    let refused = try ExitCode::ExitCode(value) catch {
      e => Some(e)
    } noraise {
      _ => None
    }
    assert_eq(refused, Some(InvalidExitCode(value)))
  }
}
