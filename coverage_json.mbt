///|
/// Portable input for staffing demands that need multiple workers per slot.
pub(all) struct CoverageRequest {
  workers : Array[Worker]
  requirements : Array[CoverageRequirement]
  policy : RosterPolicy
} derive(Eq, Debug, ToJson, FromJson)

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
/// Encode a coverage roster and its search statistics as JSON text.
pub fn encode_coverage_roster(roster : CoverageRoster, indent : Int) -> String {
  @json.to_json(roster).stringify(indent~)
}
