///|
priv struct FileCliResponse {
  roster : Json
  error : Json
} derive(ToJson)

///|
fn file_cli_error(message : String) -> String {
  let absent : String? = None
  let response : FileCliResponse = {
    roster: @json.to_json(absent),
    error: @json.to_json(message),
  }
  @json.to_json(response).stringify(indent=2)
}

///|
fn flag_value(args : Array[String], flag : String) -> String? {
  let mut found : String? = None
  for index = 0; index + 1 < args.length(); index = index + 1 {
    if args[index] == flag {
      if found is Some(_) {
        return None
      }
      found = Some(args[index + 1])
    }
  }
  found
}

///|
fn render_coverage(text : String, args : Array[String]) -> String {
  let request = match @moonplan.decode_coverage_request(text) {
    Err(error) => return file_cli_error(error.message())
    Ok(request) => request
  }
  let fair_text = flag_value(args, "--fair-node-limit")
  if args.contains("--fair-node-limit") && fair_text is None {
    return file_cli_error("--fair-node-limit requires a positive integer")
  }
  let check = args.contains("--check")
  let csv = args.contains("--csv")
  if (check && (fair_text is Some(_) || csv)) || (csv && fair_text is Some(_)) {
    return file_cli_error(
      "--check, --csv, and --fair-node-limit cannot be combined",
    )
  }
  match fair_text {
    Some(raw_limit) => {
      let limit = @string.parse_int(raw_limit) catch {
        _ =>
          return file_cli_error("--fair-node-limit requires a positive integer")
      }
      if limit <= 0 {
        return file_cli_error("--fair-node-limit requires a positive integer")
      }
      match request.solve_fairest(limit) {
        Err(error) => file_cli_error(error.message())
        Ok(outcome) => @moonplan.encode_fair_coverage_outcome(outcome, 2)
      }
    }
    None => {
      let analysis = match
        @moonplan.analyze_coverage_with_policy(
          request.workers,
          request.requirements,
          request.policy,
        ) {
        Err(error) => return file_cli_error(error.message())
        Ok(analysis) => analysis
      }
      if check {
        return @moonplan.encode_coverage_analysis(analysis, 2)
      }
      if !analysis.is_feasible() {
        return file_cli_error(analysis.summary())
      }
      match request.solve() {
        Err(error) => file_cli_error(error.message())
        Ok(roster) => {
          if csv {
            return @moonplan.encode_coverage_roster_csv(roster)
          }
          let absent : String? = None
          let response : FileCliResponse = {
            roster: @json.to_json(roster),
            error: @json.to_json(absent),
          }
          @json.to_json(response).stringify(indent=2)
        }
      }
    }
  }
}

///|
async fn main {
  let args = @env.args()
  let path = flag_value(args, "--file")
  let use_stdin = args.contains("--stdin")
  if (path is Some(_) && use_stdin) || (path is None && !use_stdin) {
    println(
      file_cli_error(
        "usage: moon run --target wasm cmd/coverage_file -- (--file PATH | --stdin) [--check | --csv | --fair-node-limit N]",
      ),
    )
    return
  }
  let text = try {
    match path {
      Some(file) => @fs.read_file(file).text()
      None => @stdio.stdin.read_all().text()
    }
  } catch {
    error => {
      println(file_cli_error("cannot read coverage input: \{error}"))
      return
    }
  }
  println(render_coverage(text, args))
}
