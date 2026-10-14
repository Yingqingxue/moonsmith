///|
/// A small interpreter for the generator's typed expression language.
pub(all) enum EvaluatedValue {
  IntValue(Int)
  BoolValue(Bool)
  ChoiceNumberValue(Int)
  ChoiceFlagValue(Bool)
}

///|
fn EvaluatedValue::as_int(self : EvaluatedValue) -> Int {
  match self {
    IntValue(value) => value
    BoolValue(_) | ChoiceNumberValue(_) | ChoiceFlagValue(_) =>
      abort("reference evaluator expected Int")
  }
}

///|
fn EvaluatedValue::as_bool(self : EvaluatedValue) -> Bool {
  match self {
    BoolValue(value) => value
    IntValue(_) | ChoiceNumberValue(_) | ChoiceFlagValue(_) =>
      abort("reference evaluator expected Bool")
  }
}

///|
pub fn EvaluatedValue::to_output(self : EvaluatedValue) -> String {
  match self {
    IntValue(value) => value.to_string()
    BoolValue(value) => if value { "true" } else { "false" }
    ChoiceNumberValue(_) | ChoiceFlagValue(_) =>
      abort("reference output cannot be an unmatched Choice value")
  }
}

///|
/// Evaluation uses the IR directly; it does not parse or execute the printed
/// source. Conditional branches are evaluated lazily.
pub fn Expr::evaluate(self : Expr) -> EvaluatedValue {
  self.evaluate_in_env([], [])
}

///|
/// Evaluate once and record the constructs and branch decisions actually
/// visited by the reference interpreter. This is reference-path evidence,
/// not instrumentation of a compiled backend.
pub fn Expr::evaluate_with_trace(
  self : Expr,
) -> (EvaluatedValue, Array[String]) {
  let trace : Array[String] = []
  let value = self.evaluate_in_env([], trace)
  (value, trace)
}

///|
fn Expr::evaluate_in_env(
  self : Expr,
  bindings : Array[(String, EvaluatedValue)],
  trace : Array[String],
) -> EvaluatedValue {
  match self {
    IntLiteral(value) => {
      trace.push("int-literal")
      IntValue(value)
    }
    BoolLiteral(value) => {
      trace.push("bool-literal")
      BoolValue(value)
    }
    Variable(_, name) => {
      trace.push("variable")
      for index = bindings.length() - 1; index >= 0; index = index - 1 {
        if bindings[index].0 == name {
          return bindings[index].1
        }
      }
      abort("reference evaluator found an unbound variable")
    }
    Let(_, name, value, body) => {
      trace.push("let")
      let scoped = bindings.copy()
      scoped.push((name, value.evaluate_in_env(bindings, trace)))
      body.evaluate_in_env(scoped, trace)
    }
    ArraySelect(_, first, second, select_second) => {
      trace.push("array-select")
      let first_value = first.evaluate_in_env(bindings, trace)
      let second_value = second.evaluate_in_env(bindings, trace)
      if select_second {
        trace.push("array-index-1")
        second_value
      } else {
        trace.push("array-index-0")
        first_value
      }
    }
    ArrayGrowSelect(_, first, second, select_second) => {
      trace.push("array-grow")
      let values : Array[EvaluatedValue] = []
      values.push(first.evaluate_in_env(bindings, trace))
      trace.push("array-grow-push")
      values.push(second.evaluate_in_env(bindings, trace))
      trace.push("array-grow-push")
      if select_second {
        trace.push("array-grow-index-1")
        values[1]
      } else {
        trace.push("array-grow-index-0")
        values[0]
      }
    }
    ArrayAliasUpdateSelect(_, first, second, replacement, select_second) => {
      trace.push("array-alias-update")
      let first_value = first.evaluate_in_env(bindings, trace)
      let second_value = second.evaluate_in_env(bindings, trace)
      let original = if select_second { second_value } else { first_value }
      let candidate = replacement.evaluate_in_env(bindings, trace)
      // A no-op write cannot reveal a broken alias. Keep the generated write
      // observably distinct while still evaluating the candidate expression.
      let updated = match (original, candidate) {
        (IntValue(before), IntValue(value)) =>
          if value == before {
            trace.push("array-alias-update-collision")
            IntValue(if before == 0 { 1 } else { 0 })
          } else {
            IntValue(value)
          }
        (BoolValue(before), BoolValue(value)) =>
          if value == before {
            trace.push("array-alias-update-collision")
            BoolValue(!before)
          } else {
            BoolValue(value)
          }
        _ => abort("array alias update requires matching primitive values")
      }
      trace.push(
        if select_second {
          "array-alias-update-index-1"
        } else {
          "array-alias-update-index-0"
        },
      )
      updated
    }
    StructSelect(result_type, number, flag) => {
      trace.push("struct-value")
      let number_value = number.evaluate_in_env(bindings, trace)
      let flag_value = flag.evaluate_in_env(bindings, trace)
      trace.push("struct-field-number")
      trace.push("struct-field-flag")
      match result_type {
        IntType => {
          trace.push("struct-result-number")
          number_value
        }
        BoolType => {
          trace.push("struct-result-flag")
          flag_value
        }
        ChoiceType => abort("Choice cannot be a struct result type")
      }
    }
    ChoiceValue(payload_type, payload) => {
      trace.push("choice-value")
      match payload_type {
        IntType =>
          ChoiceNumberValue(payload.evaluate_in_env(bindings, trace).as_int())
        BoolType =>
          ChoiceFlagValue(payload.evaluate_in_env(bindings, trace).as_bool())
        ChoiceType => abort("nested Choice payload is not supported")
      }
    }
    MatchChoice(_, choice, number_name, number_body, flag_name, flag_body) =>
      match choice.evaluate_in_env(bindings, trace) {
        ChoiceNumberValue(value) => {
          trace.push("choice-number")
          let scoped = bindings.copy()
          scoped.push((number_name, IntValue(value)))
          number_body.evaluate_in_env(scoped, trace)
        }
        ChoiceFlagValue(value) => {
          trace.push("choice-flag")
          let scoped = bindings.copy()
          scoped.push((flag_name, BoolValue(value)))
          flag_body.evaluate_in_env(scoped, trace)
        }
        IntValue(_) | BoolValue(_) =>
          abort("reference evaluator expected a Choice scrutinee")
      }
    FunctionApply(_, name, argument, body) => {
      trace.push("function-call")
      let scoped = bindings.copy()
      scoped.push((name, argument.evaluate_in_env(bindings, trace)))
      body.evaluate_in_env(scoped, trace)
    }
    ForLoop(iterations, initial, body) => {
      trace.push("for-loop")
      let mut accumulator = initial.evaluate_in_env(bindings, trace).as_int()
      for index = 0; index < iterations; index = index + 1 {
        trace.push("for-iteration")
        let scoped = bindings.copy()
        scoped.push(("_ms_index", IntValue(index)))
        scoped.push(("_ms_acc", IntValue(accumulator)))
        accumulator = body.evaluate_in_env(scoped, trace).as_int()
      }
      trace.push("for-normal-exit")
      IntValue(accumulator)
    }
    WhileLoop(iterations, initial, body) => {
      trace.push("while-loop")
      let mut accumulator = initial.evaluate_in_env(bindings, trace).as_int()
      let mut index = 0
      while index < iterations {
        trace.push("while-iteration")
        let scoped = bindings.copy()
        scoped.push(("_ms_index", IntValue(index)))
        scoped.push(("_ms_acc", IntValue(accumulator)))
        accumulator = body.evaluate_in_env(scoped, trace).as_int()
        index = index + 1
      }
      trace.push("while-normal-exit")
      IntValue(accumulator)
    }
    ValtypeRaiseProbe(value) => {
      let input = value.evaluate_in_env(bindings, trace).as_int()
      trace.push("valtype-raise-probe")
      if input < 0 {
        trace.push("valtype-raise-error-path")
      } else {
        trace.push("valtype-raise-success-path")
      }
      BoolValue(true)
    }
    ValtypeEnumArrayProbe(value) => {
      trace.push("valtype-enum-array-probe")
      let input = value.evaluate_in_env(bindings, trace).as_int()
      trace.push("valtype-enum-array-empty-init")
      trace.push("valtype-enum-array-push")
      trace.push("valtype-enum-array-growth-push")
      trace.push("valtype-enum-array-index")
      trace.push("valtype-enum-array-index-after-growth")
      IntValue(input + 1)
    }
    FmaContractionProbe => {
      trace.push("fma-contraction-probe")
      // The JS-target reference evaluator enforces separate binary64
      // rounding between these operations, independent of the tested native
      // compiler's contraction flags.
      let a = 1.000000007450580596923828125
      let b = 0.999999992549419403076171875
      let c = -1.0
      let product = a * b
      BoolValue(product + c == 0.0)
    }
    Add(left, right) => {
      trace.push("add")
      IntValue(
        left.evaluate_in_env(bindings, trace).as_int() +
        right.evaluate_in_env(bindings, trace).as_int(),
      )
    }
    Subtract(left, right) => {
      trace.push("subtract")
      IntValue(
        left.evaluate_in_env(bindings, trace).as_int() -
        right.evaluate_in_env(bindings, trace).as_int(),
      )
    }
    And(left, right) => {
      trace.push("and")
      if left.evaluate_in_env(bindings, trace).as_bool() {
        trace.push("and-rhs-executed")
        BoolValue(right.evaluate_in_env(bindings, trace).as_bool())
      } else {
        trace.push("and-rhs-skipped")
        BoolValue(false)
      }
    }
    Or(left, right) => {
      trace.push("or")
      if left.evaluate_in_env(bindings, trace).as_bool() {
        trace.push("or-rhs-skipped")
        BoolValue(true)
      } else {
        trace.push("or-rhs-executed")
        BoolValue(right.evaluate_in_env(bindings, trace).as_bool())
      }
    }
    LessThan(left, right) => {
      trace.push("less-than")
      BoolValue(
        left.evaluate_in_env(bindings, trace).as_int() <
        right.evaluate_in_env(bindings, trace).as_int(),
      )
    }
    EqualInt(left, right) => {
      trace.push("equal-int")
      BoolValue(
        left.evaluate_in_env(bindings, trace).as_int() ==
        right.evaluate_in_env(bindings, trace).as_int(),
      )
    }
    Not(value) => {
      trace.push("not")
      BoolValue(!value.evaluate_in_env(bindings, trace).as_bool())
    }
    If(_, condition, then_expr, else_expr) => {
      trace.push("if")
      if condition.evaluate_in_env(bindings, trace).as_bool() {
        trace.push("if-then")
        then_expr.evaluate_in_env(bindings, trace)
      } else {
        trace.push("if-else")
        else_expr.evaluate_in_env(bindings, trace)
      }
    }
    MatchBool(_, condition, true_expr, false_expr) => {
      trace.push("match-bool")
      if condition.evaluate_in_env(bindings, trace).as_bool() {
        trace.push("match-true")
        true_expr.evaluate_in_env(bindings, trace)
      } else {
        trace.push("match-false")
        false_expr.evaluate_in_env(bindings, trace)
      }
    }
  }
}

///|
pub fn Program::expected_output(self : Program) -> String {
  self.result.evaluate().to_output() + "\n"
}
