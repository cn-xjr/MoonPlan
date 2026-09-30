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
priv struct FileOptions {
  path : String?
  check : Bool
  csv : Bool
  fair_limit : Int?
}

///|
fn parse_file_options(args : Array[String]) -> Result[FileOptions, String] {
  let mut path : String? = None
  let mut use_stdin = false
  let mut check = false
  let mut csv = false
  let mut fair_limit : Int? = None
  let mut index = 1
  while index < args.length() {
    match args[index] {
      "--file" => {
        if path is Some(_) ||
          index + 1 >= args.length() ||
          args[index + 1].has_prefix("--") {
          return Err("--file requires exactly one path")
        }
        path = Some(args[index + 1])
        index = index + 2
      }
      "--stdin" => {
        if use_stdin {
          return Err("--stdin may be given only once")
        }
        use_stdin = true
        index = index + 1
      }
      "--check" => {
        if check {
          return Err("--check may be given only once")
        }
        check = true
        index = index + 1
      }
      "--csv" => {
        if csv {
          return Err("--csv may be given only once")
        }
        csv = true
        index = index + 1
      }
      "--fair-node-limit" => {
        if fair_limit is Some(_) || index + 1 >= args.length() {
          return Err("--fair-node-limit requires exactly one positive integer")
        }
        let limit = @string.parse_int(args[index + 1]) catch {
          _ =>
            return Err(
              "--fair-node-limit requires exactly one positive integer",
            )
        }
        if limit <= 0 {
          return Err("--fair-node-limit requires exactly one positive integer")
        }
        fair_limit = Some(limit)
        index = index + 2
      }
      other => return Err("unknown option: \{other}")
    }
  }
  if (path is Some(_) && use_stdin) || (path is None && !use_stdin) {
    return Err("exactly one of --file PATH and --stdin is required")
  }
  if (check && (csv || fair_limit is Some(_))) || (csv && fair_limit is Some(_)) {
    return Err("--check, --csv, and --fair-node-limit cannot be combined")
  }
  Ok({ path, check, csv, fair_limit, })
}

///|
fn render_coverage(text : String, options : FileOptions) -> String {
  let request = match @moonplan.decode_coverage_request(text) {
    Err(error) => return file_cli_error(error.message())
    Ok(request) => request
  }
  match options.fair_limit {
    Some(limit) =>
      match request.solve_fairest(limit) {
        Err(error) => file_cli_error(error.message())
        Ok(outcome) => @moonplan.encode_fair_coverage_outcome(outcome, 2)
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
      if options.check {
        return @moonplan.encode_coverage_analysis(analysis, 2)
      }
      if !analysis.is_feasible() {
        return file_cli_error(analysis.summary())
      }
      match request.solve() {
        Err(error) => file_cli_error(error.message())
        Ok(roster) => {
          if options.csv {
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
  let options = match parse_file_options(args) {
    Err(message) => {
      println(file_cli_error(message))
      return
    }
    Ok(options) => options
  }
  let text = try {
    match options.path {
      Some(file) => @fs.read_file(file).text()
      None => @stdio.stdin.read_all().text()
    }
  } catch {
    error => {
      println(file_cli_error("cannot read coverage input: \{error}"))
      return
    }
  }
  println(render_coverage(text, options))
}
