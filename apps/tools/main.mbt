///|
/// Run one command and give its outcome. The host does the I/O; the core renders the result.
async fn execute(command : Command) -> Outcome {
  match command {
    Help => help_outcome()
    Version(format) => version_outcome(format)
    OpenSpec(Check(scope, format), repository) => {
      let report = @host.check(repository, check_level(scope)) catch {
        error =>
          return check_error_outcome(
            repository.text(),
            "\{error}",
            scope,
            format,
          )
      }
      check_outcome(report.root(), report.problems(), scope, format)
    }
    OpenSpec(Install, repository) => {
      @host.install(repository, tool())
      install_outcome()
    }
    OpenSpec(Setup, repository) => {
      @host.setup(repository)
      setup_outcome()
    }
  }
}

///|
async fn main {
  let parsed : Result[Command, UsageError] = Ok(parse(@env.args()[1:])) catch {
    error => Err(error)
  }
  let outcome = match parsed {
    Err(error) => usage_outcome(error)
    Ok(command) =>
      execute(command) catch {
        @host.CheckFailed(problems) =>
          failure_outcome(problems.map(p => p.message()))
        error => failure_outcome(["\{error}"])
      }
  }
  for line in outcome.stdout {
    println(line)
  }
  for line in outcome.stderr {
    eprintln(line)
  }
  if outcome.exit_code != Success {
    @sys.exit(outcome.exit_code.to_int())
  }
}
