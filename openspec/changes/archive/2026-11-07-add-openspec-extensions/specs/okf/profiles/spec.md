## ADDED Requirements

### Requirement: Profile asset classification
WHEN an active profile classifies a Markdown path as an asset, the bundle loader SHALL retain it as an opaque asset without parsing it as a concept. WHEN no active profile classifies the path as an asset, the loader SHALL use the existing document classification.

#### Scenario: Template has a Markdown extension
- **WHEN** a profile classifies a schema template as an asset
- **THEN** the loader preserves its content without frontmatter validation
