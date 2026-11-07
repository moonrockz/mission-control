///|
/// Why an install, a check or a setup stopped. Each case gives its own message.
pub suberror InstallError {
  Symlink(String)
  LocalEdit(@extension.BundleFile)
  EditedRetired(@extension.RetiredFile)
  UnsupportedLock
  OpenSpecVersion
  SetupFailed(Int32)
  CheckFailed(Array[@extension.Problem])
}

///|
pub fn InstallError::message(self : InstallError) -> String {
  match self {
    Symlink(path) => "Refusing symlink destination: \{path}"
    LocalEdit(file) =>
      "Local or unmanaged file: \{file.path()}. Review and move it aside before installing."
    EditedRetired(file) =>
      "Edited retired file: \{file.path()}. Review it and remove it before installing."
    UnsupportedLock =>
      "Unsupported extension lock; restore it from version control"
    OpenSpecVersion => "Setup requires OpenSpec \{openspec_version}"
    SetupFailed(code) => "OpenSpec integration setup failed: \{code}"
    CheckFailed(problems) => problems.map(p => p.message()).iter().join("\n")
  }
}

///|
/// The OpenSpec CLI version that setup supports.
let openspec_version : String = "1.14.3"

///|
/// Reject symlink destinations, including dangling links and parent directories.
async fn safe_path(root : String, relative : String) -> Unit {
  let mut path = root
  for part in relative.split("/") {
    path = path + "/" + part.to_owned()
    let kind = Some(@fs.kind(path, follow_symlink=false)) catch { _ => None }
    if kind is Some(SymLink) {
      raise Symlink(path)
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
/// The result of a check: the resolved repository root and the problems, in report order.
pub struct CheckReport {
  root : String
  problems : Array[@extension.Problem]
}

///|
/// Read the lock, the config and the managed files, and check them. This never writes files.
pub async fn check(
  repository : @extension.RepositoryPath,
  level : @extension.CheckLevel,
) -> CheckReport {
  let root = @fs.realpath(repository.text())
  safe_path(root, @extension.lock_path)
  safe_path(root, @extension.config_path)
  let texts = []
  for file in @extension.files() {
    safe_path(root, file.path())
    texts.push((file, read_optional("\{root}/\{file.path()}")))
  }
  let problems = @extension.check_snapshot(
    lock=read_optional("\{root}/\{@extension.lock_path}"),
    config=read_optional("\{root}/\{@extension.config_path}"),
    file=wanted => {
      for entry in texts {
        if entry.0 == wanted {
          break entry.1
        }
      } nobreak {
        None
      }
    },
    level~,
  )
  { root, problems, }
}

///|
/// Preflight all ownership and config checks before writing any destination.
/// A failed I/O write leaves the old lock in place; rerunning repairs partial installs.
pub async fn install(
  repository : @extension.RepositoryPath,
  tool : @extension.Tool,
) -> Unit {
  let root = @fs.realpath(repository.text())
  for
    relative in [
      @extension.config_path,
      @extension.lock_path,
      "\{@extension.lock_path}.next",
      "openspec/specs",
      "openspec/changes/archive",
    ] {
    safe_path(root, relative)
  }
  let config_file = "\{root}/\{@extension.config_path}"
  let config = match read_optional(config_file) {
    Some(source) => @extension.configure(source)
    None => @extension.initial_config()
  }
  let previous = match read_optional("\{root}/\{@extension.lock_path}") {
    None => None
    Some(text) =>
      match @extension.parse_lock(text) {
        Some(lock) => Some(lock)
        None => raise UnsupportedLock
      }
  }
  for file in @extension.files() {
    safe_path(root, file.path())
    guard @extension.can_replace(
      file,
      read_optional("\{root}/\{file.path()}"),
      previous.bind(lock => lock.files().get(file.path())),
    ) else {
      raise LocalEdit(file)
    }
  }
  let retire = []
  for file in @extension.retired_files() {
    safe_path(root, file.path())
    match
      @extension.retirement(
        file,
        read_optional("\{root}/\{file.path()}"),
        previous,
      ) {
      Delete => retire.push(file)
      Edited => raise EditedRetired(file)
      Absent | Unmanaged => ()
    }
  }
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
  if read_optional(config_file) != Some(config) {
    @fs.write_file(config_file, config)
  }
  // Retired files go after the managed writes and before the lock: a rerun after an
  // interruption still finds the previous lock and repeats the same decisions.
  for file in retire {
    @fs.remove("\{root}/\{file.path()}")
  }
  // Commit the ownership record last, so a failed write cannot certify a partial install.
  let lock = @extension.lock_text(tool)
  if read_optional("\{root}/\{@extension.lock_path}") != Some(lock) {
    let next = "\{root}/\{@extension.lock_path}.next"
    @fs.write_file(next, lock)
    @fs.rename(next, "\{root}/\{@extension.lock_path}", replace=true)
  }
}

///|
/// The global OpenSpec preferences that setup uses, whatever the user's own preferences are.
pub fn setup_preferences() -> Json {
  {
    "profile": "core",
    "delivery": "skills",
    "telemetry": { "noticeSeen": true },
  }
}

///|
/// Own the lifetime of a temporary configuration directory and pass it explicitly to
/// `run_init` as its home and its environment. The directory is removed after `run_init` returns.
pub async fn isolated_init(
  run_init : async (String, Map[String, String]) -> Int32,
) -> Unit {
  let home = @fs.tmpdir(prefix="openspec-ext")
  defer @fs.rmdir(home, recursive=true)
  @fs.mkdir("\{home}/openspec")
  @fs.write_file(
    "\{home}/openspec/config.json",
    setup_preferences().stringify(),
  )
  let code = run_init(home, {
    "XDG_CONFIG_HOME": home,
    "OPENSPEC_TELEMETRY": "0",
  })
  guard code == 0 else { raise SetupFailed(code) }
}

///|
/// The agents that setup generates skills for.
let setup_tools : String = "agents,codex,claude,github-copilot,cursor,grok,gemini,opencode"

///|
/// Check the snapshot, require the supported OpenSpec CLI, and generate the core skills with
/// isolated preferences. User preferences are untouched. Setup does not install.
pub async fn setup(repository : @extension.RepositoryPath) -> Unit {
  let report = check(repository, Snapshot)
  guard report.problems.is_empty() else { raise CheckFailed(report.problems) }
  let root = report.root
  let (code, output, _) = @process.collect_output(
    "openspec",
    ["--version"],
    cwd=root,
  ) catch {
    _ => raise OpenSpecVersion
  }
  guard code == 0 && output.text().trim() == openspec_version else {
    raise OpenSpecVersion
  }
  isolated_init(async fn(_, environment) {
    @process.run(
      "openspec",
      ["init", "--tools", setup_tools, "--profile", "core", "--no-animation"],
      cwd=root,
      extra_env=environment,
      stdout=@stdio.stdout,
      stderr=@stdio.stderr,
    )
  })
}

///|
pub impl Show for InstallError with fn output(self, logger) {
  logger.write_string(self.message())
}

///|
#deprecated
pub extend InstallError with Show::{output, to_string}
