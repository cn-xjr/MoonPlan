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
fn solve_coverage_json(text : String) -> String {
  let request = match @moonplan.decode_coverage_request(text) {
    Err(error) => return response_error(error.message())
    Ok(request) => request
  }
  let analysis = match
    @moonplan.analyze_coverage(request.workers, request.requirements) {
    Err(error) => return response_error(error.message())
    Ok(analysis) => analysis
  }
  if !analysis.is_feasible() {
    return response_error(analysis.summary())
  }
  match request.solve() {
    Err(error) => response_error(error.message())
    Ok(roster) => {
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
  match json_argument(@env.args()) {
    None =>
      println(
        response_error(
          "usage: moon run cmd/coverage --json '<coverage-request-json>'",
        ),
      )
    Some(text) => println(solve_coverage_json(text))
  }
}
