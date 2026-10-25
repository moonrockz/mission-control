///|
/// Raised when an IndexedDB name breaks its rule.
pub(all) suberror IdbNameError {
  /// The database name is empty.
  EmptyDatabaseName
  /// The object store name is empty.
  EmptyObjectStoreName
} derive(Eq, Debug)

///|
/// The name of an IndexedDB database: a text that is not empty.
struct DatabaseName {
  text : String
} derive(Eq, Hash, Debug)

///|
pub fn DatabaseName::DatabaseName(
  text : String,
) -> DatabaseName raise IdbNameError {
  if text.is_empty() {
    raise EmptyDatabaseName
  }
  { text, }
}

///|
/// The default database name, `okf`.
pub fn DatabaseName::default() -> DatabaseName {
  { text: "okf", }
}

///|
pub fn DatabaseName::to_string(self : DatabaseName) -> String {
  self.text
}

///|
pub impl Show for DatabaseName with fn output(self, logger) {
  logger.write_string(self.text)
}

///|
/// The name of an IndexedDB object store: a text that is not empty.
struct ObjectStoreName {
  text : String
} derive(Eq, Hash, Debug)

///|
pub fn ObjectStoreName::ObjectStoreName(
  text : String,
) -> ObjectStoreName raise IdbNameError {
  if text.is_empty() {
    raise EmptyObjectStoreName
  }
  { text, }
}

///|
/// The default object store name, `files`.
pub fn ObjectStoreName::default() -> ObjectStoreName {
  { text: "files", }
}

///|
pub fn ObjectStoreName::to_string(self : ObjectStoreName) -> String {
  self.text
}

///|
pub impl Show for ObjectStoreName with fn output(self, logger) {
  logger.write_string(self.text)
}

///|
/// Raised when a quota breaks its rule.
pub(all) suberror QuotaError {
  /// The quota is negative.
  NegativeQuota(Int32)
} derive(Eq, Debug)

///|
/// A storage quota in bytes: zero or more.
struct QuotaBytes {
  bytes : Int32
} derive(Eq, Hash, Debug)

///|
pub fn QuotaBytes::QuotaBytes(bytes : Int32) -> QuotaBytes raise QuotaError {
  if bytes < 0 {
    raise NegativeQuota(bytes)
  }
  { bytes, }
}

///|
pub fn QuotaBytes::to_int(self : QuotaBytes) -> Int32 {
  self.bytes
}

///|
pub extend QuotaError with Eq::{not_equal, equal}

///|
pub extend QuotaError with @debug.Debug::{to_repr}

///|
pub extend QuotaBytes with Eq::{not_equal, equal}

///|
pub extend QuotaBytes with Hash::{hash, hash_combine}

///|
pub extend QuotaBytes with @debug.Debug::{to_repr}

///|
pub extend IdbNameError with Eq::{not_equal, equal}

///|
pub extend IdbNameError with @debug.Debug::{to_repr}

///|
pub extend DatabaseName with Eq::{not_equal, equal}

///|
pub extend DatabaseName with Hash::{hash, hash_combine}

///|
pub extend DatabaseName with @debug.Debug::{to_repr}

///|
pub extend ObjectStoreName with Eq::{not_equal, equal}

///|
pub extend ObjectStoreName with Hash::{hash, hash_combine}

///|
pub extend ObjectStoreName with @debug.Debug::{to_repr}

///|
pub extend DatabaseName with Show::{output}

///|
pub extend ObjectStoreName with Show::{output}
