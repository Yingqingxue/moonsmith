///|
priv struct Candidate {
  seed : Int
  path_ids : Array[Int]
  size_quartile : Int
}

///|
#cfg(target="js")
fn cli_args() -> ArrayView[String] {
  match @env.args() {
    [_, _, .. rest] => rest
    _ => []
  }
}

///|
#cfg(not(target="js"))
fn cli_args() -> ArrayView[String] {
  match @env.args() {
    [_, .. rest] => rest
    [] => []
  }
}

///|
#cfg(target="js")
extern "js" fn invoke_live_verifier(
  script : String,
  seed : Int,
  depth : Int,
  targets : String,
  timeout_seconds : Int,
) -> String =
  #| (script, seed, depth, targets, timeoutSeconds) => {
  #|   const { spawnSync } = require("node:child_process");
  #|   const targetNames = targets.split(",").filter((name) => name.length > 0);
  #|   const quote = (value) => "'" + String(value).replace(/'/g, "''") + "'";
  #|   const targetArray = "@(" + targetNames.map(quote).join(",") + ")";
  #|   const command = "& " + quote(script) + " -Seed " + String(seed) +
  #|     " -Depth " + String(depth) + " -Targets " + targetArray +
  #|     " -TimeoutSeconds " + String(timeoutSeconds) + " -NoPersist";
  #|   const args = ["-NoLogo", "-NoProfile", "-Command", command];
  #|   const outerTimeout = Math.max(120000, (targetNames.length * 2 * timeoutSeconds + 60) * 1000);
  #|   const started = Date.now();
  #|   const result = spawnSync("pwsh", args, {
  #|     encoding: "utf8", timeout: outerTimeout, windowsHide: true,
  #|     maxBuffer: 4 * 1024 * 1024,
  #|   });
  #|   const elapsed = Date.now() - started;
  #|   if (result.error) return "ERROR\t" + result.error.message;
  #|   if (result.status !== 0 && result.status !== 1) {
  #|     const detail = (result.stderr || "").trim().replace(/[\r\n\t]+/g, " ");
  #|     return "ERROR\tverifier exit " + result.status + "\t" + detail;
  #|   }
  #|   let report;
  #|   try { report = JSON.parse((result.stdout || "").trim()); }
  #|   catch (error) { return "ERROR\tinvalid verifier JSON\t" + String(error); }
  #|   const sizeOnly = report.finding === "generator-limit" &&
  #|     !report.referenceChecked && Number.isInteger(report.sourceLineCount) &&
  #|     Array.isArray(report.runs) && report.runs.length === 0;
  #|   if (report.seed !== seed || !Number.isInteger(report.sourceLineCount) ||
  #|       (!sizeOnly && (!report.referenceChecked || !report.referenceTrace ||
  #|       !Array.isArray(report.referenceTrace.visited) ||
  #|       !Array.isArray(report.runs) || report.runs.length !== targetNames.length))) {
  #|     return "ERROR\tincomplete verifier report seed=" + String(report.seed) +
  #|       " ref=" + String(report.referenceChecked) + " paths=" +
  #|       String(report.referenceTrace && Array.isArray(report.referenceTrace.visited)) +
  #|       " runs=" + String(report.runs && report.runs.length) +
  #|       " expected=" + String(targetNames.length);
  #|   }
  #|   const lines = ["OK\t" + report.finding + "\t" + elapsed + "\t" +
  #|     String(report.sourceLineCount) + "\t" +
  #|     String(report.generationDurationMs || 0) + "\t" +
  #|     String(report.referenceEvaluationDurationMs || 0) + "\t" +
  #|     String(report.referenceTraceDurationMs || 0)];
  #|   lines.push("SIZE\t" + report.sourceLineCount);
  #|   if (sizeOnly) return lines.join("\n");
  #|   for (const path of [...new Set(report.referenceTrace.visited)].sort()) {
  #|     lines.push("PATH\t" + String(path));
  #|   }
  #|   for (const run of report.runs) {
  #|     lines.push("BACKEND\t" + run.target + "\t" + run.status + "\t" +
  #|       run.exitCode + "\t" + String(run.durationMs || 0) + "\t" +
  #|       String(Boolean(run.executionAttempted)));
  #|   }
  #|   return lines.join("\n");
  #| }

///|
#cfg(not(target="js"))
fn invoke_live_verifier(
  _script : String,
  _seed : Int,
  _depth : Int,
  _targets : String,
  _timeout_seconds : Int,
) -> String {
  "ERROR\tlive target requires the JavaScript host"
}

///|
fn parse_int(value : String, field : String) -> Int {
  @string.parse_int(value) catch {
    _ => abort("invalid " + field + ": " + value)
  }
}

///|
fn parse_candidate(spec : String) -> Candidate {
  let parts = spec.split(":").map(value => value.to_owned()).to_array()
  if parts.length() != 3 {
    abort("candidate must be seed:quartile:path-id,path-id: " + spec)
  }
  let path_ids : Array[Int] = []
  if parts[2] != "-" {
    for path_id in parts[2].split(",") {
      path_ids.push(parse_int(path_id.to_owned(), "path id"))
    }
  }
  {
    seed: parse_int(parts[0], "seed"),
    size_quartile: parse_int(parts[1], "size quartile"),
    path_ids,
  }
}

///|
fn main {
  let raw_args = cli_args()
  let live_pool_mode = raw_args.length() > 0 && raw_args[0] == "live"
  let live_generated_mode = raw_args.length() > 0 &&
    raw_args[0] == "live-generated"
  let live_mode = live_pool_mode || live_generated_mode
  let args = if live_mode { raw_args[1:] } else { raw_args }
  let config_count = if live_pool_mode {
    4
  } else if live_generated_mode {
    6
  } else {
    0
  }
  let candidate_count = if live_generated_mode { 0 } else { 2 }
  if args.length() < 3 + config_count + candidate_count {
    abort(
      "usage: moon run cmd/main -- [live|live-generated] EXECUTIONS SEED PATHS_CSV " +
      "[VERIFY_SCRIPT TARGETS_CSV DEPTH TIMEOUT_SECONDS [SEED_MIN SEED_MAX]] CANDIDATE...",
    )
  }
  let executions = parse_int(args[0], "execution budget")
  let seed = @string.parse_int64(args[1]) catch {
    _ => abort("invalid campaign seed")
  }
  let paths = if args[2] == "-" {
    []
  } else {
    args[2].split(",").map(value => value.to_owned()).to_array()
  }
  let verify_script = if live_mode { args[3] } else { "" }
  let targets_csv = if live_mode { args[4] } else { "" }
  let depth = if live_mode { parse_int(args[5], "depth") } else { 0 }
  let timeout_seconds = if live_mode {
    parse_int(args[6], "timeout seconds")
  } else {
    0
  }
  let seed_minimum = if live_generated_mode {
    parse_int(args[7], "minimum generator seed")
  } else {
    0
  }
  let seed_maximum = if live_generated_mode {
    parse_int(args[8], "maximum generator seed")
  } else {
    0
  }
  let candidate_start = if live_pool_mode {
    7
  } else if live_generated_mode {
    9
  } else {
    3
  }
  let candidates : Array[Candidate] = []
  for spec in args[candidate_start:] {
    candidates.push(parse_candidate(spec))
  }
  if executions <= 0 ||
    (!live_generated_mode && candidates.length() < 2) ||
    (!live_generated_mode && paths.is_empty()) {
    abort("need positive budget, at least two candidates, and path labels")
  }
  if live_mode &&
    (
      verify_script == "" ||
      targets_csv == "" ||
      depth < 0 ||
      timeout_seconds <= 0
    ) {
    abort(
      "live mode requires verifier, targets, nonnegative depth, and positive timeout",
    )
  }
  if live_generated_mode && (seed_minimum < 0 || seed_maximum < seed_minimum) {
    abort("generated seed range must be nonnegative and ordered")
  }
  for candidate in candidates {
    if candidate.size_quartile < 0 || candidate.size_quartile > 3 {
      abort("candidate size quartile must be 0..3")
    }
    for path_id in candidate.path_ids {
      if path_id < 0 || path_id >= paths.length() {
        abort("candidate path id outside PATHS_CSV")
      }
    }
  }
  let builder = @grammata.GrammarBuilder::new()
  let start_rule = if live_generated_mode {
    builder.integer(seed_minimum, seed_maximum, name="moonsmith-generator-seed")
  } else {
    builder.dictionary(
      candidates.map(candidate => candidate.seed.to_string()),
      name="frozen-candidate-id",
    )
  }
  let grammar = builder.set_start(start_rule).build().unwrap()
  let observed : @hashmap.HashMap[Int, Unit] = @hashmap.HashMap([])
  let observed_order : Array[Int] = []
  let target_execution_order : Array[Int] = []
  let live_observed_paths : @hashmap.HashMap[String, Unit] = @hashmap.HashMap([])
  let live_findings : @hashmap.HashMap[String, Unit] = @hashmap.HashMap([])
  let live_backend_outcomes : @hashmap.HashMap[String, Unit] = @hashmap.HashMap([],
  )
  let live_source_size_buckets : @hashmap.HashMap[String, Unit] = @hashmap.HashMap([],
  )
  let live_observations : Array[String] = []
  let mut live_evaluations = 0
  let mut live_failures = 0
  let mut live_generator_limits = 0
  let mut live_reference_checks = 0
  let mut live_backend_executions = 0
  let mut live_duration_ms = 0
  let mut live_last_error = ""
  let target = @grammata.Target::new(
    if live_generated_mode {
      "moonsmith-live-generated-seed-verifier"
    } else if live_mode {
      "moonsmith-live-pool-verifier"
    } else {
      "moonsmith-frozen-candidate-pool"
    },
    input => {
      let text = @utf8.decode(input) catch {
        _ => return @grammata.rejected("invalid-candidate-id")
      }
      let id = @string.parse_int(text) catch {
        _ => return @grammata.rejected("invalid-candidate-id")
      }
      let mut candidate : Candidate? = None
      if !live_generated_mode {
        for entry in candidates {
          if entry.seed == id {
            candidate = Some(entry)
            break
          }
        }
      }
      let candidate_quartile = match candidate {
        None if live_generated_mode => -1
        None => return @grammata.rejected("candidate-outside-frozen-pool")
        Some(value) => value.size_quartile
      }
      target_execution_order.push(id)
      if !observed.contains(id) {
        observed.set(id, ())
        observed_order.push(id)
      }
      let features : Array[@grammata.Feature] = []
      if candidate_quartile >= 0 {
        features.push(
          @grammata.feature(
            "source-size-quartile",
            candidate_quartile.to_string(),
          ),
        )
      }
      if live_mode {
        live_evaluations += 1
        let response = invoke_live_verifier(
          verify_script, id, depth, targets_csv, timeout_seconds,
        )
        let lines = response
          .split("\n")
          .map(value => value.to_owned())
          .to_array()
        let first = lines[0]
          .split("\t")
          .map(value => value.to_owned())
          .to_array()
        if first[0] != "OK" || first.length() != 7 {
          live_failures += 1
          live_last_error = response
            .split("\n")
            .map(value => value.to_owned())
            .join(" ")
          return @grammata.rejected("live-verification-failed")
        }
        let finding = first[1]
        live_findings.set(finding, ())
        if finding == "generator-limit" {
          live_generator_limits += 1
        } else {
          live_reference_checks += 1
        }
        let duration_ms = parse_int(first[2], "live verifier duration")
        let source_lines = parse_int(
          first[3],
          "live verifier source-line count",
        )
        let generation_ms = parse_int(first[4], "generation duration")
        let reference_ms = parse_int(first[5], "reference evaluation duration")
        let trace_ms = parse_int(first[6], "reference trace duration")
        live_duration_ms += duration_ms
        features.push(@grammata.feature("live-finding", finding))
        let size_bucket = if source_lines < 50 {
          "under-50"
        } else if source_lines < 100 {
          "50-to-99"
        } else {
          "100-or-more"
        }
        live_source_size_buckets.set(size_bucket, ())
        features.push(@grammata.feature("source-size-bucket", size_bucket))
        let observation_paths : Array[String] = []
        let observation_backends : Array[String] = []
        for line in lines[1:] {
          let parts = line.split("\t").map(value => value.to_owned()).to_array()
          if parts.length() == 2 && parts[0] == "PATH" {
            let path = parts[1]
            live_observed_paths.set(path, ())
            observation_paths.push(path)
            features.push(@grammata.feature("reference-path", path))
          } else if parts.length() == 6 && parts[0] == "BACKEND" {
            let backend_outcome = parts[1] +
              ":" +
              parts[2] +
              ":" +
              parts[3] +
              ":" +
              parts[4] +
              ":" +
              parts[5]
            live_backend_outcomes.set(
              parts[1] + ":" + parts[2] + ":" + parts[3],
              (),
            )
            observation_backends.push(backend_outcome)
            if parts[5] == "true" {
              live_backend_executions += 1
            }
            features.push(
              @grammata.feature(
                "backend-outcome",
                parts[1] + ":" + parts[2] + ":" + parts[3],
              ),
            )
          }
        }
        live_observations.push(
          [
            id.to_string(),
            finding,
            duration_ms.to_string(),
            source_lines.to_string(),
            generation_ms.to_string(),
            reference_ms.to_string(),
            trace_ms.to_string(),
            if finding == "generator-limit" {
              "not-checked"
            } else {
              "checked"
            },
            observation_paths.join(","),
            observation_backends.join(","),
          ].join("|"),
        )
        return @grammata.accepted(
          features~,
          cost_class=(duration_ms / 1000).max(0),
        )
      }
      if !live_mode {
        match candidate {
          None => ()
          Some(value) =>
            for path_id in value.path_ids {
              features.push(@grammata.feature("reference-path", paths[path_id]))
            }
        }
      }
      @grammata.accepted(features~)
    },
  )
  let config : @grammata.CampaignConfig = {
    ..@grammata.CampaignConfig::default(seed~),
    executions,
    initial_inputs: executions.min(16),
    crossover_percent: 0,
  }
  let result = @grammata.run_campaign(grammar, target, config).unwrap()
  let stats = result.statistics
  println(
    if live_generated_mode {
      "MOONSMITH_LIVE_GENERATED_V1"
    } else if live_pool_mode {
      "MOONSMITH_LIVE_POOL_V1"
    } else {
      "MOONSMITH_FIXED_POOL_V1"
    },
  )
  println("requested=" + stats.requested_executions.to_string())
  println("completed=" + stats.completed_executions.to_string())
  println("unique_observed=" + observed.length().to_string())
  println("unique_features=" + stats.final_corpus.unique_features.to_string())
  println(
    "unique_signatures=" + stats.final_corpus.unique_signatures.to_string(),
  )
  println(
    "observed_seeds=" + observed_order.map(value => value.to_string()).join(","),
  )
  println(
    "target_execution_order=" +
    target_execution_order.map(value => value.to_string()).join(","),
  )
  println("corpus_entries=" + stats.final_corpus.entries.to_string())
  println("campaign_generated=" + stats.generated_inputs.to_string())
  println("campaign_mutated=" + stats.mutated_inputs.to_string())
  println("campaign_crossed=" + stats.crossed_inputs.to_string())
  println("mutation_failures=" + stats.mutation_failures.to_string())
  println("candidate_pool=" + candidates.length().to_string())
  if live_mode {
    println("live_callback_evaluations=" + live_evaluations.to_string())
    println("live_callback_failures=" + live_failures.to_string())
    println("live_generator_limits=" + live_generator_limits.to_string())
    println("live_reference_checks=" + live_reference_checks.to_string())
    println("live_backend_executions=" + live_backend_executions.to_string())
    for observation in live_observations {
      println("live_observation=" + observation)
    }
    println("live_verifier_duration_ms=" + live_duration_ms.to_string())
    println(
      "live_source_size_buckets=" +
      live_source_size_buckets.keys().to_array().join(","),
    )
    println(
      "live_reference_paths=" + live_observed_paths.keys().to_array().join(","),
    )
    println("live_findings=" + live_findings.keys().to_array().join(","))
    println(
      "live_backend_outcomes=" +
      live_backend_outcomes.keys().to_array().join(","),
    )
    println("live_error=" + live_last_error)
  }
}
