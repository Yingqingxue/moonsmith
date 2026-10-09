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
fn parse_integer(value : String) -> Int {
  @string.parse_int(value) catch {
    _ => abort("invalid integer: " + value)
  }
}

///|
/// Regenerate an AST from a seed, apply previously accepted candidate indices,
/// and emit the next candidate list as JSON.
fn main {
  let args = cli_args()
  if args.length() < 2 {
    abort("usage: moon run cmd/reduce <seed> <depth> [accepted-index ...]")
  }
  let seed = parse_integer(args[0])
  let depth = parse_integer(args[1])
  let mut program = @lib.generate_program(seed, depth)
  for index = 2; index < args.length(); index = index + 1 {
    let choice = parse_integer(args[index])
    let candidates = program.shrink_candidates()
    if choice < 0 || choice >= candidates.length() {
      abort("candidate index out of range")
    }
    program = candidates[choice]
  }
  println(program.candidates_json())
}
