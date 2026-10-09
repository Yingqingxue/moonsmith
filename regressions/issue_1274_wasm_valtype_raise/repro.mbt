///|
#valtype
priv struct W {
  value : Double
}

///|
priv suberror E

///|
fn make(i : Int64) -> W raise E {
  if i < 0L {
    raise E
  }
  { value: i.to_double(), }
}

///|
fn run(i : Int64) -> Double {
  match (try? make(i)) {
    Ok({ value, }) => value
    Err(_) => -1.0
  }
}

///|
test "issue 1274 valtype and raise result paths" {
  assert_eq(run(-2147483648L), -1.0)
  assert_eq(run(0L), 0.0)
  assert_eq(run(2147483647L), 2147483647.0)
}
