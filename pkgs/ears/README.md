# EARS

`moonrockz/ears` parses and represents requirements written in
[EARS, the Easy Approach to Requirements Syntax](https://alistairmavin.com/ears/).
It supports ubiquitous, state driven, event driven, optional feature, unwanted
behaviour and complex requirements.

Import `moonrockz/ears` as `@ears` in `moon.pkg`. To work with an
existing MDC document, also import `moonrockz/mdc` as `@mdc`.

## One requirement

```moonbit
let requirement = @ears.Requirement::Requirement(
  "While enabled, when polled, the sensor shall report temperature.",
)
// requirement.pattern() == @ears.Complex
// requirement.preconditions() == ["enabled"]
// requirement.trigger() is Some(Event("polled"))
// requirement.system() == "sensor"
// requirement.response() == "report temperature."
```

`parse(source)` is an alias for the constructor. Both raise a typed `ParseError`
on invalid syntax. Each case except `EmptyRequirement` has the
`SentencePosition` in the normalized sentence where the parse failed
(`error.position()`), and `EmptyClause` names its `Keyword` (`Where`, `While`,
`When` or `If`). `keywords` lists the clause keywords. `Requirement` is opaque
and immutable. Accessors expose an optional feature, a read-only sequence of
preconditions, an optional event or unwanted trigger (a read-only `Trigger`),
the system name and its response. `pattern()` derives the
classification from those clauses. Multiple clauses produce `Complex`.

The accepted grammar is:

```text
[Where <feature>,] [While <state>, ...]
[When <event>, | If <unwanted condition>, then]
the <system> shall <response>
```

`Where` comes first, followed by zero or more `While` clauses, then at most one
`When` or `If` clause. `If` requires `then`; the comma immediately before
`then` is optional. Conditional clauses otherwise need comma separators.
Keywords are case-insensitive. ASCII whitespace folds to a single space;
the case and punctuation of free text remain intact. A final period is optional
and remains part of `response()`. `to_string()` renders canonical keyword case
and spacing and can be parsed back to an equal requirement.

Clauses, the system name and the response must be nonempty. Clause contents are
free text: the parser does not split English conjunctions into separate states
or responses, infer actor identities, or judge whether a requirement is testable.
A comma followed by an EARS keyword starts a new clause. In unwanted conditions,
`then` is structural only when followed by `the`. Avoid other clause-opening
keyword sequences inside a clause's free text. Requirement IDs, labels and
sentence splitting are outside this grammar.

## Plain-text specifications

```moonbit
let spec = @ears.parse_text(
  "The sensor shall measure.\nWhen polled, the sensor shall reply.\n",
)
let requirement = spec.requirements()[0].requirement()
```

Plain text contains one requirement per nonblank line. Every nonblank line is
checked. Invalid lines become `Diagnostic` values and do not discard valid
requirements on other lines. LF, CRLF, CR and a leading BOM are supported.
Blank input yields an empty specification. Use the single-requirement constructor
for a standalone sentence wrapped across lines.

## Markdown and MDC

```moonbit
let spec = @ears.parse_markdown(
  "---\ntitle: Sensor\n---\n- When **polled**, the sensor shall reply.\n",
)
// spec.document() retains the immutable MDC document and its frontmatter.

let document = @mdc.Document::Document("The sensor shall measure.")
let extracted = @ears.from_mdc(document)
```

`parse_markdown` uses MDC's parser, including its optional YAML mapping header.
`strict` and `file` pass through to MDC. Invalid frontmatter raises MDC's
`ParseError`. EARS syntax failures appear in `spec.diagnostics()`.
`from_mdc` uses an existing document without reparsing it.

Write one requirement per paragraph or list-item paragraph. Paragraphs in
blockquotes also count. Wrapped lines join with spaces. Emphasis and link text,
inline code, autolinks and inline math supply sentence text. Headings, fenced
and indented code blocks, HTML blocks, image alt text, tables, footnotes and
frontmatter do not supply requirements.

Extraction considers paragraphs starting with `Where`, `While`, `When` or `If`,
or starting with `The` and containing the word `shall`, `should` or `must`.
Those candidates either produce requirements or diagnostics. Other prose is
ignored. This rule lets documents mix requirements with explanatory text;
prose beginning with a conditional keyword can also produce a diagnostic.

## Source context

`requirements()` and `diagnostics()` return read-only arrays in source order.
Each occurrence contains a validated requirement and its `Origin`. Each
diagnostic contains its candidate text, typed error and origin.

`Origin::Text` carries a `SourceSpan` excluding indentation and newline characters.
`Origin::Markdown` carries a path that resolves through
`spec.document().unwrap().root().at(path)`, and an optional span covering the
original paragraph, including inline markup and line wrapping.

Spans use half-open UTF-16 offsets in the original input and one-based start
lines and columns. Frontmatter and a leading BOM contribute to offsets. Columns
count UTF-16 code units, including the BOM on the first line. For MDC documents
parsed with `locs=false`, Markdown spans are absent and paths remain available.

## Dialects and lexicons

Without a dialect, every function parses strict EARS: `the <system> shall
<response>`. A `Dialect` adds vocabulary to the same grammar. Each method has a
default, so a dialect gives only what it adds:

| Method | Adds | Example |
| --- | --- | --- |
| `modals` | modal verbs besides `shall`; `not` after one negates it | `must` |
| `determiners` | words that start a subject besides `the` | `each`, `an` |
| `pronouns` | words that stand for a system | `it` |
| `system_nouns` | phrases that are a whole subject | `Mission Control` |
| `lead_ins` | phrases before the clauses | `otherwise`, `for each` |
| `headings` | Markdown headings that start a requirement block | level 3, `Requirement:` |

`parse(source, dialects=[...])`, `parse_text`, `parse_block`, `parse_markdown`
and `from_mdc` take a list of dialects and use the union of their vocabularies.
Keywords match without letter case. A `Requirement` records its `lead_in()`, its
`subject()` (`Determined`, `Noun` or `Pronoun`), its `opener()` and its
`modal()` (verb and negation). `system()` gives the system, or for a pronoun the
system that block parsing resolved it to. `to_string()` renders the requirement
so that parsing it again with the same dialects gives an equal requirement.

`parse_block(text, dialects=[...])` splits a requirement text into sentences: a
sentence ends at `.`, `?` or `!` that white space or the end follows, outside
backticks. A pronoun subject refers to the system of the nearest earlier
sentence; without one, the requirement stays and an `UnresolvedPronoun`
diagnostic names it. With heading rules, `parse_markdown` gives one
`RequirementBlock` for each matching heading (`blocks()`): its name, its heading
range, and the requirements of the paragraphs up to the next heading.

A `Lexicon` is a dialect as data. Build one in code with `Lexicon(systems=[...])`,
or parse a lexicon file with `Lexicon::from_yaml(text)`:

```yaml
name: mission-control
modals: [must]
determiners: [each]
pronouns: [it]
systems: [Mission Control]
lead_ins: [otherwise, for each]
headings:
  - level: 3
    prefix: "Requirement:"
```

Words (`Word`) have no white space, comma or full stop; phrases (`Phrase`) are
words with single spaces. An unknown key, a value of the wrong kind and an
invalid entry raise `LexiconError` with the line. `openspec_dialect()` gives the
OpenSpec dialect: `shall` and `must`, the usual determiners, `it` and `they`, the
lead-in `otherwise`, and the `### Requirement:` heading.

## Tests

Focused regressions live beside the parser. Public behaviour has Gherkin scenarios
in `tests/ears-acceptance/` and reproducible generated laws in `tests/ears-laws/`.

```shell
mise exec -- moon test pkgs/ears tests/ears-acceptance tests/ears-laws --target js
```
