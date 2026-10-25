///|
/// A command the CLI, the web UI and the desktop shell all understand.
pub(all) enum Command {
  Help
  Version
} derive(Eq, Debug)

///|
/// Raised when a text names no command.
pub(all) suberror CommandError {
  /// The text is not the name or an alias of a command.
  UnknownCommand(String)
} derive(Eq, Debug)

///|
/// Every command, in the order that the help text lists them.
pub let commands : ReadOnlyArray[Command] = [Help, Version]

///|
/// Reads a command name. `--help`, `-h`, `--version` and `-V` are accepted.
pub fn Command::Command(name : String) -> Command raise CommandError {
  match name {
    "help" | "--help" | "-h" => Help
    "version" | "--version" | "-V" => Version
    _ => raise UnknownCommand(name)
  }
}

///|
/// The name of the command on the command line.
pub fn Command::name(self : Command) -> String {
  match self {
    Help => "help"
    Version => "version"
  }
}

///|
/// The ID of the Proton command that the desktop shell exposes.
pub fn Command::proton_id(self : Command) -> String {
  "mission-control." + self.name()
}

///|
/// One line that describes the command in the help text.
pub fn Command::description(self : Command) -> String {
  match self {
    Help => "Print this help"
    Version => "Print the version"
  }
}

///|
/// Raised when a text is not a version.
pub(all) suberror VersionError {
  /// The text is not three non-negative integers joined with `.`, without
  /// leading zeros.
  InvalidVersion(String)
} derive(Eq, Debug)

///|
/// A version such as `0.0.2`: three non-negative integer parts.
struct Version {
  major : Int32
  minor : Int32
  patch : Int32
} derive(Eq, Compare, Hash, Debug)

///|
/// Parses `X.Y.Z`. Each part is a non-negative integer with at most nine
/// digits and no leading zero.
pub fn Version::Version(text : String) -> Version raise VersionError {
  let parts = text.split(".").map(p => p.to_owned()).collect()
  guard parts.length() == 3 else { raise InvalidVersion(text) }
  let numbers = []
  for part in parts {
    let ok = part.length() > 0 &&
      part.length() <= 9 &&
      part.iter().all(c => c >= '0' && c <= '9') &&
      !(part.length() > 1 && part.has_prefix("0"))
    guard ok else { raise InvalidVersion(text) }
    let mut n = 0
    for c in part {
      n = n * 10 + (c.to_int() - '0'.to_int())
    }
    numbers.push(n)
  }
  { major: numbers[0], minor: numbers[1], patch: numbers[2], }
}

///|
pub fn Version::major(self : Version) -> Int32 {
  self.major
}

///|
pub fn Version::minor(self : Version) -> Int32 {
  self.minor
}

///|
pub fn Version::patch(self : Version) -> Int32 {
  self.patch
}

///|
pub fn Version::to_string(self : Version) -> String {
  "\{self.major}.\{self.minor}.\{self.patch}"
}

///|
pub impl Show for Version with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
/// The version text of this module. `scripts/versions.mbtx` sets it to the
/// workspace version.
let current_version : String = "0.1.0"

///|
/// The version of this module. It matches the workspace version.
pub fn Version::current() -> Version {
  // A test checks that the text above parses.
  Version::Version(current_version) catch {
    _ => abort("the contract version is not a version: \{current_version}")
  }
}

///|
/// The version of this module. It matches the workspace version.
pub fn version() -> Version {
  Version::current()
}

///|
pub extend Command with Eq::{not_equal, equal}

///|
pub extend Command with @debug.Debug::{to_repr}

///|
pub extend CommandError with Eq::{not_equal, equal}

///|
pub extend CommandError with @debug.Debug::{to_repr}

///|
pub extend VersionError with Eq::{not_equal, equal}

///|
pub extend VersionError with @debug.Debug::{to_repr}

///|
pub extend Version with Eq::{not_equal, equal}

///|
pub extend Version with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend Version with Hash::{hash, hash_combine}

///|
pub extend Version with @debug.Debug::{to_repr}

///|
pub extend Version with Show::{output}
