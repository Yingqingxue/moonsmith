///|
fn int_arg_or(args : ArrayView[String], index : Int, fallback : Int) -> Int {
  if args.length() <= index {
    fallback
  } else {
    @string.parse_int(args[index]) catch {
      _ => fallback
    }
  }
}

///|
/// Node prepends two runtime values; native and Wasm hosts prepend one. Keep
/// that target detail at the CLI boundary so the generator stays portable.
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
/// Print one deterministic generated program. Positional arguments are seed
/// and maximum expression depth; invalid values intentionally use defaults in
/// this bootstrap CLI and will become structured errors in the full command.
fn main {
  let args = cli_args()
  let seed = int_arg_or(args, 0, 42)
  let depth = int_arg_or(args, 1, 4)
  let program = @lib.generate_program(seed, depth)
  if args.length() > 2 && args[2] == "--trace" {
    let (value, trace) = program.result.evaluate_with_trace()
    let json = StringBuilder()
    json.write_string("{\"value\":\"")
    json.write_string(value.to_output())
    json.write_string("\",\"visited\":[")
    for index = 0; index < trace.length(); index = index + 1 {
      if index > 0 {
        json.write_char(',')
      }
      json.write_char('"')
      json.write_string(trace[index])
      json.write_char('"')
    }
    json.write_string("]}")
    println(json.to_string())
  } else if args.length() > 2 && args[2] == "--expected" {
    println(program.result.evaluate().to_output())
  } else {
    println(program.to_source())
  }
}
