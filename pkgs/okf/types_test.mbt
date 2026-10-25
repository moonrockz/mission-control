///|
/// The error that `f` raises, as a debug string, or `"ok"` when it does not raise.
fn outcome(f : () -> Unit raise) -> String {
  try f() catch {
    e => @debug.to_string(e)
  } noraise {
    _ => "ok"
  }
}

///|
test "bundle labels: segments on each side of the rules" {
  assert_eq(@okf.BundleLabel("ir").to_string(), "ir")
  let label = @okf.BundleLabel("morphir/ir")
  assert_eq(
    (label.name(), label.group().iter().collect(), label.is_bare()),
    ("ir", ["morphir"], false),
  )
  assert_eq(@okf.BundleLabel("my notes").name(), "my notes")
  for text in ["", "morphir//ir", "/ir", "ir/", "a:b", "a\nb", "a\rb"] {
    assert_eq(
      outcome(() => @okf.BundleLabel(text) |> ignore),
      @debug.to_string(@okf.ValueError::InvalidLabel(text)),
    )
  }
}

///|
test "store directories: the root, children and invalid segments" {
  assert_true(@okf.StoreDir::root().is_root())
  assert_eq(@okf.StoreDir("").to_string(), "")
  let dir = @okf.StoreDir("bundles/morphir")
  assert_eq(dir.name(), Some("morphir"))
  assert_true(dir.contains(@okf.StorePath("bundles/morphir/ir/index.md")))
  assert_false(dir.contains(@okf.StorePath("bundles/morphirx/index.md")))
  assert_true(@okf.StoreDir("bundles").encloses(dir))
  assert_false(dir.encloses(@okf.StoreDir("bundles")))
  assert_eq(dir.child(@okf.EntryName("ir")).to_string(), "bundles/morphir/ir")
  // Parsing normalizes the text, so the value has no empty, `.` or `..` segment.
  assert_eq(@okf.StoreDir("a/./b//c/../d/").to_string(), "a/b/d")
  for text in ["..", "a/../..", "../a"] {
    assert_eq(
      outcome(() => @okf.StoreDir(text) |> ignore),
      @debug.to_string(@okf.PathError::EscapesRoot(text)),
    )
  }
  for text in ["", ".", "..", "a/b"] {
    assert_true(outcome(() => @okf.EntryName(text) |> ignore) != "ok")
  }
}

///|
test "concept types are not blank and compare without case" {
  assert_eq(
    @okf.ConceptType("Decision Record"),
    @okf.ConceptType("decision record"),
  )
  assert_eq(@okf.ConceptType("Decision Record").to_string(), "Decision Record")
  for text in ["", " ", "\t"] {
    assert_eq(
      outcome(() => @okf.ConceptType(text) |> ignore),
      @debug.to_string(@okf.ValueError::BlankConceptType(text)),
    )
  }
}

///|
test "field keys are plain keys" {
  for text in ["a", "_x", "9", "status", "a.b-c_d"] {
    assert_eq(@okf.FieldKey(text).to_string(), text)
  }
  for text in ["", "-a", ".a", "a b", "a:b", "\"a\"", "a\nb"] {
    assert_eq(
      outcome(() => @okf.FieldKey(text) |> ignore),
      @debug.to_string(@okf.ValueError::InvalidFieldKey(text)),
    )
  }
}

///|
test "rule names are lower-case kebab case" {
  for text in ["a", "concept-missing-type", "rule-2"] {
    assert_eq(@okf.RuleName(text).to_string(), text)
  }
  for text in ["", "-a", "a-", "a--b", "A", "a_b", "a b"] {
    assert_eq(
      outcome(() => @okf.RuleName(text) |> ignore),
      @debug.to_string(@okf.ValueError::InvalidRuleName(text)),
    )
  }
}

///|
test "search limits run from 1 to the maximum" {
  assert_eq(@okf.SearchLimit::default().to_int(), 20)
  assert_eq(@okf.SearchLimit(1).to_int(), 1)
  assert_eq(
    @okf.SearchLimit(@okf.max_search_limit).to_int(),
    @okf.max_search_limit,
  )
  for value in [-1, 0, @okf.max_search_limit + 1] {
    assert_eq(
      outcome(() => @okf.SearchLimit(value) |> ignore),
      @debug.to_string(@okf.ValueError::InvalidSearchLimit(value)),
    )
  }
}

///|

///|
test "log dates are real calendar dates" {
  assert_eq(@okf.LogDate("2024-02-29").to_string(), "2024-02-29")
  assert_true(@okf.LogDate("2026-09-01") < @okf.LogDate("2026-10-20"))
  for
    text in [
      "2026-02-29", "2026-13-01", "2026-1-01", "26-01-01", "", "2026-01-01T00:00:00Z",
    ] {
    assert_eq(
      outcome(() => @okf.LogDate(text) |> ignore),
      @debug.to_string(@okf.ValueError::InvalidDate(text)),
    )
  }
}

///|
test "OKF versions are known or unknown with their text" {
  assert_true(@okf.OkfVersion::parse("0.2") is V02)
  assert_true(@okf.OkfVersion::parse("0.1") is V01)
  assert_true(@okf.OkfVersion::parse("0.3") is Unknown("0.3"))
  assert_eq(@okf.OkfVersion::parse("0.3").to_string(), "0.3")
  assert_false(@okf.OkfVersion::parse("0.3").is_known())
  let b = @okf.load_bundle(
    @okf.DocumentSet::of_texts([
      ("index.md", "---\nokf_version: \"0.3\"\n---\n"),
    ]),
  )
  assert_true(b.okf_version() is Some(Unknown("0.3")))
}

///|
test "register parts: names, states, record IDs and ID widths" {
  assert_eq(@okf.IdWidth::default().to_int(), 4)
  assert_eq(@okf.IdWidth(1).to_int(), 1)
  assert_eq(@okf.IdWidth(9).to_int(), 9)
  for value in [0, 10] {
    assert_eq(
      outcome(() => @okf.IdWidth(value) |> ignore),
      @debug.to_string(@okf.ValueError::InvalidIdWidth(value)),
    )
  }
  for text in ["", " "] {
    assert_true(outcome(() => @okf.RegisterName(text) |> ignore) != "ok")
    assert_true(outcome(() => @okf.StateName(text) |> ignore) != "ok")
    assert_true(outcome(() => @okf.RecordId(text) |> ignore) != "ok")
  }
  assert_eq(
    @okf.normalize_id("42", @okf.IdWidth::default()).map(i => i.to_string()),
    Some("0042"),
  )
}

///|
test "a register checks that its states exist" {
  let name = @okf.RegisterName("decision")
  let kind = @okf.ConceptType("Decision Record")
  let proposed = @okf.StateName("proposed")
  let accepted = @okf.StateName("accepted")
  let ok = @okf.Register(name, kind, states=[proposed, accepted], transitions=[
    @okf.Transition(accepted, from=[proposed]),
  ])
  assert_eq(ok.states().length(), 2)
  let bad = outcome(() => {
    @okf.Register(name, kind, states=[proposed], transitions=[
      @okf.Transition(accepted, from=[proposed]),
    ])
    |> ignore
  })
  assert_eq(
    bad,
    @debug.to_string(
      @okf.ValueError::UnknownState(register="decision", state="accepted"),
    ),
  )
  let bad_superseded = outcome(() => {
    @okf.Register(name, kind, states=[proposed], superseded_states=[accepted])
    |> ignore
  })
  assert_true(bad_superseded != "ok")
}

///|
test "no sentinel values: Concept IDs, statuses and actors" {
  assert_eq(
    outcome(() => @okf.ConceptId("/.md") |> ignore),
    @debug.to_string(@okf.PathError::EmptyPath("/.md")),
  )
  assert_eq(
    @okf.ConceptId("/tables/customers.md").to_string(),
    "tables/customers",
  )
  assert_eq(@okf.Status::parse(""), None)
  assert_eq(@okf.Status::parse("  "), None)
  assert_eq(@okf.Status::parse(" Draft "), Some(Draft))
  guard @okf.Status::parse("archived") is Some(Unknown(word)) else {
    fail("expected an unknown status")
  }
  assert_eq(word.to_string(), "archived")
  assert_true(@okf.Actor::parse("") is None)
  assert_true(@okf.Actor::parse("human:") is Some(Other("human:")))
  assert_true(@okf.Actor::parse("human:jsmith") is Some(Human("jsmith")))
  let v01 = @okf.Options::default().update(v01_fields=true)
  let m = @okf.Metadata("timestamp: 2026-06-12T00:00:00Z\n")
  assert_eq(m.generated(options=v01).map(g => g.by), Some(None))
}

///|
test "an index preamble is a section, not a heading with level 0" {
  let b = @okf.load_bundle(
    @okf.DocumentSet::of_texts([
      ("index.md", "Intro prose.\n\n## Tables\n\n* [Orders](orders.md)\n"),
    ]),
  )
  guard b.document(@okf.BundlePath("/index.md")) is Some(doc) else {
    fail("no index")
  }
  let sections = doc.index_model().sections
  assert_eq(sections.length(), 2)
  assert_true(sections[0].heading is Preamble)
  assert_eq(sections[0].text.iter().collect(), ["Intro prose."])
  guard sections[1].heading is Titled(text, level) else { fail("no heading") }
  assert_eq(
    (text, level.to_int(), sections[1].entries.length()),
    ("Tables", 2, 1),
  )
}

///|
test "log order comes from the dates" {
  let b = @okf.load_bundle(
    @okf.DocumentSet::of_texts([
      ("log.md", "# Log\n\n## 2026-09-01\n\n* x\n\n## 2026-10-20\n\n## Later\n"),
    ]),
  )
  guard b.root_log() is Some(log) else { fail("no log") }
  let model = log.log_model()
  assert_true(model.sections[0].heading is Dated(_))
  assert_eq(model.sections[0].entries.length(), 1)
  assert_true(model.sections[2].heading is Undated("Later"))
  guard model.order_problem() is Some((a, c)) else { fail("no order problem") }
  assert_eq(
    (a.heading.to_string(), c.heading.to_string()),
    ("2026-09-01", "2026-10-20"),
  )
}

///|
test "a concept type named Subdirectories stays apart from subdirectories" {
  let b = @okf.load_bundle(
    @okf.DocumentSet::of_texts([
      ("a.md", "---\ntype: Subdirectories\ntitle: A\n---\n"),
      ("sub/b.md", "---\ntype: Note\n---\n"),
    ]),
  )
  assert_eq(
    @okf.generate_index(b),
    "# Subdirectories\n\n* [A](a.md)\n\n# Subdirectories\n\n* [sub](sub/index.md)\n",
  )
}

///|
test "a validation config keeps its own copy of the lists" {
  let disabled = [@okf.RuleName("concept-missing-type")]
  let config = @okf.ValidationConfig(disabled~)
  disabled.push(@okf.RuleName("orphan-concept"))
  assert_eq(config.disabled().length(), 1)
}

///|
test "fixed clocks parse instants" {
  assert_eq(
    @okf.FixedClock::at("2026-10-24").now(),
    @okf.FixedClock::at("2026-10-24T00:00:00Z").now(),
  )
  assert_eq(
    outcome(() => @okf.FixedClock::at("yesterday") |> ignore),
    @debug.to_string(@okf.ValueError::InvalidInstant("yesterday")),
  )
}
