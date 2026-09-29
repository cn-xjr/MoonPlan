///|
fn consecutive_coverage_request() -> @moonplan.CoverageRequest {
  {
    workers: [
      { id: 1, name: "An", skills: ["support"], available_slots: [9, 10, 11], },
      { id: 2, name: "Bo", skills: ["support"], available_slots: [9, 10, 11], },
    ],
    requirements: [
      {
        id: 20,
        name: "Early",
        slot: 9,
        required_skill: "support",
        workers_needed: 1,
      },
      {
        id: 21,
        name: "Middle",
        slot: 10,
        required_skill: "support",
        workers_needed: 1,
      },
      {
        id: 22,
        name: "Late",
        slot: 11,
        required_skill: "support",
        workers_needed: 1,
      },
    ],
    policy: @moonplan.RosterPolicy::default(),
  }
}

///|
test "coverage request limits consecutive assignments and retains demand ids" {
  let roster = consecutive_coverage_request()
    .solve_with_consecutive_limit(2)
    .unwrap()
  assert_eq(roster.entries.length(), 3)
  assert_eq(roster.entries[0].requirement.id, 20)
  assert_eq(roster.entries[1].requirement.id, 21)
  assert_eq(roster.entries[2].requirement.id, 22)
  assert_true(
    roster.entries[0].worker.id != roster.entries[2].worker.id ||
    roster.entries[1].worker.id != roster.entries[2].worker.id,
  )
}

///|
test "coverage consecutive rule detects impossible solo schedule" {
  let request = consecutive_coverage_request()
  let solo : @moonplan.CoverageRequest = {
    workers: [request.workers[0]],
    requirements: request.requirements,
    policy: request.policy,
  }
  assert_true(
    solo.solve_with_consecutive_limit(2) is Err(@moonplan.Unsatisfiable(_)),
  )
}

///|
test "coverage consecutive rule rejects non-positive limits" {
  assert_true(
    consecutive_coverage_request().solve_with_consecutive_limit(0)
    is Err(@moonplan.InvalidConsecutiveWorkLimit(0)),
  )
}
