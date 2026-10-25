# Spec Delta

## Purpose

Report the line of the wrong item in a lexicon file, also when the list is a flow list.

## MODIFIED Requirements

### Requirement: Lexicon files
The library SHALL parse a lexicon from YAML text with the keys `name`, `modals`, `determiners`, `pronouns`, `systems`, `lead_ins` and `headings`, where each heading has a `level` and a `prefix`. It SHALL report an unknown key or a wrong value type as an error with its line. WHEN a list item is wrong, the library SHALL report the line of that item, in a block list and in a flow list.

#### Scenario: Lexicon file
- **WHEN** a caller parses a lexicon file with `systems: [Mission Control]` and `lead_ins: [otherwise]`
- **THEN** the lexicon adds that system noun and that lead-in phrase

#### Scenario: Wrong type
- **WHEN** a lexicon file has `modals: must`
- **THEN** parsing fails with an error that names `modals` and its line

#### Scenario: Flow list item
- **WHEN** a lexicon file has `modals: [must,` on line 1 and `"a b"]` on line 2
- **THEN** parsing fails with an error that names `modals` and line 2
