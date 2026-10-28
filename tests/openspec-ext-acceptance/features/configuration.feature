Feature: Portable OpenSpec configuration
  Scenario: Adopt HTML designs without losing repository policy
    Given a repository with its own OpenSpec context and task rules
    When the HTML design extension selects its schema
    Then the schema is html-design and the repository policy is unchanged

  Scenario: Protect a locally customized template
    Given a locally customized HTML design template
    When the extension checks whether it can replace the template
    Then the local template must be kept
