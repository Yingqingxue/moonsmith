///|
#cfg(target="js")
fn cli_args() -> ArrayView[String] {
  match @env.args() {
    [_, _, .. rest] => rest
    _ => []
  }
}

///|
#cfg(not(target="js"))
fn cli_args() -> ArrayView[String] {
  match @env.args() {
    [_, .. rest] => rest
    [] => []
  }
}

///|
fn parse_status(value : String) -> @lib.RunStatus {
  match value {
    "succeeded" => Succeeded
    "compile-failed" => CompileFailed
    "runtime-failed" => RuntimeFailed
    "timed-out" => TimedOut
    "unavailable" => Unavailable
    _ => abort("invalid backend status: " + value)
  }
}

///|
fn parse_exit_code(value : String) -> Int {
  @string.parse_int(value) catch {
    _ => abort("invalid exit code: " + value)
  }
}

///|
/// Arguments start with reference mode and expected stdout, then repeated
/// groups of target, status, exit-code, stdout, stderr, root, and case path.
fn main {
  let args = cli_args()
  if args.length() < 2 || (args.length() - 2) % 7 != 0 {
    abort(
      "expected <some|none> <expected-output> followed by backend result groups",
    )
  }
  let expected_output = match args[0] {
    "some" => args[1]
    "none" => ""
    _ => abort("reference mode must be some or none")
  }
  let results : Array[@lib.RunResult] = []
  for index = 2; index < args.length(); index = index + 7 {
    results.push({
      target: args[index],
      status: parse_status(args[index + 1]),
      exit_code: parse_exit_code(args[index + 2]),
      stdout: args[index + 3],
      stderr: args[index + 4],
      duration_ms: 0,
      diagnostic_root: args[index + 5],
      diagnostic_case: args[index + 6],
    })
  }
  println(@lib.analyze_results(results, expected_output~).summary_json())
}
