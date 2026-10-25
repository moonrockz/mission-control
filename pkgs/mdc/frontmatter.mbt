///|
/// A YAML payload and its parsed mapping. Construct with `Frontmatter::Frontmatter`.
/// The representation is hidden so text and parsed YAML always agree.
struct Frontmatter {
  raw : String
  value : @yaml.Yaml
} derive(Debug)

///|
pub extend Frontmatter with @debug.Debug::{to_repr}

///|
/// Validate a YAML payload without delimiter lines and preserve its exact text.
/// Empty and comment-only payloads become empty mappings. Reject invalid YAML,
/// multiple documents and non-mappings. Error positions are one-based and
/// relative to this payload; `parse` translates them to document positions.
pub fn Frontmatter::Frontmatter(
  raw : String,
) -> Frontmatter raise FrontmatterError {
  let values = @yaml.Yaml::load_from_string(raw[:]) catch {
    @yaml.YamlError(mark~, info~) =>
      raise InvalidYaml(at=yaml_position(mark.line, mark.col + 1), message=info)
  }
  let value = match values {
    [] => @yaml.Yaml::Map({})
    [Map(_) as value] => value
    [_] => raise NotAMapping
    _ => raise MultipleDocuments(count=values.length())
  }
  { raw, value, }
}

///|
/// The position that the YAML parser reports. The parser counts lines from 1;
/// a value below 1 becomes 1.
fn yaml_position(line : Int32, column : Int32) -> TextPosition {
  {
    line: if line < 1 {
      1
    } else {
      line
    },
    column: if column < 1 {
      1
    } else {
      column
    },
  }
}

///|
/// The original YAML payload, excluding delimiter lines.
pub fn Frontmatter::raw(self : Frontmatter) -> String {
  self.raw
}

///|
/// A deep copy of the parsed YAML mapping. Changes to returned maps and arrays
/// cannot change this frontmatter or make its stored YAML disagree with `raw`.
pub fn Frontmatter::value(self : Frontmatter) -> @yaml.Yaml {
  copy_yaml(self.value)
}

///|
fn copy_yaml(value : @yaml.Yaml) -> @yaml.Yaml {
  match value {
    Map(fields) => {
      let copy = Map([])
      for key, value in fields {
        copy[key] = copy_yaml(value)
      }
      Map(copy)
    }
    Array(values) => Array(values.map(copy_yaml))
    Real(_) | Integer(_) | String(_) | Boolean(_) | Null | BadValue => value
  }
}
