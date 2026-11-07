# mission-control-tools

`mission-control-tools` is a command-line tool for repositories that use Mission Control's shared
conventions. The first command group is `openspec`. It installs and checks the shared `html-design`
OpenSpec schema, and it generates the agent skills. It replaces the copy of `scripts/openspec-ext.mbtx`
that each consumer kept. You pin a released binary, so a MoonBit toolchain change in your repository
cannot break these commands.

The tools CLI has its own version and its own releases (`tools-vX.Y.Z`). They are separate from the
main `mission-control` CLI.

## Install with mise

Each release lists the exact entry in its release notes. For version 0.1.1:

```toml
[tools."github:moonrockz/mission-control"]
version = "0.1.1"
version_prefix = "tools-v"

[tools."github:moonrockz/mission-control".platforms]
linux-x64 = { asset_pattern = "mission-control-tools-linux-x64.tar.gz" }
linux-arm64 = { asset_pattern = "mission-control-tools-linux-arm64.tar.gz" }
macos-arm64 = { asset_pattern = "mission-control-tools-darwin-arm64.tar.gz" }
macos-x64 = { asset_pattern = "mission-control-tools-darwin-x64.tar.gz" }
windows-x64 = { asset_pattern = "mission-control-tools-windows-x64.zip" }
# No Windows arm64 build; Windows on Arm runs the x64 build under emulation.
windows-arm64 = { asset_pattern = "mission-control-tools-windows-x64.zip" }
```

- `version_prefix` makes mise read only the `tools-v` releases.
- mise checks each download against its GitHub asset digest (SHA-256) and against its GitHub artifact
  attestation. Enable `mise.lock` to keep the digest of each platform in your repository.
- Renovate's mise manager can bump this entry: it reads the `github` backend and turns `version_prefix`
  into `extractVersion`. The asset patterns have no version, so a bump changes only `version`.

If your repository also installs the main CLI from `github:moonrockz/mission-control`, give the tools CLI
an alias. mise allows only one entry for each backend key. Renovate does not read aliases, so you move
this version yourself:

```toml
[tool_alias]
mission-control-tools = "github:moonrockz/mission-control"

[tools.mission-control-tools]
version = "0.1.1"
version_prefix = "tools-v"

[tools.mission-control-tools.platforms]
# The same six asset patterns as above.
```

### Verify a download

The release workflow attests each archive and `checksums.txt` with GitHub build provenance:

```shell
gh attestation verify mission-control-tools-linux-x64.tar.gz \
  --repo moonrockz/mission-control \
  --signer-workflow moonrockz/mission-control/.github/workflows/release-tools.yml \
  --source-ref refs/heads/main
sha256sum -c checksums.txt
```

`--source-ref refs/heads/main` accepts only an archive that the workflow built from main. A dry run from
another branch also attests its archives, and this option rejects them.

The executable is at the root of each archive.

## Commands

```text
mission-control-tools version [--json]
mission-control-tools openspec check [--bundle] [--json] [REPOSITORY]
mission-control-tools openspec install [REPOSITORY]
mission-control-tools openspec setup [REPOSITORY]
```

`REPOSITORY` is the repository root. The default is the current directory. Options and the path can come
in any order after the command.

| Command | What it does | Writes files |
|---------|--------------|--------------|
| `openspec check` | Compares each managed file with its digest in `openspec/extensions.lock.json`, and checks that `openspec/config.yaml` selects `html-design`. The result does not depend on the tool version. This is what `scripts/openspec-ext.mbtx check` did. | No |
| `openspec check --bundle` | Does the snapshot check, then checks that the lock records this tool and version, and that each managed file is the file in this binary. Use it in `openspec:check`, so that a version bump without `install` fails. | No |
| `openspec install` | Installs or updates the schema, the templates, `LICENSE` and `NOTICE`, selects `html-design` in the config, and writes the lock. It refuses a local edit before it writes anything. It deletes the retired script copy when it is not edited. | Yes |
| `openspec setup` | Does the snapshot check, requires OpenSpec 1.14.3 or a 1.16 patch release (1.16.x), and runs `openspec init` for the core profile with a temporary configuration directory. Your global OpenSpec settings do not change. It does not install. | Agent skills |

Exit codes: 0 for success, 1 for a failure and 2 for a usage error. A usage error stops before any file is
read.

Success lines are `html-design snapshot: OK` (check and setup) and
`html-design: OK (mission-control-tools X.Y.Z)` (install). Each problem is one line on standard error,
after `openspec-ext: `, with the texts of the old script:

```text
openspec-ext: Unsupported extension lock
openspec-ext: Unexpected extension file set
openspec-ext: Missing digest: <path>
openspec-ext: Extension drift: <path>
openspec-ext: Default schema must be html-design
openspec-ext: Missing file: <path>
openspec-ext: Extension lock format 1 is from the bundled script. Run mission-control-tools openspec install.
openspec-ext: Extension lock records mission-control-tools 0.1.0; this is mission-control-tools 0.2.0. Run mission-control-tools openspec install.
openspec-ext: Bundle drift: <path> differs from mission-control-tools 0.2.0
```

The script printed the same texts inside `Failure(<file>:<line> FAILED: …)`. The binary prints the text
only, and it reports every problem, not only the first.

With `--json`, `check` prints one JSON object on standard output, and the exit code is the same:

```json
{"tool":"mission-control-tools","version":"0.1.0","command":"openspec check","level":"bundle","repository":"/work/repo","ok":false,"problems":[{"code":"drift","path":"openspec/schemas/html-design/templates/design.html","message":"Extension drift: openspec/schemas/html-design/templates/design.html"}]}
```

The problem codes are `missing-file`, `unsupported-lock`, `legacy-lock`, `file-set`, `missing-digest`,
`drift`, `schema`, `tool-version` and `bundle-drift`. `version --json` prints
`{"tool":"mission-control-tools","version":"0.1.0","bundle":"html-design"}`.

## The lock

`openspec/extensions.lock.json` has format 2. It records the tool and the tool version that wrote it,
and the SHA-256 of each of the seven managed files:

```json
{
  "format": 2,
  "extension": "html-design",
  "tool": "moonrockz/mission-control-tools",
  "version": "0.1.0",
  "files": {
    "openspec/schemas/html-design/schema.yaml": "…",
    "openspec/schemas/html-design/templates/proposal.md": "…",
    "openspec/schemas/html-design/templates/spec.md": "…",
    "openspec/schemas/html-design/templates/design.html": "…",
    "openspec/schemas/html-design/templates/tasks.md": "…",
    "openspec/schemas/html-design/NOTICE": "…",
    "openspec/schemas/html-design/LICENSE": "…"
  }
}
```

The managed files stay in your repository, because OpenSpec reads them. The version in the lock and the
version in your mise entry are the same after `install`; `check --bundle` fails when they differ.

The managed files are compared byte for byte. On Windows, keep LF line endings for them, for example with
`openspec/schemas/html-design/** text eol=lf` in `.gitattributes`.

## Migrate from scripts/openspec-ext.mbtx

Do these steps in one pull request.

1. Add the mise entry above to `.config/mise/config.toml`. Run `mise install`, then
   `mission-control-tools version`.
2. Run `mission-control-tools openspec install`. It keeps the schema files, writes the format 2 lock, and
   deletes `scripts/openspec-ext.mbtx` and `scripts/features/openspec_ext.feature` when they have the
   digests of your old lock. If you edited the script, install stops with
   `Edited retired file: scripts/openspec-ext.mbtx. Review it and remove it before installing.` and
   changes nothing. Move your change into your own task, delete the file and run install again.
3. Point the OpenSpec tasks at the binary, and remove the script test task:

   ```toml
   [tasks."openspec:check"]
   description = "Check the shared OpenSpec workflow"
   run = "mission-control-tools openspec check --bundle"

   [tasks."openspec:setup"]
   description = "Set up the shared OpenSpec workflow"
   run = "mission-control-tools openspec setup"

   [tasks."openspec:validate"]
   description = "Validate the shared OpenSpec workflow"
   run = ["openspec schema validate html-design", "openspec validate --all --strict"]

   [tasks."openspec:verify"]
   description = "Verify the shared OpenSpec workflow"
   run = ["mise run openspec:check", "mise run openspec:validate"]
   ```

   Delete `openspec:test` and the `moon update` step that ran only for the script. Remove the script from
   any task that runs the tests of `scripts/*.mbtx`, and remove `moonrockz/moonspec` and
   `moonrockz/expect` if only the script used them. Remove `scripts/openspec-ext.mbtx` and
   `scripts/features/openspec_ext.feature` from CI path filters, and change documentation that tells
   readers to run the script or `moon run apps/openspec-ext/cmd`.
4. Run `mise run openspec:verify`. Commit the mise file, the lock and the two deletions.

To roll back, revert the pull request. The old lock and the script come back with it.

## For maintainers

The source is `apps/tools` (this module) and `apps/openspec-ext` (the bundle and the host I/O). From a
Mission Control checkout:

```shell
mise run openspec:check                    # moon run apps/tools -- openspec check --bundle .
moon test apps/tools apps/openspec-ext tests/openspec-ext-acceptance --target native
```

The version is in `apps/tools/moon.mod`. It is not the workspace version. `mise run validate:versions`
checks both families. `moonx scripts/versions.mbtx set-tools X.Y.Z` changes the tools family only: the
module, the version text in `version.mbt` and its test, and the Mission Control extension lock.

To release:

1. On a branch, run `moonx scripts/versions.mbtx set-tools X.Y.Z` and `mise run openspec:install`.
2. In `apps/tools/CHANGELOG.md`, rename `## [Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD` with a few sentences
   of highlights.
3. Before the first merge of a workflow change, or whenever you want proof, run
   `gh workflow run release-tools.yml -f dry_run=true` on main. It builds, attests and smoke checks all five
   platforms and creates no tag.
4. Open the pull request. The merge changes `apps/tools/moon.mod` or `apps/tools/CHANGELOG.md` on main, so
   `.github/workflows/release-tools.yml` runs. It releases when the section exists and the release
   `tools-vX.Y.Z` is not complete. It never marks the release as latest.
5. Run `mise run release:tools-status`.

After a transient failure, use "Re-run failed jobs". The release step uploads only the missing assets.
