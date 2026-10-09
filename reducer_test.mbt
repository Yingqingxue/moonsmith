///|
test "reducer candidates preserve the result type and reduce complexity" {
  for seed = 0; seed < 100; seed = seed + 1 {
    let program = @moonsmith.generate_program(seed, 4)
    let original_complexity = program.result.complexity()
    for candidate in program.shrink_candidates() {
      match (candidate.result.value_type(), program.result_type) {
        (IntType, IntType) | (BoolType, BoolType) => ()
        _ => abort("reducer changed the program result type")
      }
      assert_true(candidate.result.complexity() < original_complexity)
    }
  }
}

///|
test "integer literal shrinking moves toward zero without duplicates" {
  let candidates = @moonsmith.IntLiteral(9).shrink_candidates()
  assert_eq(candidates.length(), 2)
  assert_eq(candidates[0].to_source(), "0")
  assert_eq(candidates[1].to_source(), "4")
}

///|
test "addition can be replaced by either same-typed operand" {
  let expression = @moonsmith.Add(IntLiteral(5), IntLiteral(8))
  let candidates = expression.shrink_candidates()
  assert_true(candidates.length() >= 2)
  assert_eq(candidates[0].to_source(), "5")
  assert_eq(candidates[1].to_source(), "8")
}

///|
test "if expression can be replaced by either branch" {
  let expression = @moonsmith.If(
    IntType,
    BoolLiteral(true),
    IntLiteral(7),
    IntLiteral(9),
  )
  let candidates = expression.shrink_candidates()
  assert_true(candidates.length() >= 2)
  assert_eq(candidates[0].to_source(), "7")
  assert_eq(candidates[1].to_source(), "9")
}

///|
test "boolean match can be replaced by either same-typed arm" {
  let expression = @moonsmith.MatchBool(
    IntType,
    BoolLiteral(true),
    IntLiteral(7),
    IntLiteral(9),
  )
  let candidates = expression.shrink_candidates()
  assert_true(candidates.length() >= 2)
  assert_eq(candidates[0].to_source(), "7")
  assert_eq(candidates[1].to_source(), "9")
}

///|
test "let reduction keeps bound references in scope" {
  let expression = @moonsmith.Let(
    IntType,
    "x",
    IntLiteral(9),
    Add(Variable(IntType, "x"), IntLiteral(2)),
  )
  for candidate in expression.shrink_candidates() {
    assert_true(candidate.to_source() != "x")
  }
  let identity = @moonsmith.Let(
    IntType,
    "x",
    IntLiteral(9),
    Variable(IntType, "x"),
  )
  assert_eq(identity.shrink_candidates()[0].to_source(), "9")
}

///|
test "subtraction and logical and have type-preserving reductions" {
  let subtraction = @moonsmith.Subtract(IntLiteral(9), IntLiteral(2))
  assert_eq(subtraction.shrink_candidates()[0].to_source(), "9")
  let conjunction = @moonsmith.And(BoolLiteral(true), BoolLiteral(false))
  assert_eq(conjunction.shrink_candidates()[0].to_source(), "true")
}

///|
test "array selection can shrink to a same-typed element" {
  let expression = @moonsmith.ArraySelect(
    IntType,
    IntLiteral(7),
    IntLiteral(9),
    true,
  )
  let candidates = expression.shrink_candidates()
  assert_eq(candidates[0].to_source(), "7")
  assert_eq(candidates[1].to_source(), "9")
  for candidate in candidates {
    assert_true(candidate.complexity() < expression.complexity())
    match candidate.value_type() {
      IntType => ()
      BoolType => abort("array reducer changed result type")
      ChoiceType => abort("array reducer changed result type")
    }
  }
}

///|
test "record selection shrinks to selected field and smaller fields" {
  let expression = @moonsmith.StructSelect(
    IntType,
    IntLiteral(7),
    BoolLiteral(true),
  )
  let candidates = expression.shrink_candidates()
  assert_eq(candidates[0].to_source(), "7")
  for candidate in candidates {
    assert_true(candidate.complexity() < expression.complexity())
    match candidate.value_type() {
      IntType => ()
      BoolType => abort("record reducer changed result type")
      ChoiceType => abort("record reducer changed result type")
    }
  }
}

///|
test "choice reduction preserves both constructor arms and payload scope" {
  let expression = @moonsmith.MatchChoice(
    IntType,
    ChoiceValue(IntType, IntLiteral(7)),
    "number",
    Add(Variable(IntType, "number"), IntLiteral(2)),
    "flag",
    If(IntType, Variable(BoolType, "flag"), IntLiteral(4), IntLiteral(5)),
  )
  let candidates = expression.shrink_candidates()
  assert_true(candidates.length() > 0)
  for candidate in candidates {
    assert_true(candidate.complexity() < expression.complexity())
    match candidate.value_type() {
      IntType => ()
      BoolType | ChoiceType => abort("choice reducer changed result type")
    }
  }
  assert_true(candidates[0].to_source() != "number")
}

///|
test "function reduction never exposes its bound parameter" {
  let expression = @moonsmith.FunctionApply(
    IntType,
    "parameter",
    IntLiteral(7),
    Add(Variable(IntType, "parameter"), IntLiteral(2)),
  )
  for candidate in expression.shrink_candidates() {
    assert_true(candidate.to_source() != "parameter")
    assert_true(candidate.complexity() < expression.complexity())
  }
  let identity = @moonsmith.FunctionApply(
    IntType,
    "parameter",
    IntLiteral(7),
    Variable(IntType, "parameter"),
  )
  assert_eq(identity.shrink_candidates()[0].to_source(), "7")
}

///|
test "for-loop reduction preserves bound variables and result type" {
  let expression = @moonsmith.ForLoop(
    3,
    IntLiteral(9),
    Add(Variable(IntType, "_ms_acc"), Variable(IntType, "_ms_index")),
  )
  let candidates = expression.shrink_candidates()
  assert_eq(candidates[0].to_source(), "9")
  assert_true(candidates.length() > 1)
  for candidate in candidates {
    assert_true(candidate.complexity() < expression.complexity())
    match candidate.value_type() {
      IntType => ()
      BoolType | ChoiceType => abort("for-loop reducer changed result type")
    }
  }
  let reduced_loop = candidates[1].to_source()
  assert_true(reduced_loop.contains("for _ms_index"))
}

///|
test "valtype raise probe reduction preserves the trigger scaffold" {
  let expression = @moonsmith.ValtypeRaiseProbe(IntLiteral(-16))
  let candidates = expression.shrink_candidates()
  assert_true(candidates.length() > 0)
  for candidate in candidates {
    assert_true(candidate.complexity() < expression.complexity())
    match candidate.value_type() {
      BoolType => ()
      IntType | ChoiceType => abort("valtype reducer changed result type")
    }
  }
  assert_true(candidates[0].to_source().contains("_ms_valtype_run"))
}
