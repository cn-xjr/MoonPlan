///|
fn preference_workers() -> Array[@moonplan.Worker] {
  [
    { id: 1, name: "Ada", skills: ["support"], available_slots: [9, 10, 11], },
    { id: 2, name: "Bo", skills: ["support"], available_slots: [9, 10, 11], },
  ]
}

///|
test "avoids a penalized assignment" {
  let shifts : Array[@moonplan.Shift] = [
    { id: 1, name: "Morning", slot: 9, required_skill: "support", },
    { id: 2, name: "Midday", slot: 10, required_skill: "support", },
  ]
  let penalties : Array[@moonplan.AssignmentPenalty] = [
    { worker_id: 1, shift_id: 2, penalty: 10, },
  ]
  let result = @moonplan.build_preferred_roster(
    preference_workers(),
    shifts,
    @moonplan.RosterPolicy::default(),
    penalties,
    4,
  ).unwrap()
  assert_eq(result.total_penalty, 0)
  assert_eq(result.balance.spread, 0)
  assert_eq(result.roster.worker_for_shift(1).unwrap().name, "Ada")
  assert_eq(result.roster.worker_for_shift(2).unwrap().name, "Bo")
}

///|
test "respects hard rest rules while optimizing preferences" {
  let shifts : Array[@moonplan.Shift] = [
    { id: 1, name: "Morning", slot: 9, required_skill: "support", },
    { id: 2, name: "Midday", slot: 10, required_skill: "support", },
  ]
  let penalties : Array[@moonplan.AssignmentPenalty] = [
    { worker_id: 2, shift_id: 1, penalty: 5, },
    { worker_id: 2, shift_id: 2, penalty: 1, },
  ]
  let policy : @moonplan.RosterPolicy = {
    max_shifts_per_worker: None,
    minimum_slot_gap: 2,
  }
  let result = @moonplan.build_preferred_roster(
    preference_workers(),
    shifts,
    policy,
    penalties,
    4,
  ).unwrap()
  assert_eq(result.total_penalty, 1)
  assert_eq(result.roster.worker_for_shift(1).unwrap().name, "Ada")
  assert_eq(result.roster.worker_for_shift(2).unwrap().name, "Bo")
}

///|
test "uses workload balance to break equal penalty ties" {
  let shifts : Array[@moonplan.Shift] = [
    { id: 1, name: "Morning", slot: 9, required_skill: "support", },
    { id: 2, name: "Midday", slot: 10, required_skill: "support", },
    { id: 3, name: "Evening", slot: 11, required_skill: "support", },
  ]
  let result = @moonplan.build_preferred_roster(
    preference_workers(),
    shifts,
    @moonplan.RosterPolicy::default(),
    [],
    8,
  ).unwrap()
  assert_eq(result.total_penalty, 0)
  assert_eq(result.balance.spread, 1)
  assert_eq(result.balance.maximum_load, 2)
}

///|
test "validates assignment penalty references and values" {
  let shifts : Array[@moonplan.Shift] = [
    { id: 1, name: "Morning", slot: 9, required_skill: "support", },
  ]
  let policy = @moonplan.RosterPolicy::default()
  assert_true(
    @moonplan.build_preferred_roster(
      preference_workers(),
      shifts,
      policy,
      [{ worker_id: 99, shift_id: 1, penalty: 1, }],
      2,
    )
    is Err(@moonplan.UnknownPenaltyWorker(99)),
  )
  assert_true(
    @moonplan.build_preferred_roster(
      preference_workers(),
      shifts,
      policy,
      [{ worker_id: 1, shift_id: 99, penalty: 1, }],
      2,
    )
    is Err(@moonplan.UnknownPenaltyShift(99)),
  )
  assert_true(
    @moonplan.build_preferred_roster(
      preference_workers(),
      shifts,
      policy,
      [{ worker_id: 1, shift_id: 1, penalty: -1, }],
      2,
    )
    is Err(@moonplan.InvalidAssignmentPenalty(1, 1, -1)),
  )
  assert_true(
    @moonplan.build_preferred_roster(
      preference_workers(),
      shifts,
      policy,
      [
        { worker_id: 1, shift_id: 1, penalty: 1, },
        { worker_id: 1, shift_id: 1, penalty: 2, },
      ],
      2,
    )
    is Err(@moonplan.DuplicateAssignmentPenalty(1, 1)),
  )
  assert_true(
    @moonplan.build_preferred_roster(
      preference_workers(),
      shifts,
      policy,
      [],
      0,
    )
    is Err(@moonplan.InvalidCandidateLimit(0)),
  )
}
