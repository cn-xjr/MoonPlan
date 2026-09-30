///|
priv struct BridgeError {
  error : String
} derive(ToJson)

///|
fn error_json(message : String) -> String {
  @json.to_json(BridgeError::{ error: message, }).stringify(indent=2)
}

///|
fn checked_request(text : String) -> Result[@moonplan.CoverageRequest, String] {
  match @moonplan.decode_coverage_request(text) {
    Err(error) => Err(error.message())
    Ok(request) => Ok(request)
  }
}

///|
/// Validate a user-edited coverage request without running full search.
#export_name("check_coverage")
pub fn check_coverage(text : String) -> String {
  let request = match checked_request(text) {
    Err(message) => return error_json(message)
    Ok(request) => request
  }
  match
    @moonplan.analyze_coverage_with_policy(
      request.workers,
      request.requirements,
      request.policy,
    ) {
    Err(error) => error_json(error.message())
    Ok(analysis) => @moonplan.encode_coverage_analysis(analysis, 2)
  }
}

///|
/// Solve for the proven minimum workload spread within a shared node budget.
#export_name("solve_fairest_coverage")
pub fn solve_fairest_coverage(text : String, node_limit : Int) -> String {
  if node_limit <= 0 {
    return error_json("node_limit must be positive")
  }
  let request = match checked_request(text) {
    Err(message) => return error_json(message)
    Ok(request) => request
  }
  match request.solve_fairest(node_limit) {
    Err(error) => error_json(error.message())
    Ok(outcome) => @moonplan.encode_fair_coverage_outcome(outcome, 2)
  }
}
