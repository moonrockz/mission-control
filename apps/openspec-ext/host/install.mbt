///|
pub suberror InstallError {
  Conflict(String)
  InvalidLock(String)
  SetupFailed(Int32)
}

///|
let lock_path : String = "openspec/extensions.lock.json"

///|
/// Reject symlink destinations, including dangling links and parent directories.
async fn safe_path(root : String, relative : String) -> Unit {
  let mut path = root
  for part in relative.split("/") {
    path = path + "/" + part.to_owned()
    let kind = Some(@fs.kind(path, follow_symlink=false)) catch { _ => None }
    if kind is Some(SymLink) {
      raise Conflict("Refusing symlink destination: \{path}")
    }
  }
}

///|
async fn read_optional(path : String) -> String? {
  if @fs.exists(path) {
    Some(@fs.read_file(path).text())
  } else {
    None
  }
}

///|
fn previous_hashes(text : String?) -> Map[String, @extension.FileDigest] raise {
  guard text is Some(text) else { return Map([]) }
  let lock = @json.parse(text)
  guard lock
    is {
      "format": 1,
      "extension": "html-design",
      "module": "moonrockz/openspec-ext",
      "version": String(_),
      "files": Object(hashes),
      ..
    } else {
    raise InvalidLock(
      "Unsupported extension lock; restore it from version control",
    )
  }
  let result = Map([])
  for file in @extension.files() {
    if hashes.get(file.path()) is None {
      continue
    }
    guard hashes.get(file.path()) is Some(String(hash)) else {
      raise InvalidLock("Missing digest for \{file.path()}")
    }
    result.set(file.path(), @extension.FileDigest(hash))
  }
  result
}

///|
/// Preflight all ownership and config checks before writing any destination.
/// A failed I/O write leaves the old lock in place; rerunning repairs partial installs.
pub async fn install(repository : @extension.RepositoryPath) -> Unit {
  let root = @fs.realpath(repository.text())
  for
    relative in [
      "openspec/config.yaml", lock_path, "openspec/extensions.lock.json.next", "openspec/specs",
      "openspec/changes/archive",
    ] {
    safe_path(root, relative)
  }
  let config_path = "\{root}/openspec/config.yaml"
  let config = match read_optional(config_path) {
    Some(source) => @extension.configure(source)
    None => @extension.initial_config()
  }
  let previous = previous_hashes(read_optional("\{root}/\{lock_path}"))
  for file in @extension.files() {
    safe_path(root, file.path())
    guard @extension.can_replace(
      file,
      read_optional("\{root}/\{file.path()}"),
      previous.get(file.path()),
    ) else {
      raise Conflict(
        "Local or unmanaged file: \{file.path()}. Review and move it aside before installing.",
      )
    }
  }
  @fs.mkdir("\{root}/scripts", recursive=true, allow_exist=true)
  @fs.mkdir(
    "\{root}/openspec/schemas/html-design/templates",
    recursive=true,
    allow_exist=true,
  )
  @fs.mkdir("\{root}/openspec/specs", recursive=true, allow_exist=true)
  @fs.mkdir(
    "\{root}/openspec/changes/archive",
    recursive=true,
    allow_exist=true,
  )
  for file in @extension.files() {
    let destination = "\{root}/\{file.path()}"
    if read_optional(destination) != Some(file.content()) {
      @fs.write_file(destination, file.content())
    }
  }
  if read_optional(config_path) != Some(config) {
    @fs.write_file(config_path, config)
  }
  // Commit the ownership record last, so a failed write cannot certify a partial install.
  if read_optional("\{root}/\{lock_path}") != Some(@extension.lock_text()) {
    let next = "\{root}/\{lock_path}.next"
    @fs.write_file(next, @extension.lock_text())
    @fs.rename(next, "\{root}/\{lock_path}", replace=true)
  }
}

///|
/// Verify the pinned bundle and config. This operation never writes files.
pub async fn check(repository : @extension.RepositoryPath) -> Unit {
  let root = @fs.realpath(repository.text())
  safe_path(root, lock_path)
  let lock = read_optional("\{root}/\{lock_path}")
  let _ = previous_hashes(lock)
  guard lock == Some(@extension.lock_text()) else {
    raise Conflict(
      "Extension lock differs from openspec-ext \{@extension.version()}; run install with the intended version",
    )
  }
  for file in @extension.files() {
    safe_path(root, file.path())
    guard read_optional("\{root}/\{file.path()}") == Some(file.content()) else {
      raise Conflict("Extension drift: \{file.path()}")
    }
  }
  safe_path(root, "openspec/config.yaml")
  guard read_optional("\{root}/openspec/config.yaml") is Some(config) &&
    @extension.configure(config) == config else {
    raise Conflict("Project default schema must be html-design")
  }
}

///|
/// Generate skills with an isolated global config, leaving user preferences untouched.
pub async fn setup(repository : @extension.RepositoryPath) -> Unit {
  let root = @fs.realpath(repository.text())
  let (version_code, output, _) = @process.collect_output(
    "openspec",
    ["--version"],
    cwd=root,
  )
  guard version_code == 0 && output.text().trim() == "1.14.3" else {
    raise Conflict(
      "setup requires OpenSpec 1.14.3; pin npm:@fission-ai/openspec in mise",
    )
  }
  install(repository)
  let code = @process.run(
    "moon",
    ["run", "--target", "wasm", "scripts/openspec-ext.mbtx", "--", "setup"],
    cwd=root,
    stdout=@stdio.stdout,
    stderr=@stdio.stderr,
  )
  guard code == 0 else { raise SetupFailed(code) }
}

///|
pub impl Show for InstallError with fn output(self, logger) {
  match self {
    Conflict(message) | InvalidLock(message) => logger.write_string(message)
    SetupFailed(code) =>
      logger.write_string(
        "OpenSpec integration setup failed with exit code \{code}",
      )
  }
}

///|
#deprecated
pub extend InstallError with Show::{output, to_string}
