///|
test "reference evaluator respects nested conditions and types" {
  let expression = @moonsmith.If(
    IntType,
    LessThan(IntLiteral(3), IntLiteral(5)),
    Add(IntLiteral(7), IntLiteral(2)),
    IntLiteral(-1),
  )
  assert_eq(expression.evaluate().to_output(), "9")
  assert_eq(@moonsmith.Not(BoolLiteral(false)).evaluate().to_output(), "true")
}

///|
test "reference trace records only the dynamically selected branch" {
  let expression = @moonsmith.If(
    IntType,
    BoolLiteral(false),
    Add(IntLiteral(1), IntLiteral(2)),
    Subtract(IntLiteral(9), IntLiteral(4)),
  )
  let (value, trace) = expression.evaluate_with_trace()
  assert_eq(value.to_output(), "5")
  assert_true(trace.contains("if-else"))
  assert_true(trace.contains("subtract"))
  assert_true(!trace.contains("if-then"))
  assert_true(!trace.contains("add"))
}

///|
test "reference trace distinguishes executed and skipped short-circuit rhs" {
  let skipped = @moonsmith.And(
    BoolLiteral(false),
    Variable(BoolType, "must_not_be_evaluated"),
  )
  let (value, trace) = skipped.evaluate_with_trace()
  assert_eq(value.to_output(), "false")
  assert_true(trace.contains("and-rhs-skipped"))
  assert_true(!trace.contains("variable"))
}

///|
test "record selection evaluates fields and traces the selected field" {
  let integer_record = @moonsmith.StructSelect(
    IntType,
    IntLiteral(12),
    BoolLiteral(false),
  )
  let (integer_value, integer_trace) = integer_record.evaluate_with_trace()
  assert_eq(integer_value.to_output(), "12")
  assert_true(integer_trace.contains("bool-literal"))
  assert_true(integer_trace.contains("struct-field-number"))

  let boolean_record = @moonsmith.StructSelect(
    BoolType,
    IntLiteral(3),
    BoolLiteral(true),
  )
  let (boolean_value, boolean_trace) = boolean_record.evaluate_with_trace()
  assert_eq(boolean_value.to_output(), "true")
  assert_true(boolean_trace.contains("struct-field-flag"))
  assert_true(boolean_trace.contains("struct-result-flag"))
}

///|
test "tagged choice match binds the selected payload and is exhaustive" {
  let number_match = @moonsmith.MatchChoice(
    IntType,
    ChoiceValue(IntType, IntLiteral(8)),
    "number",
    Add(Variable(IntType, "number"), IntLiteral(2)),
    "flag",
    If(IntType, Variable(BoolType, "flag"), IntLiteral(1), IntLiteral(0)),
  )
  let (number_value, number_trace) = number_match.evaluate_with_trace()
  assert_eq(number_value.to_output(), "10")
  assert_true(number_trace.contains("choice-number"))
  assert_true(!number_trace.contains("choice-flag"))

  let flag_match = @moonsmith.MatchChoice(
    BoolType,
    ChoiceValue(BoolType, BoolLiteral(true)),
    "number",
    LessThan(Variable(IntType, "number"), IntLiteral(0)),
    "flag",
    And(Variable(BoolType, "flag"), BoolLiteral(false)),
  )
  let (flag_value, flag_trace) = flag_match.evaluate_with_trace()
  assert_eq(flag_value.to_output(), "false")
  assert_true(flag_trace.contains("choice-flag"))
  assert_true(!flag_trace.contains("choice-number"))
}

///|
test "reference output is deterministic for generated seeds" {
  for seed = 0; seed < 100; seed = seed + 1 {
    let first = @moonsmith.generate_program(seed, 4).expected_output()
    let second = @moonsmith.generate_program(seed, 4).expected_output()
    assert_eq(first, second)
    assert_true(first.has_suffix("\n"))
  }
}

///|
test "reference evaluator selects the matching boolean arm" {
  let expression = @moonsmith.MatchBool(
    IntType,
    BoolLiteral(false),
    IntLiteral(7),
    IntLiteral(9),
  )
  assert_eq(expression.evaluate().to_output(), "9")
  assert_true(expression.to_source().contains("match false"))
}

///|
test "reference evaluator respects let bindings and shadowing" {
  let expression = @moonsmith.Let(
    IntType,
    "x",
    IntLiteral(4),
    Add(
      Variable(IntType, "x"),
      Let(IntType, "x", IntLiteral(9), Variable(IntType, "x")),
    ),
  )
  assert_eq(expression.evaluate().to_output(), "13")
  let boolean = @moonsmith.Let(
    BoolType,
    "enabled",
    BoolLiteral(false),
    Not(Variable(BoolType, "enabled")),
  )
  assert_eq(boolean.evaluate().to_output(), "true")
}

///|
test "subtraction and logical and have the expected semantics" {
  let subtraction = @moonsmith.Subtract(IntLiteral(3), IntLiteral(8))
  assert_eq(subtraction.evaluate().to_output(), "-5")
  let short_circuit = @moonsmith.And(
    BoolLiteral(false),
    Variable(BoolType, "must_not_be_evaluated"),
  )
  assert_eq(short_circuit.evaluate().to_output(), "false")
  assert_eq(
    @moonsmith.And(BoolLiteral(true), BoolLiteral(true)).evaluate().to_output(),
    "true",
  )
}

///|
test "fixed-size array selection evaluates both result types" {
  let first_int = @moonsmith.ArraySelect(
    IntType,
    IntLiteral(7),
    IntLiteral(9),
    false,
  )
  let second_int = @moonsmith.ArraySelect(
    IntType,
    IntLiteral(7),
    IntLiteral(9),
    true,
  )
  assert_eq(first_int.evaluate().to_output(), "7")
  assert_eq(second_int.evaluate().to_output(), "9")
  assert_true(second_int.to_source().contains("let items = [7, 9]"))
  assert_true(second_int.to_source().contains("items[1]"))
  let boolean = @moonsmith.ArraySelect(
    BoolType,
    BoolLiteral(false),
    BoolLiteral(true),
    true,
  )
  assert_eq(boolean.evaluate().to_output(), "true")
}

///|
test "function application binds parameters and captures outer values" {
  let expression = @moonsmith.Let(
    IntType,
    "captured",
    IntLiteral(5),
    FunctionApply(
      IntType,
      "parameter",
      IntLiteral(7),
      Add(Variable(IntType, "parameter"), Variable(IntType, "captured")),
    ),
  )
  assert_eq(expression.evaluate().to_output(), "12")
  let boolean = @moonsmith.FunctionApply(
    BoolType,
    "flag",
    BoolLiteral(true),
    Not(Variable(BoolType, "flag")),
  )
  assert_eq(boolean.evaluate().to_output(), "false")
  assert_true(boolean.to_source().contains("fn(flag : Bool)"))
  assert_true(boolean.to_source().contains("transform(true)"))
}
