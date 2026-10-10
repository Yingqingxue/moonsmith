///|
test "same seed produces the same program" {
  let first = @moonsmith.generate_program(42, 4)
  let second = @moonsmith.generate_program(42, 4)
  assert_eq(first.to_source(), second.to_source())
}

///|
test "extreme Int seeds generate reproducible well-typed programs" {
  let min_int = -2147483647 - 1
  let seeds = [min_int, -1, 0, 1, 2147483647]
  for seed in seeds {
    let first = @moonsmith.generate_program(seed, 3)
    let second = @moonsmith.generate_program(seed, 3)
    assert_eq(first.to_source(), second.to_source())
    match (first.result.value_type(), first.result_type) {
      (@moonsmith.IntType, @moonsmith.IntType)
      | (@moonsmith.BoolType, @moonsmith.BoolType) => ()
      _ => abort("extreme seed generated an ill-typed result")
    }
  }
}

///|
test "the former 997-seed cycle is gone" {
  let first = @moonsmith.generate_program(0, 4).to_source()
  let later = @moonsmith.generate_program(997, 4).to_source()
  let first_body = first.split_once("\n").unwrap().1.to_owned()
  let later_body = later.split_once("\n").unwrap().1.to_owned()
  assert_true(first_body != later_body)
}

///|
test "first hundred seeds retain structural diversity" {
  let bodies : Array[String] = []
  for seed = 0; seed < 100; seed = seed + 1 {
    let body = @moonsmith.generate_program(seed, 4).result.to_source()
    let mut already_seen = false
    for earlier in bodies {
      if earlier == body {
        already_seen = true
      }
    }
    if !already_seen {
      bodies.push(body)
    }
  }
  assert_true(bodies.length() >= 95)
}

///|
test "generated expression has the declared type" {
  for seed = 0; seed < 100; seed = seed + 1 {
    let program = @moonsmith.generate_program(seed, 4)
    match (program.result.value_type(), program.result_type) {
      (IntType, IntType) | (BoolType, BoolType) => ()
      _ => abort("generated expression has the wrong result type")
    }
  }
}

///|
test "rendered program is deterministic and self contained" {
  let source = @moonsmith.generate_program(7, 3).to_source()
  assert_true(source.contains("seed=7"))
  assert_true(source.contains("fn main"))
  assert_true(source.contains("println"))
}

///|
test "generated corpus exercises both safe array indices" {
  let mut first = false
  let mut second = false
  for seed = 0; seed < 100; seed = seed + 1 {
    let source = @moonsmith.generate_program(seed, 4).to_source()
    if source.contains("items[0]") {
      first = true
    }
    if source.contains("items[1]") {
      second = true
    }
  }
  assert_true(first && second)
}

///|
test "generated corpus exercises integer and boolean function calls" {
  let mut integer_function = false
  let mut boolean_function = false
  for seed = 0; seed < 100; seed = seed + 1 {
    let source = @moonsmith.generate_program(seed, 4).to_source()
    if source.contains("fn(p") && source.contains(" : Int)") {
      integer_function = true
    }
    if source.contains("fn(p") && source.contains(" : Bool)") {
      boolean_function = true
    }
  }
  assert_true(integer_function && boolean_function)
}

///|
test "generated corpus exercises both typed record fields" {
  let mut integer_field = false
  let mut boolean_field = false
  for seed = 0; seed < 100; seed = seed + 1 {
    let source = @moonsmith.generate_program(seed, 4).to_source()
    if source.contains("pair.number") {
      integer_field = true
    }
    if source.contains("pair.flag") {
      boolean_field = true
    }
  }
  assert_true(integer_field && boolean_field)
}

///|
test "generated corpus exercises both tagged enum payloads and match arms" {
  let mut number_case = false
  let mut flag_case = false
  let mut number_payload = false
  let mut flag_payload = false
  for seed = 0; seed < 100; seed = seed + 1 {
    let source = @moonsmith.generate_program(seed, 4).to_source()
    if source.contains("Choice::Number") {
      number_case = true
    }
    if source.contains("Choice::Flag") {
      flag_case = true
    }
    if source.contains("let selected_choice = Choice::Number(") {
      number_payload = true
    }
    if source.contains("let selected_choice = Choice::Flag(") {
      flag_payload = true
    }
  }
  assert_true(number_case && flag_case && number_payload && flag_payload)
}

///|
test "generated corpus contains bounded integer loops" {
  let mut has_loop = false
  let mut compares_loop_result = false
  for seed = 0; seed < 100; seed = seed + 1 {
    let source = @moonsmith.generate_program(seed, 4).to_source()
    if source.contains("for _ms_index = 0, _ms_acc =") {
      has_loop = true
    }
    if source.contains("nobreak") && source.contains("_ms_index <") {
      compares_loop_result = true
    }
  }
  assert_true(has_loop && compares_loop_result)
}

///|
test "generated boolean corpus exercises valtype raise probes" {
  let mut has_probe = false
  let mut has_scaffold = false
  for seed = 0; seed < 200; seed = seed + 1 {
    let program = @moonsmith.generate_program(seed, 4)
    if program.to_source().contains("_ms_valtype_run") {
      has_probe = true
      has_scaffold = program.to_source().contains("#valtype") &&
        program.to_source().contains("try? _ms_valtype_make")
    }
  }
  assert_true(has_probe && has_scaffold)
}

///|
test "valtype raise support declarations are emitted only when needed" {
  let probe_program = @moonsmith.generate_program(0, 4).to_source()
  let ordinary_program = @moonsmith.generate_program(0, 0).to_source()
  assert_true(probe_program.contains("#valtype\npriv struct MoonSmithValtype"))
  assert_true(!ordinary_program.contains("#valtype"))
  assert_true(!ordinary_program.contains("_ms_valtype_run"))
}

///|
test "generated integer corpus includes valtype enum array programs" {
  let mut found = false
  for seed = 0; seed < 200; seed = seed + 1 {
    let source = @moonsmith.generate_program(seed, 3).to_source()
    if source.contains("_ms_valtype_array_run(") {
      found = true
      assert_true(source.contains("#valtype\npriv struct MoonSmithEntry"))
      assert_true(
        source.contains("let values : Array[MoonSmithEntry] = [{ id: i"),
      )
      assert_true(source.contains("match values[0].kind"))
    }
  }
  assert_true(found)
}
