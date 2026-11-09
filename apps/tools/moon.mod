name = "moonrockz/mission-control-tools"

version = "0.1.2"

description = "Repository tools for Mission Control consumers, released as native binaries"

repository = "https://github.com/moonrockz/mission-control"

license = "Apache-2.0"

readme = "README.md"

preferred_target = "wasm"

// The host I/O comes from moonbitlang/async/fs and async/process, which have no JS or wasm-gc backend.

supported_targets = "wasm+native"

import {
  "moonrockz/mission-control-contracts@0.1.0",
  "moonrockz/openspec-ext@0.1.0",
  "moonbitlang/async@0.22.5",
  "moonbitlang/x@0.5.5",
}
