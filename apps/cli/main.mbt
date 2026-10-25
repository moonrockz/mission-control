///|
fn main {
  let result = run(program_args())
  match result {
    Text(text) => println(text)
    Unknown(command) => {
      eprintln("mission-control: unknown command '\{command}'")
      eprintln(usage())
      @sys.exit(result.exit_code().to_int())
    }
  }
}
