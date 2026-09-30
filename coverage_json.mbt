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
/// Stable JSON envelope for an exact fairness search.
pub(all) struct FairCoverageResponse {
  status : String
  roster : Json
  balance : Json
  windows_checked : Int
  total_nodes : Int
  total_backtracks : Int
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
/// Search a coverage request with a selected strategy and assignment budget.
pub fn CoverageRequest::solve_with_strategy(
  self : CoverageRequest,
  node_limit : Int,
  strategy : SearchStrategy,
) -> Result[CoverageSolveOutcome, RosterError] {
  build_coverage_roster_with_strategy(
    self.workers,
    self.requirements,
    self.policy,
    node_limit,
    strategy,
  )
}

///|
/// Evaluate a bounded number of feasible coverage rosters for workload balance.
pub fn CoverageRequest::solve_balanced(
  self : CoverageRequest,
  candidate_limit : Int,
) -> Result[OptimizedCoverageRoster, RosterError] {
  build_balanced_coverage_roster(
    self.workers,
    self.requirements,
    self.policy,
    candidate_limit,
  )
}

///|
/// Search for a provably fairest coverage roster within a global node budget.
pub fn CoverageRequest::solve_fairest(
  self : CoverageRequest,
  node_limit : Int,
) -> Result[FairCoverageOutcome, RosterError] {
  build_fairest_coverage_roster(
    self.workers,
    self.requirements,
    self.policy,
    node_limit,
  )
}

///|
/// Encode an exact fairness outcome without conflating budget exhaustion
/// with an optimality or infeasibility proof.
pub fn encode_fair_coverage_outcome(
  outcome : FairCoverageOutcome,
  indent : Int,
) -> String {
  let absent : String? = None
  let null = @json.to_json(absent)
  let response : FairCoverageResponse = match outcome {
    FairCoverageFound(result) =>
      {
        status: "optimal",
        roster: @json.to_json(result.roster),
        balance: @json.to_json(result.balance),
        windows_checked: result.windows_checked,
        total_nodes: result.total_nodes,
        total_backtracks: result.total_backtracks,
        error: null,
      }
    FairCoverageProvedUnsatisfiable(stats, windows_checked) =>
      {
        status: "unsatisfiable",
        roster: null,
        balance: null,
        windows_checked,
        total_nodes: stats.nodes,
        total_backtracks: stats.backtracks,
        error: null,
      }
    FairCoverageBudgetExhausted(stats, windows_checked) =>
      {
        status: "budget_exhausted",
        roster: null,
        balance: null,
        windows_checked,
        total_nodes: stats.nodes,
        total_backtracks: stats.backtracks,
        error: null,
      }
  }
  @json.to_json(response).stringify(indent~)
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
