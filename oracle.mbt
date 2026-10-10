///|
/// The terminal state observed for one compiler backend.
pub(all) enum RunStatus {
  Succeeded
  CompileFailed
  RuntimeFailed
  TimedOut
  Unavailable
}

///|
/// Raw evidence collected from one backend execution.
pub(all) struct RunResult {
  target : String
  status : RunStatus
  exit_code : Int
  stdout : String
  stderr : String
  duration_ms : Int
  diagnostic_root : String
  diagnostic_case : String
}

///|
/// Differential classification for a complete backend matrix.
pub(all) enum FindingKind {
  Consistent
  CompileFailure
  RuntimeFailure
  Timeout
  OutputMismatch
  ReferenceMismatch
  MixedFailure
  EnvironmentFailure
  NoResults
}

///|
/// A stable, machine-comparable finding plus normalized backend evidence.
pub(all) struct DifferentialReport {
  kind : FindingKind
  signature : String
  results : Array[RunResult]
  expected_output : String
}

///|
/// Reduction preserves the backend failure pattern and failing diagnostics.
/// Successful output values may change when a program is made smaller.
pub fn DifferentialReport::reduction_key(self : DifferentialReport) -> String {
  let no_reduction = match self.kind {
    Consistent | EnvironmentFailure | NoResults => true
    _ => false
  }
  if no_reduction {
    return self.signature
  }
  let buffer = StringBuilder()
  buffer.write_string(self.kind.label())
  for index = 0; index < self.results.length(); index = index + 1 {
    let result = self.results[index]
    buffer.write_char('|')
    buffer.write_string(signature_field(result.target))
    buffer.write_char('=')
    buffer.write_string(result.status.label())
    let failed = match result.status {
      CompileFailed | RuntimeFailed | TimedOut => true
      _ => false
    }
    let output_failure = match self.kind {
      OutputMismatch | ReferenceMismatch => true
      _ => false
    }
    if output_failure {
      let output = normalize_stdout(result.stdout)
      let mut group = index
      for previous = 0; previous < index; previous = previous + 1 {
        if normalize_stdout(self.results[previous].stdout) == output {
          group = previous
          break
        }
      }
      buffer.write_char(':')
      buffer.write_string(group.to_string())
      if self.expected_output != "" {
        buffer.write_string(":expected=")
        buffer.write_string(
          if output == normalize_stdout(self.expected_output) {
            "yes"
          } else {
            "no"
          },
        )
      }
    } else if failed {
      buffer.write_string(":exit=")
      buffer.write_string(result.exit_code.to_string())
      buffer.write_string(":diagnostic=")
      buffer.write_string(
        signature_field(
          normalize_stderr(
            result.stderr,
            diagnostic_root=result.diagnostic_root,
            diagnostic_case=result.diagnostic_case,
          ),
        ),
      )
    }
  }
  buffer.to_string()
}

///|
/// Normalize line-ending encoding only. Spaces and trailing newlines remain
/// observable program output and must not disappear from differential checks.
pub fn normalize_stdout(output : String) -> String {
  output.replace_all(old="\r\n", new="\n").replace_all(old="\r", new="\n")
}

///|
/// Normalize an absolute source path and the Moon compiler's per-source build
/// directory so a generated case and its relocated reduction compare alike.
fn normalize_case_paths(output : String, case_path : String) -> String {
  if case_path == "" {
    return output
  }
  let mut file_name = case_path
  while file_name.contains("/") {
    file_name = file_name.split_once("/").unwrap().1.to_owned()
  }
  if file_name == case_path {
    return output.replace_all(old=case_path, new="<case>")
  }
  let case_directory = case_path.replace_all(old="/" + file_name, new="")
  let case_build = case_directory + "/_build/" + file_name
  output
  .replace_all(old=case_build, new="<case-build>")
  .replace_all(old=case_path, new="<case>")
  .replace_all(old=case_directory, new="<case-dir>")
}

///|
/// Diagnostic normalization unifies path separators and masks the source path
/// and workspace root supplied by the runner, including its compiler build
/// directory when the case is moved into the reducer's temporary directory.
pub fn normalize_stderr(
  output : String,
  diagnostic_root? : String = "",
  diagnostic_case? : String = "",
) -> String {
  let normalized = output
    .replace_all(old="\r\n", new="\n")
    .replace_all(old="\r", new="\n")
    .replace_all(old="\\", new="/")
    .trim_end(chars=" \t\n")
    .to_owned()
  let root = diagnostic_root
    .replace_all(old="\\", new="/")
    .trim_end(chars="/")
    .to_owned()
  let source = diagnostic_case.replace_all(old="\\", new="/")
  let without_source = normalize_case_paths(normalized, source)
  if root == "" {
    without_source
  } else {
    without_source.replace_all(old=root, new="<workspace>")
  }
}

///|
pub fn RunStatus::label(self : RunStatus) -> String {
  match self {
    Succeeded => "succeeded"
    CompileFailed => "compile-failed"
    RuntimeFailed => "runtime-failed"
    TimedOut => "timed-out"
    Unavailable => "unavailable"
  }
}

///|
pub fn FindingKind::label(self : FindingKind) -> String {
  match self {
    Consistent => "consistent"
    CompileFailure => "compile-failure"
    RuntimeFailure => "runtime-failure"
    Timeout => "timeout"
    OutputMismatch => "output-mismatch"
    ReferenceMismatch => "reference-mismatch"
    MixedFailure => "mixed-failure"
    EnvironmentFailure => "environment-failure"
    NoResults => "no-results"
  }
}

///|
/// Length-prefix fields so embedded separators cannot cause signature
/// collisions. The signature is intentionally readable before a compact hash
/// is introduced.
fn signature_field(value : String) -> String {
  value.length().to_string() + ":" + value
}

///|
fn RunResult::signature_fragment(self : RunResult) -> String {
  let normalized_stdout = normalize_stdout(self.stdout)
  let normalized_stderr = normalize_stderr(
    self.stderr,
    diagnostic_root=self.diagnostic_root,
    diagnostic_case=self.diagnostic_case,
  )
  signature_field(self.target) +
  "=" +
  self.status.label() +
  ",exit=" +
  self.exit_code.to_string() +
  ",out=" +
  signature_field(normalized_stdout) +
  ",err=" +
  signature_field(normalized_stderr)
}

///|
fn build_signature(
  kind : FindingKind,
  results : Array[RunResult],
  expected_output : String,
) -> String {
  let buffer = StringBuilder()
  buffer.write_string(kind.label())
  for result in results {
    buffer.write_char('|')
    buffer.write_string(result.signature_fragment())
  }
  if expected_output != "" {
    buffer.write_string("|reference=")
    buffer.write_string(signature_field(normalize_stdout(expected_output)))
  }
  buffer.to_string()
}

///|
pub fn json_escape(value : String) -> String {
  value
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="\"", new="\\\"")
  .replace_all(old="\r", new="\\r")
  .replace_all(old="\n", new="\\n")
  .replace_all(old="\t", new="\\t")
}

///|
/// Compact machine-readable output used by the bootstrap host adapter.
pub fn DifferentialReport::summary_json(self : DifferentialReport) -> String {
  "{\"kind\":\"" +
  self.kind.label() +
  "\",\"signature\":\"" +
  json_escape(self.signature) +
  "\",\"reductionKey\":\"" +
  json_escape(self.reduction_key()) +
  "\",\"referenceChecked\":" +
  (if self.expected_output == "" { "false" } else { "true" }) +
  ",\"expectedOutput\":\"" +
  json_escape(self.expected_output) +
  "\"}"
}

///|
/// Classify a backend matrix. Mixed terminal failures are reported explicitly
/// rather than hidden behind arbitrary precedence.
pub fn analyze_results(
  results : Array[RunResult],
  expected_output? : String = "",
) -> DifferentialReport {
  if results.length() == 0 {
    let kind = NoResults
    return { kind, signature: kind.label(), results, expected_output, }
  }

  let mut compile_failures = 0
  let mut runtime_failures = 0
  let mut timeouts = 0
  let mut unavailable = 0
  let mut successes = 0
  for result in results {
    match result.status {
      Succeeded => successes = successes + 1
      CompileFailed => compile_failures = compile_failures + 1
      RuntimeFailed => runtime_failures = runtime_failures + 1
      TimedOut => timeouts = timeouts + 1
      Unavailable => unavailable = unavailable + 1
    }
  }

  let failure_kinds = (if compile_failures > 0 { 1 } else { 0 }) +
    (if runtime_failures > 0 { 1 } else { 0 }) +
    (if timeouts > 0 { 1 } else { 0 }) +
    (if unavailable > 0 { 1 } else { 0 })

  let kind = if failure_kinds > 1 {
    MixedFailure
  } else if compile_failures > 0 {
    CompileFailure
  } else if runtime_failures > 0 {
    RuntimeFailure
  } else if timeouts > 0 {
    Timeout
  } else if unavailable > 0 {
    EnvironmentFailure
  } else if successes == results.length() {
    let expected = normalize_stdout(results[0].stdout)
    let mut mismatch = false
    for index = 1; index < results.length(); index = index + 1 {
      if normalize_stdout(results[index].stdout) != expected {
        mismatch = true
      }
    }
    if mismatch {
      OutputMismatch
    } else if expected_output != "" &&
      expected != normalize_stdout(expected_output) {
      ReferenceMismatch
    } else {
      Consistent
    }
  } else {
    // Defensive fallback for future RunStatus variants.
    MixedFailure
  }

  {
    kind,
    signature: build_signature(kind, results, expected_output),
    results,
    expected_output,
  }
}
