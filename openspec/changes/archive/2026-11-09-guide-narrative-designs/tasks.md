# Tasks

## 1. Shared authoring guidance and release

- [x] 1.1 Update the bundle source and its authoring guide. Run the source installer and verify that the generated instructions and templates contain the guidance, the snapshot check passes and existing required sections remain.
- [x] 1.2 Set the tools family to 0.1.2 with the existing version script and write release highlights and adoption instructions. Verify tools and workspace version validation without changing the main-family version.
- [x] 1.3 Run focused extension/tools acceptance tests, lint, validation and schema checks. Review the candidate through an orchestrated reviewer and retain the results before landing.

Verification: lint, package and version validation, schema validation and all 19 OpenSpec items passed. Focused tools/extension tests passed on wasm and native, 40 tests per target. All eight task-script suites passed. The orchestrated review reported no findings and verified the seven managed files against source, lock hashes and staged bytes. Five-platform packaging, attestations and published-binary smoke checks remain release-workflow gates.

## Workflow follow-up

- Archive the completed authoring change, land its reviewed release PR, and verify the release workflow's built, attested and smoke-tested artifacts.
- Adopt the released bundle in Morphir through its pinned binary and source installer. Do not hand-edit consumer snapshots.
