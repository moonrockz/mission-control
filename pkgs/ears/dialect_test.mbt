///|
priv struct NameOnly {}

///|
impl @ears.Dialect for NameOnly with fn name(_) {
  "name only"
}

///|
/// A word that the tests write in code.
fn word(text : String) -> @ears.Word {
  @ears.Word(text) catch {
    _ => abort("not a word: \{text}")
  }
}

///|
priv struct Musts {}

///|
impl @ears.Dialect for Musts with fn name(_) {
  "musts"
}

///|
impl @ears.Dialect for Musts with fn modals(_) {
  [word("must")]
}

///|
priv struct Eaches {}

///|
impl @ears.Dialect for Eaches with fn name(_) {
  "eaches"
}

///|
impl @ears.Dialect for Eaches with fn determiners(_) {
  [word("each")]
}

///|
fn lexicon_error(
  f : () -> Unit raise @ears.LexiconError,
) -> @ears.LexiconError? {
  try f() catch {
    e => Some(e)
  } noraise {
    _ => None
  }
}

///|
test "words, phrases and heading prefixes keep their rules" {
  assert_eq(@ears.Word("MUST").to_string(), "MUST")
  assert_eq(@ears.Word("MUST"), @ears.Word("must"))
  for text in ["", "a b", "a,", "a.", "a\tb"] {
    assert_eq(
      lexicon_error(() => @ears.Word(text) |> ignore),
      Some(InvalidWord(text)),
      msg=text,
    )
  }
  assert_eq(@ears.Phrase("Mission Control").to_string(), "Mission Control")
  for text in ["", " a", "a ", "a  b", "a, b", "a.b", "a\nb"] {
    assert_eq(
      lexicon_error(() => @ears.Phrase(text) |> ignore),
      Some(InvalidPhrase(text)),
      msg=text,
    )
  }
  assert_eq(@ears.HeadingPrefix("Requirement:").to_string(), "Requirement:")
  for text in ["", "a\nb"] {
    assert_eq(
      lexicon_error(() => @ears.HeadingPrefix(text) |> ignore),
      Some(InvalidHeadingPrefix(text)),
      msg=text,
    )
  }
  let rule = @ears.HeadingRule(H3, @ears.HeadingPrefix("Requirement:"))
  assert_eq((rule.level(), rule.prefix().to_string()), (H3, "Requirement:"))
}

///|
test "without a dialect the grammar stays strict" {
  let refused = try @ears.parse("It shall report the version.") catch {
    e => Some(e)
  } noraise {
    _ => None
  }
  assert_true(refused is Some(ExpectedSystem(_)))
  let r = @ears.parse(
    "While enabled, when polled, the sensor shall report temperature.",
  )
  assert_eq(r.preconditions().iter().collect(), ["enabled"])
  assert_true(r.trigger() is Some(Event("polled")))
  assert_eq(r.system(), Some("sensor"))
  assert_eq(r.response(), "report temperature.")
  assert_eq(r.lead_in(), None)
  assert_eq(r.opener(), Some(@ears.Word("the")))
  assert_eq((r.modal().verb, r.modal().negated), (@ears.Word("shall"), false))
}

///|
test "an empty dialect gives the strict results" {
  let dialects : Array[&@ears.Dialect] = [NameOnly::{ }]
  for
    text in [
      "The sensor shall report.", "When polled, the sensor shall reply.", "It shall report.",
      "The sensor should report.",
    ] {
    let strict = try @ears.parse(text) catch {
      e => Err(@debug.to_string(e))
    } noraise {
      r => Ok(r)
    }
    let with_dialect = try @ears.parse(text, dialects~) catch {
      e => Err(@debug.to_string(e))
    } noraise {
      r => Ok(r)
    }
    assert_eq(with_dialect, strict, msg=text)
  }
}

///|
test "dialects combine, and keywords match without letter case" {
  let dialects : Array[&@ears.Dialect] = [Musts::{ }, Eaches::{ }]
  let r = @ears.parse("Each entry MUST have a link.", dialects~)
  assert_eq(r.opener().map(w => w.to_string()), Some("Each"))
  assert_eq(r.system(), Some("entry"))
  assert_eq(r.modal().verb, @ears.Word("must"))
  assert_eq(r.response(), "have a link.")
}

///|
test "a negated modal verb is recorded and left out of the response" {
  let r = @ears.parse("The store MUST NOT write outside its root.", dialects=[
    Musts::{ },
  ])
  assert_eq((r.modal().verb, r.modal().negated), (@ears.Word("must"), true))
  assert_eq(r.response(), "write outside its root.")
}

///|
test "openers, system nouns and lead-ins come from the vocabulary" {
  let lexicon = @ears.Lexicon(
    modals=[@ears.Word("must")],
    determiners=[@ears.Word("an")],
    pronouns=[@ears.Word("it")],
    systems=[@ears.Phrase("Mission Control"), @ears.Phrase("OpenSpec")],
    lead_ins=[@ears.Phrase("otherwise"), @ears.Phrase("for each")],
  )
  let dialects : Array[&@ears.Dialect] = [lexicon]
  let edit = @ears.parse("An edit SHALL keep every other byte.", dialects~)
  assert_eq(
    (edit.opener().map(w => w.to_string()), edit.system()),
    (Some("An"), Some("edit")),
  )
  let it = @ears.parse("It SHALL report the error.", dialects~)
  assert_eq(it.opener().map(w => w.to_string()), Some("It"))
  assert_eq((it.system(), it.resolved_system()), (None, None))
  let mc = @ears.parse("Mission Control SHALL publish one version.", dialects~)
  assert_eq((mc.system(), mc.opener()), (Some("Mission Control"), None))
  assert_eq(
    @ears.parse("OpenSpec SHALL validate the change.", dialects~).system(),
    Some("OpenSpec"),
  )
  let otherwise = @ears.parse(
    "Otherwise it SHALL select the root index.",
    dialects~,
  )
  assert_eq(otherwise.lead_in(), Some("Otherwise"))
  assert_eq(otherwise.opener().map(w => w.to_string()), Some("it"))
  assert_eq(otherwise.response(), "select the root index.")
  let each = @ears.parse(
    "For each document, the graph SHALL give its backlinks.",
    dialects~,
  )
  assert_eq(
    (each.lead_in(), each.system()),
    (Some("For each document"), Some("graph")),
  )
}

///|
test "render and parse give an equal requirement" {
  let lexicon = @ears.Lexicon(
    modals=[@ears.Word("must")],
    pronouns=[@ears.Word("it")],
    lead_ins=[@ears.Phrase("for each"), @ears.Phrase("otherwise")],
  )
  let dialects : Array[&@ears.Dialect] = [lexicon]
  for
    text in [
      "For each document, the graph SHALL NOT drop links.", "Otherwise it MUST select the root.",
      "While enabled, if disconnected then it must stop.", "The sensor shall report.",
    ] {
    let first = @ears.parse(text, dialects~)
    let second = @ears.parse(first.to_string(), dialects~)
    assert_eq(second, first, msg=first.to_string())
  }
  assert_eq(
    @ears.parse("For each document, the graph SHALL NOT drop links.", dialects~).to_string(),
    "For each document, the graph shall not drop links.",
  )
}

///|
test "a block splits into sentences and resolves pronouns" {
  let dialects : Array[&@ears.Dialect] = [@ears.openspec_dialect()]
  let spec = @ears.parse_block(
    "The store SHALL list files. It SHALL sort them by path.",
    dialects~,
  )
  assert_eq(spec.requirements().length(), 2)
  assert_eq(spec.diagnostics().length(), 0)
  let second = spec.requirements()[1]
  assert_eq(second.requirement().resolved_system(), Some("store"))
  guard second.origin() is Text(span) else { fail("not a text origin") }
  assert_eq((span.start(), span.line(), span.column()), (28, 1, 29))
  let code = @ears.parse_block("The parser SHALL read `a.md` files.", dialects~)
  assert_eq(code.requirements().length(), 1)
  let alone = @ears.parse_block(
    "It SHALL report.\nThe store SHALL list files.",
    dialects~,
  )
  assert_eq(alone.requirements().length(), 2)
  assert_eq(alone.diagnostics().length(), 1)
  assert_true(alone.diagnostics()[0].error() is UnresolvedPronoun(..))
  let bad = @ears.parse_block(
    "The store SHALL list files. Fast responses are important.",
    dialects~,
  )
  assert_eq((bad.requirements().length(), bad.diagnostics().length()), (1, 1))
  guard bad.diagnostics()[0].origin() is Text(span) else { fail("no span") }
  assert_eq(span.start(), 28)
}

///|
let openspec_markdown : String =
  #|## Requirements
  #|
  #|### Requirement: Path safety
  #|The store SHALL refuse a path that escapes the root.
  #|It SHALL report the path.
  #|
  #|#### Scenario: Escape
  #|- **WHEN** a caller reads `../x.md`
  #|- **THEN** the store refuses it
  #|

///|
test "Markdown requirement headings form blocks" {
  let spec = @ears.parse_markdown(openspec_markdown, dialects=[
    @ears.openspec_dialect(),
  ])
  assert_eq(spec.blocks().length(), 1)
  let block = spec.blocks()[0]
  assert_eq(block.name(), "Path safety")
  assert_eq(block.requirements().length(), 2)
  assert_eq(block.diagnostics().length(), 0)
  assert_eq(block.heading().map(r => r.start().line()), Some(3))
  assert_eq(spec.requirements().length(), 2)
  // Without a dialect: today's extraction, one sentence per paragraph. The
  // requirement paragraph is one requirement, and the `WHEN` item is a
  // diagnostic.
  let strict = @ears.parse_markdown(openspec_markdown)
  assert_eq(strict.blocks().length(), 0)
  assert_eq(
    (strict.requirements().length(), strict.diagnostics().length()),
    (1, 1),
  )
}

///|
test "a lexicon file adds vocabulary and reports bad values with lines" {
  let lexicon = @ears.Lexicon::from_yaml(
    "name: mission-control\nsystems: [Mission Control]\nlead_ins:\n  - otherwise\nheadings:\n  - level: 2\n    prefix: \"Rule:\"\n",
  )
  assert_eq(lexicon.name(), "mission-control")
  assert_eq(lexicon.system_nouns(), [@ears.Phrase("Mission Control")])
  assert_eq(lexicon.lead_ins(), [@ears.Phrase("otherwise")])
  assert_eq(lexicon.headings().map(h => (h.level(), h.prefix().to_string())), [
    (H2, "Rule:"),
  ])
  assert_eq(
    lexicon_error(() => {
      @ears.Lexicon::from_yaml("name: x\nmodals: must\n") |> ignore
    }),
    Some(WrongType(key="modals", line=2, expected=List)),
  )
  assert_eq(
    lexicon_error(() => @ears.Lexicon::from_yaml("verbs: [must]\n") |> ignore),
    Some(UnknownKey(key="verbs", line=1)),
  )
  assert_eq(
    lexicon_error(() => {
      @ears.Lexicon::from_yaml("pronouns:\n  - it\n  - two words\n") |> ignore
    }),
    Some(InvalidEntry(key="pronouns", line=3, error=InvalidWord("two words"))),
  )
  assert_true(
    lexicon_error(() => @ears.Lexicon::from_yaml("a: [") |> ignore)
    is Some(InvalidLexiconFile(..)),
  )
}

///|
test "the OpenSpec dialect parses each failure class of the probe" {
  let dialects : Array[&@ears.Dialect] = [@ears.openspec_dialect()]
  for
    text in [
      "It SHALL report the error.", "A store SHALL list files.", "Each entry MUST have a link.",
      "Otherwise it SHALL select the root index.", "The store MUST NOT write outside its root.",
    ] {
    let _ = @ears.parse(text, dialects~)
  }
  let block = @ears.parse_block(
    "The store SHALL list files. They SHALL be sorted.",
    dialects~,
  )
  assert_eq(block.diagnostics().length(), 0)
}

///|
test "a lead-in ends at the first clause or subject after it" {
  let dialects : Array[&@ears.Dialect] = [@ears.openspec_dialect()]
  let saves = @ears.parse(
    "Otherwise when the user saves, the store SHALL write.",
    dialects~,
  )
  assert_eq(saves.lead_in(), Some("Otherwise"))
  assert_true(saves.trigger() is Some(Event("the user saves")))
  let idle = @ears.parse("Otherwise while idle, it SHALL wait.", dialects~)
  assert_eq(idle.lead_in(), Some("Otherwise"))
  assert_eq(idle.preconditions().iter().collect(), ["idle"])
  for
    text in [
      "Otherwise it SHALL list files, then exit.", "Otherwise it SHALL retry, when possible.",
      "Otherwise the store SHALL keep files, the index and logs.",
    ] {
    let r = @ears.parse(text, dialects~)
    assert_eq(r.lead_in(), Some("Otherwise"), msg=text)
  }
  let unwanted = @ears.parse("Otherwise if x, then it SHALL y.", dialects~)
  assert_true(unwanted.trigger() is Some(Unwanted("x")))
}

///|
test "strict EARS keeps not in the response" {
  let r = @ears.parse("The system shall not crash.")
  assert_eq((r.modal().negated, r.response()), (false, "not crash."))
  assert_eq(@ears.parse("The system shall not").response(), "not")
  let empty : Array[&@ears.Dialect] = [NameOnly::{ }]
  assert_eq(@ears.parse("The system shall not crash.", dialects=empty), r)
}

///|
test "with a dialect, a clause takes commas up to the last subject comma before the modal verb" {
  let dialects : Array[&@ears.Dialect] = [@ears.openspec_dialect()]
  let cold = @ears.parse(
    "While the cache is cold, that is, empty, the store SHALL wait.",
    dialects~,
  )
  assert_eq(cold.preconditions().iter().collect(), [
    "the cache is cold, that is, empty",
  ])
  assert_eq(cold.system(), Some("store"))
  let file = @ears.parse(
    "When a file, a folder or a link changes, the store SHALL reindex.",
    dialects~,
  )
  assert_true(
    file.trigger() is Some(Event("a file, a folder or a link changes")),
  )
  let large = @ears.parse(
    "If the file is large, that is, over 1 MB, then the store SHALL reject it.",
    dialects~,
  )
  assert_true(
    large.trigger() is Some(Unwanted("the file is large, that is, over 1 MB")),
  )
}

///|
test "sentence ends: code, brackets, quote marks and blank lines" {
  let dialects : Array[&@ears.Dialect] = [@ears.openspec_dialect()]
  let count = (text : String) => {
    let spec = @ears.parse_block(text, dialects~)
    (spec.requirements().length(), spec.diagnostics().length())
  }
  assert_eq(count("The store SHALL read ` files.\nIt SHALL sort them."), (2, 0))
  assert_eq(
    count("The store SHALL list files (see below.) It SHALL sort them."),
    (2, 0),
  )
  assert_eq(count("The store SHALL list files\n\nIt SHALL sort them."), (2, 0))
  let markdown = @ears.parse_markdown(
    "### Requirement: A\nThe store SHALL write `x. y` z.\n",
    dialects~,
  )
  assert_eq(
    (markdown.requirements().length(), markdown.diagnostics().length()),
    (1, 0),
  )
}

///|
test "lexicon rules: white space, empty heading names and large heading levels" {
  assert_eq(
    lexicon_error(() => @ears.Word("a\u{0B}b") |> ignore),
    Some(InvalidWord("a\u{0B}b")),
  )
  assert_eq(
    lexicon_error(() => @ears.Phrase("a\u{0B}b") |> ignore),
    Some(InvalidPhrase("a\u{0B}b")),
  )
  assert_true(
    lexicon_error(() => {
      @ears.Lexicon::from_yaml(
        "headings:\n  - level: 4294967299\n    prefix: X\n",
      )
      |> ignore
    })
    is Some(InvalidEntry(key="headings", error=InvalidHeadingLevel(_), ..)),
  )
  assert_eq(
    lexicon_error(() => @ears.Lexicon::from_yaml("\"verbs\": [x]\n") |> ignore),
    Some(UnknownKey(key="verbs", line=1)),
  )
  let spec = @ears.parse_markdown(
    "### Requirement:\nThe store SHALL list files.\n",
    dialects=[@ears.openspec_dialect()],
  )
  assert_eq(spec.blocks().length(), 0)
}
