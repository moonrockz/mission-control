Feature: Check an installed html-design snapshot
  Scenario Outline: Check a snapshot at the snapshot level
    Given a snapshot installed by tools version "0.1.0"
    And the snapshot has "<condition>"
    When the snapshot is checked at the snapshot level
    Then the problems are "<problems>"

    Examples:
      | condition          | problems                                                                                    |
      | no change          |                                                                                             |
      | edited template    | Extension drift: openspec/schemas/html-design/templates/design.html                         |
      | deleted template   | Missing file: openspec/schemas/html-design/templates/tasks.md                               |
      | wrong schema       | Default schema must be html-design                                                          |
      | malformed config   | Default schema must be html-design                                                          |
      | malformed lock     | Unsupported extension lock                                                                  |
      | format 1 lock      | Extension lock format 1 is from the bundled script. Run mission-control-tools openspec install. |
      | missing lock       | Missing file: openspec/extensions.lock.json                                                 |
      | extra lock entry   | Unexpected extension file set                                                               |
      | missing digest     | Unexpected extension file set; Missing digest: openspec/schemas/html-design/NOTICE          |
      | drift and schema   | Extension drift: openspec/schemas/html-design/templates/design.html; Default schema must be html-design |

  Scenario: The snapshot level does not depend on the tool version
    Given a snapshot installed by tools version "0.1.0"
    When the snapshot is checked at the snapshot level by tools version "0.2.0"
    Then the problems are ""

  Scenario: The bundle level reports a moved pin
    Given a snapshot installed by tools version "0.1.0"
    When the snapshot is checked at the bundle level by tools version "0.2.0"
    Then the problems are "Extension lock records mission-control-tools 0.1.0; this is mission-control-tools 0.2.0. Run mission-control-tools openspec install."

  Scenario: The bundle level reports a file that matches its lock but not the bundle
    Given a snapshot installed by tools version "0.1.0"
    And the snapshot has "relocked template"
    When the snapshot is checked at the bundle level by tools version "0.1.0"
    Then the problems are "Bundle drift: openspec/schemas/html-design/templates/design.html differs from mission-control-tools 0.1.0"
