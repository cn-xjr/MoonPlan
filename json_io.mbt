///|
/// A complete, portable input document for preferred roster optimization.
pub(all) struct RosterRequest {
  workers : Array[Worker]
  shifts : Array[Shift]
  policy : RosterPolicy
  penalties : Array[AssignmentPenalty]
  candidate_limit : Int
} derive(Eq, Debug, ToJson, FromJson)

///|
/// A portable optimization request with a composable soft objective.
///
/// This type extends the JSON integration without changing the established
/// `RosterRequest` schema used by existing clients.
pub(all) struct RosterOptimizationRequest {
  workers : Array[Worker]
  shifts : Array[Shift]
  policy : RosterPolicy
  objective : RosterObjective
  candidate_limit : Int
} derive(Eq, Debug, ToJson, FromJson)

///|
/// Errors produced while decoding a roster request.
pub(all) enum RosterJsonError {
  InvalidJson(String)
  InvalidRosterSchema(String)
} derive(Eq, Debug)

///|
/// Explain a JSON decoding failure with its parser or field path detail.
pub fn RosterJsonError::message(self : RosterJsonError) -> String {
  match self {
    InvalidJson(detail) => "invalid JSON: \{detail}"
    InvalidRosterSchema(detail) => "invalid roster schema: \{detail}"
  }
}

///|
/// Decode a complete roster request from JSON text.
pub fn decode_roster_request(
  text : String,
) -> Result[RosterRequest, RosterJsonError] {
  let json = @json.parse(text) catch {
    error => return Err(InvalidJson(error.to_string()))
  }
  let request : RosterRequest = @json.from_json(json) catch {
    error => return Err(InvalidRosterSchema(error.to_string()))
  }
  Ok(request)
}

///|
/// Decode an objective-aware roster optimization request from JSON text.
pub fn decode_roster_optimization_request(
  text : String,
) -> Result[RosterOptimizationRequest, RosterJsonError] {
  let json = @json.parse(text) catch {
    error => return Err(InvalidJson(error.to_string()))
  }
  let request : RosterOptimizationRequest = @json.from_json(json) catch {
    error => return Err(InvalidRosterSchema(error.to_string()))
  }
  Ok(request)
}

///|
/// Solve a decoded request using its hard policy and soft penalties.
pub fn RosterRequest::solve(
  self : RosterRequest,
) -> Result[PreferredRoster, RosterError] {
  build_preferred_roster(
    self.workers,
    self.shifts,
    self.policy,
    self.penalties,
    self.candidate_limit,
  )
}

///|
/// Solve an objective-aware request using all hard and soft rules.
pub fn RosterOptimizationRequest::solve(
  self : RosterOptimizationRequest,
) -> Result[PreferredRoster, RosterError] {
  build_preferred_roster_with_objective(
    self.workers,
    self.shifts,
    self.policy,
    self.objective,
    self.candidate_limit,
  )
}

///|
/// Encode an optimized roster as stable JSON text.
pub fn encode_preferred_roster(
  result : PreferredRoster,
  indent : Int,
) -> String {
  @json.to_json(result).stringify(indent~)
}
