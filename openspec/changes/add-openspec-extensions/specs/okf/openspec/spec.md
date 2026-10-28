## ADDED Requirements

### Requirement: Preserve custom schema files
WHEN a caller loads, imports or exports an OpenSpec tree with custom schemas, the OpenSpec profile SHALL retain all files under schemas as assets, including Markdown templates, without changing their content.

#### Scenario: Schema template round trip
- **WHEN** a tree contains schemas/html-design/templates/proposal.md and its schema definition
- **THEN** import and export retain both files byte for byte and do not require concept frontmatter on the template
