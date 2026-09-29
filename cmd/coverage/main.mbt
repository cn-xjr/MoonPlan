///|
priv struct CoverageCliResponse {
  roster : Json
  error : Json
} derive(ToJson)

///|
fn response_error(message : String) -> String {
  let absent : String? = None
  let response : CoverageCliResponse = {
    roster: @json.to_json(absent),
    error: @json.to_json(message),
  }
  @json.to_json(response).stringify(indent=2)
}

///|
fn check_coverage(text : String) -> String {
  let request = match @moonplan.decode_coverage_request(text) {
    Err(error) => return response_error(error.message())
    Ok(request) => request
  }
  match
    @moonplan.analyze_coverage_with_policy(
      request.workers,
      request.requirements,
      request.policy,
    ) {
    Err(error) => response_error(error.message())
    Ok(analysis) => @moonplan.encode_coverage_analysis(analysis, 2)
  }
}

///|
fn solve_coverage(text : String, csv : Bool) -> String {
  let request = match @moonplan.decode_coverage_request(text) {
    Err(error) => return response_error(error.message())
    Ok(request) => request
  }
  let analysis = match
    @moonplan.analyze_coverage_with_policy(
      request.workers,
      request.requirements,
      request.policy,
    ) {
    Err(error) => return response_error(error.message())
    Ok(analysis) => analysis
  }
  if !analysis.is_feasible() {
    return response_error(analysis.summary())
  }
  match request.solve() {
    Err(error) => response_error(error.message())
    Ok(roster) => {
      if csv {
        return @moonplan.encode_coverage_roster_csv(roster)
      }
      let absent : String? = None
      let response : CoverageCliResponse = {
        roster: @json.to_json(roster),
        error: @json.to_json(absent),
      }
      @json.to_json(response).stringify(indent=2)
    }
  }
}

///|
fn output_csv(args : Array[String]) -> Bool? {
  let mut found = false
  let mut csv = false
  for index = 0; index < args.length(); index = index + 1 {
    if args[index] == "--format" {
      if found || index + 1 >= args.length() {
        return None
      }
      found = true
      match args[index + 1] {
        "json" => csv = false
        "csv" => csv = true
        _ => return None
      }
    }
  }
  Some(csv)
}

///|
fn json_argument(args : Array[String]) -> String? {
  let mut result : String? = None
  for index = 0; index + 1 < args.length(); index = index + 1 {
    if args[index] == "--json" {
      if result is Some(_) {
        return None
      }
      result = Some(args[index + 1])
    }
  }
  result
}

///|
fn main {
  let args = @env.args()
  match (json_argument(args), output_csv(args)) {
    (Some(text), Some(csv)) =>
      if args.contains("--check") {
        if csv {
          println(response_error("--check cannot be combined with CSV output"))
        } else {
          println(check_coverage(text))
        }
      } else {
        println(solve_coverage(text, csv))
      }
    _ =>
      println(
        response_error(
          "usage: moon run cmd/coverage --json '<coverage-request-json>' [--check | --format json|csv]",
        ),
      )
  }
}
