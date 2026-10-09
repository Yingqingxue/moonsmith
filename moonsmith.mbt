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
  LessThan(Expr, Expr)
  EqualInt(Expr, Expr)
  Not(Expr)
  If(ValueType, Expr, Expr, Expr)
  MatchBool(ValueType, Expr, Expr, Expr)
  Let(ValueType, String, Expr, Expr)
  ArraySelect(ValueType, Expr, Expr, Bool)
  StructSelect(ValueType, Expr, Expr)
  ChoiceValue(ValueType, Expr)
  MatchChoice(ValueType, Expr, String, Expr, String, Expr)
  FunctionApply(ValueType, String, Expr, Expr)
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
/// Generate an expression of exactly the requested type.
pub fn generate_expr(seed : Int, expected : ValueType, depth : Int) -> Expr {
  if depth <= 0 {
    match expected {
      IntType => int_leaf(seed)
      BoolType => bool_leaf(seed)
      ChoiceType => abort("cannot generate a Choice result expression")
    }
  } else {
    // Two steps break the parity correlation between result type and branch.
    let choice = advance_seed(advance_seed(seed)) % 10
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
            ArraySelect(
              IntType,
              generate_expr(child_seed(seed, 27), IntType, depth - 1),
              generate_expr(child_seed(seed, 28), IntType, depth - 1),
              advance_seed(child_seed(seed, 31)) % 2 == 0,
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
              ChoiceValue(
                payload_type,
                generate_expr(child_seed(seed, 42), payload_type, depth - 1),
              ),
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
          _ => {
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
        }
      BoolType =>
        match choice {
          0 =>
            And(
              generate_expr(child_seed(seed, 25), BoolType, depth - 1),
              generate_expr(child_seed(seed, 26), BoolType, depth - 1),
            )
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
            ArraySelect(
              BoolType,
              generate_expr(child_seed(seed, 29), BoolType, depth - 1),
              generate_expr(child_seed(seed, 30), BoolType, depth - 1),
              advance_seed(child_seed(seed, 32)) % 2 == 0,
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
              ChoiceValue(
                payload_type,
                generate_expr(child_seed(seed, 47), payload_type, depth - 1),
              ),
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
          _ => {
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
        }
      ChoiceType => abort("cannot generate Choice expressions directly")
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
    BoolLiteral(_) | And(_, _) | LessThan(_, _) | EqualInt(_, _) | Not(_) =>
      BoolType
    If(result_type, _, _, _) | MatchBool(result_type, _, _, _) => result_type
    Variable(value_type, _) => value_type
    Let(_, _, _, body) => body.value_type()
    ArraySelect(result_type, _, _, _) => result_type
    StructSelect(result_type, _, _) => result_type
    ChoiceValue(_, _) => ChoiceType
    MatchChoice(result_type, _, _, _, _, _) => result_type
    FunctionApply(result_type, _, _, _) => result_type
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
    | LessThan(left, right)
    | EqualInt(left, right) => left.contains_struct() || right.contains_struct()
    Not(value) => value.contains_struct()
    If(_, condition, yes, no) | MatchBool(_, condition, yes, no) =>
      condition.contains_struct() ||
      yes.contains_struct() ||
      no.contains_struct()
    Let(_, _, value, body) => value.contains_struct() || body.contains_struct()
    ArraySelect(_, first, second, _) =>
      first.contains_struct() || second.contains_struct()
    FunctionApply(_, _, argument, body) =>
      argument.contains_struct() || body.contains_struct()
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
    | LessThan(left, right)
    | EqualInt(left, right) => left.contains_choice() || right.contains_choice()
    Not(value) => value.contains_choice()
    If(_, condition, yes, no) | MatchBool(_, condition, yes, no) =>
      condition.contains_choice() ||
      yes.contains_choice() ||
      no.contains_choice()
    Let(_, _, value, body) => value.contains_choice() || body.contains_choice()
    ArraySelect(_, first, second, _) =>
      first.contains_choice() || second.contains_choice()
    StructSelect(_, number, flag) =>
      number.contains_choice() || flag.contains_choice()
    FunctionApply(_, _, argument, body) =>
      argument.contains_choice() || body.contains_choice()
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
      "(" + left.to_source() + " && " + right.to_source() + ")"
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
    FunctionApply(result_type, name, argument, body) => {
      let type_source = match result_type {
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
  "// Generated by MoonSmith; seed=" +
  self.seed.to_string() +
  "\n" +
  choice_declaration +
  pair_declaration +
  "fn main {\n  println(" +
  self.result.to_source() +
  ")\n}\n"
}
