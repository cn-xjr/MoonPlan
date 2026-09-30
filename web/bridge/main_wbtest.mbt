///|
fn bridge_example() -> String {
  (
    #|{"workers":[{"id":1,"name":"An","skills":["support"],"available_slots":[9]}],"requirements":[{"id":7,"name":"Help","slot":9,"required_skill":"support","workers_needed":1}],"policy":{"max_shifts_per_worker":1,"minimum_slot_gap":0}}
  )
}

///|
test "browser bridge checks and solves with MoonBit core" {
  assert_true(
    check_coverage(bridge_example()).contains("\"preflight_passed\": true"),
  )
  let solved = solve_fairest_coverage(bridge_example(), 100)
  assert_true(solved.contains("\"status\": \"optimal\""))
  assert_true(solved.contains("\"spread\": 0"))
}

///|
test "browser bridge returns errors without trapping" {
  assert_true(check_coverage("{").contains("\"error\""))
  assert_true(solve_fairest_coverage(bridge_example(), 0).contains("positive"))
}
