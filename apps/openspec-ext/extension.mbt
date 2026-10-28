///|
pub suberror ExtensionError {
  InvalidArguments(String)
  InvalidConfig(String)
  InvalidDigest(String)
}

///|
/// An explicitly supplied repository location, with no NUL or line breaks.
pub struct RepositoryPath {
  value : String
}

///|
pub fn RepositoryPath::RepositoryPath(
  value : String,
) -> RepositoryPath raise ExtensionError {
  guard !value.is_empty() &&
    !value.contains("\u{0000}") &&
    !value.contains("\n") &&
    !value.contains("\r") else {
    raise InvalidArguments(
      "Repository path must be nonempty and contain no NUL or line breaks",
    )
  }
  { value, }
}

///|
pub fn RepositoryPath::text(self : RepositoryPath) -> String {
  self.value
}

///|
pub enum Operation {
  Install
  Check
  Setup
}

///|
pub enum Command {
  Help
  Version
  Repository(Operation, RepositoryPath)
}

///|
pub fn parse_command(args : ArrayView[String]) -> Command raise ExtensionError {
  match args {
    [] | ["help"] | ["--help"] | ["-h"] => Help
    ["version"] | ["--version"] => Version
    [name, .. rest] => {
      let operation = match name {
        "install" => Install
        "check" => Check
        "setup" => Setup
        _ => raise InvalidArguments("Unknown command: \{name}")
      }
      let path = match rest {
        [] => "."
        [path] if !path.has_prefix("-") => path
        _ => raise InvalidArguments("Expected at most one repository path")
      }
      Repository(operation, RepositoryPath(path))
    }
  }
}

///|
pub fn version() -> String {
  @contracts.version().to_string()
}

///|
pub fn usage() -> String {
  "Usage: openspec-ext install|check|setup [repository]\n       openspec-ext version\n\ninstall  Install or update html-design; preserve project context and rules\ncheck    Check managed files, lock and default schema without writing\nsetup    Install html-design and regenerate the core agent skills"
}

///|
/// A canonical lower-case SHA-256 digest, parsed once at the lock boundary.
pub struct FileDigest {
  value : String
} derive(Eq)

///|
pub fn FileDigest::FileDigest(
  value : String,
) -> FileDigest raise ExtensionError {
  guard value.length() == 64 &&
    value.iter().all(c => (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')) else {
    raise InvalidDigest("Expected 64 lower-case hexadecimal SHA-256 characters")
  }
  { value, }
}

///|
pub fn FileDigest::text(self : FileDigest) -> String {
  self.value
}

///|
#deprecated
pub extend FileDigest with Eq::{equal, not_equal}

///|
pub fn digest(text : String) -> FileDigest {
  { value: @crypto.bytes_to_hex_string(@crypto.sha256(@utf8.encode(text))), }
}

///|
/// Select html-design while preserving the original config's comments and other values.
/// Unsupported YAML layouts are refused before any file is written.
pub fn configure(source : String) -> String raise ExtensionError {
  let documents = @yaml.Yaml::load_from_string(source) catch {
    _ => raise InvalidConfig("Invalid OpenSpec YAML")
  }
  let values = match documents {
    [Map(values)] => values.copy()
    _ => raise InvalidConfig("OpenSpec config must be one YAML mapping")
  }
  if values.get("schema") == Some(@yaml.Yaml::String("html-design")) {
    return source
  }
  let lines = source.split("\n").map(l => l.to_owned()).collect()
  let mut found = false
  for i, line in lines {
    if line.has_prefix("schema:") {
      guard !found else { raise InvalidConfig("Duplicate schema keys") }
      lines[i] = "schema: html-design" +
        (if line.has_suffix("\r") { "\r" } else { "" })
      found = true
    }
  }
  let result = if found {
    lines.join("\n")
  } else {
    guard values.get("schema") is None else {
      raise InvalidConfig(
        "Put the schema key on its own unquoted line before installing",
      )
    }
    if source.has_prefix("---\n") {
      "---\nschema: html-design\n" + source[4:].to_owned()
    } else {
      "schema: html-design\n" + source
    }
  }
  values.set("schema", @yaml.Yaml::String("html-design"))
  let parsed = @yaml.Yaml::load_from_string(result) catch {
    _ => raise InvalidConfig("Cannot safely select schema")
  }
  guard parsed == [@yaml.Yaml::Map(values)] else {
    raise InvalidConfig(
      "Cannot change schema without changing project configuration",
    )
  }
  result
}

///|
pub fn initial_config() -> String {
  "schema: html-design\ngithubCopilot:\n  cloudAgent: false\ncontext: |\n  Follow AGENTS.md and README.md for repository conventions and local tracking.\n"
}

///|
/// Refuse to replace a pre-existing unowned file or a locally edited managed file.
pub fn can_replace(
  file : BundleFile,
  current : String?,
  previous_digest : FileDigest?,
) -> Bool {
  match current {
    None => true
    Some(text) =>
      text == file.content() || previous_digest == Some(digest(text))
  }
}

///|
pub fn lock_text() -> String {
  let hashes : Map[String, Json] = Map([])
  for file in files() {
    hashes.set(file.path(), Json(digest(file.content()).text()))
  }
  let lock : Json = {
    "format": 1,
    "extension": "html-design",
    "module": "moonrockz/openspec-ext",
    "version": version(),
    "files": Json(hashes),
  }
  lock.stringify(indent=2) + "\n"
}

///|
pub impl Show for ExtensionError with fn output(self, logger) {
  match self {
    InvalidArguments(message)
    | InvalidConfig(message)
    | InvalidDigest(message) => logger.write_string(message)
  }
}

///|
#deprecated
pub extend ExtensionError with Show::{output, to_string}
