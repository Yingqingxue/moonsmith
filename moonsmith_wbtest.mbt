///|
test "negative seeds are normalized deterministically" {
  assert_eq(normalize_seed(-1), 2147483646)
  assert_true(normalize_seed(-998) > 0)
  assert_true(child_seed(-998, 1) > 0)
}

///|
test "seed normalization and stepping cover signed Int boundaries" {
  let min_int = -2147483647 - 1
  let max_int = 2147483647
  assert_eq(normalize_seed(min_int), 2147483646)
  assert_eq(normalize_seed(max_int), 2147483646)
  assert_eq(normalize_seed(2147483646), 2147483646)
  assert_true(advance_seed(min_int) > 0)
  assert_true(advance_seed(max_int) > 0)
  assert_true(child_seed(min_int, 58) > 0)
  assert_true(child_seed(max_int, 58) > 0)
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

///|
test "variable-use analysis traverses every expression family" {
  let expression = Let(
    IntType,
    "outer",
    ArraySelect(IntType, IntLiteral(1), IntLiteral(2), false),
    MatchBool(
      IntType,
      And(Not(BoolLiteral(false)), LessThan(IntLiteral(1), IntLiteral(2))),
      MatchChoice(
        IntType,
        ChoiceValue(
          IntType,
          StructSelect(IntType, IntLiteral(3), BoolLiteral(true)),
        ),
        "number",
        FunctionApply(
          IntType,
          "parameter",
          Variable(IntType, "captured"),
          Add(
            Variable(IntType, "parameter"),
            ForLoop(1, IntLiteral(0), Variable(IntType, "_ms_acc")),
          ),
        ),
        "flag",
        If(
          IntType,
          Variable(BoolType, "flag"),
          Let(IntType, "inner", IntLiteral(3), IntLiteral(4)),
          ValtypeRaiseProbe(Variable(IntType, "captured")),
        ),
      ),
      EqualInt(IntLiteral(3), IntLiteral(3)),
    ),
  )
  assert_false(expression.uses_variable("not-present"))
  assert_true(expression.uses_variable("captured"))
  assert_false(
    Let(IntType, "x", IntLiteral(1), Variable(IntType, "x")).uses_variable("x"),
  )
  assert_false(
    ForLoop(1, IntLiteral(0), Variable(IntType, "_ms_index")).uses_variable(
      "_ms_index",
    ),
  )
}
