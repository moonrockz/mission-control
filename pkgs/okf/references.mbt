///|
/// What a typed reference points to.
pub(all) enum RefTarget {
  ToDocument(DocKey)
  ToRecord(register~ : RegisterName, record~ : DocKey)
  ToFile(StorePath)
  ToUri(String)
  /// A free-text scope, such as `all queries in project X`.
  FreeText(String)
  /// The value does not have the form that the field requires.
  Malformed(String)
  /// The value has the right form, but names nothing that exists.
  Unresolved(String)
} derive(Eq, Debug)

///|
/// One typed reference of a document. The key is the frontmatter key, such as
/// `sources`.
pub struct TypedReference {
  key : FieldKey
  value : String
  line : Int32?
  target : RefTarget
} derive(Eq, Debug)

///|
pub fn TypedReference::is_resolved(self : TypedReference) -> Bool {
  match self.target {
    ToDocument(_) | ToRecord(..) | ToFile(_) | ToUri(_) | FreeText(_) => true
    Malformed(_) | Unresolved(_) => false
  }
}

///|
/// Raised when a document reference does not parse.
pub(all) suberror DocRefError {
  /// The text is neither `/path.md` nor `bundle-label:/path.md`.
  NotADocRef(String)
  /// The label part is not a valid bundle label.
  BadLabel(text~ : String, error~ : ValueError)
  /// The path part escapes the bundle or names no file.
  BadPath(text~ : String, error~ : PathError)
} derive(Eq, Debug)

///|
/// A document reference: `bundle-label:/path.md`, or `/path.md` in the same
/// bundle. It holds a valid label and a valid bundle path.
struct DocRef {
  bundle : BundleLabel?
  path : BundlePath
} derive(Eq, Debug)

///|
/// Parses `bundle-label:/path.md` or `/path.md`.
pub fn DocRef::DocRef(text : String) -> DocRef raise DocRefError {
  let t = text.trim(chars=" \t").to_owned()
  let (label_text, path_text) = if t.has_prefix("/") {
    (None, t)
  } else {
    match t.find(":/") {
      Some(i) if i > 0 => (Some(t[:i].to_owned()), t[i + 1:].to_owned())
      _ => raise NotADocRef(text)
    }
  }
  let bundle = match label_text {
    Some(l) =>
      Some(BundleLabel(l) catch { e => raise BadLabel(text~, error=e) })
    None => None
  }
  let path = BundlePath(path_text) catch { e => raise BadPath(text~, error=e) }
  { bundle, path, }
}

///|
/// The bundle label, or `None` for a reference in the same bundle.
pub fn DocRef::bundle(self : DocRef) -> BundleLabel? {
  self.bundle
}

///|
pub fn DocRef::path(self : DocRef) -> BundlePath {
  self.path
}

///|
fn path_target(
  knowledge : Knowledge,
  bundle : Bundle,
  doc : Document,
  value : String,
  resolver : &LinkResolver?,
) -> RefTarget {
  if value.contains(" ") && !value.has_prefix("/") && !has_scheme(value) {
    return FreeText(value)
  }
  match resolve_field_path(bundle, doc, value) {
    ExternalUri(uri) => ToUri(uri)
    SameDocument(_) => ToDocument(DocKey::of(bundle, doc))
    Unresolvable(v) => Unresolved(v)
    StoreTarget(path~, ..) =>
      match knowledge.document_at(path) {
        Some((b, d)) => ToDocument(DocKey::of(b, d))
        None => {
          let known = match resolver {
            Some(r) => r.exists(path)
            None => false
          }
          if known {
            ToFile(path)
          } else {
            Unresolved(value)
          }
        }
      }
  }
}

///|
fn doc_ref_target(
  knowledge : Knowledge,
  bundle : Bundle,
  value : String,
) -> RefTarget {
  let r = DocRef(value) catch { _ => return Malformed(value) }
  let target_bundle = match r.bundle {
    None => Some(bundle)
    Some(label) => knowledge.bundle(label).to_option()
  }
  match target_bundle {
    None => Unresolved(value)
    Some(b) =>
      match b.document(r.path) {
        Some(d) => ToDocument(DocKey::of(b, d))
        None => Unresolved(value)
      }
  }
}

///|
/// The `sources` key, which is a valid field key.
let sources_key : FieldKey = { text: "sources", }

///|
/// The typed references of a document: each `sources[].resource`, and each
/// value of the reference fields of `profiles`. A profile whose definitions
/// break a rule adds no references; `validate` reports it.
pub fn typed_references(
  knowledge : Knowledge,
  bundle : Bundle,
  doc : Document,
  profiles~ : ArrayView[&Profile] = [],
  resolver? : &LinkResolver,
) -> Array[TypedReference] {
  let meta = doc.metadata()
  let out = []
  for source in meta.sources() {
    out.push({
      key: sources_key,
      value: source.resource,
      line: meta.line_of("sources"),
      target: path_target(knowledge, bundle, doc, source.resource, resolver),
    })
  }
  let registers = registers_of(profiles)
  for profile in profiles {
    let fields = profile.reference_fields() catch { _ => [] }
    for field in fields {
      let key = field.key.to_string()
      for value in meta.texts(key) {
        let target = match field.kind {
          PathRef => path_target(knowledge, bundle, doc, value, resolver)
          DocumentRef => doc_ref_target(knowledge, bundle, value)
          RecordRef(register~) =>
            match registers.iter().find_first(r => r.name() == register) {
              None => Unresolved(value)
              Some(reg) =>
                match reg.find(reg.records(bundle), value) {
                  Found(record) => ToRecord(register~, record=record.key())
                  _ => Unresolved(value)
                }
            }
        }
        out.push({ key: field.key, value, line: meta.line_of(key), target, })
      }
    }
  }
  out
}

///|
/// Raised when a GitHub URL is not a commit-pinned file URL.
pub(all) suberror GitHubUrlError {
  /// The URL does not start with `https://github.com/`.
  NotGitHub(String)
  /// The URL has no `blob` or `tree` part, or an empty organization,
  /// repository or path.
  MissingPart(String)
  /// The commit is not 7 to 40 hexadecimal characters.
  NotACommit(String)
} derive(Eq, Debug)

///|
/// A commit SHA of 7 to 40 hexadecimal characters.
struct CommitSha {
  text : String
} derive(Eq, Hash, Debug)

///|
fn is_hex(text : String) -> Bool {
  text.length() > 0 &&
  text
  .iter()
  .all(c => {
    (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
  })
}

///|
pub fn CommitSha::CommitSha(text : String) -> CommitSha raise GitHubUrlError {
  if text.length() < 7 || text.length() > 40 || !is_hex(text) {
    raise NotACommit(text)
  }
  { text, }
}

///|
pub fn CommitSha::to_string(self : CommitSha) -> String {
  self.text
}

///|
/// The parts of a commit-pinned GitHub URL. No part is empty.
struct GitHubSource {
  org : String
  repo : String
  commit : CommitSha
  path : String
} derive(Eq, Debug)

///|
/// Parses `https://github.com/<org>/<repo>/blob/<commit>/<path>` (or `tree`).
pub fn GitHubSource::GitHubSource(
  url : String,
) -> GitHubSource raise GitHubUrlError {
  let prefix = "https://github.com/"
  guard url.has_prefix(prefix) else { raise NotGitHub(url) }
  let rest = url[prefix.length():].to_owned()
  let rest = match rest.find("#") {
    Some(i) => rest[:i].to_owned()
    None => rest
  }
  let parts = rest.split("/").map(s => s.to_owned()).collect()
  guard parts.length() >= 5 && (parts[2] == "blob" || parts[2] == "tree") else {
    raise MissingPart(url)
  }
  let path = parts[4:].to_owned().join("/")
  guard parts[0].length() > 0 && parts[1].length() > 0 && path.length() > 0 else {
    raise MissingPart(url)
  }
  { org: parts[0], repo: parts[1], commit: CommitSha(parts[3]), path, }
}

///|
pub fn GitHubSource::org(self : GitHubSource) -> String {
  self.org
}

///|
pub fn GitHubSource::repo(self : GitHubSource) -> String {
  self.repo
}

///|
pub fn GitHubSource::commit(self : GitHubSource) -> CommitSha {
  self.commit
}

///|
/// The file path in the repository.
pub fn GitHubSource::path(self : GitHubSource) -> String {
  self.path
}

///|
pub extend RefTarget with Eq::{not_equal, equal}

///|
pub extend RefTarget with @debug.Debug::{to_repr}

///|
pub extend TypedReference with Eq::{not_equal, equal}

///|
pub extend TypedReference with @debug.Debug::{to_repr}

///|
pub extend DocRefError with Eq::{not_equal, equal}

///|
pub extend DocRefError with @debug.Debug::{to_repr}

///|
pub extend DocRef with Eq::{not_equal, equal}

///|
pub extend DocRef with @debug.Debug::{to_repr}

///|
pub extend GitHubUrlError with Eq::{not_equal, equal}

///|
pub extend GitHubUrlError with @debug.Debug::{to_repr}

///|
pub extend CommitSha with Eq::{not_equal, equal}

///|
pub extend CommitSha with Hash::{hash, hash_combine}

///|
pub extend CommitSha with @debug.Debug::{to_repr}

///|
pub extend GitHubSource with Eq::{not_equal, equal}

///|
pub extend GitHubSource with @debug.Debug::{to_repr}
