///|
test "command names, aliases and Proton IDs" {
  inspect(Command::Help.name(), content="help")
  inspect(Command::Version.name(), content="version")
  for text in ["version", "--version", "-V"] {
    assert_eq(Command::Command(text), Command::Version)
  }
  for text in ["help", "--help", "-h"] {
    assert_eq(Command::Command(text), Command::Help)
  }
  let refused = try Command::Command("nope") catch {
    e => Some(e)
  } noraise {
    _ => None
  }
  assert_eq(refused, Some(UnknownCommand("nope")))
  inspect(Command::Version.proton_id(), content="mission-control.version")
  assert_eq(commands.iter().collect(), [Command::Help, Command::Version])
}

///|
test "version is the workspace version" {
  inspect(version(), content="0.0.2")
}

///|
test "versions: three parts without leading zeros" {
  let v = Version::Version("1.20.3")
  assert_eq((v.major(), v.minor(), v.patch()), (1, 20, 3))
  assert_eq(v.to_string(), "1.20.3")
  assert_eq(Version::Version("0.0.0").to_string(), "0.0.0")
  assert_true(Version::Version("0.0.9") < Version::Version("0.0.10"))
  for
    text in [
      "", "1", "1.2", "1.2.3.4", "01.2.3", "1.02.3", "1.2.-3", "1.2.x", "1..3", "1234567890.0.0",
    ] {
    let refused = try Version::Version(text) catch {
      e => Some(e)
    } noraise {
      _ => None
    }
    assert_eq(refused, Some(InvalidVersion(text)), msg=text)
  }
}
