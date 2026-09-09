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
/// Encode an optimized roster as stable JSON text.
pub fn encode_preferred_roster(
  result : PreferredRoster,
  indent : Int,
) -> String {
  @json.to_json(result).stringify(indent~)
}
