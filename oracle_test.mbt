///|
fn result(
  target : String,
  status : @moonsmith.RunStatus,
  exit_code : Int,
  stdout : String,
  stderr : String,
) -> @moonsmith.RunResult {
  {
    target,
    status,
    exit_code,
    stdout,
    stderr,
    duration_ms: 1,
    diagnostic_root: "",
    diagnostic_case: "",
  }
}

///|
test "normalization preserves observable spaces and trailing newlines" {
  assert_eq(@moonsmith.normalize_stdout("  value \r\n\r\n"), "  value \n\n")
  assert_eq(
    @moonsmith.normalize_stderr("C:\\tmp\\case.mbt: error\r\n"),
    "C:/tmp/case.mbt: error",
  )
  assert_eq(
    @moonsmith.normalize_stderr(
      "D:\\work\\moon\\case.mbt: error\r\n",
      diagnostic_root="D:\\work\\moon",
    ),
    "<workspace>/case.mbt: error",
  )
  assert_eq(
    @moonsmith.normalize_stderr(
      "D:\\work\\moon\\case.mbt: error\r\n",
      diagnostic_root="D:\\work\\moon",
      diagnostic_case="D:\\work\\moon\\case.mbt",
    ),
    "<case>: error",
  )
}

///|
test "matching successful outputs are consistent" {
  let report = @moonsmith.analyze_results([
    result("js", Succeeded, 0, "9\n", ""),
    result("wasm", Succeeded, 0, "9\r\n", ""),
    result("wasm-gc", Succeeded, 0, "9\n", ""),
  ])
  assert_true(report.kind is Consistent)
  assert_true(report.signature.has_prefix("consistent|"))
}

///|
test "successful output differences are reported" {
  let report = @moonsmith.analyze_results([
    result("js", Succeeded, 0, "9", ""),
    result("wasm", Succeeded, 0, "10", ""),
  ])
  assert_true(report.kind is OutputMismatch)
  assert_true(report.signature.has_prefix("output-mismatch|"))
}

///|
test "compile failure is reported even when another backend succeeds" {
  let report = @moonsmith.analyze_results([
    result("js", Succeeded, 0, "9", ""),
    result("wasm", CompileFailed, 2, "", "compiler panic"),
  ])
  assert_true(report.kind is CompileFailure)
  assert_true(report.signature.contains("compile-failed"))
}

///|
test "runtime failure and timeout have distinct classifications" {
  let runtime = @moonsmith.analyze_results([
    result("js", RuntimeFailed, 1, "", "trap"),
  ])
  let timeout = @moonsmith.analyze_results([
    result("wasm", TimedOut, -1, "", "deadline exceeded"),
  ])
  assert_true(runtime.kind is RuntimeFailure)
  assert_true(timeout.kind is Timeout)
}

///|
test "mixed terminal failures are not hidden by precedence" {
  let report = @moonsmith.analyze_results([
    result("js", CompileFailed, 2, "", "compile error"),
    result("wasm", TimedOut, -1, "", "timeout"),
  ])
  assert_true(report.kind is MixedFailure)
}

///|
test "missing backend prerequisites are not compiler failures" {
  let report = @moonsmith.analyze_results([
    result("js", Succeeded, 0, "9", ""),
    result("native", Unavailable, -1, "", "no system C compiler"),
  ])
  assert_true(report.kind is EnvironmentFailure)
  assert_true(report.signature.contains("unavailable"))
}

///|
test "empty matrix is invalid evidence" {
  let report = @moonsmith.analyze_results([])
  assert_true(report.kind is NoResults)
  assert_eq(report.signature, "no-results")
}

///|
test "signature encoding distinguishes embedded delimiters" {
  let first = @moonsmith.analyze_results([
    result("js", Succeeded, 0, "a|b", ""),
    result("wasm", Succeeded, 0, "a|b", ""),
  ])
  let second = @moonsmith.analyze_results([
    result("js", Succeeded, 0, "a", "b"),
    result("wasm", Succeeded, 0, "a", "b"),
  ])
  assert_false(first.signature == second.signature)
}

///|
test "reduction key keeps output partition when literal values change" {
  let original = @moonsmith.analyze_results([
    result("js", Succeeded, 0, "9", ""),
    result("wasm", Succeeded, 0, "9", ""),
    result("wasm-gc", Succeeded, 0, "10", ""),
  ])
  let candidate = @moonsmith.analyze_results([
    result("js", Succeeded, 0, "0", ""),
    result("wasm", Succeeded, 0, "0", ""),
    result("wasm-gc", Succeeded, 0, "1", ""),
  ])
  let different = @moonsmith.analyze_results([
    result("js", Succeeded, 0, "0", ""),
    result("wasm", Succeeded, 0, "1", ""),
    result("wasm-gc", Succeeded, 0, "1", ""),
  ])
  assert_eq(original.reduction_key(), candidate.reduction_key())
  assert_true(original.reduction_key() != different.reduction_key())
}

///|
test "compile reduction key ignores successful output and source path" {
  let initial_failure = {
    ..result(
      "wasm",
      CompileFailed,
      2,
      "",
      "D:\\project\\original.mbt: Error: [1234] compiler panic",
    ),
    diagnostic_root: "D:\\project",
    diagnostic_case: "D:\\project\\original.mbt",
  }
  let reduced_failure = {
    ..result(
      "wasm",
      CompileFailed,
      2,
      "",
      "D:\\project\\candidate.mbt: Error: [1234] compiler panic",
    ),
    diagnostic_root: "D:\\project",
    diagnostic_case: "D:\\project\\candidate.mbt",
  }
  let initial = @moonsmith.analyze_results([
    result("js", Succeeded, 0, "9\n", ""),
    initial_failure,
  ])
  let reduced = @moonsmith.analyze_results([
    result("js", Succeeded, 0, "0\n", ""),
    reduced_failure,
  ])
  assert_true(initial.signature != reduced.signature)
  assert_eq(initial.reduction_key(), reduced.reduction_key())
}

///|
test "compile reduction key rejects a changed failure diagnostic" {
  let first = @moonsmith.analyze_results([
    result("wasm", CompileFailed, 2, "", "Error: [1234] compiler panic"),
  ])
  let second = @moonsmith.analyze_results([
    result("wasm", CompileFailed, 2, "", "Error: [5678] type error"),
  ])
  assert_true(first.reduction_key() != second.reduction_key())
}

///|
test "timeout reduction key retains the affected backend and phase" {
  let build = @moonsmith.analyze_results([
    result("js", Succeeded, 0, "9", ""),
    result("wasm", TimedOut, -1, "", "build timed out after 10 seconds"),
  ])
  let execute = @moonsmith.analyze_results([
    result("js", Succeeded, 0, "0", ""),
    result("wasm", TimedOut, -1, "", "execution timed out after 10 seconds"),
  ])
  assert_true(build.reduction_key() != execute.reduction_key())
}

///|
test "reference oracle detects a common wrong result" {
  let runs = [
    result("js", Succeeded, 0, "10\n", ""),
    result("wasm", Succeeded, 0, "10\r\n", ""),
    result("wasm-gc", Succeeded, 0, "10\n", ""),
  ]
  let with_reference = @moonsmith.analyze_results(runs, expected_output="9\n")
  let without_reference = @moonsmith.analyze_results(runs)
  assert_true(with_reference.kind is ReferenceMismatch)
  assert_true(without_reference.kind is Consistent)
  assert_true(with_reference.reduction_key().has_prefix("reference-mismatch|"))
}

///|
test "reference oracle accepts the expected output" {
  let report = @moonsmith.analyze_results(
    [result("js", Succeeded, 0, "9\r\n", "")],
    expected_output="9\n",
  )
  assert_true(report.kind is Consistent)
}

///|
test "output mismatch key tracks which backend matches reference" {
  let first = @moonsmith.analyze_results(
    [
      result("js", Succeeded, 0, "9\n", ""),
      result("wasm", Succeeded, 0, "10\n", ""),
    ],
    expected_output="9\n",
  )
  let swapped = @moonsmith.analyze_results(
    [
      result("js", Succeeded, 0, "10\n", ""),
      result("wasm", Succeeded, 0, "9\n", ""),
    ],
    expected_output="9\n",
  )
  assert_true(first.kind is OutputMismatch)
  assert_true(first.reduction_key() != swapped.reduction_key())
}

///|
test "reference mismatch reduction key tolerates value changes" {
  let first = @moonsmith.analyze_results(
    [
      result("js", Succeeded, 0, "10\n", ""),
      result("wasm", Succeeded, 0, "10\n", ""),
    ],
    expected_output="9\n",
  )
  let reduced = @moonsmith.analyze_results(
    [
      result("js", Succeeded, 0, "1\n", ""),
      result("wasm", Succeeded, 0, "1\n", ""),
    ],
    expected_output="0\n",
  )
  assert_true(first.kind is ReferenceMismatch)
  assert_eq(first.reduction_key(), reduced.reduction_key())
}
