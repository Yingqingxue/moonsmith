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
test "reference evaluator preserves short-circuit disjunction" {
  let skipped = @moonsmith.Or(
    BoolLiteral(true),
    Variable(BoolType, "must_not_be_evaluated"),
  )
  let (skipped_value, skipped_trace) = skipped.evaluate_with_trace()
  assert_eq(skipped_value.to_output(), "true")
  assert_true(skipped_trace.contains("or-rhs-skipped"))
  assert_true(!skipped_trace.contains("variable"))

  let executed = @moonsmith.Or(BoolLiteral(false), BoolLiteral(true))
  let (executed_value, executed_trace) = executed.evaluate_with_trace()
  assert_eq(executed_value.to_output(), "true")
  assert_true(executed_trace.contains("or-rhs-executed"))
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
test "growing arrays preserve insertion order and typed selections" {
  let first = @moonsmith.ArrayGrowSelect(
    IntType,
    IntLiteral(7),
    IntLiteral(9),
    false,
  )
  let second = @moonsmith.ArrayGrowSelect(
    IntType,
    IntLiteral(7),
    IntLiteral(9),
    true,
  )
  assert_eq(first.evaluate().to_output(), "7")
  let (second_value, trace) = second.evaluate_with_trace()
  assert_eq(second_value.to_output(), "9")
  assert_true(trace.contains("array-grow"))
  assert_true(trace.contains("array-grow-push"))
  assert_true(trace.contains("array-grow-index-1"))
  assert_true(second.to_source().contains("let grown_items : Array[Int] = []"))
  assert_true(second.to_source().contains("grown_items.push(9)"))
  let boolean = @moonsmith.ArrayGrowSelect(
    BoolType,
    BoolLiteral(false),
    BoolLiteral(true),
    true,
  )
  assert_eq(boolean.evaluate().to_output(), "true")
  assert_true(boolean.to_source().contains("Array[Bool]"))
}

///|
test "array alias update observes replacement through the original array" {
  let first = @moonsmith.ArrayAliasUpdateSelect(
    IntType,
    IntLiteral(7),
    IntLiteral(9),
    IntLiteral(11),
    false,
  )
  let second = @moonsmith.ArrayAliasUpdateSelect(
    BoolType,
    BoolLiteral(false),
    BoolLiteral(true),
    BoolLiteral(false),
    true,
  )
  let (first_value, first_trace) = first.evaluate_with_trace()
  let (second_value, second_trace) = second.evaluate_with_trace()
  assert_eq(first_value.to_output(), "11")
  assert_eq(second_value.to_output(), "false")
  assert_true(first_trace.contains("array-alias-update-index-0"))
  assert_true(second_trace.contains("array-alias-update-index-1"))
  assert_true(!first_trace.contains("array-alias-update-collision"))
  assert_true(!second_trace.contains("array-alias-update-collision"))
  let source = first.to_source()
  assert_true(source.contains("let _ms_alias = items"))
  assert_true(source.contains("_ms_alias[0] = replacement"))
  assert_true(source.contains("items[0] == replacement"))
  assert_true(source.contains("items[1] == other_before"))
}

///|
test "array alias update turns a no-op candidate into an observable write" {
  let zero = @moonsmith.ArrayAliasUpdateSelect(
    IntType,
    IntLiteral(0),
    IntLiteral(8),
    IntLiteral(0),
    false,
  )
  let nonzero = @moonsmith.ArrayAliasUpdateSelect(
    IntType,
    IntLiteral(8),
    IntLiteral(-3),
    IntLiteral(-3),
    true,
  )
  let boolean = @moonsmith.ArrayAliasUpdateSelect(
    BoolType,
    BoolLiteral(false),
    BoolLiteral(true),
    BoolLiteral(true),
    true,
  )
  let (zero_value, zero_trace) = zero.evaluate_with_trace()
  let (nonzero_value, nonzero_trace) = nonzero.evaluate_with_trace()
  let (boolean_value, boolean_trace) = boolean.evaluate_with_trace()
  assert_eq(zero_value.to_output(), "1")
  assert_eq(nonzero_value.to_output(), "0")
  assert_eq(boolean_value.to_output(), "false")
  assert_true(zero_trace.contains("array-alias-update-collision"))
  assert_true(nonzero_trace.contains("array-alias-update-collision"))
  assert_true(boolean_trace.contains("array-alias-update-collision"))
  assert_true(zero.to_source().contains("if original == 0 { 1 } else { 0 }"))
  assert_true(
    boolean.to_source().contains("if candidate == original { !original }"),
  )
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

///|
test "Choice-returning local functions preserve payload types" {
  let expression = @moonsmith.MatchChoice(
    IntType,
    @moonsmith.FunctionApply(
      ChoiceType,
      "payload",
      IntLiteral(7),
      @moonsmith.ChoiceValue(IntType, Variable(IntType, "payload")),
    ),
    "number",
    Variable(IntType, "number"),
    "flag",
    If(IntType, Variable(BoolType, "flag"), IntLiteral(1), IntLiteral(0)),
  )
  assert_eq(expression.evaluate().to_output(), "7")
  assert_true(expression.to_source().contains("fn(payload : Int)"))
  assert_true(expression.to_source().contains("transform(7)"))
}

///|
test "bounded for loop updates index and accumulator together" {
  let expression = @moonsmith.ForLoop(
    3,
    IntLiteral(10),
    Add(Variable(IntType, "_ms_acc"), Variable(IntType, "_ms_index")),
  )
  let (value, trace) = expression.evaluate_with_trace()
  assert_eq(value.to_output(), "13")
  assert_true(trace.contains("for-loop"))
  assert_true(trace.contains("for-iteration"))
  assert_true(trace.contains("for-normal-exit"))
  assert_true(expression.to_source().contains("_ms_index < 3"))
  assert_true(expression.to_source().contains("nobreak"))
}

///|
test "bounded for loop with zero iterations returns its initial accumulator" {
  let expression = @moonsmith.ForLoop(
    0,
    IntLiteral(-4),
    Add(Variable(IntType, "_ms_acc"), Variable(IntType, "_ms_index")),
  )
  let (value, trace) = expression.evaluate_with_trace()
  assert_eq(value.to_output(), "-4")
  assert_true(!trace.contains("for-iteration"))
}

///|
test "bounded while loop updates index and accumulator" {
  let expression = @moonsmith.WhileLoop(
    3,
    IntLiteral(10),
    Add(Variable(IntType, "_ms_acc"), Variable(IntType, "_ms_index")),
  )
  let (value, trace) = expression.evaluate_with_trace()
  assert_eq(value.to_output(), "13")
  assert_true(trace.contains("while-loop"))
  assert_true(trace.contains("while-iteration"))
  assert_true(trace.contains("while-normal-exit"))
  assert_true(expression.to_source().contains("while _ms_index < 3"))
  assert_true(expression.to_source().contains("_ms_acc = _ms_next"))
}

///|
test "bounded while loop with zero iterations returns its initial accumulator" {
  let expression = @moonsmith.WhileLoop(
    0,
    IntLiteral(-4),
    Add(Variable(IntType, "_ms_acc"), Variable(IntType, "_ms_index")),
  )
  let (value, trace) = expression.evaluate_with_trace()
  assert_eq(value.to_output(), "-4")
  assert_true(!trace.contains("while-iteration"))
}

///|
test "valtype raise probe models both success and error paths" {
  let success = @moonsmith.ValtypeRaiseProbe(IntLiteral(8))
  let (success_value, success_trace) = success.evaluate_with_trace()
  assert_eq(success_value.to_output(), "true")
  assert_true(success_trace.contains("valtype-raise-success-path"))

  let failure = @moonsmith.ValtypeRaiseProbe(IntLiteral(-8))
  let (failure_value, failure_trace) = failure.evaluate_with_trace()
  assert_eq(failure_value.to_output(), "true")
  assert_true(failure_trace.contains("valtype-raise-error-path"))

  assert_true(failure.to_source().contains("_ms_valtype_run"))
  assert_true(failure.to_source().contains("_ms_valtype_expected"))
}

///|
test "valtype raise probe keeps the sign boundary and upstream trigger shape" {
  let error = @moonsmith.ValtypeRaiseProbe(IntLiteral(-1))
  let zero = @moonsmith.ValtypeRaiseProbe(IntLiteral(0))
  let positive = @moonsmith.ValtypeRaiseProbe(IntLiteral(1))
  let (_, error_trace) = error.evaluate_with_trace()
  let (_, zero_trace) = zero.evaluate_with_trace()
  let (_, positive_trace) = positive.evaluate_with_trace()
  assert_true(error_trace.contains("valtype-raise-error-path"))
  assert_true(zero_trace.contains("valtype-raise-success-path"))
  assert_true(positive_trace.contains("valtype-raise-success-path"))

  let source = @moonsmith.generate_program(0, 4).to_source()
  assert_true(
    source.contains(
      "#valtype\npriv struct MoonSmithValtype {\n  value : Double",
    ),
  )
  assert_true(
    source.contains(
      "fn _ms_valtype_make(i : Int64) -> MoonSmithValtype raise MoonSmithValtypeError",
    ),
  )
  assert_true(source.contains("match (try? _ms_valtype_make(i))"))
}

///|
test "valtype enum array probe returns the indexed field after enum matching" {
  for input in [-8, 0, 8] {
    let probe = @moonsmith.ValtypeEnumArrayProbe(IntLiteral(input))
    let (value, trace) = probe.evaluate_with_trace()
    assert_eq(value.to_output(), (input + 1).to_string())
    assert_true(trace.contains("valtype-enum-array-probe"))
    assert_true(trace.contains("valtype-enum-array-empty-init"))
    assert_true(trace.contains("valtype-enum-array-push"))
    assert_true(trace.contains("valtype-enum-array-growth-push"))
    assert_true(trace.contains("valtype-enum-array-index"))
    assert_true(trace.contains("valtype-enum-array-index-after-growth"))
    assert_true(probe.to_source().contains("_ms_valtype_array_run("))
  }
  let program : @moonsmith.Program = {
    seed: 1,
    result_type: IntType,
    result: ValtypeEnumArrayProbe(IntLiteral(-8)),
  }
  let source = program.to_source()
  assert_true(source.contains("MoonSmithEntryKind::Ref(\"x\")"))
  assert_true(source.contains("MoonSmithEntryKind::Ref(value)"))
  assert_true(source.contains("let values : Array[MoonSmithEntry] = []"))
  assert_true(
    source.contains(
      "values.push({ id: i, kind: MoonSmithEntryKind::Ref(\"x\") })",
    ),
  )
  assert_true(
    source.contains(
      "values.push({ id: i + 1, kind: MoonSmithEntryKind::Ref(\"x\") })",
    ),
  )
  assert_true(source.contains("values[1].id"))
}

///|
test "enum array result flows through valtype raise reference evaluation" {
  let expression : @moonsmith.Expr = @moonsmith.ValtypeRaiseProbe(
    @moonsmith.ValtypeEnumArrayProbe(@moonsmith.IntLiteral(8)),
  )
  let (value, trace) = expression.evaluate_with_trace()
  assert_eq(value.to_output(), "true")
  assert_true(trace.contains("valtype-enum-array-probe"))
  assert_true(trace.contains("valtype-raise-success-path"))

  let program : @moonsmith.Program = {
    seed: 1,
    result_type: @moonsmith.BoolType,
    result: expression,
  }
  let source = program.to_source()
  assert_true(source.contains("_ms_valtype_array_run(8)"))
  assert_true(source.contains("_ms_valtype_run(_ms_valtype_input.to_int64())"))
  assert_true(source.contains("#valtype\npriv struct MoonSmithEntry"))
  assert_true(source.contains("#valtype\npriv struct MoonSmithValtype"))
}
