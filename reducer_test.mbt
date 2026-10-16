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
test "minimum integer literals retain a nonnegative shrink complexity" {
  let minimum = -2147483647 - 1
  let expression = @moonsmith.IntLiteral(minimum)
  assert_eq(expression.complexity(), 2147483649L)
  let candidates = expression.shrink_candidates()
  assert_eq(candidates.length(), 2)
  for candidate in candidates {
    assert_true(candidate.complexity() < expression.complexity())
  }
  assert_eq(@moonsmith.Add(expression, expression).complexity(), 4294968298L)
  let compound = @moonsmith.Add(expression, expression)
  let compound_candidates = compound.shrink_candidates()
  assert_true(compound_candidates.length() > 0)
  let mut can_remove_compound = false
  for candidate in compound_candidates {
    assert_true(candidate.complexity() < compound.complexity())
    if candidate.to_source() == expression.to_source() {
      can_remove_compound = true
    }
  }
  assert_true(can_remove_compound)
}

///|
test "FMA probe is a minimal typed leaf and has no invalid shrink candidates" {
  let expression = @moonsmith.FmaContractionProbe
  assert_true(expression.value_type() is @moonsmith.BoolType)
  assert_eq(expression.complexity(), 1)
  assert_eq(expression.shrink_candidates().length(), 0)
}

///|
test "structural shrinking can retain the FMA trigger as a minimal body" {
  let trigger = @moonsmith.FmaContractionProbe
  let expression = @moonsmith.And(trigger, @moonsmith.BoolLiteral(true))
  let candidates = expression.shrink_candidates()
  let mut retained_trigger = false
  for candidate in candidates {
    if candidate.to_source() == trigger.to_source() {
      retained_trigger = true
    }
  }
  assert_true(retained_trigger)
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
test "logical or reduction preserves type and lowers complexity" {
  let expression = @moonsmith.Or(BoolLiteral(false), BoolLiteral(true))
  let candidates = expression.shrink_candidates()
  assert_eq(candidates[0].to_source(), "false")
  assert_eq(candidates[1].to_source(), "true")
  for candidate in candidates {
    assert_true(candidate.value_type() is BoolType)
    assert_true(candidate.complexity() < expression.complexity())
  }
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
test "array growth reduction preserves element type and push scaffold" {
  let expression = @moonsmith.ArrayGrowSelect(
    BoolType,
    BoolLiteral(false),
    BoolLiteral(true),
    true,
  )
  let candidates = expression.shrink_candidates()
  assert_true(candidates.length() > 2)
  assert_eq(candidates[0].to_source(), "false")
  assert_eq(candidates[1].to_source(), "true")
  for candidate in candidates {
    assert_true(candidate.value_type() is BoolType)
    assert_true(candidate.complexity() < expression.complexity())
  }
  assert_true(candidates[2].to_source().contains("grown_items.push"))
}

///|
test "array alias update reduction retains typed observable mutation" {
  let expression = @moonsmith.ArrayAliasUpdateSelect(
    IntType,
    IntLiteral(7),
    IntLiteral(9),
    IntLiteral(11),
    true,
  )
  let candidates = expression.shrink_candidates()
  assert_true(candidates.length() > 1)
  assert_eq(candidates[0].to_source(), "11")
  for candidate in candidates {
    assert_true(candidate.value_type() is IntType)
    assert_true(candidate.complexity() < expression.complexity())
  }
  assert_true(candidates[1].to_source().contains("_ms_alias[1] = replacement"))
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
test "Choice-returning function reduction preserves its result type" {
  let expression = @moonsmith.FunctionApply(
    ChoiceType,
    "payload",
    IntLiteral(7),
    @moonsmith.ChoiceValue(IntType, @moonsmith.Variable(IntType, "payload")),
  )
  let candidates = expression.shrink_candidates()
  assert_true(candidates.length() > 0)
  for candidate in candidates {
    assert_true(candidate.complexity() < expression.complexity())
    assert_true(candidate.value_type() is ChoiceType)
  }
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
test "while-loop reduction preserves bound variables and result type" {
  let expression = @moonsmith.WhileLoop(
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
      BoolType | ChoiceType => abort("while-loop reducer changed result type")
    }
  }
  assert_true(candidates[1].to_source().contains("while _ms_index < 0"))
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

///|
test "valtype enum array reduction preserves its array and match call" {
  let expression = @moonsmith.ValtypeEnumArrayProbe(IntLiteral(-16))
  let candidates = expression.shrink_candidates()
  assert_true(candidates.length() > 0)
  for candidate in candidates {
    assert_true(candidate.complexity() < expression.complexity())
    assert_true(candidate.to_source().contains("_ms_valtype_array_run("))
    match candidate.value_type() {
      IntType => ()
      BoolType | ChoiceType =>
        abort("valtype array reducer changed result type")
    }
  }
}

///|
test "combined valtype reduction preserves both probe layers" {
  let expression : @moonsmith.Expr = @moonsmith.ValtypeRaiseProbe(
    @moonsmith.ValtypeEnumArrayProbe(@moonsmith.IntLiteral(-16)),
  )
  let candidates = expression.shrink_candidates()
  assert_true(candidates.length() > 0)
  for candidate in candidates {
    assert_true(candidate.complexity() < expression.complexity())
    match candidate.value_type() {
      @moonsmith.BoolType => ()
      @moonsmith.IntType | @moonsmith.ChoiceType =>
        abort("combined valtype reducer changed result type")
    }
    let source = candidate.to_source()
    assert_true(source.contains("_ms_valtype_array_run("))
    assert_true(source.contains("_ms_valtype_run("))
  }
}

///|
test "candidate manifest serializes a real reduction" {
  let program = @moonsmith.generate_program(7, 2)
  let manifest = program.candidates_json()
  assert_true(manifest.has_prefix("{\"complexity\":"))
  assert_true(manifest.contains("\"expectedOutput\":\""))
  assert_true(manifest.contains("\"source\":"))
  assert_true(manifest.contains("\"candidates\":["))
  assert_true(manifest.has_suffix("]}"))
}

///|
test "unused match arms can be removed without changing result type" {
  let expression = @moonsmith.MatchChoice(
    @moonsmith.IntType,
    @moonsmith.ChoiceValue(@moonsmith.IntType, @moonsmith.IntLiteral(9)),
    "number",
    @moonsmith.IntLiteral(3),
    "flag",
    @moonsmith.IntLiteral(4),
  )
  let candidates = expression.shrink_candidates()
  assert_true(candidates.length() > 1)
  assert_eq(candidates[0].to_source(), "3")
  assert_eq(candidates[1].to_source(), "4")
}

///|
test "unused function and let bindings can be removed" {
  let function = @moonsmith.FunctionApply(
    @moonsmith.IntType,
    "unused_parameter",
    @moonsmith.IntLiteral(5),
    @moonsmith.IntLiteral(9),
  )
  let function_candidates = function.shrink_candidates()
  assert_eq(function_candidates[0].to_source(), "5")
  assert_eq(function_candidates[1].to_source(), "9")
  let binding = @moonsmith.Let(
    @moonsmith.IntType,
    "unused_binding",
    @moonsmith.IntLiteral(9),
    @moonsmith.Add(@moonsmith.IntLiteral(3), @moonsmith.IntLiteral(4)),
  )
  assert_eq(binding.shrink_candidates()[0].to_source(), "(3 + 4)")
}
