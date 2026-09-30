///|
priv struct CoverageCliResponse {
  roster : Json
  error : Json
} derive(ToJson)

///|
priv struct BalancedCliResponse {
  roster : Json
  balance : Json
  candidates_evaluated : Int
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
fn solve_coverage_bounded(text : String, node_limit : Int) -> String {
  let request = match @moonplan.decode_coverage_request(text) {
    Err(error) => return response_error(error.message())
    Ok(request) => request
  }
  match request.solve_with_node_limit(node_limit) {
    Err(error) => return response_error(error.message())
    Ok(outcome) => @moonplan.encode_coverage_solve_outcome(outcome, 2)
  }
}

///|
fn solve_coverage_balanced(text : String, candidate_limit : Int) -> String {
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
  match request.solve_balanced(candidate_limit) {
    Err(error) => response_error(error.message())
    Ok(result) => {
      let absent : String? = None
      let response : BalancedCliResponse = {
        roster: @json.to_json(result.roster),
        balance: @json.to_json(result.balance),
        candidates_evaluated: result.candidates_evaluated,
        error: @json.to_json(absent),
      }
      @json.to_json(response).stringify(indent=2)
    }
  }
}

///|
fn solve_coverage_fairest(text : String, node_limit : Int) -> String {
  let request = match @moonplan.decode_coverage_request(text) {
    Err(error) => return response_error(error.message())
    Ok(request) => request
  }
  match request.solve_fairest(node_limit) {
    Err(error) => response_error(error.message())
    Ok(outcome) => @moonplan.encode_fair_coverage_outcome(outcome, 2)
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
fn positive_limit(args : Array[String], flag : String) -> Result[Int?, String] {
  let mut budget : Int? = None
  for index = 0; index < args.length(); index = index + 1 {
    if args[index] == flag {
      if budget is Some(_) || index + 1 >= args.length() {
        return Err("\{flag} requires exactly one positive integer")
      }
      let parsed = @string.parse_int(args[index + 1]) catch {
        _ => return Err("\{flag} requires exactly one positive integer")
      }
      if parsed <= 0 {
        return Err("\{flag} requires exactly one positive integer")
      }
      budget = Some(parsed)
    }
  }
  Ok(budget)
}

///|
fn node_budget(args : Array[String]) -> Result[Int?, String] {
  positive_limit(args, "--node-limit")
}

///|
fn candidate_budget(args : Array[String]) -> Result[Int?, String] {
  positive_limit(args, "--candidate-limit")
}

///|
fn fair_budget(args : Array[String]) -> Result[Int?, String] {
  positive_limit(args, "--fair-node-limit")
}

///|
fn main {
  let args = @env.args()
  match
    (
      json_argument(args),
      output_csv(args),
      node_budget(args),
      candidate_budget(args),
      fair_budget(args),
    ) {
    (Some(text), Some(csv), Ok(budget), Ok(candidates), Ok(fair_limit)) =>
      if (
          args.contains("--check") &&
          (
            csv ||
            budget is Some(_) ||
            candidates is Some(_) ||
            fair_limit is Some(_)
          )
        ) ||
        (
          csv &&
          (budget is Some(_) || candidates is Some(_) || fair_limit is Some(_))
        ) ||
        (budget is Some(_) && (candidates is Some(_) || fair_limit is Some(_))) ||
        (candidates is Some(_) && fair_limit is Some(_)) {
        println(
          response_error(
            "--check, --format csv, --node-limit, --candidate-limit, and --fair-node-limit cannot be combined",
          ),
        )
      } else if args.contains("--check") {
        println(check_coverage(text))
      } else {
        match budget {
          Some(limit) => println(solve_coverage_bounded(text, limit))
          None =>
            match candidates {
              Some(limit) => println(solve_coverage_balanced(text, limit))
              None =>
                match fair_limit {
                  Some(limit) => println(solve_coverage_fairest(text, limit))
                  None => println(solve_coverage(text, csv))
                }
            }
        }
      }
    (_, _, Err(message), _, _) => println(response_error(message))
    (_, _, _, Err(message), _) => println(response_error(message))
    (_, _, _, _, Err(message)) => println(response_error(message))
    _ =>
      println(
        response_error(
          "usage: moon run cmd/coverage --json '<coverage-request-json>' [--check | --format json|csv | --node-limit N | --candidate-limit N | --fair-node-limit N]",
        ),
      )
  }
}
