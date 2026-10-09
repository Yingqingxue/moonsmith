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
test "issue 1274 valtype returned from raise-capable function" {
  assert_eq(run(123L), 123.0)
}
