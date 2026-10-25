# moonrockz/mission-control-contracts

Shared commands for the Mission Control CLI, the Rabbita web UI and the Proton desktop shell.

```shell
moon add moonrockz/mission-control-contracts
```

`version()` gives the workspace version as a `Version` value (three integer
parts; `Version::Version(text)` raises `VersionError` for any other text).
`Command::Command(name)` reads `help` or `version`, or an alias such as
`--version`, and raises `CommandError::UnknownCommand` with the name for any other
text. Each command gives its CLI name (`name()`), its Proton command ID
(`proton_id()`, such as `mission-control.version`) and its help line
(`description()`). `commands` lists every command.
