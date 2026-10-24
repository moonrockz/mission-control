///|
/// The `status` key, as a typed frontmatter key.
let status_key : @okf.FieldKey = @okf.FieldKey("status") catch { _ => panic() }

///|
test "law: loading keeps every frontmatter key in order and every scalar as written" {
  @expect.for_all(
    (input : BundleCase) => {
      let b = input.bundle()
      @expect.expect_all(s => {
        for i, p in input.paths() {
          guard b.document(@okf.BundlePath(p)) is Some(doc) else {
            s.expect(p, label="missing").to_equal("")
            continue
          }
          let extras = input.extras(i)
          let expected_keys = ["type", "title", "description"] +
            extras.map(kv => kv.0)
          s
          .expect(doc.metadata().keys(), label="keys of \{p}")
          .to_equal(expected_keys)
          for kv in extras {
            s
            .expect(doc.metadata().text(kv.0), label="\{kv.0} of \{p}")
            .to_equal(Some(kv.1))
          }
        }
      })
    },
    count=300,
    max_size=12,
    max_shrinks=200,
    seed=2001,
  )
}

///|
test "law: a Concept ID and its path convert both ways" {
  @expect.for_all(
    (input : BundleCase) => {
      @expect.expect_all(s => {
        for p in input.paths() {
          let path = @okf.BundlePath(p) catch { _ => panic() }
          guard @okf.ConceptId::of_path(path) is Some(id) else { panic() }
          s.expect(id.to_path(), label="path").to_equal(path)
          s
          .expect(
            @okf.ConceptId(id.to_string()) catch {
              _ => panic()
            },
            label="id",
          )
          .to_equal(id)
        }
      })
    },
    count=300,
    max_size=12,
    max_shrinks=200,
    seed=2002,
  )
}

///|
test "law: each resolved link has exactly one matching backlink" {
  @expect.for_all(
    (input : BundleCase) => {
      let k = @okf.Knowledge([input.bundle()])
      let g = @okf.Graph::build(k)
      @expect.expect_all(s => {
        let mut resolved = 0
        for e in g.edges() {
          match e.target {
            Doc(key) => {
              resolved += 1
              let matches = g.backlinks(key).iter().filter(b => b == e).count()
              s
              .expect(matches, label="backlinks of \{key.to_string()}")
              .to_equal(1)
            }
            _ => ()
          }
        }
        let total = k
          .documents()
          .fold(init=0, (acc, pair) => {
            acc + g.backlinks(@okf.DocKey::of(pair.0, pair.1)).length()
          })
        s.expect(total, label="backlink count").to_equal(resolved)
      })
    },
    count=300,
    max_size=12,
    max_shrinks=200,
    seed=2003,
  )
}

///|
test "law: a key edit changes only the key line, and repeating it changes nothing" {
  @expect.for_all(
    (input : BundleCase) => {
      @expect.expect_all(s => {
        for i, _ in input.paths() {
          let text = input.concept_text(i)
          let r = @edit.set_key(text, status_key, "draft") catch {
            _ => panic()
          }
          let before = @okf.split_lines(text).map(l => l.text)
          let after = @okf.split_lines(r.text).map(l => l.text)
          s
          .expect(after.length(), label="one added line")
          .to_equal(before.length() + 1)
          s
          .expect(after.filter(l => !before.contains(l)), label="new lines")
          .to_equal(["status: draft"])
          s
          .expect(@okf.detect_line_ending(r.text), label="line ending")
          .to_equal(@okf.detect_line_ending(text))
          let again = @edit.set_key(r.text, status_key, "draft") catch {
            _ => panic()
          }
          s.expect(again.changed, label="idempotent").to_equal(false)
          let removed = @edit.remove_key(r.text, status_key) catch {
            _ => panic()
          }
          s.expect(removed.text, label="remove restores").to_equal(text)
        }
      })
    },
    count=300,
    max_size=12,
    max_shrinks=200,
    seed=2004,
  )
}

///|
test "law: a generated index lists every concept of its directory" {
  @expect.for_all(
    (input : BundleCase) => {
      let b = input.bundle()
      @expect.expect_all(s => {
        for d in ["", "tables", "metrics", "metrics/daily"] {
          let dir = if d == "" {
            []
          } else {
            d.split("/").map(x => x.to_owned()).collect()
          }
          let store_dir = @okf.StoreDir(d) catch { _ => panic() }
          let text = @okf.generate_index(b, dir=store_dir)
          for doc in b.concepts() {
            if doc.path().directory() == dir {
              s
              .expect(
                text.contains("](\{doc.path().name()})"),
                label="\{doc.path()} in \{d}",
              )
              .to_equal(true)
            }
          }
        }
      })
    },
    count=200,
    max_size=12,
    max_shrinks=200,
    seed=2005,
  )
}

///|
/// A random supersession graph over records 1..n: each record may name a
/// successor and may list predecessors.
priv struct SupersessionCase {
  choices : ReadOnlyArray[UInt32]
} derive(Debug)

///|
impl @quickcheck.Arbitrary for SupersessionCase with fn arbitrary(size, state) {
  { choices: @quickcheck.Arbitrary::arbitrary(size, state), }
}

///|
impl @shrink.Shrink for SupersessionCase with fn shrink(self) {
  @shrink.Shrink::shrink(self.choices).map(c => { choices: c, })
}

///|
fn law_register() -> @okf.Register raise @okf.ValueError {
  @okf.Register(
    @okf.RegisterName("decision"),
    @okf.ConceptType("Decision Record"),
    state_key=@okf.FieldKey("state"),
    supersedes_key=@okf.FieldKey("supersedes"),
    superseded_by_key=@okf.FieldKey("superseded_by"),
  )
}

///|
test "law: supersession is reported as not mutual exactly when one side is missing" {
  @expect.for_all(
    (input : SupersessionCase) => {
      let n = 4
      let pick = (i : Int32, m : Int32) => {
        if input.choices.is_empty() {
          0
        } else {
          (input.choices[i % input.choices.length()] % m.reinterpret_as_uint()).reinterpret_as_int()
        }
      }
      // successor[i] in 0..n (0 = none); predecessors via a bit mask.
      let successor = Array::makei(n, i => pick(i, n + 1))
      let preds = Array::makei(n, i => pick(i + n, 1 << n))
      let files = []
      for i in 0..<n {
        let id = i + 1
        let lines = ["---", "type: Decision Record", "state: Accepted"]
        if successor[i] > 0 && successor[i] != id {
          lines.push("superseded_by: \"\{successor[i]}\"")
        }
        let list = []
        for j in 0..<n {
          if ((preds[i] >> j) & 1) == 1 && j + 1 != id {
            list.push("\"\{j + 1}\"")
          }
        }
        if !list.is_empty() {
          lines.push("supersedes: [" + list.join(", ") + "]")
        }
        lines.push("---")
        files.push(("000\{id}-d.md", lines.join("\n") + "\n"))
      }
      let set = @okf.DocumentSet::of_texts(files) catch { _ => panic() }
      let law_register = law_register() catch { _ => panic() }
      let records = law_register.records(@okf.load_bundle(set))
      let names = (r : @okf.Record, key : String) => {
        r.metadata().texts(key).map(t => law_register.parse_id(t))
      }
      let id_text = (r : @okf.Record) => {
        r.id.map(i => i.to_string()).unwrap_or("")
      }
      // The model: a pair (a, b) is one-sided when a names b as successor and
      // b does not list a, or b lists a and a does not name b.
      let expected = []
      for a in records {
        for b in records {
          let a_names_b = b.id is Some(_) &&
            names(a, "superseded_by").contains(b.id)
          let b_lists_a = a.id is Some(_) &&
            names(b, "supersedes").contains(a.id)
          if a_names_b != b_lists_a {
            expected.push((id_text(a), id_text(b)))
          }
        }
      }
      let actual = []
      for i in law_register.supersession_issues(records) {
        match i {
          NotMutual(a, b) => {
            let pair = (id_text(a), id_text(b))
            if !actual.contains(pair) {
              actual.push(pair)
            }
          }
          _ => ()
        }
      }
      expected.sort()
      actual.sort()
      @expect.expect(actual).to_equal(expected)
    },
    count=300,
    max_size=16,
    max_shrinks=200,
    seed=2006,
  )
}

///|
test "law: importing OpenSpec and exporting it again keeps every file" {
  @expect.for_all(
    (input : BundleCase) => {
      let files = [("openspec/config.yaml", "schema: spec-driven\n")]
      for i, p in input.paths() {
        let cap = p.replace_all(old=".md", new="").replace_all(old="/", new="-")
        let reqs = []
        for j in 0..<(1 + input.pick(i + 3, 3)) {
          reqs.push(
            "### Requirement: R\{j}\nThe system SHALL do \{j}.\n\n#### Scenario: S\{j}\n- **WHEN** \{j}\n- **THEN** done\n",
          )
        }
        files.push(
          (
            "openspec/specs/\{cap}/spec.md",
            "# \{cap} Specification\n\n## Purpose\n\nPurpose \{i}.\n\n## Requirements\n\n" +
            reqs.join("\n"),
          ),
        )
      }
      let original = @okf.DocumentSet::of_texts(files) catch { _ => panic() }
      let (openspec_dir, kb_dir, date) = (
        @okf.StoreDir("openspec"),
        @okf.StoreDir("kb"),
        @okf.LogDate("2026-10-23"),
      ) catch {
        _ => panic()
      }
      let imported = (@openspec.import_openspec(
        original, openspec_dir, kb_dir, date,
      ) catch {
        _ => panic()
      }).apply_to(@okf.DocumentSet([]))
      let exported = (@openspec.export_openspec(imported, kb_dir, openspec_dir) catch {
        _ => panic()
      }).apply_to(@okf.DocumentSet([]))
      @expect.expect(
        exported.entries().map(e => (e.path.to_string(), e.content.text())),
      ).to_equal(
        original.entries().map(e => (e.path.to_string(), e.content.text())),
      )
    },
    count=150,
    max_size=10,
    max_shrinks=100,
    seed=2007,
  )
}
