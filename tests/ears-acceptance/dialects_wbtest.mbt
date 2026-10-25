///|
/// Scenario state for `features/dialects.feature`.
struct DialectWorld {
  dialects : Array[&@ears.Dialect]
  mut parsed : Result[@ears.Requirement, @ears.ParseError]?
  mut spec : @ears.Specification?
  mut lexicon : Result[@ears.Lexicon, @ears.LexiconError]?
}

///|
fn DialectWorld::DialectWorld() -> DialectWorld {
  { dialects: [], parsed: None, spec: None, lexicon: None, }
}

///|
fn DialectWorld::requirement(self : DialectWorld) -> @ears.Requirement raise {
  guard self.parsed is Some(Ok(r)) else {
    fail("no parsed requirement: \{@debug.to_string(self.parsed)}")
  }
  r
}

///|
fn DialectWorld::specification(
  self : DialectWorld,
) -> @ears.Specification raise {
  guard self.spec is Some(spec) else { fail("no block or Markdown parsed") }
  spec
}

///|
fn error_name(error : @ears.ParseError) -> String {
  match error {
    EmptyRequirement => "EmptyRequirement"
    ExpectedSystem(_) => "ExpectedSystem"
    MissingShall(_) => "MissingShall"
    MissingResponse(_) => "MissingResponse"
    EmptyClause(_) => "EmptyClause"
    MissingSeparator(_) => "MissingSeparator"
    MissingThen(_) => "MissingThen"
    InvalidClauseOrder(_) => "InvalidClauseOrder"
    UnresolvedPronoun(..) => "UnresolvedPronoun"
  }
}

///|
impl @moonspec.World for DialectWorld with fn configure(self, setup) {
  setup.given0("no dialect", () => ())
  setup.given0("the OpenSpec dialect", () => {
    self.dialects.push(@ears.openspec_dialect())
  })
  setup.given1("the lexicon:", (doc : @moonspec.DocString) => {
    self.dialects.push(@ears.Lexicon::from_yaml(doc.content))
  })
  setup.given1("a lexicon in code with the system noun {string}", (
    noun : String,
  ) => self.dialects.push(@ears.Lexicon(systems=[@ears.Phrase(noun)])))
  setup.when1("I parse the sentence {string}", (text : String) => {
    self.parsed = Some(
      try @ears.parse(text, dialects=self.dialects) catch {
        e => Err(e)
      } noraise {
        r => Ok(r)
      },
    )
  })
  setup.when1("I parse the block {string}", (text : String) => {
    self.spec = Some(@ears.parse_block(text, dialects=self.dialects))
  })
  setup.when1("I extract requirements from the Markdown:", (
    doc : @moonspec.DocString,
  ) => {
    self.spec = Some(
      @ears.parse_markdown(doc.content + "\n", dialects=self.dialects),
    )
  })
  setup.when1("I parse the lexicon file:", (doc : @moonspec.DocString) => {
    self.lexicon = Some(
      try @ears.Lexicon::from_yaml(doc.content + "\n") catch {
        e => Err(e)
      } noraise {
        l => Ok(l)
      },
    )
  })
  setup.then1("the parse fails with {string}", (expected : String) => {
    guard self.parsed is Some(Err(e)) else { fail("the parse did not fail") }
    @expect.expect(error_name(e)).to_equal(expected)
  })
  setup.then1("the subject opener is {string}", (expected : String) => {
    @expect.expect(self.requirement().opener().map(w => w.to_string())).to_equal(
      Some(expected),
    )
  })
  setup.then1("the system is {string}", (expected : String) => {
    @expect.expect(self.requirement().system()).to_equal(Some(expected))
  })
  setup.then0("the system is not resolved", () => {
    @expect.expect(self.requirement().system() is None).to_be_true()
  })
  setup.then1("the modal verb is {string}", (expected : String) => {
    @expect.expect(self.requirement().modal().verb.lower()).to_equal(expected)
  })
  setup.then0("the modal verb is negated", () => {
    @expect.expect(self.requirement().modal().negated).to_be_true()
  })
  setup.then1("the response is {string}", (expected : String) => {
    @expect.expect(self.requirement().response()).to_equal(expected)
  })
  setup.then1("the lead-in is {string}", (expected : String) => {
    @expect.expect(self.requirement().lead_in()).to_equal(Some(expected))
  })
  setup.then0("rendering and parsing again gives an equal requirement", () => {
    let first = self.requirement()
    let second = @ears.parse(first.to_string(), dialects=self.dialects)
    @expect.expect(second).to_equal(first)
  })
  setup.then2("the block has {int} requirements and {int} diagnostics", (
    requirements : Int32,
    diagnostics : Int32,
  ) => {
    let spec = self.specification()
    @expect.expect_all(s => {
      s.expect(spec.requirements().length()).to_equal(requirements)
      s.expect(spec.diagnostics().length()).to_equal(diagnostics)
    })
  })
  setup.then2("requirement {int} has the resolved system {string}", (
    index : Int32,
    expected : String,
  ) => {
    let spec = self.specification()
    guard spec.requirements().get(index - 1) is Some(item) else {
      fail("no requirement \{index}")
    }
    @expect.expect(item.requirement().resolved_system()).to_equal(
      Some(expected),
    )
  })
  setup.then2("there is one block named {string} with {int} requirements", (
    name : String,
    requirements : Int32,
  ) => {
    let blocks = self.specification().blocks()
    @expect.expect(blocks.length()).to_equal(1)
    @expect.expect_all(s => {
      s.expect(blocks[0].name()).to_equal(name)
      s.expect(blocks[0].requirements().length()).to_equal(requirements)
      s.expect(blocks[0].diagnostics().length()).to_equal(0)
    })
  })
  setup.then0("there are no blocks", () => {
    @expect.expect(self.specification().blocks().length()).to_equal(0)
  })
  setup.then1("the extraction has {int} requirements", (requirements : Int32) => {
    @expect.expect(self.specification().requirements().length()).to_equal(
      requirements,
    )
  })
  setup.then2(
    "the lexicon adds the system noun {string} and the lead-in {string}",
    (noun : String, lead_in : String) => {
      guard self.lexicon is Some(Ok(lexicon)) else {
        fail("the lexicon file did not parse")
      }
      @expect.expect_all(s => {
        s.expect(lexicon.system_nouns()).to_equal([@ears.Phrase(noun)])
        s.expect(lexicon.lead_ins()).to_equal([@ears.Phrase(lead_in)])
      })
    },
  )
  setup.then2("the lexicon file fails for {string} on line {int}", (
    key : String,
    line : Int32,
  ) => {
    guard self.lexicon is Some(Err(WrongType(key=k, line=l, ..))) else {
      fail("no wrong type error: \{@debug.to_string(self.lexicon)}")
    }
    @expect.expect((k, l)).to_equal((key, line))
  })
}

///|
async test "EARS dialect scenarios" {
  @moonspec.run_or_fail(
    () => DialectWorld::DialectWorld(),
    @moonspec.RunOptions::RunOptions([
      @moonspec.FeatureSource::File("ears-acceptance/features/dialects.feature"),
    ]),
  )
}
