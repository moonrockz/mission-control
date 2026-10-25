///|
/// The lexicon file of an `openspec/` tree, `ears.yaml`.
priv enum LexiconFile {
  /// The tree has no lexicon file.
  NoFile
  Loaded(@ears.Lexicon)
  /// The file does not parse; the profile parses with the other dialects.
  Invalid(@ears.LexiconError)
}

///|
/// The OpenSpec profile. It reads `openspec/` trees as OKF bundles, defines
/// native OKF types for OpenSpec content, links changes to capabilities, and
/// adds the OpenSpec checks. It parses requirement texts as EARS with the
/// OpenSpec dialect, the project lexicon file and a lexicon in code.
struct OpenSpecProfile {
  lexicon : @ears.Lexicon?
  file : LexiconFile
  /// The directory of the `openspec/` tree that holds the lexicon file.
  file_root : @okf.StoreDir?
}

///|
/// A profile with the OpenSpec dialect and, when given, a lexicon in code.
pub fn OpenSpecProfile::OpenSpecProfile(
  lexicon? : @ears.Lexicon,
) -> OpenSpecProfile {
  { lexicon, file: NoFile, file_root: None, }
}

///|
/// The name of the lexicon file at the root of an `openspec/` tree.
let lexicon_file_name : String = "ears.yaml"

///|
/// A profile for the `openspec/` tree at `root` of `set`. It reads the
/// project lexicon from `ears.yaml` at the root of the tree when it exists.
/// An invalid lexicon file gives an `openspec-lexicon-invalid` finding, and
/// the profile parses without it.
pub fn OpenSpecProfile::of_tree(
  set : @okf.DocumentSet,
  root : @okf.StoreDir,
  lexicon? : @ears.Lexicon,
) -> OpenSpecProfile {
  let name = @okf.EntryName(lexicon_file_name) catch {
    _ => abort("the lexicon file name is not an entry name")
  }
  let file = match set.get(root.file(name)) {
    None => NoFile
    Some(entry) =>
      try @ears.Lexicon::from_yaml(entry.content.text()) catch {
        e => Invalid(e)
      } noraise {
        l => Loaded(l)
      }
  }
  { lexicon, file, file_root: Some(root), }
}

///|
/// The dialects that the profile parses requirement texts with: the OpenSpec
/// dialect, the lexicon file when it parses, and the lexicon in code.
pub fn OpenSpecProfile::dialects(
  self : OpenSpecProfile,
) -> Array[&@ears.Dialect] {
  let out : Array[&@ears.Dialect] = [@ears.openspec_dialect()]
  match self.file {
    Loaded(l) => out.push(l)
    NoFile | Invalid(_) => ()
  }
  match self.lexicon {
    Some(l) => out.push(l)
    None => ()
  }
  out
}

///|
/// The error of the lexicon file, when it does not parse.
pub fn OpenSpecProfile::lexicon_error(
  self : OpenSpecProfile,
) -> @ears.LexiconError? {
  match self.file {
    Invalid(e) => Some(e)
    NoFile | Loaded(_) => None
  }
}

///|
/// The line of a lexicon error, when it has one.
fn lexicon_line(error : @ears.LexiconError) -> Int32? {
  match error {
    InvalidLexiconFile(line~, ..)
    | UnknownKey(line~, ..)
    | WrongType(line~, ..)
    | InvalidEntry(line~, ..) => Some(line)
    InvalidWord(_)
    | InvalidPhrase(_)
    | InvalidHeadingPrefix(_)
    | InvalidHeadingLevel(_) => None
  }
}

///|
/// Why a sentence is not EARS, in words.
fn parse_problem(error : @ears.ParseError) -> String {
  match error {
    EmptyRequirement => "it is empty"
    ExpectedSystem(_) => "it has no subject that the dialects know"
    MissingShall(_) => "it has no modal verb, such as SHALL or MUST"
    MissingResponse(_) => "nothing follows the modal verb"
    EmptyClause(keyword~, ..) => "its \{keyword} clause is empty"
    MissingSeparator(_) => "a clause has no comma before the next part"
    MissingThen(_) => "its If clause has no then"
    InvalidClauseOrder(_) => "its clauses are out of order"
    UnresolvedPronoun(pronoun~, ..) =>
      "`\{pronoun}` refers to no earlier sentence with a system"
  }
}

///|
/// The requirement sentences that do not parse as EARS, with the rule
/// `openspec-requirement-not-ears`: in spec documents and spec deltas, and in
/// native Requirement concepts, each at its own path and line. Archived
/// changes are not checked.
fn check_not_ears(
  ctx : @okf.ValidationContext,
  dialects : ArrayView[&@ears.Dialect],
) -> Array[@okf.Issue] {
  let out = []
  let report = (bundle : @okf.Bundle, doc : @okf.Document, r : Requirement) => {
    for d in r.sentence_diagnostics {
      let line = match d.origin() {
        Text(span) => r.text_lines.get(span.start().line() - 1)
        Markdown(..) => r.text_lines.get(0)
      }
      out.push(
        @okf.Issue::at(
          bundle,
          doc,
          "the sentence `\{d.text()}` of `\{r.name}` is not EARS: \{parse_problem(d.error())}",
          line?,
          hint="Write `<subject> SHALL <response>`, or add the word to openspec/ears.yaml.",
        ),
      )
    }
  }
  // Native Requirement concepts: the text is the body of the concept.
  for pair in ctx.knowledge.concepts() {
    let (bundle, doc) = pair
    guard type_of(doc) is Some(RequirementConcept) else { continue }
    guard capability_of(doc) is Some(cap) else { continue }
    guard requirement_of(doc, "requirement") is Some(name) else { continue }
    guard doc.metadata().line_of("requirement") is Some(line) else { continue }
    let model = parse_spec(
      cap,
      [(line, "### Requirement: " + name.to_string())] + doc.prose_lines(),
      dialects~,
    )
    for r in model.requirements {
      report(bundle, doc, r)
    }
  }
  for pair in spec_docs(ctx) {
    // An archived change is history, so its text is not checked.
    let archived = pair.1.metadata().text("state").bind(ChangeState::parse)
      is Some(Archived)
    guard !archived else { continue }
    guard model_of(pair.1, dialects) is Some(model) else { continue }
    for r in all_requirements(model) {
      report(pair.0, pair.1, r)
    }
  }
  out
}

///|
/// The lexicon file of the tree when it does not parse, with the rule
/// `openspec-lexicon-invalid`.
fn check_lexicon(
  ctx : @okf.ValidationContext,
  profile : OpenSpecProfile,
) -> Array[@okf.Issue] {
  guard profile.lexicon_error() is Some(error) else { return [] }
  guard profile.file_root is Some(root) else { return [] }
  let path = @okf.BundlePath("/" + lexicon_file_name) catch {
    _ => abort("the lexicon file path is not a bundle path")
  }
  let message = "the lexicon file does not parse: \{@debug.to_string(error)}"
  let out = []
  for bundle in ctx.knowledge.bundles() {
    if bundle.root() == root {
      out.push(
        @okf.Issue::in_bundle(
          { bundle: bundle.label(), path, },
          message,
          line?=lexicon_line(error),
        ),
      )
    }
  }
  // No bundle has the root of the tree: report the file by its store path.
  if out.is_empty() {
    let name = @okf.EntryName(lexicon_file_name) catch {
      _ => abort("the lexicon file name is not an entry name")
    }
    let at = lexicon_line(error).map(l => " (line \{l})").unwrap_or("")
    out.push(@okf.Issue::stray(root.file(name), message + at))
  }
  out
}
