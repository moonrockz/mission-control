///|
async fn main {
  let command = @extension.parse_command(@env.args()[1:]) catch {
    error => {
      eprintln("openspec-ext: \{error}")
      eprintln(@extension.usage())
      @sys.exit(2)
      return
    }
  }
  try {
    match command {
      Help => println(@extension.usage())
      Version => println("openspec-ext \{@extension.version()}")
      Repository(operation, repository) => {
        match operation {
          Install => @host.install(repository)
          Check => @host.check(repository)
          Setup => @host.setup(repository)
        }
        println("html-design: OK (openspec-ext \{@extension.version()})")
      }
    }
  } catch {
    error => {
      eprintln("openspec-ext: \{error}")
      @sys.exit(1)
    }
  }
}
