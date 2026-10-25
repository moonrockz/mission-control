///|
/// The level of a Markdown heading, from 1 (`#`) to 6 (`######`).
pub(all) enum HeadingLevel {
  H1
  H2
  H3
  H4
  H5
  H6
} derive(Eq, Compare, Hash, Debug)

///|
/// The level as a number from 1 to 6.
pub fn HeadingLevel::to_int(self : HeadingLevel) -> Int32 {
  match self {
    H1 => 1
    H2 => 2
    H3 => 3
    H4 => 4
    H5 => 5
    H6 => 6
  }
}

///|
/// The level for a number from 1 to 6, or `None` for any other number.
pub fn HeadingLevel::of_int(n : Int32) -> HeadingLevel? {
  match n {
    1 => Some(H1)
    2 => Some(H2)
    3 => Some(H3)
    4 => Some(H4)
    5 => Some(H5)
    6 => Some(H6)
    _ => None
  }
}

///|
pub impl Show for HeadingLevel with fn output(self, logger) {
  logger.write_object(self.to_int())
}

///|
/// Raised when a position or a range breaks its rules.
pub(all) suberror PositionError {
  /// A line or a column is less than 1.
  InvalidPosition(line~ : Int32, column~ : Int32)
  /// The start of a range is after its end.
  StartAfterEnd(start~ : TextPosition, end~ : TextPosition)
  /// An offset is negative, or the start offset is after the end offset.
  InvalidOffsets(start~ : Int32, end~ : Int32)
} derive(Eq, Debug)

///|
/// A position in a text: a line and a column, both counted from 1. Columns
/// count UTF-16 code units. Positions order by line, then by column.
struct TextPosition {
  line : Int32
  column : Int32
} derive(Eq, Compare, Hash, Debug)

///|
/// Checks a position. Raises `InvalidPosition` when the line or the column is
/// less than 1.
pub fn TextPosition::TextPosition(
  line~ : Int32,
  column~ : Int32,
) -> TextPosition raise PositionError {
  if line < 1 || column < 1 {
    raise InvalidPosition(line~, column~)
  }
  { line, column, }
}

///|
pub fn TextPosition::line(self : TextPosition) -> Int32 {
  self.line
}

///|
pub fn TextPosition::column(self : TextPosition) -> Int32 {
  self.column
}

///|
/// The position as `line:column`.
pub fn TextPosition::to_string(self : TextPosition) -> String {
  "\{self.line}:\{self.column}"
}

///|
pub impl Show for TextPosition with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
/// A range of source text: the positions of its first and last characters,
/// and the UTF-16 offsets of its start and of its end. The end offset is the
/// offset after the last character. An empty range starts and ends at the
/// same position and offset.
struct SourceRange {
  start : TextPosition
  end : TextPosition
  start_offset : Int32
  end_offset : Int32
} derive(Eq, Hash, Debug)

///|
/// Checks a range. Raises `StartAfterEnd` when `start` is after `end`, and
/// `InvalidOffsets` when an offset is negative or the start offset is after
/// the end offset.
pub fn SourceRange::SourceRange(
  start~ : TextPosition,
  end~ : TextPosition,
  start_offset~ : Int32,
  end_offset~ : Int32,
) -> SourceRange raise PositionError {
  if start > end {
    raise StartAfterEnd(start~, end~)
  }
  if start_offset < 0 || start_offset > end_offset {
    raise InvalidOffsets(start=start_offset, end=end_offset)
  }
  { start, end, start_offset, end_offset, }
}

///|
/// The position of the first character.
pub fn SourceRange::start(self : SourceRange) -> TextPosition {
  self.start
}

///|
/// The position of the last character, or the start of an empty range.
pub fn SourceRange::end(self : SourceRange) -> TextPosition {
  self.end
}

///|
/// The UTF-16 offset of the first character.
pub fn SourceRange::start_offset(self : SourceRange) -> Int32 {
  self.start_offset
}

///|
/// The UTF-16 offset after the last character.
pub fn SourceRange::end_offset(self : SourceRange) -> Int32 {
  self.end_offset
}

///|
/// Raised when a frontmatter payload is not one YAML mapping.
pub(all) suberror FrontmatterError {
  /// The payload is not valid YAML. The position is relative to the payload.
  InvalidYaml(at~ : TextPosition, message~ : String)
  /// The payload is one YAML document that is not a mapping.
  NotAMapping
  /// The payload holds more than one YAML document.
  MultipleDocuments(count~ : Int32)
} derive(Eq, Debug)

///|
pub extend HeadingLevel with Eq::{not_equal, equal}

///|
pub extend HeadingLevel with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend HeadingLevel with Hash::{hash, hash_combine}

///|
pub extend HeadingLevel with @debug.Debug::{to_repr}

///|
pub extend HeadingLevel with Show::{to_string, output}

///|
pub extend PositionError with Eq::{not_equal, equal}

///|
pub extend PositionError with @debug.Debug::{to_repr}

///|
pub extend TextPosition with Eq::{not_equal, equal}

///|
pub extend TextPosition with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend TextPosition with Hash::{hash, hash_combine}

///|
pub extend TextPosition with @debug.Debug::{to_repr}

///|
pub extend TextPosition with Show::{output}

///|
pub extend SourceRange with Eq::{not_equal, equal}

///|
pub extend SourceRange with Hash::{hash, hash_combine}

///|
pub extend SourceRange with @debug.Debug::{to_repr}

///|
pub extend FrontmatterError with Eq::{not_equal, equal}

///|
pub extend FrontmatterError with @debug.Debug::{to_repr}
