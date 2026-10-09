///|
test "negative seeds are normalized deterministically" {
  assert_eq(normalize_seed(-1), 2147483646)
  assert_true(normalize_seed(-998) > 0)
  assert_true(child_seed(-998, 1) > 0)
}

///|
test "leaf values stay in their intended small domain" {
  for seed = -1000; seed < 1000; seed = seed + 1 {
    match int_leaf(seed) {
      IntLiteral(value) => {
        assert_true(value >= -20)
        assert_true(value <= 20)
      }
      _ => abort("int_leaf returned a non-integer expression")
    }
  }
}
