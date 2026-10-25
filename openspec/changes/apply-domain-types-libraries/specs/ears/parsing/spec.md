# Spec Delta

## Purpose

Give EARS parse errors as typed values that name the clause keyword and the place where the parse failed, so that callers match cases and point to the problem.

## ADDED Requirements

### Requirement: Keyword values in errors
The library SHALL name a clause keyword in a parse error as a keyword value (`Where`, `While`, `When` or `If`), not as text.

#### Scenario: Empty clause
- **WHEN** a caller parses `When , the sensor shall reply.`
- **THEN** the error is the empty clause case with the keyword value `When`

### Requirement: Error positions
A parse error SHALL carry the position in the normalized sentence where the parse failed.

#### Scenario: Missing separator
- **WHEN** a caller parses `When polled the sensor shall reply.`
- **THEN** the error is the missing separator case, with a position in the `When` clause

### Requirement: Source ranges
The library SHALL give the origin of each requirement and each diagnostic as an mdc source range, with the positions of its first and last characters and its offsets in the input.

#### Scenario: Sentence over two lines
- **WHEN** a caller parses a requirement block in which a sentence starts at line 2, column 3 and ends at line 3, column 7
- **THEN** the origin of the requirement is a source range from 2:3 to 3:7
