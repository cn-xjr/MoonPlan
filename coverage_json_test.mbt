///|
fn sample_coverage_json() -> String {
  (
    #|{
    #|  "workers": [
    #|    {"id": 1, "name": "Ada", "skills": ["support"], "available_slots": [9]},
    #|    {"id": 2, "name": "Bo", "skills": ["support"], "available_slots": [9]}
    #|  ],
    #|  "requirements": [
    #|    {"id": 20, "name": "Help desk", "slot": 9, "required_skill": "support", "workers_needed": 2}
    #|  ],
    #|  "policy": {"max_shifts_per_worker": 1, "minimum_slot_gap": 0}
    #|}
  )
}

///|
test "decodes and solves a multi-worker coverage request" {
  let request = @moonplan.decode_coverage_request(sample_coverage_json()).unwrap()
  let roster = request.solve().unwrap()
  let workers = roster.workers_for_requirement(20)
  assert_eq(workers.length(), 2)
  assert_true(workers[0].id != workers[1].id)
  let output = @moonplan.encode_coverage_roster(roster, 2)
  assert_true(output.contains("\"requirement\""))
  assert_true(output.contains("\"workers_needed\": 2"))
  assert_true(output.contains("\"position\": 2"))
}

///|
test "round trips coverage input without changing its requirements" {
  let request = @moonplan.decode_coverage_request(sample_coverage_json()).unwrap()
  let encoded = @json.to_json(request).stringify()
  assert_eq(@moonplan.decode_coverage_request(encoded).unwrap(), request)
}

///|
test "separates malformed coverage JSON from missing fields" {
  assert_true(
    @moonplan.decode_coverage_request("{") is Err(@moonplan.InvalidJson(_)),
  )
  assert_true(
    @moonplan.decode_coverage_request("{\"workers\":[]}")
    is Err(@moonplan.InvalidRosterSchema(_)),
  )
}

///|
test "validates coverage counts after decoding" {
  let request : @moonplan.CoverageRequest = {
    workers: [],
    requirements: [
      {
        id: 3,
        name: "Invalid",
        slot: 9,
        required_skill: "support",
        workers_needed: 0,
      },
    ],
    policy: @moonplan.RosterPolicy::default(),
  }
  assert_true(
    request.solve() is Err(@moonplan.InvalidCoverageWorkerCount(3, 0)),
  )
}
