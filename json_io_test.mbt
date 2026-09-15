///|
fn roster_request_json() -> String {
  (
    #|{
    #|  "workers": [
    #|    {"id": 1, "name": "Ada", "skills": ["support"], "available_slots": [9, 10]},
    #|    {"id": 2, "name": "Bo", "skills": ["support"], "available_slots": [9, 10]}
    #|  ],
    #|  "shifts": [
    #|    {"id": 1, "name": "Morning", "slot": 9, "required_skill": "support"},
    #|    {"id": 2, "name": "Midday", "slot": 10, "required_skill": "support"}
    #|  ],
    #|  "policy": {"max_shifts_per_worker": 1, "minimum_slot_gap": 0},
    #|  "penalties": [
    #|    {"worker_id": 1, "shift_id": 2, "penalty": 10}
    #|  ],
    #|  "candidate_limit": 8
    #|}
  )
}

///|
fn roster_optimization_request_json() -> String {
  (
    #|{
    #|  "workers": [
    #|    {"id": 1, "name": "Ada", "skills": ["support"], "available_slots": [9, 10]},
    #|    {"id": 2, "name": "Bo", "skills": ["support"], "available_slots": [9, 10]}
    #|  ],
    #|  "shifts": [
    #|    {"id": 1, "name": "Morning", "slot": 9, "required_skill": "support"},
    #|    {"id": 2, "name": "Midday", "slot": 10, "required_skill": "support"}
    #|  ],
    #|  "policy": {"max_shifts_per_worker": 2, "minimum_slot_gap": 0},
    #|  "objective": {
    #|    "assignment_penalties": [
    #|      {"worker_id": 2, "shift_id": 1, "penalty": 5},
    #|      {"worker_id": 2, "shift_id": 2, "penalty": 5}
    #|    ],
    #|    "consecutive_slot_penalty": 20
    #|  },
    #|  "candidate_limit": 4
    #|}
  )
}

///|
test "decodes solves and encodes a roster request" {
  let request = @moonplan.decode_roster_request(roster_request_json()).unwrap()
  assert_eq(request.workers.length(), 2)
  assert_eq(request.policy.max_shifts_per_worker, Some(1))
  let result = request.solve().unwrap()
  assert_eq(result.total_penalty, 0)
  assert_eq(result.roster.worker_for_shift(1).unwrap().name, "Ada")
  assert_eq(result.roster.worker_for_shift(2).unwrap().name, "Bo")
  let output = @moonplan.encode_preferred_roster(result, 2)
  assert_true(output.contains("\"total_penalty\": 0"))
  assert_true(output.contains("\"candidates_evaluated\": 2"))
  assert_true(output.contains("\"worker\""))
}

///|
test "reports malformed JSON separately from schema errors" {
  assert_true(
    @moonplan.decode_roster_request("{") is Err(@moonplan.InvalidJson(_)),
  )
  assert_true(
    @moonplan.decode_roster_request("{\"workers\": []}")
    is Err(@moonplan.InvalidRosterSchema(_)),
  )
}

///|
test "round trips a roster request through JSON" {
  let request = @moonplan.decode_roster_request(roster_request_json()).unwrap()
  let encoded = @json.to_json(request).stringify()
  let decoded = @moonplan.decode_roster_request(encoded).unwrap()
  assert_eq(decoded, request)
}

///|
test "decodes and solves an objective-aware request" {
  let request = @moonplan.decode_roster_optimization_request(
    roster_optimization_request_json(),
  ).unwrap()
  assert_eq(request.objective.consecutive_slot_penalty, 20)
  let result = request.solve().unwrap()
  assert_eq(result.total_penalty, 5)
  assert_eq(result.roster.worker_for_shift(1).unwrap().name, "Ada")
  assert_eq(result.roster.worker_for_shift(2).unwrap().name, "Bo")
}

///|
test "round trips an objective-aware request through JSON" {
  let request = @moonplan.decode_roster_optimization_request(
    roster_optimization_request_json(),
  ).unwrap()
  let encoded = @json.to_json(request).stringify()
  let decoded = @moonplan.decode_roster_optimization_request(encoded).unwrap()
  assert_eq(decoded, request)
}

///|
test "reports objective request syntax and schema errors" {
  assert_true(
    @moonplan.decode_roster_optimization_request("{")
    is Err(@moonplan.InvalidJson(_)),
  )
  assert_true(
    @moonplan.decode_roster_optimization_request(
      "{\"workers\":[],\"shifts\":[]}",
    )
    is Err(@moonplan.InvalidRosterSchema(_)),
  )
}

///|
test "validates a decoded objective before solving" {
  let request : @moonplan.RosterOptimizationRequest = {
    workers: [],
    shifts: [],
    policy: @moonplan.RosterPolicy::default(),
    objective: { assignment_penalties: [], consecutive_slot_penalty: -1, },
    candidate_limit: 1,
  }
  assert_true(
    request.solve() is Err(@moonplan.InvalidConsecutiveSlotPenalty(-1)),
  )
}
