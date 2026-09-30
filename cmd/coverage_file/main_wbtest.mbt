///|
fn file_cli_sample() -> String {
  (
    #|{"workers":[{"id":1,"name":"An","skills":["support"],"available_slots":[9]},{"id":2,"name":"Bo","skills":["support"],"available_slots":[9]}],"requirements":[{"id":7,"name":"Help","slot":9,"required_skill":"support","workers_needed":2}],"policy":{"max_shifts_per_worker":1,"minimum_slot_gap":0}}
  )
}

///|
test "file command renders the same request in check and fair modes" {
  let check = render_coverage(file_cli_sample(), ["runner", "--check"])
  assert_true(check.contains("\"preflight_passed\": true"))
  let fair = render_coverage(file_cli_sample(), [
    "runner", "--fair-node-limit", "100",
  ])
  assert_true(fair.contains("\"status\": \"optimal\""))
  assert_true(fair.contains("\"spread\": 0"))
}

///|
test "file command rejects an incomplete fairness flag" {
  let output = render_coverage(file_cli_sample(), [
    "runner", "--fair-node-limit",
  ])
  assert_true(output.contains("requires a positive integer"))
  assert_true(output.contains("\"error\""))
}
