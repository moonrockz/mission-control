///|
pub suberror ExtensionError {
  InvalidPath(String)
  InvalidConfig(String)
  InvalidDigest(String)
  InvalidTool(String)
}

///|
/// An explicitly supplied repository location, with no NUL or line breaks.
pub struct RepositoryPath {
  priv value : String
}

///|
pub fn RepositoryPath::RepositoryPath(
  value : String,
) -> RepositoryPath raise ExtensionError {
  guard !value.is_empty() &&
    !value.contains("\u{0000}") &&
    !value.contains("\n") &&
    !value.contains("\r") else {
    raise InvalidPath(
      "Repository path must be nonempty and contain no NUL or line breaks",
    )
  }
  { value, }
}

///|
/// The path as the user gave it.
pub fn RepositoryPath::text(self : RepositoryPath) -> String {
  self.value
}

///|
/// The tool that writes and checks a lock: a module name `owner/name` and its version.
pub struct Tool {
  priv module_name : String
  priv version : @contracts.Version
} derive(Eq)

///|
#deprecated
pub extend Tool with Eq::{equal, not_equal}

///|
/// `module_name` is `owner/name`, each part lower-case letters, digits and `-`, not empty.
pub fn Tool::Tool(
  module_name : String,
  version : @contracts.Version,
) -> Tool raise ExtensionError {
  let parts = module_name.split("/").map(p => p.to_owned()).collect()
  let valid_part = (part : String) => {
    !part.is_empty() &&
    part
    .iter()
    .all(c => (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-')
  }
  guard parts.length() == 2 && parts.iter().all(valid_part) else {
    raise InvalidTool(
      "Tool module must be owner/name with lower-case letters, digits and -: \{module_name}",
    )
  }
  { module_name, version, }
}

///|
/// The module name, such as `moonrockz/mission-control-tools`.
pub fn Tool::module_name(self : Tool) -> String {
  self.module_name
}

///|
/// The last part of the module name, which is also the executable name.
pub fn Tool::name(self : Tool) -> String {
  match self.module_name.rev_find("/") {
    Some(i) => self.module_name[i + 1:].to_owned()
    None => self.module_name
  }
}

///|
/// The version of the tool.
pub fn Tool::version(self : Tool) -> @contracts.Version {
  self.version
}

///|
/// A canonical lower-case SHA-256 digest, parsed once at the lock boundary.
pub struct FileDigest {
  priv value : String
} derive(Eq)

///|
#deprecated
pub extend FileDigest with Eq::{equal, not_equal}

///|
/// Parse 64 lower-case hexadecimal characters.
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
/// The 64 hexadecimal characters.
pub fn FileDigest::text(self : FileDigest) -> String {
  self.value
}

///|
/// The SHA-256 of the UTF-8 bytes of `text`.
pub fn digest(text : String) -> FileDigest {
  { value: @crypto.bytes_to_hex_string(@crypto.sha256(@utf8.encode(text))), }
}

///|
/// A file that an earlier bundle managed and the current bundle does not. Install deletes it
/// when it still has the digest of the previous lock. Only these fixed paths are ever deleted,
/// whatever other paths a lock names.
pub(all) enum RetiredFile {
  Script
  ScriptFeature
} derive(Eq)

///|
#deprecated
pub extend RetiredFile with Eq::{equal, not_equal}

///|
/// Every retired file, in a fixed order.
pub fn retired_files() -> Array[RetiredFile] {
  [Script, ScriptFeature]
}

///|
/// The fixed repository-relative path of the retired file.
pub fn RetiredFile::path(self : RetiredFile) -> String {
  match self {
    Script => "scripts/openspec-ext.mbtx"
    ScriptFeature => "scripts/features/openspec_ext.feature"
  }
}

///|
/// The digests that a lock records, by repository-relative path. The map is private, so a
/// lock cannot change after the parse.
pub struct LockedFiles {
  priv digests : Map[String, FileDigest]
}

///|
/// The digest that the lock records for `path`, if any.
pub fn LockedFiles::get(self : LockedFiles, path : String) -> FileDigest? {
  self.digests.get(path)
}

///|
/// The number of recorded digests.
pub fn LockedFiles::length(self : LockedFiles) -> Int32 {
  self.digests.length()
}

///|
/// A parsed ownership lock.
pub enum Lock {
  /// Format 1, written by `moonrockz/openspec-ext` with the bundled script.
  Legacy(LockedFiles)
  /// Format 2, written by a tool that it names.
  Current(Tool, LockedFiles)
}

///|
/// The digests of either format.
pub fn Lock::files(self : Lock) -> LockedFiles {
  match self {
    Legacy(files) | Current(_, files) => files
  }
}

///|
/// The repository-relative path of the ownership lock.
pub let lock_path : String = "openspec/extensions.lock.json"

///|
/// The repository-relative path of the OpenSpec project config.
pub let config_path : String = "openspec/config.yaml"

///|
/// Why lock text is not a supported lock. Each case names the rule that the text breaks.
pub suberror LockError {
  /// The text is not JSON.
  Syntax
  /// The JSON is not an object, or a required field is missing or has another type.
  MissingField(String)
  /// The `format` is not 1 or 2.
  UnknownFormat(String)
  /// The `extension` is not `html-design`.
  WrongExtension(String)
  /// A format 1 lock names another module than `moonrockz/openspec-ext`.
  WrongModule(String)
  /// A format 2 lock names a tool that is not `owner/name`.
  InvalidToolName(String)
  /// The `version` is not `X.Y.Z`.
  InvalidVersion(String)
  /// The digest of this path is not a lower-case SHA-256.
  InvalidDigest(String)
}

///|
/// A message that names the rule.
pub fn LockError::message(self : LockError) -> String {
  match self {
    Syntax => "the lock is not JSON"
    MissingField(name) => "the lock has no valid field `\{name}`"
    UnknownFormat(text) => "the lock format \{text} is not 1 or 2"
    WrongExtension(text) => "the lock extension \{text} is not html-design"
    WrongModule(text) =>
      "the format 1 lock module \{text} is not moonrockz/openspec-ext"
    InvalidToolName(text) => "the lock tool \{text} is not owner/name"
    InvalidVersion(text) => "the lock version \{text} is not X.Y.Z"
    InvalidDigest(path) => "the lock digest of \{path} is not a SHA-256"
  }
}

///|
pub impl Show for LockError with fn output(self, logger) {
  logger.write_string(self.message())
}

///|
#deprecated
pub extend LockError with Show::{output, to_string}

///|
fn string_field(
  fields : Map[String, Json],
  name : String,
) -> String raise LockError {
  match fields.get(name) {
    Some(String(text)) => text
    _ => raise MissingField(name)
  }
}

///|
fn locked_files(fields : Map[String, Json]) -> LockedFiles raise LockError {
  guard fields.get("files") is Some(Object(hashes)) else {
    raise MissingField("files")
  }
  let digests = Map([])
  for path, value in hashes {
    guard value is String(text) else { raise InvalidDigest(path) }
    let parsed = FileDigest(text) catch { _ => raise InvalidDigest(path) }
    digests.set(path, parsed)
  }
  { digests, }
}

///|
/// Parse lock text at the boundary into a format 1 or a format 2 lock.
pub fn parse_lock(text : String) -> Lock raise LockError {
  let json = @json.parse(text) catch { _ => raise Syntax }
  guard json is Object(fields) else { raise MissingField("format") }
  let legacy = match fields.get("format") {
    Some(Number(1.0, ..)) => true
    Some(Number(2.0, ..)) => false
    Some(other) => raise UnknownFormat(other.stringify())
    None => raise MissingField("format")
  }
  let extension = string_field(fields, "extension")
  guard extension == "html-design" else { raise WrongExtension(extension) }
  let version = string_field(fields, "version")
  if legacy {
    let module_name = string_field(fields, "module")
    guard module_name == "moonrockz/openspec-ext" else {
      raise WrongModule(module_name)
    }
    Legacy(locked_files(fields))
  } else {
    let module_name = string_field(fields, "tool")
    let parsed = @contracts.Version::Version(version) catch {
      _ => raise InvalidVersion(version)
    }
    let tool = Tool(module_name, parsed) catch {
      _ => raise InvalidToolName(module_name)
    }
    Current(tool, locked_files(fields))
  }
}

///|
/// The format 2 lock that `tool` writes for this bundle.
pub fn lock_text(tool : Tool) -> String {
  let hashes : Map[String, Json] = Map([])
  for file in files() {
    hashes.set(file.path(), Json(digest(file.content()).text()))
  }
  let lock : Json = {
    "format": 2,
    "extension": "html-design",
    "tool": tool.module_name,
    "version": tool.version.to_string(),
    "files": Json(hashes),
  }
  lock.stringify(indent=2) + "\n"
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
/// The config that install writes into a repository that has none.
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
/// What a retired file needs at install time.
pub enum Retirement {
  /// The file is absent: nothing to do.
  Absent
  /// The file still has the digest of the previous lock: delete it.
  Delete
  /// The file differs from the digest of the previous lock: keep it and stop before any write.
  Edited
  /// No previous lock records the file, so the bundle never owned it: leave it alone.
  Unmanaged
}

///|
/// Decide what install does with `file`, from its current text and the previous lock.
pub fn retirement(
  file : RetiredFile,
  current : String?,
  previous : Lock?,
) -> Retirement {
  match current {
    None => Absent
    Some(text) =>
      match previous.bind(lock => lock.files().get(file.path())) {
        None => Unmanaged
        Some(recorded) => if recorded == digest(text) { Delete } else { Edited }
      }
  }
}

///|
/// An input of a check: the lock, the project config, or a managed file.
pub enum Input {
  LockFile
  Config
  Managed(BundleFile)
} derive(Eq)

///|
#deprecated
pub extend Input with Eq::{equal, not_equal}

///|
/// The repository-relative path of the input.
pub fn Input::path(self : Input) -> String {
  match self {
    LockFile => lock_path
    Config => config_path
    Managed(file) => file.path()
  }
}

///|
/// What a check compares the repository with.
pub(all) enum CheckLevel {
  /// The lock digests only, as the bundled script did. Independent of the tool version.
  Snapshot
  /// The lock digests, then the tool and the bundle of this tool.
  Bundle(Tool)
}

///|
/// One problem that a check found.
pub enum Problem {
  MissingFile(Input)
  UnsupportedLock
  LegacyLock
  FileSet
  MissingDigest(BundleFile)
  Drift(BundleFile)
  Schema
  ToolVersion(recorded~ : Tool, expected~ : Tool)
  BundleDrift(BundleFile, Tool)
}

///|
/// A stable code for JSON reports.
pub fn Problem::code(self : Problem) -> String {
  match self {
    MissingFile(_) => "missing-file"
    UnsupportedLock => "unsupported-lock"
    LegacyLock => "legacy-lock"
    FileSet => "file-set"
    MissingDigest(_) => "missing-digest"
    Drift(_) => "drift"
    Schema => "schema"
    ToolVersion(..) => "tool-version"
    BundleDrift(_, _) => "bundle-drift"
  }
}

///|
/// The repository-relative path that the problem is about, if there is one.
pub fn Problem::path(self : Problem) -> String? {
  match self {
    MissingFile(input) => Some(input.path())
    UnsupportedLock | LegacyLock | FileSet | ToolVersion(..) => Some(lock_path)
    MissingDigest(file) | Drift(file) | BundleDrift(file, _) =>
      Some(file.path())
    Schema => Some(config_path)
  }
}

///|
/// The message. The texts of the bundled script are kept without its source location.
pub fn Problem::message(self : Problem) -> String {
  match self {
    MissingFile(input) => "Missing file: \{input.path()}"
    UnsupportedLock => "Unsupported extension lock"
    LegacyLock =>
      "Extension lock format 1 is from the bundled script. Run mission-control-tools openspec install."
    FileSet => "Unexpected extension file set"
    MissingDigest(file) => "Missing digest: \{file.path()}"
    Drift(file) => "Extension drift: \{file.path()}"
    Schema => "Default schema must be html-design"
    ToolVersion(recorded~, expected~) =>
      "Extension lock records \{recorded.name()} \{recorded.version}; this is \{expected.name()} \{expected.version}. Run \{expected.name()} openspec install."
    BundleDrift(file, tool) =>
      "Bundle drift: \{file.path()} differs from \{tool.name()} \{tool.version}"
  }
}

///|
fn schema_is_html_design(config : String) -> Bool {
  let documents = @yaml.Yaml::load_from_string(config) catch {
    _ => return false
  }
  documents is [Map(values)] &&
  values.get("schema") is Some(String("html-design"))
}

///|
/// Check a snapshot from the texts that the host read. `None` is a missing file. The problems
/// come in a fixed order: lock, managed files in bundle order, config. A missing managed file is
/// reported even when the lock is missing or cannot be read. The function reads no files.
pub fn check_snapshot(
  lock~ : String?,
  config~ : String?,
  file~ : (BundleFile) -> String?,
  level~ : CheckLevel,
) -> Array[Problem] {
  let problems = []
  let parsed = match lock {
    None => {
      problems.push(MissingFile(LockFile))
      None
    }
    Some(text) =>
      try parse_lock(text) catch {
        _ => {
          problems.push(UnsupportedLock)
          None
        }
      } noraise {
        Legacy(_) => {
          problems.push(LegacyLock)
          None
        }
        Current(tool, locked) => Some((tool, locked))
      }
  }
  // The lock is needed only to compare digests. A missing managed file is reported whatever the lock is.
  let (locked, bundle) = match parsed {
    None => (None, None)
    Some((recorded, locked)) => {
      // After a tool mismatch, every changed template would also differ from this bundle.
      // The mismatch alone says what to do, so bundle drift is reported only for the same tool.
      let bundle = match level {
        Bundle(expected) if recorded != expected => {
          problems.push(ToolVersion(recorded~, expected~))
          None
        }
        Bundle(expected) => Some(expected)
        Snapshot => None
      }
      if locked.length() != files().length() {
        problems.push(FileSet)
      }
      (Some(locked), bundle)
    }
  }
  for managed in files() {
    let recorded = locked.bind(l => l.get(managed.path()))
    if locked is Some(_) && recorded is None {
      problems.push(MissingDigest(managed))
    }
    match (file(managed), recorded) {
      (None, _) => problems.push(MissingFile(Managed(managed)))
      (Some(_), None) => ()
      (Some(text), Some(expected)) =>
        if digest(text) != expected {
          problems.push(Drift(managed))
        } else if bundle is Some(tool) && text != managed.content() {
          problems.push(BundleDrift(managed, tool))
        }
    }
  }
  match config {
    None => problems.push(MissingFile(Config))
    Some(text) => if !schema_is_html_design(text) { problems.push(Schema) }
  }
  problems
}

///|
pub impl Show for ExtensionError with fn output(self, logger) {
  match self {
    InvalidPath(message)
    | InvalidConfig(message)
    | InvalidDigest(message)
    | InvalidTool(message) => logger.write_string(message)
  }
}

///|
#deprecated
pub extend ExtensionError with Show::{output, to_string}
