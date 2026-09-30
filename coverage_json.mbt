///|
/// Portable input for staffing demands that need multiple workers per slot.
pub(all) struct CoverageRequest {
  workers : Array[Worker]
  requirements : Array[CoverageRequirement]
  policy : RosterPolicy
} derive(Eq, Debug, ToJson, FromJson)

///|
/// Stable JSON envelope for a bounded coverage search.
pub(all) struct CoverageSolveResponse {
  status : String
  roster : Json
  stats : Json
  error : Json
} derive(ToJson)

///|
/// Decode a coverage request, preserving parser and schema errors separately.
pub fn decode_coverage_request(
  text : String,
) -> Result[CoverageRequest, RosterJsonError] {
  let json = @json.parse(text) catch {
    error => return Err(InvalidJson(error.to_string()))
  }
  let request : CoverageRequest = @json.from_json(json) catch {
    error => return Err(InvalidRosterSchema(error.to_string()))
  }
  Ok(request)
}

///|
/// Solve a decoded coverage request with the standard scheduling rules.
pub fn CoverageRequest::solve(
  self : CoverageRequest,
) -> Result[CoverageRoster, RosterError] {
  build_coverage_roster(self.workers, self.requirements, self.policy)
}

///|
/// Solve a JSON-compatible request with a consecutive-work hard limit.
pub fn CoverageRequest::solve_with_consecutive_limit(
  self : CoverageRequest,
  maximum_consecutive_slots : Int,
) -> Result[CoverageRoster, RosterError] {
  build_coverage_roster_with_consecutive_limit(
    self.workers,
    self.requirements,
    self.policy,
    maximum_consecutive_slots,
  )
}

///|
/// Solve a request with an explicit search budget and a three-way outcome.
pub fn CoverageRequest::solve_with_node_limit(
  self : CoverageRequest,
  node_limit : Int,
) -> Result[CoverageSolveOutcome, RosterError] {
  build_coverage_roster_with_node_limit(
    self.workers,
    self.requirements,
    self.policy,
    node_limit,
  )
}

///|
/// Encode a bounded search outcome for CLI, browser, and service callers.
/// `budget_exhausted` is intentionally distinct from `unsatisfiable`.
pub fn encode_coverage_solve_outcome(
  outcome : CoverageSolveOutcome,
  indent : Int,
) -> String {
  let absent : String? = None
  let response : CoverageSolveResponse = match outcome {
    CoverageFound(roster) =>
      {
        status: "found",
        roster: @json.to_json(roster),
        stats: @json.to_json(roster.stats),
        error: @json.to_json(absent),
      }
    CoverageProvedUnsatisfiable(stats) =>
      {
        status: "unsatisfiable",
        roster: @json.to_json(absent),
        stats: @json.to_json(stats),
        error: @json.to_json(absent),
      }
    CoverageBudgetExhausted(stats) =>
      {
        status: "budget_exhausted",
        roster: @json.to_json(absent),
        stats: @json.to_json(stats),
        error: @json.to_json(absent),
      }
  }
  @json.to_json(response).stringify(indent~)
}

///|
/// Encode a coverage roster and its search statistics as JSON text.
pub fn encode_coverage_roster(roster : CoverageRoster, indent : Int) -> String {
  @json.to_json(roster).stringify(indent~)
}
