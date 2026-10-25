///|
/// Raised when a number is not an exit code.
pub(all) suberror ExitCodeError {
  /// The number is outside 0 to 255.
  InvalidExitCode(Int32)
} derive(Eq, Debug)

///|
/// The exit code of a process: a number from 0 to 255.
struct ExitCode {
  value : Int32
} derive(Eq, Hash, Debug)

///|
pub fn ExitCode::ExitCode(value : Int32) -> ExitCode raise ExitCodeError {
  if value < 0 || value > 255 {
    raise InvalidExitCode(value)
  }
  { value, }
}

///|
/// 0: the command did what it was asked.
pub fn ExitCode::success() -> ExitCode {
  { value: 0, }
}

///|
/// 1: the command failed.
pub fn ExitCode::failure() -> ExitCode {
  { value: 1, }
}

///|
/// 2: the arguments are not a valid use of the command.
pub fn ExitCode::usage() -> ExitCode {
  { value: 2, }
}

///|
pub fn ExitCode::to_int(self : ExitCode) -> Int32 {
  self.value
}

///|
/// What `run` decided to do with the arguments.
pub enum Run {
  Text(String)
  Unknown(String)
}

///|
/// The exit code of the result: success for text, a usage error for an
/// unknown command.
pub fn Run::exit_code(self : Run) -> ExitCode {
  match self {
    Text(_) => ExitCode::success()
    Unknown(_) => ExitCode::usage()
  }
}

///|
pub fn usage() -> String {
  let lines = ["Usage: mission-control <command>", "", "Commands:"]
  // Names and descriptions line up, with at least four spaces between them.
  let width = @contracts.commands
    .iter()
    .fold(init=7, (w, c) => {
      if c.name().length() > w {
        c.name().length()
      } else {
        w
      }
    })
  for command in @contracts.commands {
    let name = command.name()
    let pad = " ".repeat(width + 4 - name.length())
    lines.push("  \{name}\{pad}\{command.description()}")
  }
  lines.join("\n")
}

///|
/// Run one invocation. `args` does not include the program name.
pub fn run(args : Array[String]) -> Run {
  let name = match args {
    [] => "help"
    [command, ..] => command
  }
  try @contracts.Command::Command(name) catch {
    UnknownCommand(_) => Unknown(name)
  } noraise {
    Help => Text(usage())
    Version => Text("mission-control " + @contracts.version().to_string())
  }
}
