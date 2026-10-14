///|
/// The deliberately small type universe supported by the first generator.
pub(all) enum ValueType {
  IntType
  BoolType
  ChoiceType
}

///|
/// A typed expression IR. Constructors only represent total, deterministic
/// operations so generated programs are meaningful differential-test inputs.
pub(all) enum Expr {
  IntLiteral(Int)
  BoolLiteral(Bool)
  Variable(ValueType, String)
  Add(Expr, Expr)
  Subtract(Expr, Expr)
  And(Expr, Expr)
  Or(Expr, Expr)
  LessThan(Expr, Expr)
  EqualInt(Expr, Expr)
  Not(Expr)
  If(ValueType, Expr, Expr, Expr)
  MatchBool(ValueType, Expr, Expr, Expr)
  Let(ValueType, String, Expr, Expr)
  ArraySelect(ValueType, Expr, Expr, Bool)
  ArrayGrowSelect(ValueType, Expr, Expr, Bool)
  ArrayAliasUpdateSelect(ValueType, Expr, Expr, Expr, Bool)
  StructSelect(ValueType, Expr, Expr)
  ChoiceValue(ValueType, Expr)
  MatchChoice(ValueType, Expr, String, Expr, String, Expr)
  FunctionApply(ValueType, String, Expr, Expr)
  ForLoop(Int, Expr, Expr)
  WhileLoop(Int, Expr, Expr)
  ValtypeRaiseProbe(Expr)
  ValtypeEnumArrayProbe(Expr)
}

///|
/// A generated test program and the metadata required to reproduce it.
pub(all) struct Program {
  seed : Int
  result_type : ValueType
  result : Expr
}

///|
/// Map every Int seed to the nonzero Park-Miller state range. This avoids the
/// old 997-seed cycle while keeping arithmetic within signed 32-bit bounds.
fn normalize_seed(seed : Int) -> Int {
  let reduced = seed % 2147483647
  if reduced < 0 {
    reduced + 2147483647
  } else if reduced == 0 {
    2147483646
  } else {
    reduced
  }
}

///|
/// Park-Miller step using Schrage's method; products stay below Int::max.
fn advance_seed(seed : Int) -> Int {
  let state = normalize_seed(seed)
  let quotient = state / 44488
  let remainder = state % 44488
  let next = 48271 * remainder - 3399 * quotient
  if next > 0 {
    next
  } else {
    next + 2147483647
  }
}

///|
/// Mix the branch into the parent state before advancing. Branch offsets are
/// bounded by the generator's fixed set of child slots.
fn child_seed(seed : Int, branch : Int) -> Int {
  let state = normalize_seed(seed)
  let offset = branch * 104729 + 17
  let mixed = if state > 2147483646 - offset {
    state - (2147483646 - offset)
  } else {
    state + offset
  }
  advance_seed(mixed)
}

///|
fn int_leaf(seed : Int) -> Expr {
  IntLiteral(normalize_seed(seed) % 41 - 20)
}

///|
fn bool_leaf(seed : Int) -> Expr {
  BoolLiteral(normalize_seed(seed) % 2 == 0)
}

///|
/// Generate a bounded loop whose two loop variables are updated together.
/// The body uses both the current index and accumulator, exercising MoonBit's
/// loop-carried value semantics without allowing an unbounded test case.
fn generate_for_loop(seed : Int, depth : Int) -> Expr {
  let index_name = "_ms_index"
  let accumulator_name = "_ms_acc"
  let index = Variable(IntType, index_name)
  let accumulator = Variable(IntType, accumulator_name)
  let extra = generate_expr(child_seed(seed, 53), IntType, depth - 1)
  let delta = if advance_seed(child_seed(seed, 54)) % 2 == 0 {
    Add(index, extra)
  } else {
    Subtract(extra, index)
  }
  ForLoop(
    advance_seed(child_seed(seed, 51)) % 6,
    generate_expr(child_seed(seed, 52), IntType, depth - 1),
    Add(accumulator, delta),
  )
}

///|
/// Keep the existing for-loop corpus mostly stable while sampling mutable
/// while-loop state with the same bounded body and iteration count.
fn generate_bounded_loop(seed : Int, depth : Int) -> Expr {
  match generate_for_loop(seed, depth) {
    ForLoop(iterations, initial, body) =>
      if advance_seed(child_seed(seed, 63)) % 4 == 0 {
        WhileLoop(iterations, initial, body)
      } else {
        ForLoop(iterations, initial, body)
      }
    _ => abort("bounded-loop generator returned a non-loop expression")
  }
}

///|
/// Sample empty-array growth without changing the type or bounds of the
/// existing two-element array selection expression.
fn generate_array_select(
  result_type : ValueType,
  first : Expr,
  second : Expr,
  select_second : Bool,
  seed : Int,
  depth : Int,
) -> Expr {
  let array_mode = advance_seed(child_seed(seed, 64)) % 4
  if array_mode == 0 {
    // A separate modulus avoids locking the growth branch to the same index
    // through parity correlations in the deterministic seed stream.
    let growth_select_second = advance_seed(child_seed(seed, 65)) % 5 < 2
    ArrayGrowSelect(result_type, first, second, growth_select_second)
  } else if array_mode == 1 {
    // Keep alias index selection independent of the array-mode branch.
    let alias_select_second = advance_seed(child_seed(seed, 67)) % 5 < 2
    ArrayAliasUpdateSelect(
      result_type,
      first,
      second,
      generate_expr(child_seed(seed, 66), result_type, depth - 1),
      alias_select_second,
    )
  } else {
    ArraySelect(result_type, first, second, select_second)
  }
}

///|
/// Generate a Choice value, sometimes through a typed local function. This
/// exercises Choice as a function result rather than only as a match input.
fn generate_choice(seed : Int, depth : Int) -> Expr {
  let payload_type = if advance_seed(child_seed(seed, 60)) % 2 == 0 {
    IntType
  } else {
    BoolType
  }
  if depth <= 0 {
    ChoiceValue(
      payload_type,
      generate_expr(child_seed(seed, 61), payload_type, 0),
    )
  } else {
    generate_choice_with_payload(seed, depth - 1, payload_type, 61)
  }
}

///|
fn generate_choice_with_payload(
  seed : Int,
  depth : Int,
  payload_type : ValueType,
  argument_branch : Int,
) -> Expr {
  let argument = generate_expr(
    child_seed(seed, argument_branch),
    payload_type,
    depth,
  )
  if advance_seed(child_seed(seed, argument_branch + 20)) % 5 == 0 {
    let name = "q" + depth.to_string()
    FunctionApply(
      ChoiceType,
      name,
      argument,
      ChoiceValue(payload_type, Variable(payload_type, name)),
    )
  } else {
    ChoiceValue(payload_type, argument)
  }
}

///|
/// Generate an expression of exactly the requested type.
pub fn generate_expr(seed : Int, expected : ValueType, depth : Int) -> Expr {
  if depth <= 0 {
    match expected {
      IntType => int_leaf(seed)
      BoolType => bool_leaf(seed)
      ChoiceType => generate_choice(seed, 0)
    }
  } else {
    // Two steps break the parity correlation between result type and branch.
    let choice = advance_seed(advance_seed(seed)) % 12
    match expected {
      IntType =>
        match choice {
          0 =>
            Subtract(
              generate_expr(child_seed(seed, 23), IntType, depth - 1),
              generate_expr(child_seed(seed, 24), IntType, depth - 1),
            )
          1 =>
            Add(
              generate_expr(child_seed(seed, 1), IntType, depth - 1),
              generate_expr(child_seed(seed, 2), IntType, depth - 1),
            )
          2 =>
            If(
              IntType,
              generate_expr(child_seed(seed, 3), BoolType, depth - 1),
              generate_expr(child_seed(seed, 4), IntType, depth - 1),
              generate_expr(child_seed(seed, 5), IntType, depth - 1),
            )
          3 =>
            MatchBool(
              IntType,
              generate_expr(child_seed(seed, 11), BoolType, depth - 1),
              generate_expr(child_seed(seed, 12), IntType, depth - 1),
              generate_expr(child_seed(seed, 13), IntType, depth - 1),
            )
          4 => {
            let name = "v" + depth.to_string()
            Let(
              IntType,
              name,
              generate_expr(child_seed(seed, 17), IntType, depth - 1),
              Add(
                Variable(IntType, name),
                generate_expr(child_seed(seed, 18), IntType, depth - 1),
              ),
            )
          }
          5 => {
            let name = "v" + depth.to_string()
            Let(
              BoolType,
              name,
              generate_expr(child_seed(seed, 19), BoolType, depth - 1),
              If(
                IntType,
                Variable(BoolType, name),
                generate_expr(child_seed(seed, 20), IntType, depth - 1),
                generate_expr(child_seed(seed, 21), IntType, depth - 1),
              ),
            )
          }
          6 =>
            generate_array_select(
              IntType,
              generate_expr(child_seed(seed, 27), IntType, depth - 1),
              generate_expr(child_seed(seed, 28), IntType, depth - 1),
              advance_seed(child_seed(seed, 31)) % 2 == 0,
              seed,
              depth,
            )
          7 =>
            StructSelect(
              IntType,
              generate_expr(child_seed(seed, 37), IntType, depth - 1),
              generate_expr(child_seed(seed, 38), BoolType, depth - 1),
            )
          8 => {
            let payload_type = if advance_seed(child_seed(seed, 41)) % 2 == 0 {
              IntType
            } else {
              BoolType
            }
            let number_name = "n" + depth.to_string()
            let flag_name = "b" + depth.to_string()
            MatchChoice(
              IntType,
              generate_choice_with_payload(seed, depth - 1, payload_type, 42),
              number_name,
              Add(
                Variable(IntType, number_name),
                generate_expr(child_seed(seed, 43), IntType, depth - 1),
              ),
              flag_name,
              If(
                IntType,
                Variable(BoolType, flag_name),
                generate_expr(child_seed(seed, 44), IntType, depth - 1),
                generate_expr(child_seed(seed, 45), IntType, depth - 1),
              ),
            )
          }
          9 => generate_bounded_loop(seed, depth)
          10 => {
            let name = "p" + depth.to_string()
            FunctionApply(
              IntType,
              name,
              generate_expr(child_seed(seed, 33), IntType, depth - 1),
              Add(
                Variable(IntType, name),
                generate_expr(child_seed(seed, 34), IntType, depth - 1),
              ),
            )
          }
          _ =>
            ValtypeEnumArrayProbe(
              generate_expr(child_seed(seed, 57), IntType, depth - 1),
            )
        }
      BoolType =>
        match choice {
          0 => {
            let left = generate_expr(child_seed(seed, 25), BoolType, depth - 1)
            let right = generate_expr(child_seed(seed, 26), BoolType, depth - 1)
            // Bias toward Or so a fixed-size corpus can inspect both short-circuit operators.
            if advance_seed(child_seed(seed, 62)) % 3 == 0 {
              And(left, right)
            } else {
              Or(left, right)
            }
          }
          1 =>
            LessThan(
              generate_expr(child_seed(seed, 6), IntType, depth - 1),
              generate_expr(child_seed(seed, 7), IntType, depth - 1),
            )
          2 =>
            EqualInt(
              generate_expr(child_seed(seed, 8), IntType, depth - 1),
              generate_expr(child_seed(seed, 9), IntType, depth - 1),
            )
          3 => Not(generate_expr(child_seed(seed, 10), BoolType, depth - 1))
          4 =>
            MatchBool(
              BoolType,
              generate_expr(child_seed(seed, 14), BoolType, depth - 1),
              generate_expr(child_seed(seed, 15), BoolType, depth - 1),
              generate_expr(child_seed(seed, 16), BoolType, depth - 1),
            )
          5 => {
            let name = "v" + depth.to_string()
            Let(
              BoolType,
              name,
              generate_expr(child_seed(seed, 22), BoolType, depth - 1),
              Not(Variable(BoolType, name)),
            )
          }
          6 =>
            generate_array_select(
              BoolType,
              generate_expr(child_seed(seed, 29), BoolType, depth - 1),
              generate_expr(child_seed(seed, 30), BoolType, depth - 1),
              advance_seed(child_seed(seed, 32)) % 2 == 0,
              seed,
              depth,
            )
          7 =>
            StructSelect(
              BoolType,
              generate_expr(child_seed(seed, 39), IntType, depth - 1),
              generate_expr(child_seed(seed, 40), BoolType, depth - 1),
            )
          8 => {
            let payload_type = if advance_seed(child_seed(seed, 46)) % 2 == 0 {
              IntType
            } else {
              BoolType
            }
            let number_name = "n" + depth.to_string()
            let flag_name = "b" + depth.to_string()
            MatchChoice(
              BoolType,
              generate_choice_with_payload(seed, depth - 1, payload_type, 47),
              number_name,
              LessThan(
                Variable(IntType, number_name),
                generate_expr(child_seed(seed, 48), IntType, depth - 1),
              ),
              flag_name,
              And(
                Variable(BoolType, flag_name),
                generate_expr(child_seed(seed, 49), BoolType, depth - 1),
              ),
            )
          }
          9 =>
            LessThan(
              generate_bounded_loop(seed, depth),
              generate_expr(child_seed(seed, 55), IntType, depth - 1),
            )
          10 => {
            let name = "p" + depth.to_string()
            FunctionApply(
              BoolType,
              name,
              generate_expr(child_seed(seed, 35), BoolType, depth - 1),
              And(
                Variable(BoolType, name),
                generate_expr(child_seed(seed, 36), BoolType, depth - 1),
              ),
            )
          }
          _ => {
            let value = generate_expr(child_seed(seed, 56), IntType, depth - 1)
            if advance_seed(seed) % 2 == 0 {
              ValtypeRaiseProbe(ValtypeEnumArrayProbe(value))
            } else {
              ValtypeRaiseProbe(value)
            }
          }
        }
      ChoiceType => generate_choice(seed, depth)
    }
  }
}

///|
/// Generate one reproducible program. Even seeds produce an Int result and odd
/// seeds produce a Bool result, ensuring both paths are exercised by a corpus.
pub fn generate_program(seed : Int, depth : Int) -> Program {
  let result_type = if normalize_seed(seed) % 2 == 0 {
    IntType
  } else {
    BoolType
  }
  { seed, result_type, result: generate_expr(seed, result_type, depth), }
}

///|
pub fn Expr::value_type(self : Expr) -> ValueType {
  match self {
    IntLiteral(_) | Add(_, _) | Subtract(_, _) => IntType
    BoolLiteral(_)
    | And(_, _)
    | Or(_, _)
    | LessThan(_, _)
    | EqualInt(_, _)
    | Not(_) => BoolType
    If(result_type, _, _, _) | MatchBool(result_type, _, _, _) => result_type
    Variable(value_type, _) => value_type
    Let(_, _, _, body) => body.value_type()
    ArraySelect(result_type, _, _, _) | ArrayGrowSelect(result_type, _, _, _) =>
      result_type
    ArrayAliasUpdateSelect(result_type, _, _, _, _) => result_type
    StructSelect(result_type, _, _) => result_type
    ChoiceValue(_, _) => ChoiceType
    MatchChoice(result_type, _, _, _, _, _) => result_type
    FunctionApply(result_type, _, _, _) => result_type
    ForLoop(_, _, _) | WhileLoop(_, _, _) | ValtypeEnumArrayProbe(_) => IntType
    ValtypeRaiseProbe(_) => BoolType
  }
}

///|
fn Expr::contains_struct(self : Expr) -> Bool {
  match self {
    StructSelect(_, _, _) => true
    ChoiceValue(_, payload) => payload.contains_struct()
    MatchChoice(_, choice, _, number_body, _, flag_body) =>
      choice.contains_struct() ||
      number_body.contains_struct() ||
      flag_body.contains_struct()
    IntLiteral(_) | BoolLiteral(_) | Variable(_, _) => false
    Add(left, right)
    | Subtract(left, right)
    | And(left, right)
    | Or(left, right)
    | LessThan(left, right)
    | EqualInt(left, right) => left.contains_struct() || right.contains_struct()
    Not(value) => value.contains_struct()
    If(_, condition, yes, no) | MatchBool(_, condition, yes, no) =>
      condition.contains_struct() ||
      yes.contains_struct() ||
      no.contains_struct()
    Let(_, _, value, body) => value.contains_struct() || body.contains_struct()
    ArraySelect(_, first, second, _) | ArrayGrowSelect(_, first, second, _) =>
      first.contains_struct() || second.contains_struct()
    ArrayAliasUpdateSelect(_, first, second, replacement, _) =>
      first.contains_struct() ||
      second.contains_struct() ||
      replacement.contains_struct()
    FunctionApply(_, _, argument, body) =>
      argument.contains_struct() || body.contains_struct()
    ForLoop(_, initial, body) | WhileLoop(_, initial, body) =>
      initial.contains_struct() || body.contains_struct()
    ValtypeRaiseProbe(value) | ValtypeEnumArrayProbe(value) =>
      value.contains_struct()
  }
}

///|
fn Expr::contains_choice(self : Expr) -> Bool {
  match self {
    ChoiceValue(_, _) | MatchChoice(_, _, _, _, _, _) => true
    IntLiteral(_) | BoolLiteral(_) | Variable(_, _) => false
    Add(left, right)
    | Subtract(left, right)
    | And(left, right)
    | Or(left, right)
    | LessThan(left, right)
    | EqualInt(left, right) => left.contains_choice() || right.contains_choice()
    Not(value) => value.contains_choice()
    If(_, condition, yes, no) | MatchBool(_, condition, yes, no) =>
      condition.contains_choice() ||
      yes.contains_choice() ||
      no.contains_choice()
    Let(_, _, value, body) => value.contains_choice() || body.contains_choice()
    ArraySelect(_, first, second, _) | ArrayGrowSelect(_, first, second, _) =>
      first.contains_choice() || second.contains_choice()
    ArrayAliasUpdateSelect(_, first, second, replacement, _) =>
      first.contains_choice() ||
      second.contains_choice() ||
      replacement.contains_choice()
    StructSelect(_, number, flag) =>
      number.contains_choice() || flag.contains_choice()
    FunctionApply(_, _, argument, body) =>
      argument.contains_choice() || body.contains_choice()
    ForLoop(_, initial, body) | WhileLoop(_, initial, body) =>
      initial.contains_choice() || body.contains_choice()
    ValtypeRaiseProbe(value) | ValtypeEnumArrayProbe(value) =>
      value.contains_choice()
  }
}

///|
pub fn Expr::to_source(self : Expr) -> String {
  match self {
    IntLiteral(value) => value.to_string()
    BoolLiteral(value) => if value { "true" } else { "false" }
    Variable(_, name) => name
    Add(left, right) => "(" + left.to_source() + " + " + right.to_source() + ")"
    Subtract(left, right) =>
      "(" + left.to_source() + " - " + right.to_source() + ")"
    And(left, right) =>
      "({\n    let mut _ms_and_rhs_calls = 0\n    let _ms_and_rhs = fn() {\n      _ms_and_rhs_calls = _ms_and_rhs_calls + 1\n      " +
      right.to_source() +
      "\n    }\n    let _ms_and_left = " +
      left.to_source() +
      "\n    let _ms_and_result = _ms_and_left && _ms_and_rhs()\n    if _ms_and_rhs_calls == (if _ms_and_left { 1 } else { 0 }) {\n      _ms_and_result\n    } else {\n      panic()\n    }\n  })"
    Or(left, right) =>
      "({\n    let mut _ms_or_rhs_calls = 0\n    let _ms_or_rhs = fn() {\n      _ms_or_rhs_calls = _ms_or_rhs_calls + 1\n      " +
      right.to_source() +
      "\n    }\n    let _ms_or_left = " +
      left.to_source() +
      "\n    let _ms_or_result = _ms_or_left || _ms_or_rhs()\n    if _ms_or_rhs_calls == (if _ms_or_left { 0 } else { 1 }) {\n      _ms_or_result\n    } else {\n      panic()\n    }\n  })"
    LessThan(left, right) =>
      "(" + left.to_source() + " < " + right.to_source() + ")"
    EqualInt(left, right) =>
      "(" + left.to_source() + " == " + right.to_source() + ")"
    Not(value) => "!(" + value.to_source() + ")"
    If(_, condition, then_expr, else_expr) =>
      "(if " +
      condition.to_source() +
      " { " +
      then_expr.to_source() +
      " } else { " +
      else_expr.to_source() +
      " })"
    MatchBool(_, condition, true_expr, false_expr) =>
      "(match " +
      condition.to_source() +
      " {\n    true => " +
      true_expr.to_source() +
      "\n    false => " +
      false_expr.to_source() +
      "\n  })"
    Let(_, name, value, body) =>
      "({\n    let " +
      name +
      " = " +
      value.to_source() +
      "\n    " +
      body.to_source() +
      "\n  })"
    ArraySelect(_, first, second, select_second) =>
      "({\n    let items = [" +
      first.to_source() +
      ", " +
      second.to_source() +
      "]\n    items[" +
      (if select_second { "1" } else { "0" }) +
      "]\n  })"
    ArrayGrowSelect(result_type, first, second, select_second) => {
      let element_type = match result_type {
        IntType => "Int"
        BoolType => "Bool"
        ChoiceType => abort("Choice cannot be an array-growth result type")
      }
      "({\n    let grown_items : Array[" +
      element_type +
      "] = []\n    grown_items.push(" +
      first.to_source() +
      ")\n    grown_items.push(" +
      second.to_source() +
      ")\n    grown_items[" +
      (if select_second { "1" } else { "0" }) +
      "]\n  })"
    }
    ArrayAliasUpdateSelect(
      result_type,
      first,
      second,
      replacement,
      select_second
    ) => {
      let selected_index = if select_second { "1" } else { "0" }
      let other_index = if select_second { "0" } else { "1" }
      // An equal candidate would make a missing alias write unobservable.
      let distinct_fallback = match result_type {
        IntType => "if original == 0 { 1 } else { 0 }"
        BoolType => "!original"
        ChoiceType =>
          abort("Choice cannot be an array-alias-update result type")
      }
      "({\n    let items = [" +
      first.to_source() +
      ", " +
      second.to_source() +
      "]\n    let _ms_alias = items\n    let other_before = items[" +
      other_index +
      "]\n    let original = items[" +
      selected_index +
      "]\n    let candidate = " +
      replacement.to_source() +
      "\n    let replacement = if candidate == original { " +
      distinct_fallback +
      " } else { candidate }" +
      "\n    _ms_alias[" +
      selected_index +
      "] = replacement\n    if items[" +
      selected_index +
      "] == replacement && items[" +
      other_index +
      "] == other_before {\n      items[" +
      selected_index +
      "]\n    } else {\n      panic()\n    }\n  })"
    }
    StructSelect(result_type, number, flag) => {
      let field = match result_type {
        IntType => "number"
        BoolType => "flag"
        ChoiceType => abort("Choice cannot be a struct result type")
      }
      "({\n    let pair = Pair::{ number: " +
      number.to_source() +
      ", flag: " +
      flag.to_source() +
      ", }\n    ignore(pair.number)\n    ignore(pair.flag)\n    pair." +
      field +
      "\n  })"
    }
    ChoiceValue(payload_type, payload) => {
      let variant = match payload_type {
        IntType => "Number"
        BoolType => "Flag"
        ChoiceType => abort("nested Choice payload is not supported")
      }
      "Choice::" + variant + "(" + payload.to_source() + ")"
    }
    MatchChoice(_, choice, number_name, number_body, flag_name, flag_body) =>
      "({\n    let selected_choice = " +
      choice.to_source() +
      "\n    match selected_choice {\n      Choice::Number(" +
      number_name +
      ") => " +
      number_body.to_source() +
      "\n      Choice::Flag(" +
      flag_name +
      ") => " +
      flag_body.to_source() +
      "\n    }\n  })"
    FunctionApply(_, name, argument, body) => {
      let type_source = match argument.value_type() {
        IntType => "Int"
        BoolType => "Bool"
        ChoiceType => "Choice"
      }
      "({\n    let transform = fn(" +
      name +
      " : " +
      type_source +
      ") { " +
      body.to_source() +
      " }\n    transform(" +
      argument.to_source() +
      ")\n  })"
    }
    ForLoop(iterations, initial, body) =>
      "({\n    for _ms_index = 0, _ms_acc = " +
      initial.to_source() +
      "; _ms_index < " +
      iterations.to_string() +
      "; _ms_index = _ms_index + 1, _ms_acc = " +
      body.to_source() +
      " {\n    } nobreak {\n      _ms_acc\n    }\n  })"
    WhileLoop(iterations, initial, body) =>
      "({\n    let mut _ms_index = 0\n    let mut _ms_acc = " +
      initial.to_source() +
      "\n    while _ms_index < " +
      iterations.to_string() +
      " {\n      let _ms_next = " +
      body.to_source() +
      "\n      _ms_acc = _ms_next\n      _ms_index = _ms_index + 1\n    }\n    _ms_acc\n  })"
    ValtypeRaiseProbe(value) =>
      "({\n    let _ms_valtype_input = " +
      value.to_source() +
      "\n    let _ms_valtype_actual = _ms_valtype_run(_ms_valtype_input.to_int64())" +
      "\n    let _ms_valtype_expected = if _ms_valtype_input < 0 { -1.0 } else { _ms_valtype_input.to_double() }" +
      "\n    _ms_valtype_actual == _ms_valtype_expected\n  })"
    ValtypeEnumArrayProbe(value) =>
      "_ms_valtype_array_run(" + value.to_source() + ")"
  }
}

///|
/// Render a self-contained MoonBit program whose single output is suitable for
/// comparison across compiler backends.
pub fn Program::to_source(self : Program) -> String {
  let pair_declaration = if self.result.contains_struct() {
    "struct Pair {\n  number : Int\n  flag : Bool\n}\n\n"
  } else {
    ""
  }
  let choice_declaration = if self.result.contains_choice() {
    "pub(all) enum Choice {\n  Number(Int)\n  Flag(Bool)\n}\n\n"
  } else {
    ""
  }
  let valtype_raise_declaration = if self.result.contains_valtype_raise_probe() {
    "#valtype\npriv struct MoonSmithValtype {\n  value : Double\n}\n\n" +
    "priv suberror MoonSmithValtypeError\n\n" +
    "fn _ms_valtype_make(i : Int64) -> MoonSmithValtype raise MoonSmithValtypeError {\n" +
    "  if i < 0L { raise MoonSmithValtypeError }\n" +
    "  { value: i.to_double() }\n" +
    "}\n\n" +
    "#warnings(\"-deprecated\")\n" +
    "fn _ms_valtype_run(i : Int64) -> Double {\n" +
    "  match (try? _ms_valtype_make(i)) {\n" +
    "    Ok({ value }) => value\n" +
    "    Err(_) => -1.0\n" +
    "  }\n" +
    "}\n\n"
  } else {
    ""
  }
  let valtype_enum_array_declaration = if self.result.contains_valtype_enum_array_probe() {
    "priv enum MoonSmithEntryKind {\n  Ref(String)\n}\n\n" +
    "#valtype\npriv struct MoonSmithEntry {\n  id : Int\n  kind : MoonSmithEntryKind\n}\n\n" +
    "fn _ms_valtype_array_run(i : Int) -> Int {\n" +
    "  let values : Array[MoonSmithEntry] = []\n" +
    "  values.push({ id: i, kind: MoonSmithEntryKind::Ref(\"x\") })\n" +
    "  values.push({ id: i + 1, kind: MoonSmithEntryKind::Ref(\"x\") })\n" +
    "  match values[0].kind {\n" +
    "    MoonSmithEntryKind::Ref(value) => if value == \"x\" { values[1].id } else { -1 }\n" +
    "  }\n" +
    "}\n\n"
  } else {
    ""
  }
  "// Generated by MoonSmith; seed=" +
  self.seed.to_string() +
  "\n" +
  choice_declaration +
  pair_declaration +
  valtype_raise_declaration +
  valtype_enum_array_declaration +
  "fn main {\n  println(" +
  self.result.to_source() +
  ")\n}\n"
}

///|
fn Expr::contains_valtype_raise_probe(self : Expr) -> Bool {
  match self {
    ValtypeRaiseProbe(_) => true
    IntLiteral(_) | BoolLiteral(_) | Variable(_, _) => false
    Add(left, right)
    | Subtract(left, right)
    | And(left, right)
    | Or(left, right)
    | LessThan(left, right)
    | EqualInt(left, right) =>
      left.contains_valtype_raise_probe() ||
      right.contains_valtype_raise_probe()
    Not(value) => value.contains_valtype_raise_probe()
    If(_, condition, yes, no) | MatchBool(_, condition, yes, no) =>
      condition.contains_valtype_raise_probe() ||
      yes.contains_valtype_raise_probe() ||
      no.contains_valtype_raise_probe()
    Let(_, _, value, body) =>
      value.contains_valtype_raise_probe() ||
      body.contains_valtype_raise_probe()
    ArraySelect(_, first, second, _) | ArrayGrowSelect(_, first, second, _) =>
      first.contains_valtype_raise_probe() ||
      second.contains_valtype_raise_probe()
    ArrayAliasUpdateSelect(_, first, second, replacement, _) =>
      first.contains_valtype_raise_probe() ||
      second.contains_valtype_raise_probe() ||
      replacement.contains_valtype_raise_probe()
    StructSelect(_, number, flag) =>
      number.contains_valtype_raise_probe() ||
      flag.contains_valtype_raise_probe()
    ChoiceValue(_, payload) => payload.contains_valtype_raise_probe()
    MatchChoice(_, choice, _, number_body, _, flag_body) =>
      choice.contains_valtype_raise_probe() ||
      number_body.contains_valtype_raise_probe() ||
      flag_body.contains_valtype_raise_probe()
    FunctionApply(_, _, argument, body) =>
      argument.contains_valtype_raise_probe() ||
      body.contains_valtype_raise_probe()
    ForLoop(_, initial, body) | WhileLoop(_, initial, body) =>
      initial.contains_valtype_raise_probe() ||
      body.contains_valtype_raise_probe()
    ValtypeEnumArrayProbe(value) => value.contains_valtype_raise_probe()
  }
}

///|
fn Expr::contains_valtype_enum_array_probe(self : Expr) -> Bool {
  match self {
    ValtypeEnumArrayProbe(_) => true
    IntLiteral(_) | BoolLiteral(_) | Variable(_, _) => false
    Add(left, right)
    | Subtract(left, right)
    | And(left, right)
    | Or(left, right)
    | LessThan(left, right)
    | EqualInt(left, right) =>
      left.contains_valtype_enum_array_probe() ||
      right.contains_valtype_enum_array_probe()
    Not(value) => value.contains_valtype_enum_array_probe()
    If(_, condition, yes, no) | MatchBool(_, condition, yes, no) =>
      condition.contains_valtype_enum_array_probe() ||
      yes.contains_valtype_enum_array_probe() ||
      no.contains_valtype_enum_array_probe()
    Let(_, _, value, body) =>
      value.contains_valtype_enum_array_probe() ||
      body.contains_valtype_enum_array_probe()
    ArraySelect(_, first, second, _) | ArrayGrowSelect(_, first, second, _) =>
      first.contains_valtype_enum_array_probe() ||
      second.contains_valtype_enum_array_probe()
    ArrayAliasUpdateSelect(_, first, second, replacement, _) =>
      first.contains_valtype_enum_array_probe() ||
      second.contains_valtype_enum_array_probe() ||
      replacement.contains_valtype_enum_array_probe()
    StructSelect(_, number, flag) =>
      number.contains_valtype_enum_array_probe() ||
      flag.contains_valtype_enum_array_probe()
    ChoiceValue(_, payload) => payload.contains_valtype_enum_array_probe()
    MatchChoice(_, choice, _, number_body, _, flag_body) =>
      choice.contains_valtype_enum_array_probe() ||
      number_body.contains_valtype_enum_array_probe() ||
      flag_body.contains_valtype_enum_array_probe()
    FunctionApply(_, _, argument, body) =>
      argument.contains_valtype_enum_array_probe() ||
      body.contains_valtype_enum_array_probe()
    ForLoop(_, initial, body) | WhileLoop(_, initial, body) =>
      initial.contains_valtype_enum_array_probe() ||
      body.contains_valtype_enum_array_probe()
    ValtypeRaiseProbe(value) => value.contains_valtype_enum_array_probe()
  }
}
