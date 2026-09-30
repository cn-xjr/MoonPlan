///|
fn balance_request() -> @moonplan.CoverageRequest {
  {
    workers: [
      { id: 1, name: "An", skills: ["support"], available_slots: [1, 2], },
      { id: 2, name: "Bo", skills: ["support"], available_slots: [1, 2], },
    ],
    requirements: [
      {
        id: 10,
        name: "Morning",
        slot: 1,
        required_skill: "support",
        workers_needed: 1,
      },
      {
        id: 20,
        name: "Evening",
        slot: 2,
        required_skill: "support",
        workers_needed: 1,
      },
    ],
    policy: { max_shifts_per_worker: Some(2), minimum_slot_gap: 0, },
  }
}

///|
test "coverage balance improves as the candidate window grows" {
  let request = balance_request()
  let first = request.solve_balanced(1).unwrap()
  let broader = request.solve_balanced(2).unwrap()
  assert_eq(first.candidates_evaluated, 1)
  assert_eq(first.balance.spread, 2)
  assert_eq(broader.candidates_evaluated, 2)
  assert_eq(broader.balance.spread, 0)
  assert_eq(broader.roster.entries.length(), 2)
}

///|
test "coverage balance enforces workload caps before scoring" {
  let base = balance_request()
  let request : @moonplan.CoverageRequest = {
    workers: base.workers,
    requirements: base.requirements,
    policy: { max_shifts_per_worker: Some(1), minimum_slot_gap: 0, },
  }
  let result = request.solve_balanced(1).unwrap()
  assert_eq(result.balance.spread, 0)
  assert_true(
    result.roster.entries[0].worker.id != result.roster.entries[1].worker.id,
  )
}

///|
test "coverage balance rejects a non-positive candidate limit" {
  assert_true(
    balance_request().solve_balanced(0)
    is Err(@moonplan.InvalidCandidateLimit(0)),
  )
}
