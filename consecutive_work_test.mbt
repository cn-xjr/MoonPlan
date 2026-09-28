///|
fn consecutive_workers() -> Array[@moonplan.Worker] {
  [
    { id: 1, name: "Ada", skills: ["support"], available_slots: [9, 10, 11], },
    { id: 2, name: "Bo", skills: ["support"], available_slots: [9, 10, 11], },
  ]
}

///|
fn consecutive_shifts() -> Array[@moonplan.Shift] {
  [
    { id: 1, name: "Morning", slot: 9, required_skill: "support", },
    { id: 2, name: "Midday", slot: 10, required_skill: "support", },
    { id: 3, name: "Evening", slot: 11, required_skill: "support", },
  ]
}

///|
test "limits consecutive occupied slots" {
  let roster = @moonplan.build_roster_with_consecutive_limit(
    consecutive_workers(),
    consecutive_shifts(),
    @moonplan.RosterPolicy::default(),
    2,
  ).unwrap()
  assert_true(roster.assignment_count(1) <= 2)
  assert_true(roster.assignment_count(2) <= 2)
}

///|
test "reports an impossible consecutive work limit" {
  let workers : Array[@moonplan.Worker] = [
    { id: 1, name: "Solo", skills: ["support"], available_slots: [9, 10], },
  ]
  let shifts : Array[@moonplan.Shift] = [
    { id: 1, name: "Morning", slot: 9, required_skill: "support", },
    { id: 2, name: "Midday", slot: 10, required_skill: "support", },
  ]
  assert_true(
    @moonplan.build_roster_with_consecutive_limit(
      workers,
      shifts,
      @moonplan.RosterPolicy::default(),
      1,
    )
    is Err(@moonplan.Unsatisfiable(_)),
  )
}

///|
test "allows separated slots with a limit of one" {
  let workers : Array[@moonplan.Worker] = [
    { id: 1, name: "Solo", skills: ["support"], available_slots: [9, 11], },
  ]
  let shifts : Array[@moonplan.Shift] = [
    { id: 1, name: "Morning", slot: 9, required_skill: "support", },
    { id: 2, name: "Evening", slot: 11, required_skill: "support", },
  ]
  let roster = @moonplan.build_roster_with_consecutive_limit(
    workers,
    shifts,
    @moonplan.RosterPolicy::default(),
    1,
  ).unwrap()
  assert_eq(roster.assignment_count(1), 2)
}

///|
test "combines consecutive and workload limits" {
  let roster = @moonplan.build_roster_with_consecutive_limit(
    consecutive_workers(),
    consecutive_shifts(),
    { max_shifts_per_worker: Some(2), minimum_slot_gap: 0, },
    2,
  ).unwrap()
  assert_eq(roster.entries.length(), 3)
  assert_true(roster.assignment_count(1) <= 2)
  assert_true(roster.assignment_count(2) <= 2)
}

///|
test "rejects a non-positive consecutive work limit" {
  assert_true(
    @moonplan.build_roster_with_consecutive_limit(
      consecutive_workers(),
      [],
      @moonplan.RosterPolicy::default(),
      0,
    )
    is Err(@moonplan.InvalidConsecutiveWorkLimit(0)),
  )
  assert_true(
    @moonplan.build_roster_with_consecutive_limit(
      consecutive_workers(),
      [],
      @moonplan.RosterPolicy::default(),
      -1,
    )
    is Err(@moonplan.InvalidConsecutiveWorkLimit(-1)),
  )
}
