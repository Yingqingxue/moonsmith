///|
fn int_magnitude(value : Int) -> Int {
  if value < 0 {
    -value
  } else {
    value
  }
}

///|
/// A deterministic ordering metric for reduction. Structural nodes dominate
/// literal magnitude so deleting syntax is preferred over merely changing a
/// number.
pub fn Expr::complexity(self : Expr) -> Int {
  match self {
    IntLiteral(value) => 1 + int_magnitude(value)
    BoolLiteral(value) => if value { 2 } else { 1 }
    Variable(_, _) => 1
    Let(_, _, value, body) => 1000 + value.complexity() + body.complexity()
    ArraySelect(_, first, second, _) =>
      1000 + first.complexity() + second.complexity()
    StructSelect(_, number, flag) =>
      1000 + number.complexity() + flag.complexity()
    ChoiceValue(_, payload) => 1000 + payload.complexity()
    MatchChoice(_, choice, _, number_body, _, flag_body) =>
      1000 +
      choice.complexity() +
      number_body.complexity() +
      flag_body.complexity()
    FunctionApply(_, _, argument, body) =>
      1000 + argument.complexity() + body.complexity()
    Add(left, right)
    | Subtract(left, right)
    | And(left, right)
    | LessThan(left, right)
    | EqualInt(left, right) => 1000 + left.complexity() + right.complexity()
    Not(value) => 1000 + value.complexity()
    If(_, condition, then_expr, else_expr)
    | MatchBool(_, condition, then_expr, else_expr) =>
      1000 +
      condition.complexity() +
      then_expr.complexity() +
      else_expr.complexity()
  }
}

///|
/// A binding in a nested body shadows the searched name; its initializer is
/// still evaluated in the enclosing scope.
fn Expr::uses_variable(self : Expr, name : String) -> Bool {
  match self {
    IntLiteral(_) | BoolLiteral(_) => false
    Variable(_, variable_name) => variable_name == name
    Add(left, right)
    | Subtract(left, right)
    | And(left, right)
    | LessThan(left, right)
    | EqualInt(left, right) =>
      left.uses_variable(name) || right.uses_variable(name)
    Not(value) => value.uses_variable(name)
    If(_, condition, yes, no) | MatchBool(_, condition, yes, no) =>
      condition.uses_variable(name) ||
      yes.uses_variable(name) ||
      no.uses_variable(name)
    Let(_, bound_name, value, body) =>
      value.uses_variable(name) ||
      (bound_name != name && body.uses_variable(name))
    ArraySelect(_, first, second, _) =>
      first.uses_variable(name) || second.uses_variable(name)
    StructSelect(_, number, flag) =>
      number.uses_variable(name) || flag.uses_variable(name)
    ChoiceValue(_, payload) => payload.uses_variable(name)
    MatchChoice(_, choice, number_name, number_body, flag_name, flag_body) =>
      choice.uses_variable(name) ||
      (number_name != name && number_body.uses_variable(name)) ||
      (flag_name != name && flag_body.uses_variable(name))
    FunctionApply(_, parameter_name, argument, body) =>
      argument.uses_variable(name) ||
      (parameter_name != name && body.uses_variable(name))
  }
}

///|
fn push_unique(candidates : Array[Expr], candidate : Expr) -> Unit {
  let source = candidate.to_source()
  for existing in candidates {
    if existing.to_source() == source {
      return
    }
  }
  candidates.push(candidate)
}

///|
fn push_if_smaller(
  candidates : Array[Expr],
  original_complexity : Int,
  candidate : Expr,
) -> Unit {
  if candidate.complexity() < original_complexity {
    push_unique(candidates, candidate)
  }
}

///|
/// Produce deterministic, type-preserving candidates. This function does not
/// decide whether a candidate keeps a compiler failure; the host reducer must
/// replay the original failure signature before accepting one.
pub fn Expr::shrink_candidates(self : Expr) -> Array[Expr] {
  let candidates : Array[Expr] = []
  let original_complexity = self.complexity()
  match self {
    IntLiteral(value) =>
      if value != 0 {
        push_if_smaller(candidates, original_complexity, IntLiteral(0))
        push_if_smaller(candidates, original_complexity, IntLiteral(value / 2))
      }
    BoolLiteral(value) =>
      if value {
        push_if_smaller(candidates, original_complexity, BoolLiteral(false))
      }
    Variable(_, _) => ()
    ArraySelect(result_type, first, second, select_second) => {
      push_if_smaller(candidates, original_complexity, first)
      push_if_smaller(candidates, original_complexity, second)
      for smaller in first.shrink_candidates() {
        push_if_smaller(
          candidates,
          original_complexity,
          ArraySelect(result_type, smaller, second, select_second),
        )
      }
      for smaller in second.shrink_candidates() {
        push_if_smaller(
          candidates,
          original_complexity,
          ArraySelect(result_type, first, smaller, select_second),
        )
      }
    }
    StructSelect(result_type, number, flag) => {
      let selected = match result_type {
        IntType => number
        BoolType => flag
        ChoiceType => abort("Choice cannot be a struct result type")
      }
      push_if_smaller(candidates, original_complexity, selected)
      for smaller in number.shrink_candidates() {
        push_if_smaller(
          candidates,
          original_complexity,
          StructSelect(result_type, smaller, flag),
        )
      }
      for smaller in flag.shrink_candidates() {
        push_if_smaller(
          candidates,
          original_complexity,
          StructSelect(result_type, number, smaller),
        )
      }
    }
    ChoiceValue(payload_type, payload) =>
      for smaller in payload.shrink_candidates() {
        push_if_smaller(
          candidates,
          original_complexity,
          ChoiceValue(payload_type, smaller),
        )
      }
    MatchChoice(
      result_type,
      choice,
      number_name,
      number_body,
      flag_name,
      flag_body
    ) => {
      if !number_body.uses_variable(number_name) {
        push_if_smaller(candidates, original_complexity, number_body)
      }
      if !flag_body.uses_variable(flag_name) {
        push_if_smaller(candidates, original_complexity, flag_body)
      }
      for smaller in choice.shrink_candidates() {
        push_if_smaller(
          candidates,
          original_complexity,
          MatchChoice(
            result_type, smaller, number_name, number_body, flag_name, flag_body,
          ),
        )
      }
      for smaller in number_body.shrink_candidates() {
        push_if_smaller(
          candidates,
          original_complexity,
          MatchChoice(
            result_type, choice, number_name, smaller, flag_name, flag_body,
          ),
        )
      }
      for smaller in flag_body.shrink_candidates() {
        push_if_smaller(
          candidates,
          original_complexity,
          MatchChoice(
            result_type, choice, number_name, number_body, flag_name, smaller,
          ),
        )
      }
    }
    FunctionApply(result_type, name, argument, body) => {
      push_if_smaller(candidates, original_complexity, argument)
      if !body.uses_variable(name) {
        push_if_smaller(candidates, original_complexity, body)
      }
      match body {
        Variable(variable_type, variable_name) =>
          if variable_name == name {
            match (variable_type, result_type) {
              (IntType, IntType) | (BoolType, BoolType) =>
                push_if_smaller(candidates, original_complexity, argument)
              _ => ()
            }
          }
        _ => ()
      }
      for smaller in argument.shrink_candidates() {
        push_if_smaller(
          candidates,
          original_complexity,
          FunctionApply(result_type, name, smaller, body),
        )
      }
      for smaller in body.shrink_candidates() {
        push_if_smaller(
          candidates,
          original_complexity,
          FunctionApply(result_type, name, argument, smaller),
        )
      }
    }
    Let(binding_type, name, value, body) => {
      if !body.uses_variable(name) {
        push_if_smaller(candidates, original_complexity, body)
      }
      match body {
        Variable(variable_type, variable_name) =>
          if variable_name == name {
            match (variable_type, binding_type) {
              (IntType, IntType) | (BoolType, BoolType) =>
                push_if_smaller(candidates, original_complexity, value)
              _ => ()
            }
          }
        _ => ()
      }
      for smaller in value.shrink_candidates() {
        push_if_smaller(
          candidates,
          original_complexity,
          Let(binding_type, name, smaller, body),
        )
      }
      for smaller in body.shrink_candidates() {
        push_if_smaller(
          candidates,
          original_complexity,
          Let(binding_type, name, value, smaller),
        )
      }
    }
    Add(left, right) => {
      push_if_smaller(candidates, original_complexity, left)
      push_if_smaller(candidates, original_complexity, right)
      for smaller in left.shrink_candidates() {
        push_if_smaller(candidates, original_complexity, Add(smaller, right))
      }
      for smaller in right.shrink_candidates() {
        push_if_smaller(candidates, original_complexity, Add(left, smaller))
      }
    }
    Subtract(left, right) => {
      push_if_smaller(candidates, original_complexity, left)
      push_if_smaller(candidates, original_complexity, right)
      for smaller in left.shrink_candidates() {
        push_if_smaller(
          candidates,
          original_complexity,
          Subtract(smaller, right),
        )
      }
      for smaller in right.shrink_candidates() {
        push_if_smaller(
          candidates,
          original_complexity,
          Subtract(left, smaller),
        )
      }
    }
    And(left, right) => {
      push_if_smaller(candidates, original_complexity, left)
      push_if_smaller(candidates, original_complexity, right)
      push_if_smaller(candidates, original_complexity, BoolLiteral(false))
      for smaller in left.shrink_candidates() {
        push_if_smaller(candidates, original_complexity, And(smaller, right))
      }
      for smaller in right.shrink_candidates() {
        push_if_smaller(candidates, original_complexity, And(left, smaller))
      }
    }
    LessThan(left, right) => {
      push_if_smaller(candidates, original_complexity, BoolLiteral(false))
      push_if_smaller(candidates, original_complexity, BoolLiteral(true))
      for smaller in left.shrink_candidates() {
        push_if_smaller(
          candidates,
          original_complexity,
          LessThan(smaller, right),
        )
      }
      for smaller in right.shrink_candidates() {
        push_if_smaller(
          candidates,
          original_complexity,
          LessThan(left, smaller),
        )
      }
    }
    EqualInt(left, right) => {
      push_if_smaller(candidates, original_complexity, BoolLiteral(false))
      push_if_smaller(candidates, original_complexity, BoolLiteral(true))
      for smaller in left.shrink_candidates() {
        push_if_smaller(
          candidates,
          original_complexity,
          EqualInt(smaller, right),
        )
      }
      for smaller in right.shrink_candidates() {
        push_if_smaller(
          candidates,
          original_complexity,
          EqualInt(left, smaller),
        )
      }
    }
    Not(value) => {
      push_if_smaller(candidates, original_complexity, value)
      push_if_smaller(candidates, original_complexity, BoolLiteral(false))
      for smaller in value.shrink_candidates() {
        push_if_smaller(candidates, original_complexity, Not(smaller))
      }
    }
    If(result_type, condition, then_expr, else_expr) => {
      push_if_smaller(candidates, original_complexity, then_expr)
      push_if_smaller(candidates, original_complexity, else_expr)
      for smaller in condition.shrink_candidates() {
        push_if_smaller(
          candidates,
          original_complexity,
          If(result_type, smaller, then_expr, else_expr),
        )
      }
      for smaller in then_expr.shrink_candidates() {
        push_if_smaller(
          candidates,
          original_complexity,
          If(result_type, condition, smaller, else_expr),
        )
      }
      for smaller in else_expr.shrink_candidates() {
        push_if_smaller(
          candidates,
          original_complexity,
          If(result_type, condition, then_expr, smaller),
        )
      }
    }
    MatchBool(result_type, condition, true_expr, false_expr) => {
      push_if_smaller(candidates, original_complexity, true_expr)
      push_if_smaller(candidates, original_complexity, false_expr)
      for smaller in condition.shrink_candidates() {
        push_if_smaller(
          candidates,
          original_complexity,
          MatchBool(result_type, smaller, true_expr, false_expr),
        )
      }
      for smaller in true_expr.shrink_candidates() {
        push_if_smaller(
          candidates,
          original_complexity,
          MatchBool(result_type, condition, smaller, false_expr),
        )
      }
      for smaller in false_expr.shrink_candidates() {
        push_if_smaller(
          candidates,
          original_complexity,
          MatchBool(result_type, condition, true_expr, smaller),
        )
      }
    }
  }
  candidates
}

///|
pub fn Program::shrink_candidates(self : Program) -> Array[Program] {
  let candidates : Array[Program] = []
  for result in self.result.shrink_candidates() {
    candidates.push({ seed: self.seed, result_type: self.result_type, result, })
  }
  candidates
}

///|
/// The host runner uses this manifest to replay each candidate. The AST and
/// candidate ordering remain entirely in MoonBit.
pub fn Program::candidates_json(self : Program) -> String {
  let candidates = self.shrink_candidates()
  let buffer = StringBuilder()
  buffer.write_string("{\"complexity\":")
  buffer.write_string(self.result.complexity().to_string())
  buffer.write_string(",\"expectedOutput\":\"")
  buffer.write_string(json_escape(self.expected_output()))
  buffer.write_char('"')
  buffer.write_string(",\"source\":\"")
  buffer.write_string(json_escape(self.to_source()))
  buffer.write_string("\",\"candidates\":[")
  for index = 0; index < candidates.length(); index = index + 1 {
    if index > 0 {
      buffer.write_char(',')
    }
    buffer.write_string("{\"index\":")
    buffer.write_string(index.to_string())
    buffer.write_string(",\"complexity\":")
    buffer.write_string(candidates[index].result.complexity().to_string())
    buffer.write_string(",\"expectedOutput\":\"")
    buffer.write_string(json_escape(candidates[index].expected_output()))
    buffer.write_char('"')
    buffer.write_string(",\"source\":\"")
    buffer.write_string(json_escape(candidates[index].to_source()))
    buffer.write_string("\"}")
  }
  buffer.write_string("]}")
  buffer.to_string()
}
