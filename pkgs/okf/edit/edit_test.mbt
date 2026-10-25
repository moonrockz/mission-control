///|
test "setting an equal value reports no change" {
  let text = "---\ntype: Metric\nstatus: stable\n---\nBody\n"
  let r = @edit.set_key(text, @okf.FieldKey("status"), "stable")
  assert_eq(r.changed, false)
  assert_eq(r.text, text)
}

///|
test "CRLF files keep CRLF and change one line only" {
  let text = "---\r\ntype: Metric\r\nstatus: draft\r\n---\r\nBody\r\n"
  let r = @edit.set_key(text, @okf.FieldKey("status"), "stable")
  assert_eq(r.text, "---\r\ntype: Metric\r\nstatus: stable\r\n---\r\nBody\r\n")
  assert_eq(r.changed, true)
}

///|
test "a new key goes after the last frontmatter line, after a block" {
  let text = "---\ntype: Metric\nsources:\n  - resource: https://a\n---\n# A\n"
  let r = @edit.set_key(text, @okf.FieldKey("status"), "deprecated")
  assert_eq(
    r.text,
    "---\ntype: Metric\nsources:\n  - resource: https://a\nstatus: deprecated\n---\n# A\n",
  )
}

///|
test "values that need quotes" {
  let r = @edit.set_key(
    "---\ntype: A\n---\n",
    @okf.FieldKey("title"),
    "Revenue: net",
  )
  assert_eq(r.text, "---\ntype: A\ntitle: \"Revenue: net\"\n---\n")
  assert_eq(@edit.yaml_scalar("say \"hi\", ok"), "\"say \\\"hi\\\", ok\"")
  assert_eq(@edit.yaml_scalar(""), "\"\"")
}

///|
test "removing a key removes its value lines only" {
  let text = "---\ntype: A\nstale_after: 2026-01-01T00:00:00Z\ntags:\n  - x\n# comment\nstatus: draft\n---\nBody\n"
  let r = @edit.remove_key(text, @okf.FieldKey("tags"))
  assert_eq(
    r.text,
    "---\ntype: A\nstale_after: 2026-01-01T00:00:00Z\n# comment\nstatus: draft\n---\nBody\n",
  )
  let r2 = @edit.remove_key(r.text, @okf.FieldKey("stale_after"))
  assert_eq(r2.text, "---\ntype: A\n# comment\nstatus: draft\n---\nBody\n")
}

///|
test "a key on a document without frontmatter adds a block" {
  let r = @edit.set_key("# A\n", @okf.FieldKey("type"), "Note")
  assert_eq(r.text, "---\ntype: Note\n---\n# A\n")
}

///|
test "index entries go after the last entry or into a new section" {
  let index = "# Tables\n\n* [Orders](/tables/orders.md) - One row per order\n\n# Other\n\n* [X](/x.md)\n"
  let r = @edit.add_index_entry(
    index,
    @edit.SectionName("Tables"),
    @edit.IndexEntryLine(
      "Customers",
      "/tables/customers.md",
      description="One row per customer",
    ),
  )
  assert_eq(
    r.text,
    "# Tables\n\n* [Orders](/tables/orders.md) - One row per order\n* [Customers](/tables/customers.md) - One row per customer\n\n# Other\n\n* [X](/x.md)\n",
  )
  let r2 = @edit.add_index_entry(
    index,
    @edit.SectionName("Metrics"),
    @edit.IndexEntryLine("Revenue", "/metrics/revenue.md"),
  )
  assert_eq(
    r2.text,
    index + "\n# Metrics\n\n* [Revenue](/metrics/revenue.md)\n",
  )
}

///|
test "refresh changes only the description and keeps the link text" {
  let index = "# Metrics\n\n* [Daily *revenue*](/metrics/revenue.md) - Old text\n"
  let r = @edit.refresh_index_entry(
    index, "/metrics/revenue.md", "Net revenue per day",
  )
  assert_eq(
    r.text,
    "# Metrics\n\n* [Daily *revenue*](/metrics/revenue.md) - Net revenue per day\n",
  )
}

///|
test "log entries: existing date, new newest date, older date" {
  let log = "# Log\n\n## 2026-10-20\n\n* **Update**: Added revenue metric.\n\n## 2026-09-01\n\n* **Creation**: Started.\n"
  let r = @edit.add_log_entry(
    log,
    @okf.LogDate("2026-10-23"),
    "Added churn.",
    label="Creation",
  )
  assert_eq(
    r.text,
    "# Log\n\n## 2026-10-23\n\n* **Creation**: Added churn.\n\n## 2026-10-20\n\n* **Update**: Added revenue metric.\n\n## 2026-09-01\n\n* **Creation**: Started.\n",
  )
  let r2 = @edit.add_log_entry(
    log,
    @okf.LogDate("2026-10-20"),
    "Fixed a typo.",
    label="Update",
  )
  assert_eq(
    r2.text,
    "# Log\n\n## 2026-10-20\n\n* **Update**: Added revenue metric.\n* **Update**: Fixed a typo.\n\n## 2026-09-01\n\n* **Creation**: Started.\n",
  )
  let r3 = @edit.add_log_entry(log, @okf.LogDate("2026-09-15"), "Middle.")
  assert_eq(
    r3.text,
    "# Log\n\n## 2026-10-20\n\n* **Update**: Added revenue metric.\n\n## 2026-09-15\n\n* Middle.\n\n## 2026-09-01\n\n* **Creation**: Started.\n",
  )
}

///|
test "regions keep their preamble and report no change for equal content" {
  let text = "# Index\n\nHand-written.\n\n<!-- intent:index -->\n* [A](/a.md)\n"
  let same = @edit.replace_region(text, "intent:index", "* [A](/a.md)\n")
  assert_eq(same.changed, false)
  let next = @edit.replace_region(text, "intent:index", "* [B](/b.md)\n")
  assert_eq(
    next.text,
    "# Index\n\nHand-written.\n\n<!-- intent:index -->\n* [B](/b.md)\n",
  )
  let missing = try
    @edit.replace_region("# Index\n", "intent:index", "")
  catch {
    NoRegion(name) => name
    _ => ""
  } noraise {
    _ => ""
  }
  assert_eq(missing, "intent:index")
}

///|
fn sample_bundle() -> @okf.Bundle raise {
  @okf.load_bundle(
    @okf.DocumentSet::of_texts([
      (
        "index.md", "---\nokf_version: \"0.2\"\n---\n# Tables\n\n* [Orders](/tables/orders.md) - Orders\n",
      ),
      ("log.md", "# Log\n\n## 2026-10-20\n\n* **Creation**: Started.\n"),
      (
        "tables/orders.md", "---\ntype: Table\ntitle: Orders\ndescription: Orders\n---\n# Orders\n",
      ),
      ("decisions/index.md", "# Decisions\n"),
    ]),
  )
}

///|
test "new concepts: reserved, escaping and existing paths are refused" {
  let b = sample_bundle()
  assert_true(refusal(b, "/tables/index.md") is Some(ReservedName(_)))
  assert_true(refusal(b, "/../x.md") is Some(EscapesBundle(_)))
  assert_true(refusal(b, "/tables/orders.md") is Some(AlreadyExists(_)))
  assert_true(refusal(b, "/tables/customers.md") is None)
}

///|
test "target index: the nearest sub-index, else the root index" {
  let b = sample_bundle()
  assert_eq(
    @edit.target_index(b, @okf.BundlePath("/decisions/0042-use-yaml.md")).map(p => {
      p.to_string()
    }),
    Some("/decisions/index.md"),
  )
  assert_eq(
    @edit.target_index(b, @okf.BundlePath("/metrics/revenue.md")).map(p => {
      p.to_string()
    }),
    Some("/index.md"),
  )
}

///|
test "planning a concept writes nothing until the plan applies" {
  let b = sample_bundle()
  let set = @okf.DocumentSet::of_texts([])
  let plan = @edit.plan_add_concept(
    b,
    "/metrics/revenue.md",
    @okf.ConceptType("Metric"),
    "Revenue",
    "Net revenue per day",
    @okf.LogDate("2026-10-23"),
  )
  let paths = plan.changes().map(c => c.path().to_string())
  assert_eq(paths.iter().collect(), ["metrics/revenue.md", "index.md", "log.md"])
  assert_eq(set.length(), 0)
  guard plan.changes()[0] is Create(text~, ..) else {
    fail("expected a create")
  }
  assert_true(
    text.has_prefix(
      "---\ntype: Metric\ntitle: Revenue\ndescription: Net revenue per day\n---\n",
    ),
  )
  guard plan.changes()[1] is Update(after~, ..) else {
    fail("expected an update")
  }
  assert_true(
    after.contains(
      "# Metric\n\n* [Revenue](/metrics/revenue.md) - Net revenue per day\n",
    ),
  )
  guard plan.changes()[2] is Update(after~, ..) else {
    fail("expected an update")
  }
  assert_true(
    after.contains(
      "## 2026-10-23\n\n* **Creation**: Added [Revenue](/metrics/revenue.md).\n",
    ),
  )
  let applied = plan.apply_to(set)
  assert_eq(applied.length(), 3)
  assert_true(plan.render().has_prefix("create metrics/revenue.md\n+ ---\n"))
}

///|
fn refusal(b : @okf.Bundle, path : String) -> @edit.PathRefusal? {
  try @edit.check_new_concept_path(b, path) catch {
    PathRefused(r) => Some(r)
    _ => None
  } noraise {
    _ => None
  }
}

///|
test "values with line breaks, null-like values and entry markers stay strings" {
  assert_eq(@edit.yaml_scalar("a\nb"), "\"a\\nb\"")
  assert_eq(@edit.yaml_scalar("tab\there"), "\"tab\\there\"")
  assert_eq(@edit.yaml_scalar("null"), "\"null\"")
  assert_eq(@edit.yaml_scalar("~"), "\"~\"")
  assert_eq(@edit.yaml_scalar("- item"), "\"- item\"")
  assert_eq(@edit.yaml_scalar("plain"), "plain")
  for
    value in [
      "a\nb\r\nc", "null", "~", "- item", "? key", "line\tend", "quote \" and \\ slash",
    ] {
    let text = @edit.set_key(
        "---\ntype: A\n---\n",
        @okf.FieldKey("title"),
        value,
      ).text
    let doc = @okf.Document(
      @okf.BundlePath("/a.md"),
      @okf.StorePath("a.md"),
      text,
    )
    assert_eq(doc.metadata().keys(), ["type", "title"], msg=value)
    assert_eq(doc.metadata().text("title"), Some(value), msg=value)
  }
}

///|
fn edit_error(
  f : () -> @edit.EditResult raise @edit.EditError,
) -> @edit.EditError? {
  try f() catch {
    e => Some(e)
  } noraise {
    _ => None
  }
}

///|
fn raw_error(text : String) -> @edit.EditError? {
  try @edit.RawYaml(text) catch {
    e => Some(e)
  } noraise {
    _ => None
  }
}

///|
test "raw values cannot add keys or close the block" {
  let text = "---\ntype: A\n---\n"
  assert_eq(raw_error("x\nstatus: done"), Some(InvalidValue("x\nstatus: done")))
  assert_eq(raw_error("x\n---"), Some(InvalidValue("x\n---")))
  assert_eq(raw_error("x"), None)
  // An indented continuation is a valid block value.
  let r = @edit.set_raw_keys(text, [
    (@okf.FieldKey("tags"), Some(@edit.RawYaml("\n  - a\n  - b"))),
  ])
  let doc = @okf.Document(
    @okf.BundlePath("/a.md"),
    @okf.StorePath("a.md"),
    r.text,
  )
  assert_eq(doc.metadata().texts("tags"), ["a", "b"])
  assert_eq(doc.metadata().keys(), ["type", "tags"])
  assert_eq(@edit.RawYaml::list(["a", "b c:"]).to_string(), "[a, \"b c:\"]")
}

///|
test "section names are one line and not blank" {
  assert_eq(@edit.SectionName("Tables").to_string(), "Tables")
  let errors = ["A\nB", "A\rB", "", "  "].map(text => {
    try @edit.SectionName(text) catch {
      e => Some(e)
    } noraise {
      _ => None
    }
  })
  assert_eq(errors, [
    Some(LineBreak(field="section", text="A\nB")),
    Some(LineBreak(field="section", text="A\rB")),
    Some(BlankText(field="section", text="")),
    Some(BlankText(field="section", text="  ")),
  ])
}

///|
test "log entries order an undated heading by its text" {
  let log = "# Log\n\n## Notes\n\n* x\n"
  let r = @edit.add_log_entry(log, @okf.LogDate("2026-01-01"), "y")
  assert_eq(r.text, "# Log\n\n## Notes\n\n* x\n\n## 2026-01-01\n\n* y\n")
}

///|
fn transition_error(
  f : () -> @edit.EditPlan raise @edit.PlanError,
) -> @edit.TransitionRefusal? {
  try f() catch {
    TransitionRefused(r) => Some(r)
    _ => None
  } noraise {
    _ => None
  }
}

///|
fn intent_register(states : Array[String]) -> @okf.Register raise {
  let states = states.map(s => @okf.StateName(s))
  @okf.Register(
    @okf.RegisterName("intent"),
    @okf.ConceptType("Intent"),
    state_key=@okf.FieldKey("state"),
    states~,
    transitions=[@okf.Transition(states[1], from=[states[0]])],
  )
}

///|
test "a transition cannot replace the checked state through extra keys" {
  let reg = intent_register(["Backlog", "Review", "Done"])
  let b = @okf.load_bundle(
    @okf.DocumentSet::of_texts([
      ("0001-a.md", "---\ntype: Intent\nstate: Backlog\n---\n"),
    ]),
  )
  let record = reg.records(b)[0]
  let review = @okf.StateName("Review")
  let extra = [(@okf.FieldKey("state"), @edit.RawYaml("Done"))]
  let refused = transition_error(() => {
    @edit.plan_transition(reg, record, review, extra~)
  })
  guard refused is Some(StateKeyInExtra(key)) else { fail("not refused") }
  assert_eq(key.to_string(), "state")
  let no_state = @okf.Register(
    @okf.RegisterName("note"),
    @okf.ConceptType("Note"),
  )
  let missing = transition_error(() => {
    @edit.plan_transition(no_state, record, review)
  })
  guard missing is Some(NoStateKey(register~)) else { fail("not refused") }
  assert_eq(register.to_string(), "note")
  let plan = @edit.plan_transition(reg, record, review)
  guard plan.changes()[0] is Update(after~, ..) else { fail("no update") }
  assert_eq(after, "---\ntype: Intent\nstate: Review\n---\n")
}

///|
test "log entries and index entries must be one line" {
  let date = @okf.LogDate("2026-01-01")
  assert_eq(
    edit_error(() => {
      @edit.add_log_entry("# Log\n", date, "x\n## 2099-01-01\n* forged")
    }),
    Some(LineBreak(field="message", text="x\n## 2099-01-01\n* forged")),
  )
  assert_eq(
    edit_error(() => @edit.add_log_entry("# Log\n", date, "x", label="A\nB")),
    Some(LineBreak(field="label", text="A\nB")),
  )
  let refused = try @edit.IndexEntryLine("Bad\n# Section", "/a.md") catch {
    LineBreak(field~, ..) => field
    _ => ""
  } noraise {
    _ => ""
  }
  assert_eq(refused, "title")
  let refused = try @edit.IndexEntryLine("x", "/x.md\n# B") catch {
    LineBreak(field~, ..) => field
    _ => ""
  } noraise {
    _ => ""
  }
  assert_eq(refused, "destination")
  let refused = try
    @edit.IndexEntryLine("x", "/x.md", description="a\rb")
  catch {
    LineBreak(field~, ..) => field
    _ => ""
  } noraise {
    _ => ""
  }
  assert_eq(refused, "description")
}

///|
test "a transition refuses a preview whose frontmatter would not parse" {
  let reg = intent_register(["Backlog", "Review"])
  let b = @okf.load_bundle(
    @okf.DocumentSet::of_texts([
      ("0001-a.md", "---\ntype: Intent\nstate: Backlog\nnote: x\n---\n"),
    ]),
  )
  let record = reg.records(b)[0]
  let review = @okf.StateName("Review")
  let extra = [(@okf.FieldKey("note"), @edit.RawYaml("[unclosed"))]
  let refused = transition_error(() => {
    @edit.plan_transition(reg, record, review, extra~)
  })
  assert_true(refused is Some(PreviewInvalid(_)))
}
