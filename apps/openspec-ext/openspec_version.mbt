///|
/// Why a version text is not an OpenSpec CLI version that setup supports.
pub suberror OpenSpecVersionError {
  /// The text, as `openspec --version` printed it after trimming, is not 1.14.3 and not a
  /// 1.16 patch release, or it is not a version.
  UnsupportedOpenSpec(String)
}

///|
/// The message of the error.
pub fn OpenSpecVersionError::message(self : OpenSpecVersionError) -> String {
  match self {
    UnsupportedOpenSpec(text) => "OpenSpec \{text} is not \{supported_openspec}"
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
/// The OpenSpec CLI versions that setup supports, as the messages name them.
pub let supported_openspec : String = "1.14.3 or 1.16.x"

///|
/// An OpenSpec CLI version that setup supports: 1.14.3, or a 1.16 patch release. Each was tested
/// with the managed html-design files before it was added.
pub struct SupportedOpenSpec {
  priv version : @contracts.Version
}

///|
/// Parse the text that `openspec --version` printed. The text must be `X.Y.Z` with no other
/// characters, and the version must be 1.14.3 or 1.16.x.
pub fn SupportedOpenSpec::SupportedOpenSpec(
  text : String,
) -> SupportedOpenSpec raise OpenSpecVersionError {
  let version = @contracts.Version::Version(text) catch {
    _ => raise UnsupportedOpenSpec(text)
  }
  let supported = match (version.major(), version.minor(), version.patch()) {
    (1, 14, 3) | (1, 16, _) => true
    _ => false
  }
  guard supported else { raise UnsupportedOpenSpec(text) }
  { version, }
}

///|
/// The version.
pub fn SupportedOpenSpec::version(
  self : SupportedOpenSpec,
) -> @contracts.Version {
  self.version
}
