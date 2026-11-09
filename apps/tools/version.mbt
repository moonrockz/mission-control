///|
/// The version text of the tools CLI. `scripts/versions.mbtx set-tools` sets it to the version
/// of `apps/tools/moon.mod`; the tools family is separate from the workspace version.
let tools_version : String = "0.1.2"

///|
/// The module that the tools CLI records in an extension lock.
let tools_module : String = "moonrockz/mission-control-tools"

///|
/// The version of the tools CLI.
pub fn version() -> @contracts.Version {
  // A test checks that the text above parses.
  @contracts.Version::Version(tools_version) catch {
    _ => abort("the tools version is not a version: \{tools_version}")
  }
}

///|
/// The tool identity that the tools CLI writes into a lock and checks against.
pub fn tool() -> @extension.Tool {
  @extension.Tool::Tool(tools_module, version()) catch {
    _ => abort("the tools module name is not valid: \{tools_module}")
  }
}
