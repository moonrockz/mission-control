Feature: Parse EARS with dialects
  Projects add their own words to the EARS grammar through dialects and
  lexicons, and mark requirements in Markdown with their own headings. Without
  a dialect the grammar stays strict EARS.

  Scenario: Strict subject
    Given no dialect
    When I parse the sentence "It shall report the version."
    Then the parse fails with "ExpectedSystem"

  Scenario: Strict requirement unchanged
    Given no dialect
    When I parse the sentence "While enabled, when polled, the sensor shall report temperature."
    Then the system is "sensor"
    And the response is "report temperature."

  Scenario: Empty dialect
    Given the lexicon:
      """
      name: empty
      """
    When I parse the sentence "It shall report the version."
    Then the parse fails with "ExpectedSystem"

  Scenario: Two dialects
    Given the lexicon:
      """
      modals: [must]
      """
    And the lexicon:
      """
      determiners: [each]
      """
    When I parse the sentence "Each entry MUST have a link."
    Then the subject opener is "Each"
    And the system is "entry"
    And the modal verb is "must"

  Scenario: MUST NOT
    Given the lexicon:
      """
      modals: [must]
      """
    When I parse the sentence "The store MUST NOT write outside its root."
    Then the modal verb is "must"
    And the modal verb is negated
    And the response is "write outside its root."

  Scenario: Determiner
    Given the lexicon:
      """
      determiners: [an]
      """
    When I parse the sentence "An edit SHALL keep every other byte."
    Then the subject opener is "An"
    And the system is "edit"

  Scenario: Pronoun alone
    Given the lexicon:
      """
      pronouns: [it]
      """
    When I parse the sentence "It SHALL report the error."
    Then the subject opener is "It"
    And the system is not resolved

  Scenario: Product name
    Given the lexicon:
      """
      systems: [Mission Control]
      """
    When I parse the sentence "Mission Control SHALL publish one version."
    Then the system is "Mission Control"

  Scenario: Otherwise
    Given the lexicon:
      """
      pronouns: [it]
      lead_ins: [otherwise]
      """
    When I parse the sentence "Otherwise it SHALL select the root index."
    Then the lead-in is "Otherwise"
    And the subject opener is "it"
    And the response is "select the root index."

  Scenario: Lead-in with a comma
    Given the lexicon:
      """
      lead_ins: [for each]
      """
    When I parse the sentence "For each document, the graph SHALL give its backlinks."
    Then the lead-in is "For each document"
    And the system is "graph"

  Scenario: Render and parse
    Given the lexicon:
      """
      lead_ins: [for each]
      """
    When I parse the sentence "For each document, the graph SHALL NOT drop links."
    Then rendering and parsing again gives an equal requirement

  Scenario: Two sentences
    Given the OpenSpec dialect
    When I parse the block "The store SHALL list files. It SHALL sort them by path."
    Then the block has 2 requirements and 0 diagnostics
    And requirement 2 has the resolved system "store"

  Scenario: Full stop in code
    Given the OpenSpec dialect
    When I parse the block "The parser SHALL read `a.md` files."
    Then the block has 1 requirements and 0 diagnostics

  Scenario: OpenSpec heading
    Given the OpenSpec dialect
    When I extract requirements from the Markdown:
      """
      ### Requirement: Path safety
      The store SHALL refuse a path that escapes the root. It SHALL report the path.

      #### Scenario: Escape
      - **WHEN** a caller reads `../x.md`
      - **THEN** the store refuses it
      """
    Then there is one block named "Path safety" with 2 requirements

  Scenario: No heading rule
    Given no dialect
    When I extract requirements from the Markdown:
      """
      ### Requirement: Path safety
      The store shall refuse a path that escapes the root.
      """
    Then there are no blocks
    And the extraction has 1 requirements

  Scenario: Lexicon in code
    Given a lexicon in code with the system noun "OpenSpec"
    When I parse the sentence "OpenSpec SHALL validate the change."
    Then the system is "OpenSpec"

  Scenario: Lexicon file
    When I parse the lexicon file:
      """
      systems: [Mission Control]
      lead_ins: [otherwise]
      """
    Then the lexicon adds the system noun "Mission Control" and the lead-in "otherwise"

  Scenario: Wrong type
    When I parse the lexicon file:
      """
      name: project
      modals: must
      """
    Then the lexicon file fails for "modals" on line 2
