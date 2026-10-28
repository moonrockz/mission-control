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
  @host.install(repository)
  @host.check(repository)
  let first_lock = @fs.read_file("\{root}/openspec/extensions.lock.json").text()
  @host.install(repository)
  let next_lock = @fs.read_file("\{root}/openspec/extensions.lock.json").text()
  let config = @fs.read_file("\{root}/openspec/config.yaml").text()
  let history = @fs.read_file("\{root}/openspec/changes/ongoing/design.md").text()
  @expect.expect_all(s => {
    s.expect(next_lock).to_equal(first_lock)
    s.expect(config).to_equal("schema: html-design\ncontext: Local context\n")
    s.expect(history).to_equal("Existing design")
  })
  @fs.write_file(
    "\{root}/openspec/schemas/html-design/templates/design.html",
    "Local edit",
  )
  let rejected = try {
    @host.install(repository)
    false
  } catch {
    _ => true
  }
  @expect.expect(rejected).to_be_true()
  @expect.expect(
    @fs.read_file("\{root}/openspec/schemas/html-design/templates/design.html").text(),
  ).to_equal("Local edit")
  let drift = try {
    @host.check(repository)
    false
  } catch {
    _ => true
  }
  @expect.expect(drift).to_be_true()
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
    @host.install(repository)
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
    @host.install(repository)
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
    @host.install(@extension.RepositoryPath(root))
    false
  } catch {
    _ => true
  }
  @expect.expect(rejected).to_be_true()
  @expect.expect(@fs.readdir(outside).length()).to_equal(0)
}

///|
async test "upgrade accepts the previous owned content and newly introduced bundle files" {
  let root = @fs.tmpdir(prefix="openspec-ext-upgrade")
  defer @fs.rmdir(root, recursive=true)
  let repository = @extension.RepositoryPath(root)
  @host.install(repository)
  let schema = @extension.BundleFile::Schema
  let old_schema = "older owned schema"
  let prior = @extension.lock_text().replace(
    old=@extension.digest(schema.content()).text(),
    new=@extension.digest(old_schema).text(),
  )
  guard @json.parse(prior) is Object(lock) &&
    lock.get("files") is Some(Object(hashes)) else {
    fail("test lock must be an object")
  }
  let workflow = @extension.BundleFile::Workflow
  hashes.remove(workflow.path())
  @fs.remove("\{root}/\{workflow.path()}")
  @fs.write_file("\{root}/\{schema.path()}", old_schema)
  @fs.write_file(
    "\{root}/openspec/extensions.lock.json",
    Json(lock).stringify(),
  )
  @host.install(repository)
  @host.check(repository)
  @expect.expect(@fs.read_file("\{root}/\{schema.path()}").text()).to_equal(
    schema.content(),
  )
  @expect.expect(@fs.exists("\{root}/\{workflow.path()}")).to_be_true()
}
