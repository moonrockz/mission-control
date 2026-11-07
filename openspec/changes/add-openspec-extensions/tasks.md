# Tasks

## 1. Portable extension tool

Bead: moonbase-933

- [x] 1.1 Implement a self-contained bundle, lossless config migration and safe install/check commands; verify focused unit and filesystem acceptance tests.
- [x] 1.2 Add isolated agent setup; verify a fresh consumer with the pinned CLI and document source usage and release status.
- [x] 1.3 Add the module to the workspace and release lists; verify lint, package validation and release-list tests.

- [x] 1.4 Preserve Markdown schema templates as opaque assets through the OKF profile and converters; verify the repository round-trip test and a focused regression.

Bead: moonbase-gid

- [x] 1.5 Move the imports of the bundled script and of every task script into frontmatter and pin MoonBit 0.10.18+6c83a7f62; verify `moon test --deny-warn` of the scripts, the app tests and the extension lock check on 0.10.18.

Bead: moonbase-agl

- [x] 1.6 Move the bundled script to `moonbitlang/async@0.22.7`, keep the extension module on 0.22.5 until a zig-cross release compiles the async 0.22.7 C stubs, keep MoonBit 0.10.18 and make 0.10.18 the supported toolchain of the script in the spec; verify `moon test --deny-warn` of the script on `wasm` and `native`, the app tests, the extension lock check and a consumer `openspec:verify` on 0.10.18.

## 2. Repository adoption

Bead: moonbase-933

- [x] 2.1 Consolidate the existing html-design consumers and enable the requested repositories; verify each schema, extension lock and all OpenSpec artifacts.
- [x] 2.2 Keep existing Markdown changes on spec-driven; verify their design bytes and schema metadata stay unchanged.

## Workflow follow-up

- Review the source changes and publish the new module through the existing Mission Control release process.
- Pin the actual published extension version in consumers after release.
