///|
fn sample_json() -> String {
  (
    #|{"workers":[{"id":1,"name":"An","skills":["support"],"available_slots":[9]},{"id":2,"name":"Bo","skills":["support"],"available_slots":[9]}],"requirements":[{"id":7,"name":"Help","slot":9,"required_skill":"support","workers_needed":2}],"policy":{"max_shifts_per_worker":1,"minimum_slot_gap":0}}
  )
}

///|
test "coverage command emits machine-readable roster" {
  let output = solve_coverage_json(sample_json())
  let response = @json.parse(output)
  assert_true(response is Object({ "roster": Object(_), "error": Null, .. }))
  assert_true(output.contains("\"position\": 1"))
  assert_true(output.contains("\"position\": 2"))
  assert_true(output.contains("\"name\": \"An\""))
  assert_true(output.contains("\"name\": \"Bo\""))
}

///|
test "coverage command returns schema and preflight errors as JSON" {
  let malformed = solve_coverage_json("{")
  assert_true(malformed.contains("invalid JSON"))
  assert_true(@json.parse(malformed) is Object(_))
  let unstaffed = sample_json().replace(
    old="\"available_slots\":[9]",
    new="\"available_slots\":[]",
  )
  let output = solve_coverage_json(unstaffed)
  assert_true(output.contains("slot 9 needs 2 workers"))
  assert_true(@json.parse(output) is Object(_))
}

///|
test "coverage command locates JSON after host-specific executable arguments" {
  assert_eq(json_argument(["runner", "--json", "{}"]), Some("{}"))
  assert_eq(json_argument(["node", "app.js", "--json", "{}"]), Some("{}"))
  assert_true(json_argument(["runner"]) is None)
  assert_true(json_argument(["runner", "--json", "{}", "--json", "[]"]) is None)
}
