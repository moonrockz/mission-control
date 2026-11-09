# OpenSpec extensions

`moonrockz/openspec-ext` is the library behind `mission-control-tools openspec`. It owns the shared
`html-design` bundle: proposal, capability specs, an offline `design.html`, and tasks. Repository context,
tracking and approval rules stay in each consumer's `AGENTS.md` and `openspec/config.yaml`.

Consumers do not use this module directly. They pin the released `mission-control-tools` binary; see
[apps/tools/README.md](../tools/README.md) for the install entry, the commands and the migration from the
old `scripts/openspec-ext.mbtx` copy.

## Packages

| Package | Content | Targets |
|---------|---------|---------|
| `moonrockz/openspec-ext` | The bundle files, the config migration, the typed lock (format 1 and 2), the retired files and the pure snapshot and bundle checks. No I/O. | wasm, wasm-gc, js, native |
| `moonrockz/openspec-ext/host` | `install`, `check` and `setup`: file reads and writes, symlink guards, the retirement of old files and the isolated `openspec init`. | wasm, native |

The host uses `moonbitlang/async` file and process support, which has no JS or wasm-gc backend. The wasm
build runs under `moonrun` (`moon run`), which supplies the file system host.

## Narrative designs

The bundle guides authors through a concrete user or system journey. A running example connects the
stages; each decision explains the constraint, choice, reason and alternatives. Diagrams clarify flow,
boundaries or state transitions. Significant failures and recovery belong in the journey too.

Scale the narrative to the change. A short paragraph and one example can be enough. Do not force personas,
diagram quotas or repeated motivation. Separate observed behavior, proposed interfaces and assumptions.
Requirements and scenarios remain normative and testable; explanatory context for a new capability goes
under Purpose so it survives archive. Required artifact sections and decision identifiers stay intact.

## Files and updates

`bundle.mbt` is the source for all shared files. Each raw multiline literal is one installed file. Change it
here, test it, and run `mise run openspec:install` for this repository. The managed set is
`openspec/schemas/html-design/` only: `schema.yaml`, four templates, `LICENSE` and `NOTICE`. Consumers commit
these files, because OpenSpec reads them.

The ownership lock (`openspec/extensions.lock.json`, format 2) records the tool module, the tool version and
the SHA-256 of each managed file. A check never writes. The snapshot check compares the files with the lock;
the bundle check also compares the lock tool version and the files with the bundle of the tool.

An install replaces only missing files, identical files, or files that still match the previous lock. It
refuses unmanaged conflicts and local edits before writing anything. A file that an older bundle managed and
this bundle does not (`scripts/openspec-ext.mbtx` and its feature) is deleted when it still has the digest of
the previous lock, and stops the install when it does not. Only these fixed paths are ever deleted. To adopt
an existing custom schema, review it, move its policy into the project config, and move the old schema aside
before installing. Unsupported YAML layouts fail before writes; ordinary block configs retain comments and
all values except the default schema.

The lock is written last. An interrupted install can leave partial files; rerun the same version to repair
them. Concurrent installation in one repository is unsupported. Symlink destinations are refused.

Existing changes keep their `.openspec.yaml` schema and their original designs. A default-schema change
applies to new work.

## Verify

```shell
mise exec -- moon test apps/openspec-ext apps/tools tests/openspec-ext-acceptance --target native --deny-warn
mise run openspec:check
mise exec -- openspec schema validate html-design
mise exec -- openspec validate --all --strict
```

The packaged host uses the module dependencies in `moon.mod`, which keep `moonbitlang/async@0.22.5`.
`moonrockz/zig-cross@0.3.2` cannot compile the `fs.c` stub of async 0.22.7: its forced `-include limits.h`
comes before `#define _GNU_SOURCE`, so `O_PATH` is not declared. Move `moon.mod` to 0.22.7 after a zig-cross
release that passes `-DNAME_MAX=255` in place of the forced include.
