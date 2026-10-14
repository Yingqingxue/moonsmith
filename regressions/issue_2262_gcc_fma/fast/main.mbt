///|
fn parse_argument(value : String) -> Double {
  @string.parse_double(value) catch {
    _ => abort("expected three valid Double arguments")
  }
}

///|
fn multiply_then_add(a : Double, b : Double, c : Double) -> Double {
  let product = a * b
  product + c
}

///|
#cfg(target="js")
fn double_arguments() -> ArrayView[String] {
  match @env.args() {
    [_, _, .. rest] => rest
    _ => []
  }
}

///|
#cfg(not(target="js"))
fn double_arguments() -> ArrayView[String] {
  match @env.args() {
    [_, .. rest] => rest
    [] => []
  }
}

///|
fn main {
  match double_arguments() {
    [a, b, c] => {
      let result = multiply_then_add(
        parse_argument(a),
        parse_argument(b),
        parse_argument(c),
      )
      println(if result == 0.0 { "zero" } else { "nonzero" })
    }
    _ => abort("expected three Double arguments")
  }
}
