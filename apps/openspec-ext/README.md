# OpenSpec extensions

`openspec-ext` installs and checks a shared OpenSpec workflow in any repository.
The first bundle is `html-design`: proposal, capability specs, an offline
`design.html`, and tasks. Repository context, tracking and approval rules stay in
`AGENTS.md` and `openspec/config.yaml`.

## Run from source

The new module is not published yet. From a Mission Control checkout, use its
pinned toolchain and pass the target repository explicitly:

```shell
mise exec -- moon run apps/openspec-ext/cmd -- install /path/to/repository
mise exec -- moon run apps/openspec-ext/cmd -- check /path/to/repository
mise exec -- moon run apps/openspec-ext/cmd -- setup /path/to/repository
```

`install` and `check` need only MoonBit. `setup` also needs OpenSpec **1.14.3**
on PATH. Pin `npm:@fission-ai/openspec = "1.14.3"` and Node 24.14.1 in the
consumer's mise tools. Setup generates the six core skills for Codex, Claude,
Copilot, Cursor, Grok, Gemini, OpenCode and portable `.agents` clients. It uses a
temporary global config, so personal profile and delivery settings do not affect
the result. Existing Copilot cloud preferences remain in project configuration.

After the module is released, use the actual published version:

```shell
moonx moonrockz/openspec-ext@<published-version>/cmd setup .
moonx moonrockz/openspec-ext@<published-version>/cmd check .
```

Do not pin an unpublished candidate in a consumer. The existing Mission Control
release scripts include this module; publication is a separate release action.

## Files and updates

Commit `openspec/config.yaml`, `openspec/schemas/html-design/`,
`openspec/extensions.lock.json`, `scripts/openspec-ext.mbtx` and generated agent skills. Fresh clones use the
checked-in files and need no global schema installation or sibling checkout.

Consumers can run the bundled script as `moon run scripts/openspec-ext.mbtx -- check`
or `-- setup` without a registry dependency. This checks the installed snapshot
against its lock; the packaged tool also compares it with the selected release.

`bundle.mbt` is the source for all shared files. Each raw multiline literal is
one installed file. Change it here, test it, and run `install` for consumers.
The ownership lock records the tool version and SHA-256 of each managed file.
`check` reports a different default schema, missing file, edited file or lock.
It never writes. Run it with the version recorded in the lock.

An update replaces only missing files, identical files, or files that still
match the previous lock. It refuses unmanaged conflicts and local edits before
writing anything. To adopt an existing custom schema, review it, move its policy
into the project config, and move the old schema aside before installing.
Keep overrides in project config rather than editing managed templates.
Unsupported YAML layouts fail before writes; ordinary block configs retain
comments and all values except the default schema.

The lock is written last. An interrupted install can leave partial files;
rerun the same version to repair them. Concurrent installation in one repository
is unsupported. Symlink destinations are refused.

Existing changes keep their `.openspec.yaml` schema and their original designs.
A default-schema change applies to new work. Existing HTML designs that use
external assets still require their original archive path handling; new bundle
designs have inline CSS and need no path rewrite.

## Verify

```shell
mise exec -- moon test apps/openspec-ext tests/openspec-ext-acceptance --target wasm --deny-warn
mise exec -- openspec schema validate html-design
mise exec -- openspec validate --all --strict
```

The pure bundle builds on all four MoonBit targets. Host I/O and the command
support wasm and native because `moonbitlang/async` does not supply JS or wasm-gc
filesystem and process support. Existing release binaries remain the
`mission-control` CLI; the extension command ships as its own mooncakes module.

The bundled script runs its Gherkin feature with `moon test scripts/openspec-ext.mbtx`.
It checks valid and edited snapshots, malformed configuration and lock data, and
setup isolation. Its filesystem test also verifies temporary configuration cleanup.
The workspace version setter updates the extension lock version alongside module
and contract versions, so normal release preparation keeps validation in step.

The shared script pins `moonbitlang/async@0.22.4`, the baseline supported by
the consuming repositories. It declares its imports in frontmatter (between two
`----` lines), so `moon test --deny-warn` passes on MoonBit 0.10.18, which warns
about an import block outside frontmatter (`unfenced_import`). Frontmatter needs
MoonBit 0.10.17+d971670cd or later. An earlier version stops with a parse error
at the first `----` line, so pin 0.10.18 or later in a consumer before you install
this snapshot.
The packaged host uses the module dependencies declared in `moon.mod`.
