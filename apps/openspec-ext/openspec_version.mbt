///|
/// Why a version text is not an OpenSpec CLI version that setup supports.
pub suberror OpenSpecVersionError {
  /// The text, as `openspec --version` printed it after trimming, is not `X.Y.Z`.
  InvalidOpenSpecVersion(String)
  /// The version is not one that setup supports.
  UnsupportedOpenSpec(@contracts.Version)
}

///|
/// The message of the error.
pub fn OpenSpecVersionError::message(self : OpenSpecVersionError) -> String {
  match self {
    InvalidOpenSpecVersion(text) =>
      "OpenSpec version text is not X.Y.Z: \{text}"
    UnsupportedOpenSpec(version) =>
      "OpenSpec \{version} is not \{supported_openspec}"
  }
}

///|
pub impl Show for OpenSpecVersionError with fn output(self, logger) {
  logger.write_string(self.message())
}

///|
#deprecated
pub extend OpenSpecVersionError with Show::{output, to_string}

///|
/// One entry of the support table: one exact release, or every patch release of a minor series.
priv enum Support {
  Exact(Int32, Int32, Int32)
  Series(Int32, Int32)
}

///|
fn Support::accepts(self : Support, version : @contracts.Version) -> Bool {
  match self {
    Exact(major, minor, patch) =>
      version.major() == major &&
      version.minor() == minor &&
      version.patch() == patch
    Series(major, minor) => version.major() == major && version.minor() == minor
  }
}

///|
fn Support::text(self : Support) -> String {
  match self {
    Exact(major, minor, patch) => "\{major}.\{minor}.\{patch}"
    Series(major, minor) => "\{major}.\{minor}.x"
  }
}

///|
/// The OpenSpec CLI versions that setup supports. 1.14.3, 1.16.0, 1.16.1 and 2.2.0 were tested
/// with the managed html-design files. Later 1.16 and 2.2 patch releases are accepted without that
/// test (see the archived changes support-openspec-1-16-setup, decision VER-2, and
/// support-openspec-2-2-setup).
let supported : ReadOnlyArray[Support] = [
  Exact(1, 14, 3),
  Series(1, 16),
  Series(2, 2),
]

///|
/// The supported versions as the messages name them, made from the support table:
/// `1.14.3, 1.16.x or 2.2.x`.
pub let supported_openspec : String = {
  let texts = supported.iter().map(Support::text).collect()
  match texts.length() {
    0 => ""
    1 => texts[0]
    n => texts[:n - 1].iter().join(", ") + " or " + texts[n - 1]
  }
}

///|
/// An OpenSpec CLI version that setup supports: an entry of the support table accepts it.
pub struct SupportedOpenSpec {
  priv version : @contracts.Version
}

///|
/// Parse the text that `openspec --version` printed. The text must be `X.Y.Z` with no other
/// characters, and the support table must accept the version.
pub fn SupportedOpenSpec::SupportedOpenSpec(
  text : String,
) -> SupportedOpenSpec raise OpenSpecVersionError {
  let version = @contracts.Version::Version(text) catch {
    _ => raise InvalidOpenSpecVersion(text)
  }
  guard supported.iter().any(s => s.accepts(version)) else {
    raise UnsupportedOpenSpec(version)
  }
  { version, }
}

///|
/// The version.
pub fn SupportedOpenSpec::version(
  self : SupportedOpenSpec,
) -> @contracts.Version {
  self.version
}

///|
/// The arguments that make `openspec init` keep the skills in the repository. OpenSpec 2 installs
/// skills for every project on the machine unless `--scope project` is given; OpenSpec 1 keeps
/// them in the repository and does not know the option.
pub fn SupportedOpenSpec::scope_arguments(
  self : SupportedOpenSpec,
) -> Array[String] {
  if self.version.major() >= 2 {
    ["--scope", "project"]
  } else {
    []
  }
}
