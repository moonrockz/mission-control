///|
test "heading levels: each level, and numbers outside 1 to 6" {
  for n in 1..<=6 {
    guard @mdc.HeadingLevel::of_int(n) is Some(level) else { fail("no \{n}") }
    assert_eq(level.to_int(), n)
  }
  for n in [-1, 0, 7, 100] {
    assert_eq(@mdc.HeadingLevel::of_int(n), None)
  }
  assert_true(@mdc.HeadingLevel::H1 < @mdc.HeadingLevel::H2)
  assert_eq(@mdc.HeadingLevel::H3.to_string(), "3")
}

///|
test "the kind of a heading block holds its level" {
  let doc = @mdc.parse("### Steps\n\nSetext\n------\n")
  let levels = doc.fold(
    [],
    @mdc.Folder::Folder((acc, node) => {
      if node is Block(view) && view.kind() is Heading(level~) {
        acc.push(level.to_int())
      }
      Continue(acc)
    }),
  )
  assert_eq(levels, [3, 2])
}

///|
fn position_error(
  f : () -> Unit raise @mdc.PositionError,
) -> @mdc.PositionError? {
  try f() catch {
    e => Some(e)
  } noraise {
    _ => None
  }
}

///|
test "positions and ranges: values on each side of the limits" {
  let p = @mdc.TextPosition(line=1, column=1)
  assert_eq(p.to_string(), "1:1")
  assert_eq(
    position_error(() => @mdc.TextPosition(line=0, column=1) |> ignore),
    Some(InvalidPosition(line=0, column=1)),
  )
  assert_eq(
    position_error(() => @mdc.TextPosition(line=1, column=0) |> ignore),
    Some(InvalidPosition(line=1, column=0)),
  )
  let q = @mdc.TextPosition(line=2, column=1)
  let r = @mdc.SourceRange(start=p, end=q, start_offset=0, end_offset=5)
  assert_eq(
    (r.start(), r.end(), r.start_offset(), r.end_offset()),
    (p, q, 0, 5),
  )
  let empty = @mdc.SourceRange(start=q, end=q, start_offset=5, end_offset=5)
  assert_eq(empty.start(), empty.end())
  assert_eq(
    position_error(() => {
      @mdc.SourceRange(start=q, end=p, start_offset=0, end_offset=5) |> ignore
    }),
    Some(StartAfterEnd(start=q, end=p)),
  )
  assert_eq(
    position_error(() => {
      @mdc.SourceRange(start=p, end=q, start_offset=6, end_offset=5) |> ignore
    }),
    Some(InvalidOffsets(start=6, end=5)),
  )
  assert_eq(
    position_error(() => {
      @mdc.SourceRange(start=p, end=q, start_offset=-1, end_offset=5) |> ignore
    }),
    Some(InvalidOffsets(start=-1, end=5)),
  )
}

///|
test "a body location translates to a range in the source" {
  let source = "---\na: 1\nb: 2\n---\n# Goal\n\nText here.\n"
  let doc = @mdc.parse(source)
  let ranges = doc.fold(
    [],
    @mdc.Folder::Folder((acc, node) => {
      if node is Block(view) && view.kind() is (Heading(_) | Paragraph) {
        acc.push(doc.source_range(view.location()))
      }
      Continue(acc)
    }),
  )
  guard ranges is [Some(heading), Some(paragraph)] else { fail("no ranges") }
  // Three frontmatter lines and the opener: the body starts on line 5.
  assert_eq(heading.start().to_string(), "5:1")
  assert_eq(source[heading.start_offset():heading.end_offset()], "# Goal")
  assert_eq(paragraph.start().to_string(), "7:1")
  assert_eq(paragraph.end().to_string(), "7:10")
  assert_eq(
    source[paragraph.start_offset():paragraph.end_offset()],
    "Text here.",
  )
}

///|
test "a range on the first line after a byte order mark counts the mark" {
  let source = "\u{FEFF}Text\n"
  let doc = @mdc.parse(source)
  let ranges = doc.fold(
    [],
    @mdc.Folder::Folder((acc, node) => {
      if node is Block(view) && view.kind() is Paragraph {
        acc.push(doc.source_range(view.location()))
      }
      Continue(acc)
    }),
  )
  guard ranges is [Some(r)] else { fail("no range") }
  assert_eq(r.start().to_string(), "1:2")
  assert_eq(source[r.start_offset():r.end_offset()], "Text")
}

///|
test "ranges in a CRLF source, and locations that are not in the body" {
  let source = "---\r\na: 1\r\n---\r\n# Goal\r\n\r\nText.\r\n"
  let doc = @mdc.parse(source)
  let ranges = doc.fold(
    [],
    @mdc.Folder::Folder((acc, node) => {
      if node is Block(view) && view.kind() is (Heading(_) | Paragraph) {
        acc.push(doc.source_range(view.location()))
      }
      Continue(acc)
    }),
  )
  guard ranges is [Some(heading), Some(paragraph)] else { fail("no ranges") }
  assert_eq(heading.start().to_string(), "4:1")
  assert_eq(source[heading.start_offset():heading.end_offset()], "# Goal")
  assert_eq(paragraph.start().to_string(), "6:1")
  assert_eq(source[paragraph.start_offset():paragraph.end_offset()], "Text.")
  // A location before the first line, or past the end of the body.
  let loc = doc.to_cmark().block.meta().loc
  assert_eq(
    doc.source_range({ ..loc, first_line: @cmark_base.LinePos(0, 0), }),
    None,
  )
  assert_eq(
    doc.source_range({ ..loc, last_ccode: 10000, last_line: loc.last_line, }),
    None,
  )
}
