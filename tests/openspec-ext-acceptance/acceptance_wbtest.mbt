///|
fn tool(version : String) -> @extension.Tool raise {
  @extension.Tool::Tool(
    "moonrockz/mission-control-tools",
    @contracts.Version::Version(version),
  )
}

///|
struct ExtensionWorld {
  mut source : String
  mut result : String
  mut replace_allowed : Bool
}

///|
impl @moonspec.World for ExtensionWorld with fn configure(self, setup) {
  setup.given0("a repository with its own OpenSpec context and task rules", () => {
    self.source = "# local policy\nschema: spec-driven\ncontext: |\n  Keep project policy.\nrules:\n  tasks:\n    - Use the local tracker.\n"
  })
  setup.when0("the HTML design extension selects its schema", () => {
    self.result = @extension.configure(self.source)
  })
  setup.then0(
    "the schema is html-design and the repository policy is unchanged",
    () => {
      @expect.expect(self.result).to_equal(
        self.source.replace(
          old="schema: spec-driven",
          new="schema: html-design",
        ),
      )
    },
  )
  setup.given0("a locally customized HTML design template", () => {
    self.source = "custom repository design"
  })
  setup.when0("the extension checks whether it can replace the template", () => {
    self.replace_allowed = @extension.can_replace(
      @extension.BundleFile::Design,
      Some(self.source),
      None,
    )
  })
  setup.then0("the local template must be kept", () => {
    @expect.expect(self.replace_allowed).to_be_false()
  })
}

///|
/// The texts of one snapshot. Each scenario edits its own copy.
struct SnapshotWorld {
  mut lock : String?
  mut config : String?
  files : Map[String, String]
  mut problems : Array[String]
}

///|
fn SnapshotWorld::read(
  self : SnapshotWorld,
  file : @extension.BundleFile,
) -> String? {
  self.files.get(file.path())
}

///|
fn SnapshotWorld::check(
  self : SnapshotWorld,
  level : @extension.CheckLevel,
) -> Unit {
  self.problems = @extension.check_snapshot(
    lock=self.lock,
    config=self.config,
    file=file => self.read(file),
    level~,
  ).map(p => p.message())
}

///|
/// Remove one entry from the `files` object of a lock, or add one.
fn edit_lock_files(
  lock : String,
  edit : (Map[String, Json]) -> Unit,
) -> String raise {
  guard @json.parse(lock) is Object(fields) &&
    fields.get("files") is Some(Object(files)) else {
    fail("the lock has no files object")
  }
  edit(files)
  Json::object(fields).stringify(indent=2) + "\n"
}

///|
impl @moonspec.World for SnapshotWorld with fn configure(self, setup) {
  setup.given1("a snapshot installed by tools version {string}", (
    version : String,
  ) => {
    self.lock = Some(@extension.lock_text(tool(version)))
    self.config = Some("schema: html-design\ncontext: Local context\n")
    for file in @extension.files() {
      self.files.set(file.path(), file.content())
    }
  })
  setup.given1("the snapshot has {string}", (condition : String) => {
    let design = @extension.BundleFile::Design.path()
    match condition {
      "no change" => ()
      "edited template" => self.files.set(design, "Local edit")
      "deleted template" =>
        self.files.remove(@extension.BundleFile::Tasks.path())
      "wrong schema" => self.config = Some("schema: spec-driven\n")
      "malformed config" => self.config = Some("schema: [broken")
      "malformed lock" => self.lock = Some("{}")
      "format 1 lock" =>
        self.lock = Some(
          "{\"format\": 1, \"extension\": \"html-design\", \"module\": \"moonrockz/openspec-ext\", \"version\": \"0.1.0\", \"files\": {}}",
        )
      "missing lock" => self.lock = None
      "extra lock entry" =>
        self.lock = Some(
          edit_lock_files(self.lock.unwrap(), files => {
            files.set("scripts/openspec-ext.mbtx", Json::string("0".repeat(64)))
          }),
        )
      "missing digest" =>
        self.lock = Some(
          edit_lock_files(self.lock.unwrap(), files => {
            files.remove(@extension.BundleFile::Notice.path())
          }),
        )
      "lock and template gone" => {
        self.lock = None
        self.files.remove(@extension.BundleFile::Tasks.path())
      }
      "format 1 and template gone" => {
        self.lock = Some(
          "{\"format\": 1, \"extension\": \"html-design\", \"module\": \"moonrockz/openspec-ext\", \"version\": \"0.1.0\", \"files\": {}}",
        )
        self.files.remove(@extension.BundleFile::Tasks.path())
      }
      "malformed lock and template gone" => {
        self.lock = Some("{}")
        self.files.remove(@extension.BundleFile::Tasks.path())
      }
      "missing digest and file" => {
        self.lock = Some(
          edit_lock_files(self.lock.unwrap(), files => {
            files.remove(@extension.BundleFile::Notice.path())
          }),
        )
        self.files.remove(@extension.BundleFile::Notice.path())
      }
      "drift and schema" => {
        self.files.set(design, "Local edit")
        self.config = Some("schema: spec-driven\n")
      }
      "relocked template" => {
        self.files.set(design, "Local edit")
        self.lock = Some(
          edit_lock_files(self.lock.unwrap(), files => {
            files.set(
              design,
              Json::string(@extension.digest("Local edit").text()),
            )
          }),
        )
      }
      _ => fail("Unknown condition: \{condition}")
    }
  })
  setup.when0("the snapshot is checked at the snapshot level", () => {
    self.check(Snapshot)
  })
  setup.when1(
    "the snapshot is checked at the snapshot level by tools version {string}",
    (_ : String) => self.check(Snapshot),
  )
  setup.when1(
    "the snapshot is checked at the bundle level by tools version {string}",
    (version : String) => self.check(Bundle(tool(version))),
  )
  setup.then1("the problems are {string}", (expected : String) => {
    @expect.expect(self.problems.iter().join("; ")).to_equal(expected)
  })
}

///|
async test "OpenSpec extension acceptance" {
  @moonspec.run_or_fail(
    () => ExtensionWorld::{ source: "", result: "", replace_allowed: false, },
    @moonspec.RunOptions::RunOptions([
      @moonspec.FeatureSource::File(
        "openspec-ext-acceptance/features/configuration.feature",
      ),
    ]),
  )
}

///|
async test "snapshot check acceptance" {
  @moonspec.run_or_fail(
    () => SnapshotWorld::{ lock: None, config: None, files: {}, problems: [], },
    @moonspec.RunOptions::RunOptions([
      @moonspec.FeatureSource::File(
        "openspec-ext-acceptance/features/snapshot.feature",
      ),
    ]),
  )
}

///|
async fn messages(
  repository : @extension.RepositoryPath,
  level : @extension.CheckLevel,
) -> Array[String] {
  @host.check(repository, level).problems().map(p => p.message())
}

///|
async test "install is repeatable, preserves history and rejects local edits before writes" {
  let root = @fs.tmpdir(prefix="openspec-ext-test")
  defer @fs.rmdir(root, recursive=true)
  let repository = @extension.RepositoryPath(root)
  @fs.mkdir("\{root}/openspec/changes/ongoing", recursive=true)
  @fs.write_file(
    "\{root}/openspec/changes/ongoing/design.md",
    "Existing design",
  )
  @fs.write_file(
    "\{root}/openspec/config.yaml",
    "schema: spec-driven\ncontext: Local context\n",
  )
  @host.install(repository, tool("0.1.0"))
  @expect.expect(messages(repository, Bundle(tool("0.1.0")))).to_equal([])
  let first_lock = @fs.read_file("\{root}/openspec/extensions.lock.json").text()
  @host.install(repository, tool("0.1.0"))
  let next_lock = @fs.read_file("\{root}/openspec/extensions.lock.json").text()
  let config = @fs.read_file("\{root}/openspec/config.yaml").text()
  let history = @fs.read_file("\{root}/openspec/changes/ongoing/design.md").text()
  let scripts = @fs.exists("\{root}/scripts")
  @expect.expect_all(s => {
    s.expect(next_lock).to_equal(first_lock)
    s.expect(config).to_equal("schema: html-design\ncontext: Local context\n")
    s.expect(history).to_equal("Existing design")
    s.expect(scripts).to_be_false()
  })
  @fs.write_file(
    "\{root}/openspec/schemas/html-design/templates/design.html",
    "Local edit",
  )
  let rejected = try {
    @host.install(repository, tool("0.1.0"))
    false
  } catch {
    _ => true
  }
  @expect.expect(rejected).to_be_true()
  @expect.expect(
    @fs.read_file("\{root}/openspec/schemas/html-design/templates/design.html").text(),
  ).to_equal("Local edit")
  @expect.expect(messages(repository, Snapshot)).to_equal([
    "Extension drift: openspec/schemas/html-design/templates/design.html",
  ])
}

///|
async test "a check reads the repository it names and writes nothing" {
  let root = @fs.tmpdir(prefix="openspec-ext-other")
  defer @fs.rmdir(root, recursive=true)
  let repository = @extension.RepositoryPath(root)
  @host.install(repository, tool("0.1.0"))
  let before = @fs.read_file("\{root}/openspec/extensions.lock.json").text()
  @fs.write_file("\{root}/openspec/config.yaml", "schema: spec-driven\n")
  let report = @host.check(repository, Bundle(tool("0.2.0")))
  let resolved = @fs.realpath(root)
  let after = @fs.read_file("\{root}/openspec/extensions.lock.json").text()
  let config = @fs.read_file("\{root}/openspec/config.yaml").text()
  @expect.expect_all(s => {
    s.expect(report.root()).to_equal(resolved)
    s
    .expect(report.problems().map(p => p.code()))
    .to_equal(["tool-version", "schema"])
    s.expect(after).to_equal(before)
    s.expect(config).to_equal("schema: spec-driven\n")
  })
}

///|
/// A format 1 consumer as the bundled script left it: the seven schema files, the script, its
/// feature and a lock with nine digests.
async fn legacy_consumer(root : String, script : String) -> Unit {
  @host.install(@extension.RepositoryPath(root), tool("0.1.0"))
  @fs.mkdir("\{root}/scripts/features", recursive=true)
  @fs.write_file("\{root}/scripts/openspec-ext.mbtx", script)
  @fs.write_file(
    "\{root}/scripts/features/openspec_ext.feature",
    "Feature: x\n",
  )
  let hashes : Map[String, Json] = Map([])
  for file in @extension.files() {
    hashes.set(
      file.path(),
      Json::string(@extension.digest(file.content()).text()),
    )
  }
  hashes.set(
    "scripts/openspec-ext.mbtx",
    Json::string(@extension.digest("old script").text()),
  )
  hashes.set(
    "scripts/features/openspec_ext.feature",
    Json::string(@extension.digest("Feature: x\n").text()),
  )
  let lock : Json = {
    "format": 1,
    "extension": "html-design",
    "module": "moonrockz/openspec-ext",
    "version": "0.1.0",
    "files": Json::object(hashes),
  }
  @fs.write_file(
    "\{root}/openspec/extensions.lock.json",
    lock.stringify(indent=2) + "\n",
  )
}

///|
async test "install migrates a format 1 consumer and deletes the unedited script" {
  let root = @fs.tmpdir(prefix="openspec-ext-legacy")
  defer @fs.rmdir(root, recursive=true)
  let repository = @extension.RepositoryPath(root)
  legacy_consumer(root, "old script")
  @expect.expect(messages(repository, Snapshot)).to_equal([
    "Extension lock format 1 is from the bundled script. Run mission-control-tools openspec install.",
  ])
  @host.install(repository, tool("0.1.0"))
  let script = @fs.exists("\{root}/scripts/openspec-ext.mbtx")
  let feature = @fs.exists("\{root}/scripts/features/openspec_ext.feature")
  let lock = @fs.read_file("\{root}/openspec/extensions.lock.json").text()
  @expect.expect_all(s => {
    s.expect(script).to_be_false()
    s.expect(feature).to_be_false()
    s.expect(lock).to_equal(@extension.lock_text(tool("0.1.0")))
  })
  @expect.expect(messages(repository, Bundle(tool("0.1.0")))).to_equal([])
}

///|
async test "install refuses an edited script copy and changes nothing" {
  let root = @fs.tmpdir(prefix="openspec-ext-edited")
  defer @fs.rmdir(root, recursive=true)
  let repository = @extension.RepositoryPath(root)
  legacy_consumer(root, "edited script")
  let lock = @fs.read_file("\{root}/openspec/extensions.lock.json").text()
  @fs.write_file("\{root}/openspec/config.yaml", "schema: spec-driven\n")
  let message = try {
    @host.install(repository, tool("0.1.0"))
    ""
  } catch {
    error => "\{error}"
  }
  let script = @fs.read_file("\{root}/scripts/openspec-ext.mbtx").text()
  let feature = @fs.exists("\{root}/scripts/features/openspec_ext.feature")
  let lock_after = @fs.read_file("\{root}/openspec/extensions.lock.json").text()
  let config = @fs.read_file("\{root}/openspec/config.yaml").text()
  @expect.expect_all(s => {
    s
    .expect(message)
    .to_equal(
      "Edited retired file: scripts/openspec-ext.mbtx. Review it and remove it before installing.",
    )
    s.expect(script).to_equal("edited script")
    s.expect(feature).to_be_true()
    s.expect(lock_after).to_equal(lock)
    s.expect(config).to_equal("schema: spec-driven\n")
  })
}

///|
async test "unmanaged conflict and invalid config leave the repository untouched" {
  let root = @fs.tmpdir(prefix="openspec-ext-conflict")
  defer @fs.rmdir(root, recursive=true)
  let repository = @extension.RepositoryPath(root)
  @fs.mkdir("\{root}/openspec/schemas/html-design/templates", recursive=true)
  @fs.write_file(
    "\{root}/openspec/schemas/html-design/templates/tasks.md",
    "Unmanaged tasks",
  )
  let rejected = try {
    @host.install(repository, tool("0.1.0"))
    false
  } catch {
    _ => true
  }
  @expect.expect(rejected).to_be_true()
  @expect.expect(@fs.exists("\{root}/openspec/config.yaml")).to_be_false()
  @expect.expect(@fs.exists("\{root}/openspec/schemas/html-design/schema.yaml")).to_be_false()
  @fs.remove("\{root}/openspec/schemas/html-design/templates/tasks.md")
  @fs.write_file("\{root}/openspec/config.yaml", "schema: [broken")
  let rejected = try {
    @host.install(repository, tool("0.1.0"))
    false
  } catch {
    _ => true
  }
  @expect.expect(rejected).to_be_true()
  @expect.expect(@fs.exists("\{root}/openspec/extensions.lock.json")).to_be_false()
}

///|
async test "symlink parents cannot redirect installation outside the repository" {
  let root = @fs.tmpdir(prefix="openspec-ext-link")
  defer @fs.rmdir(root, recursive=true)
  let outside = @fs.tmpdir(prefix="openspec-ext-outside")
  defer @fs.rmdir(outside, recursive=true)
  @fs.symlink(target=outside, "\{root}/openspec")
  let rejected = try {
    @host.install(@extension.RepositoryPath(root), tool("0.1.0"))
    false
  } catch {
    _ => true
  }
  @expect.expect(rejected).to_be_true()
  @expect.expect(@fs.readdir(outside).length()).to_equal(0)
}

///|
async test "upgrade accepts the previous owned content and records the new tool version" {
  let root = @fs.tmpdir(prefix="openspec-ext-upgrade")
  defer @fs.rmdir(root, recursive=true)
  let repository = @extension.RepositoryPath(root)
  @host.install(repository, tool("0.1.0"))
  let schema = @extension.BundleFile::Schema
  let old_schema = "older owned schema"
  let prior = @extension.lock_text(tool("0.1.0")).replace(
    old=@extension.digest(schema.content()).text(),
    new=@extension.digest(old_schema).text(),
  )
  @fs.write_file("\{root}/\{schema.path()}", old_schema)
  @fs.write_file("\{root}/openspec/extensions.lock.json", prior)
  @host.install(repository, tool("0.2.0"))
  let installed = @fs.read_file("\{root}/\{schema.path()}").text()
  let lock = @fs.read_file("\{root}/openspec/extensions.lock.json").text()
  @expect.expect_all(s => {
    s.expect(installed).to_equal(schema.content())
    s.expect(lock).to_equal(@extension.lock_text(tool("0.2.0")))
  })
}

///|
async test "setup isolates its config and removes it after the process returns" {
  let mut seen_home : String? = None
  @host.isolated_init(async fn(home, environment) {
    seen_home = Some(home)
    let preferences = @json.parse(
      @fs.read_file("\{home}/openspec/config.json").text(),
    )
    @expect.expect_all(s => {
      s.expect(environment.get("XDG_CONFIG_HOME")).to_equal(Some(home))
      s.expect(environment.get("OPENSPEC_TELEMETRY")).to_equal(Some("0"))
      s.expect(preferences).to_equal(@host.setup_preferences())
    })
    0
  })
  let home = match seen_home {
    Some(home) => home
    None => fail("setup did not invoke the process callback")
  }
  @expect.expect(@fs.exists(home)).to_be_false()
  let failed = try {
    @host.isolated_init(fn(_, _) { 3 })
    ""
  } catch {
    error => "\{error}"
  }
  @expect.expect(failed).to_equal("OpenSpec integration setup failed: 3")
}

///|
async test "setup refuses another OpenSpec version and runs no init" {
  let root = @fs.tmpdir(prefix="openspec-ext-setup")
  defer @fs.rmdir(root, recursive=true)
  let repository = @extension.RepositoryPath(root)
  @host.install(repository, tool("0.1.0"))
  for
    found in [
      Some("1.13.0"),
      Some("1.14.2"),
      Some("1.15.0"),
      Some("1.17.0"),
      Some("1.16"),
      Some("1.16.1-beta.1"),
      None,
    ] {
    let mut runs = 0
    let refused = try {
      @host.setup_with(repository, _ => found, (_, _, _) => {
        runs += 1
        0
      })
      ""
    } catch {
      error => "\{error}"
    }
    @expect.expect_all(s => {
      s.expect(refused).to_equal("Setup requires OpenSpec 1.14.3 or 1.16.x")
      s.expect(runs).to_equal(0)
    })
  }
}

///|
async test "setup runs init for OpenSpec 1.14.3 and 1.16 patch releases" {
  let root = @fs.tmpdir(prefix="openspec-ext-setup-supported")
  defer @fs.rmdir(root, recursive=true)
  let repository = @extension.RepositoryPath(root)
  @host.install(repository, tool("0.1.0"))
  for version in ["1.14.3", "1.16.0", "1.16.1"] {
    let mut seen_root = ""
    @host.setup_with(repository, _ => Some(version), (r, _, environment) => {
      seen_root = r
      guard environment.get("OPENSPEC_TELEMETRY") is Some("0") else { return 9 }
      0
    })
    @expect.expect(seen_root).to_equal(@fs.realpath(root))
  }
}

///|
async test "setup stops on a snapshot problem before it asks for the OpenSpec version" {
  let root = @fs.tmpdir(prefix="openspec-ext-setup-drift")
  defer @fs.rmdir(root, recursive=true)
  let repository = @extension.RepositoryPath(root)
  @host.install(repository, tool("0.1.0"))
  @fs.write_file("\{root}/openspec/config.yaml", "schema: spec-driven\n")
  let mut asked = false
  let message = try {
    @host.setup_with(
      repository,
      _ => {
        asked = true
        Some("1.14.3")
      },
      (_, _, _) => 0,
    )
    ""
  } catch {
    error => "\{error}"
  }
  @expect.expect_all(s => {
    s.expect(message).to_equal("Default schema must be html-design")
    s.expect(asked).to_be_false()
  })
}

///|
async test "an unsupported lock names its rule in the install error" {
  let root = @fs.tmpdir(prefix="openspec-ext-badlock")
  defer @fs.rmdir(root, recursive=true)
  @fs.mkdir("\{root}/openspec", recursive=true)
  @fs.write_file(
    "\{root}/openspec/extensions.lock.json",
    "{\"format\": 7, \"extension\": \"html-design\"}",
  )
  let message = try {
    @host.install(@extension.RepositoryPath(root), tool("0.1.0"))
    ""
  } catch {
    error => "\{error}"
  }
  @expect.expect(message).to_equal(
    "Unsupported extension lock (the lock format 7 is not 1 or 2); restore it from version control",
  )
}

///|
async test "a linked scripts folder does not stop an install that retires nothing" {
  let root = @fs.tmpdir(prefix="openspec-ext-scripts-link")
  defer @fs.rmdir(root, recursive=true)
  let elsewhere = @fs.tmpdir(prefix="openspec-ext-scripts-target")
  defer @fs.rmdir(elsewhere, recursive=true)
  @fs.write_file("\{elsewhere}/openspec-ext.mbtx", "my own script")
  @fs.symlink(target=elsewhere, "\{root}/scripts")
  @host.install(@extension.RepositoryPath(root), tool("0.1.0"))
  @expect.expect(@fs.read_file("\{elsewhere}/openspec-ext.mbtx").text()).to_equal(
    "my own script",
  )
}
