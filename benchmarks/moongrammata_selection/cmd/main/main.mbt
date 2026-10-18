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
  let args = cli_args()
  if args.length() < 4 {
    abort("usage: moon run cmd/main -- EXECUTIONS SEED PATHS_CSV CANDIDATE...")
  }
  let executions = parse_int(args[0], "execution budget")
  let seed = @string.parse_int64(args[1]) catch {
    _ => abort("invalid campaign seed")
  }
  let paths = args[2].split(",").map(value => value.to_owned()).to_array()
  let candidates : Array[Candidate] = []
  for spec in args[3:] {
    candidates.push(parse_candidate(spec))
  }
  if executions <= 0 || candidates.length() < 2 || paths.is_empty() {
    abort("need positive budget, at least two candidates, and path labels")
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
  let values = candidates.map(candidate => candidate.seed.to_string())
  let builder = @grammata.GrammarBuilder::new()
  let pool_rule = builder.dictionary(values, name="frozen-candidate-id")
  let grammar = builder.set_start(pool_rule).build().unwrap()
  let observed : @hashmap.HashMap[Int, Unit] = @hashmap.HashMap([])
  let observed_order : Array[Int] = []
  let target = @grammata.Target::new("moonsmith-frozen-candidate-pool", input => {
    let text = @utf8.decode(input) catch {
      _ => return @grammata.rejected("invalid-candidate-id")
    }
    let id = @string.parse_int(text) catch {
      _ => return @grammata.rejected("invalid-candidate-id")
    }
    let mut candidate : Candidate? = None
    for entry in candidates {
      if entry.seed == id {
        candidate = Some(entry)
        break
      }
    }
    let candidate = match candidate {
      None => return @grammata.rejected("candidate-outside-frozen-pool")
      Some(value) => value
    }
    if !observed.contains(id) {
      observed.set(id, ())
      observed_order.push(id)
    }
    let features : Array[@grammata.Feature] = [
      @grammata.feature(
        "source-size-quartile",
        candidate.size_quartile.to_string(),
      ),
    ]
    for path_id in candidate.path_ids {
      features.push(@grammata.feature("reference-path", paths[path_id]))
    }
    @grammata.accepted(features~)
  })
  let config : @grammata.CampaignConfig = {
    ..@grammata.CampaignConfig::default(seed~),
    executions,
    initial_inputs: executions.min(16),
    crossover_percent: 0,
  }
  let result = @grammata.run_campaign(grammar, target, config).unwrap()
  let stats = result.statistics
  println("MOONSMITH_FIXED_POOL_V1")
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
  println("corpus_entries=" + stats.final_corpus.entries.to_string())
  println("campaign_generated=" + stats.generated_inputs.to_string())
  println("campaign_mutated=" + stats.mutated_inputs.to_string())
  println("campaign_crossed=" + stats.crossed_inputs.to_string())
  println("mutation_failures=" + stats.mutation_failures.to_string())
  println("candidate_pool=" + candidates.length().to_string())
}
