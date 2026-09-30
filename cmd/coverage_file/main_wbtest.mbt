///|
fn file_cli_sample() -> String {
  (
    #|{"workers":[{"id":1,"name":"An","skills":["support"],"available_slots":[9]},{"id":2,"name":"Bo","skills":["support"],"available_slots":[9]}],"requirements":[{"id":7,"name":"Help","slot":9,"required_skill":"support","workers_needed":2}],"policy":{"max_shifts_per_worker":1,"minimum_slot_gap":0}}
  )
}

///|
test "file command renders the same request in check and fair modes" {
  let check = render_coverage(
    file_cli_sample(),
    parse_file_options(["runner", "--stdin", "--check"]).unwrap(),
  )
  assert_true(check.contains("\"preflight_passed\": true"))
  let fair = render_coverage(
    file_cli_sample(),
    parse_file_options(["runner", "--stdin", "--fair-node-limit", "100"]).unwrap(),
  )
  assert_true(fair.contains("\"status\": \"optimal\""))
  assert_true(fair.contains("\"spread\": 0"))
}

///|
test "file command rejects incomplete and duplicate flags" {
  assert_true(
    parse_file_options(["runner", "--stdin", "--fair-node-limit"]) is Err(_),
  )
  assert_true(parse_file_options(["runner", "--stdin", "--stdin"]) is Err(_))
  assert_true(parse_file_options(["runner", "--file", "--check"]) is Err(_))
  assert_true(parse_file_options(["runner", "--stdin", "--mystery"]) is Err(_))
}

///|
test "file command requires one input and one output mode" {
  assert_true(parse_file_options(["runner", "--check"]) is Err(_))
  assert_true(
    parse_file_options(["runner", "--stdin", "--file", "input.json"]) is Err(_),
  )
  assert_true(
    parse_file_options(["runner", "--stdin", "--csv", "--check"]) is Err(_),
  )
}
