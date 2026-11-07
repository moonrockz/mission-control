Feature: Release the tools CLI
  The tools CLI has its own version, its own tools-v tags and its own changelog. A dry run only checks.
  A release needs main, a version without a complete release, and a changelog section with highlights.

  Scenario: A dry run never releases
    Given a run of "workflow_dispatch" with dry_run "true"
    And the ref "branch" "feature"
    And the commit is not on main
    When the plan runs for version "0.1.0"
    Then the plan is "dry run 0.1.0"

  Scenario: A push to main with a ready section releases
    Given a run of "push" with dry_run ""
    And the ref "branch" "main"
    And the changelog:
      """
      # Changelog

      ## [0.1.0] - 2026-11-08

      The first release.
      """
    When the plan runs for version "0.1.0"
    Then the plan is "release 0.1.0"

  Scenario: The first merge without a section releases nothing
    Given a run of "push" with dry_run ""
    And the ref "branch" "main"
    And the changelog:
      """
      # Changelog

      ## [Unreleased]
      """
    When the plan runs for version "0.1.0"
    Then the plan is "skip: apps/tools/CHANGELOG.md has no section for 0.1.0; nothing to release"

  Scenario: A section with the highlights placeholder stops the run
    Given a run of "push" with dry_run ""
    And the ref "branch" "main"
    And the changelog:
      """
      ## [0.1.0] - 2026-11-08

      <!-- Highlights: write a few sentences -->
      """
    When the plan runs for version "0.1.0"
    Then the plan is "error: the apps/tools/CHANGELOG.md section for 0.1.0 still has the highlights placeholder"

  Scenario: A complete release is skipped
    Given a run of "push" with dry_run ""
    And the ref "branch" "main"
    And the release is complete
    When the plan runs for version "0.1.0"
    Then the plan is "skip: tools-v0.1.0 is already released"

  Scenario: A branch that is not main does not release
    Given a run of "workflow_dispatch" with dry_run "false"
    And the ref "branch" "feature"
    And the commit is not on main
    When the plan runs for version "0.1.0"
    Then the plan is "error: feature is not on main"

  Scenario: A tools tag must name the version of apps/tools/moon.mod
    Given a run of "workflow_dispatch" with dry_run "false"
    And the ref "tag" "tools-v0.2.0"
    When the plan runs for version "0.1.0"
    Then the plan is "error: tag tools-v0.2.0 does not match apps/tools/moon.mod version 0.1.0"

  Scenario Outline: Unknown inputs are refused
    Then the inputs "<event>" and "<tag>" are refused with "<message>"

    Examples:
      | event        | tag          | message                                                  |
      | pull_request | tools-v0.1.0 | the event `pull_request` is not push or workflow_dispatch |
      | push         | v0.1.0       | the tag `v0.1.0` is not tools-v and a version             |
      | push         | tools-v0.1   | the tag `tools-v0.1` is not tools-v and a version         |

  Scenario: The plan outputs name the tools tag
    Then the outputs of a release of "0.1.0" are:
      """
      release=true
      dry_run=false
      version=0.1.0
      tag=tools-v0.1.0
      """

  Scenario: A new release is created with every asset and is not the latest release
    When the release steps run with no release
    Then the steps are:
      """
      release create tools-v0.1.0 --target abc --title mission-control-tools 0.1.0 --notes-file notes.md --latest=false dist-tools/mission-control-tools-linux-x64.tar.gz dist-tools/mission-control-tools-linux-arm64.tar.gz dist-tools/mission-control-tools-darwin-arm64.tar.gz dist-tools/mission-control-tools-darwin-x64.tar.gz dist-tools/mission-control-tools-windows-x64.zip dist-tools/checksums.txt
      """

  Scenario: A re-run uploads only the missing assets
    When the release steps run with the remote assets "mission-control-tools-linux-x64.tar.gz,mission-control-tools-linux-arm64.tar.gz,mission-control-tools-darwin-arm64.tar.gz,mission-control-tools-darwin-x64.tar.gz"
    Then the steps are:
      """
      release upload tools-v0.1.0 dist-tools/mission-control-tools-windows-x64.zip dist-tools/checksums.txt --clobber
      """

  Scenario: The notes give the Renovate-friendly mise entry
    Then the notes of "0.1.0" contain:
      """
      [tools."github:moonrockz/mission-control"]
      version = "0.1.0"
      version_prefix = "tools-v"

      [tools."github:moonrockz/mission-control".platforms]
      linux-x64 = { asset_pattern = "mission-control-tools-linux-x64.tar.gz" }
      linux-arm64 = { asset_pattern = "mission-control-tools-linux-arm64.tar.gz" }
      macos-arm64 = { asset_pattern = "mission-control-tools-darwin-arm64.tar.gz" }
      macos-x64 = { asset_pattern = "mission-control-tools-darwin-x64.tar.gz" }
      windows-x64 = { asset_pattern = "mission-control-tools-windows-x64.zip" }
      # No Windows arm64 build; Windows on Arm runs the x64 build under emulation.
      windows-arm64 = { asset_pattern = "mission-control-tools-windows-x64.zip" }
      """

  Scenario: The notes give the alias form for a repository with both CLIs
    Then the notes of "0.1.0" contain:
      """
      [tool_alias]
      mission-control-tools = "github:moonrockz/mission-control"

      [tools.mission-control-tools]
      version = "0.1.0"
      version_prefix = "tools-v"
      """

  Scenario: The notes give the attestation check with the signer workflow
    Then the notes of "0.1.0" contain:
      """
      gh attestation verify mission-control-tools-linux-x64.tar.gz --repo moonrockz/mission-control --signer-workflow moonrockz/mission-control/.github/workflows/release-tools.yml
      """

  Scenario: The version type is the one of the main release script
    Then the version block is the one in release.mbtx
