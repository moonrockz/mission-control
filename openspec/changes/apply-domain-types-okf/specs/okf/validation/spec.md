# Spec Delta

## MODIFIED Requirements

### Requirement: Finding order
The library SHALL sort findings by severity, then by subject (the validation config, then profiles by name, then documents of bundles by bundle label and path, then stray files by path), then by line, then by rule name, then by message, so that the same input always gives the same order.

#### Scenario: Stable order
- **WHEN** a caller validates the same bundle two times
- **THEN** both runs return the same findings in the same order

## ADDED Requirements

### Requirement: Rule names
The library SHALL represent rule names as values that are not empty and are in kebab case, and SHALL report a validation config that overrides or turns off a rule name that no active rule set defines.

#### Scenario: Misspelled rule
- **WHEN** a caller turns off `link-broke` and no rule has that name
- **THEN** validation reports that the config names an unknown rule

### Requirement: Finding subjects
A finding SHALL name its subject as a document of a bundle (a bundle label and a bundle path) or as a stray file (a store path), not as raw text.

#### Scenario: Stray file
- **WHEN** validation reports a stray Markdown file
- **THEN** the finding has a stray subject with the store path of the file

### Requirement: Invalid profiles
The library SHALL report a profile whose definitions break a rule of a value type, such as a rule name that is not in kebab case, as a `profile-invalid` error, and SHALL use none of the definitions that fail.

#### Scenario: Severity for a rule name with spaces
- **WHEN** a profile gives a severity for the rule name `Not Kebab`
- **THEN** validation reports `profile-invalid` for that profile
