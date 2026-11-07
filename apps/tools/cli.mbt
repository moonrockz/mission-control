///|
/// The exit code of the tools CLI: 0 for success, 1 for a failure and 2 for a usage error.
pub(all) enum ExitCode {
  Success
  Failure
  Usage
} derive(Eq)

///|
#deprecated
pub extend ExitCode with Eq::{equal, not_equal}

///|
/// The number that the process exits with.
pub fn ExitCode::to_int(self : ExitCode) -> Int32 {
  match self {
    Success => 0
    Failure => 1
    Usage => 2
  }
}

///|
/// Text for a person, or one JSON object for an agent or CI.
pub(all) enum Format {
  Text
  JsonReport
} derive(Eq)

///|
#deprecated
pub extend Format with Eq::{equal, not_equal}

///|
/// What `openspec check` compares a repository with.
pub(all) enum CheckScope {
  /// The lock digests only. The result does not depend on the tool version.
  Snapshot
  /// The lock digests, the tool version in the lock and the bundle in this binary.
  Bundle
} derive(Eq)

///|
#deprecated
pub extend CheckScope with Eq::{equal, not_equal}

///|
/// A command of the `openspec` group.
pub enum OpenSpecCommand {
  Check(CheckScope, Format)
  Install
  Setup
}

///|
/// A parsed command line. Parsing happens once, before any file is read.
pub enum Command {
  Help
  Version(Format)
  OpenSpec(OpenSpecCommand, @extension.RepositoryPath)
}

///|
/// Why the arguments are not a valid use of the tools CLI.
pub suberror UsageError {
  UnknownCommand(String)
  UnknownOption(String)
  RepeatedOption(String)
  ExtraArgument(String)
  UnexpectedArgument(String)
  MissingCommand
  InvalidRepository(String)
}

///|
/// The message that follows `mission-control-tools: ` on standard error.
pub fn UsageError::message(self : UsageError) -> String {
  match self {
    UnknownCommand(name) => "unknown command '\{name}'"
    UnknownOption(name) => "unknown option '\{name}'"
    RepeatedOption(name) => "option '\{name}' is given more than one time"
    ExtraArgument(text) =>
      "expected at most one repository path, found '\{text}'"
    UnexpectedArgument(text) => "version takes no argument, found '\{text}'"
    MissingCommand => "openspec needs a command: check, install or setup"
    InvalidRepository(message) => message
  }
}

///|
/// The help text.
pub fn usage() -> String {
  [
    "Usage: mission-control-tools <command>", "", "Commands:", "  version [--json]                                 Print the tools version",
    "  openspec check [--bundle] [--json] [REPOSITORY]  Check the html-design snapshot without writing",
    "  openspec install [REPOSITORY]                    Install or update html-design and its lock",
    "  openspec setup [REPOSITORY]                      Check the snapshot and regenerate the core agent skills",
    "  help                                             Print this help", "", "REPOSITORY is the repository root. The default is the current directory.",
    "--bundle also compares the lock tool version and the files with this binary.",
  ].join("\n")
}

///|
/// Options and at most one path, in any order. `allowed` names the options that the command takes.
fn options_and_path(
  args : ArrayView[String],
  allowed : Array[String],
) -> (Array[String], String?) raise UsageError {
  let options = []
  let mut path = None
  for arg in args {
    if arg.has_prefix("-") {
      guard allowed.contains(arg) else { raise UnknownOption(arg) }
      guard !options.contains(arg) else { raise RepeatedOption(arg) }
      options.push(arg)
    } else {
      guard path is None else { raise ExtraArgument(arg) }
      path = Some(arg)
    }
  }
  (options, path)
}

///|
fn repository(path : String?) -> @extension.RepositoryPath raise UsageError {
  @extension.RepositoryPath::RepositoryPath(path.unwrap_or(".")) catch {
    error => raise InvalidRepository("\{error}")
  }
}

///|
fn format_of(options : Array[String]) -> Format {
  if options.contains("--json") {
    JsonReport
  } else {
    Text
  }
}

///|
/// Parse the arguments after the program name.
pub fn parse(args : ArrayView[String]) -> Command raise UsageError {
  match args {
    [] | ["help"] | ["--help"] | ["-h"] => Help
    ["version", .. rest] | ["--version", .. rest] => {
      let (options, path) = options_and_path(rest, ["--json"])
      if path is Some(extra) {
        raise UnexpectedArgument(extra)
      }
      Version(format_of(options))
    }
    ["openspec"] => raise MissingCommand
    ["openspec", "help" | "--help" | "-h"] => Help
    ["openspec", name, .. rest] => {
      let (command, allowed) = match name {
        "check" => (None, ["--bundle", "--json"])
        "install" => (Some(Install), [])
        "setup" => (Some(Setup), [])
        _ => raise UnknownCommand("openspec \{name}")
      }
      let (options, path) = options_and_path(rest, allowed)
      let command = match command {
        Some(command) => command
        None =>
          Check(
            if options.contains("--bundle") {
              Bundle
            } else {
              Snapshot
            },
            format_of(options),
          )
      }
      OpenSpec(command, repository(path))
    }
    [name, ..] => raise UnknownCommand(name)
  }
}

///|
/// What the shell prints and how it exits. The core decides; `main` only writes. The fields are
/// private, so only this package makes an outcome.
pub struct Outcome {
  priv stdout : Array[String]
  priv stderr : Array[String]
  priv exit_code : ExitCode
}

///|
/// A copy of the lines for standard output.
pub fn Outcome::stdout(self : Outcome) -> Array[String] {
  self.stdout.copy()
}

///|
/// A copy of the lines for standard error.
pub fn Outcome::stderr(self : Outcome) -> Array[String] {
  self.stderr.copy()
}

///|
/// The exit code.
pub fn Outcome::exit_code(self : Outcome) -> ExitCode {
  self.exit_code
}

///|
/// The prefix of problem and failure lines. It is the prefix of the bundled script, so logs and
/// documentation that search for it keep working.
let problem_prefix : String = "openspec-ext: "

///|
/// A usage error: the message and the help text on standard error, exit code 2.
pub fn usage_outcome(error : UsageError) -> Outcome {
  {
    stdout: [],
    stderr: ["mission-control-tools: \{error.message()}", usage()],
    exit_code: Usage,
  }
}

///|
/// The help text on standard output.
pub fn help_outcome() -> Outcome {
  { stdout: [usage()], stderr: [], exit_code: Success, }
}

///|
/// The version, as text or as one JSON object.
pub fn version_outcome(format : Format) -> Outcome {
  let t = tool()
  let line = match format {
    Text => "\{t.name()} \{t.version()}"
    JsonReport => {
      let json : Json = {
        "tool": t.name(),
        "version": t.version().to_string(),
        "bundle": "html-design",
      }
      json.stringify()
    }
  }
  { stdout: [line], stderr: [], exit_code: Success, }
}

///|
/// A failure with one or more message lines, each after the problem prefix.
pub fn failure_outcome(lines : Array[String]) -> Outcome {
  {
    stdout: [],
    stderr: lines.map(line => problem_prefix + line),
    exit_code: Failure,
  }
}

///|
fn problem_json(problem : @extension.Problem) -> Json {
  let fields : Map[String, Json] = { "code": Json(problem.code()) }
  if problem.path() is Some(path) {
    fields.set("path", Json(path))
  }
  fields.set("message", Json(problem.message()))
  Json(fields)
}

///|
/// A check that could not read the repository, such as a missing directory or a symlink
/// destination. In JSON the report has `"ok": false` and one problem with the code `error`.
pub fn check_error_outcome(
  repository : String,
  message : String,
  scope : CheckScope,
  format : Format,
) -> Outcome {
  match format {
    Text => failure_outcome([message])
    JsonReport => {
      let t = tool()
      let report : Json = {
        "tool": t.name(),
        "version": t.version().to_string(),
        "command": "openspec check",
        "level": match scope {
          Snapshot => "snapshot"
          Bundle => "bundle"
        },
        "repository": repository,
        "ok": false,
        "problems": [{ "code": "error", "message": message }],
      }
      { stdout: [report.stringify()], stderr: [], exit_code: Failure, }
    }
  }
}

///|
/// The outcome of a check of the repository at `root`.
pub fn check_outcome(
  root : String,
  problems : Array[@extension.Problem],
  scope : CheckScope,
  format : Format,
) -> Outcome {
  let exit_code = if problems.is_empty() { Success } else { Failure }
  match format {
    Text =>
      if problems.is_empty() {
        { stdout: ["html-design snapshot: OK"], stderr: [], exit_code, }
      } else {
        failure_outcome(problems.map(p => p.message()))
      }
    JsonReport => {
      let t = tool()
      let report : Json = {
        "tool": t.name(),
        "version": t.version().to_string(),
        "command": "openspec check",
        "level": match scope {
          Snapshot => "snapshot"
          Bundle => "bundle"
        },
        "repository": root,
        "ok": problems.is_empty(),
        "problems": Json(problems.map(problem_json)),
      }
      { stdout: [report.stringify()], stderr: [], exit_code, }
    }
  }
}

///|
/// The success line of install.
pub fn install_outcome() -> Outcome {
  let t = tool()
  {
    stdout: ["html-design: OK (\{t.name()} \{t.version()})"],
    stderr: [],
    exit_code: Success,
  }
}

///|
/// The success line of setup, which is the line of the snapshot check.
pub fn setup_outcome() -> Outcome {
  { stdout: ["html-design snapshot: OK"], stderr: [], exit_code: Success, }
}

///|
/// The check level of the extension for a scope of this CLI.
pub fn check_level(scope : CheckScope) -> @extension.CheckLevel {
  match scope {
    Snapshot => Snapshot
    Bundle => Bundle(tool())
  }
}

///|
pub impl Show for UsageError with fn output(self, logger) {
  logger.write_string(self.message())
}

///|
#deprecated
pub extend UsageError with Show::{output, to_string}
