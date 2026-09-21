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

///|
test "trades assignment preference against consecutive work" {
  let shifts : Array[@moonplan.Shift] = [
    { id: 1, name: "Morning", slot: 9, required_skill: "support", },
    { id: 2, name: "Midday", slot: 10, required_skill: "support", },
  ]
  let objective : @moonplan.RosterObjective = {
    assignment_penalties: [
      { worker_id: 2, shift_id: 1, penalty: 5, },
      { worker_id: 2, shift_id: 2, penalty: 5, },
    ],
    consecutive_slot_penalty: 20,
  }
  let result = @moonplan.build_preferred_roster_with_objective(
    preference_workers(),
    shifts,
    @moonplan.RosterPolicy::default(),
    objective,
    4,
  ).unwrap()
  assert_eq(result.total_penalty, 5)
  assert_eq(result.objective_order, @moonplan.WeightedTotal)
  assert_eq(result.roster.worker_for_shift(1).unwrap().name, "Ada")
  assert_eq(result.roster.worker_for_shift(2).unwrap().name, "Bo")
}

///|
test "can prioritize assignment preferences over consecutive work" {
  let shifts : Array[@moonplan.Shift] = [
    { id: 1, name: "Morning", slot: 9, required_skill: "support", },
    { id: 2, name: "Midday", slot: 10, required_skill: "support", },
  ]
  let objective : @moonplan.RosterObjective = {
    assignment_penalties: [
      { worker_id: 2, shift_id: 1, penalty: 1, },
      { worker_id: 2, shift_id: 2, penalty: 1, },
    ],
    consecutive_slot_penalty: 10,
  }
  let weighted = @moonplan.build_preferred_roster_with_objective(
    preference_workers(),
    shifts,
    @moonplan.RosterPolicy::default(),
    objective,
    4,
  ).unwrap()
  let prioritized = @moonplan.build_preferred_roster_with_order(
    preference_workers(),
    shifts,
    @moonplan.RosterPolicy::default(),
    objective,
    @moonplan.AssignmentThenConsecutive,
    4,
  ).unwrap()
  assert_eq(weighted.penalty_breakdown.assignment_total, 1)
  assert_eq(weighted.penalty_breakdown.consecutive_slot_total, 0)
  assert_eq(prioritized.penalty_breakdown.assignment_total, 0)
  assert_eq(prioritized.penalty_breakdown.consecutive_slot_total, 10)
  assert_eq(prioritized.objective_order, @moonplan.AssignmentThenConsecutive)
}

///|
test "can prioritize consecutive work over assignment preferences" {
  let shifts : Array[@moonplan.Shift] = [
    { id: 1, name: "Morning", slot: 9, required_skill: "support", },
    { id: 2, name: "Midday", slot: 10, required_skill: "support", },
  ]
  let objective : @moonplan.RosterObjective = {
    assignment_penalties: [
      { worker_id: 2, shift_id: 1, penalty: 100, },
      { worker_id: 2, shift_id: 2, penalty: 100, },
    ],
    consecutive_slot_penalty: 1,
  }
  let weighted = @moonplan.build_preferred_roster_with_objective(
    preference_workers(),
    shifts,
    @moonplan.RosterPolicy::default(),
    objective,
    4,
  ).unwrap()
  let prioritized = @moonplan.build_preferred_roster_with_order(
    preference_workers(),
    shifts,
    @moonplan.RosterPolicy::default(),
    objective,
    @moonplan.ConsecutiveThenAssignment,
    4,
  ).unwrap()
  assert_eq(weighted.penalty_breakdown.assignment_total, 0)
  assert_eq(weighted.penalty_breakdown.consecutive_slot_total, 1)
  assert_eq(prioritized.penalty_breakdown.assignment_total, 100)
  assert_eq(prioritized.penalty_breakdown.consecutive_slot_total, 0)
  assert_eq(prioritized.objective_order, @moonplan.ConsecutiveThenAssignment)
}

///|
test "charges every adjacent pair in a work sequence" {
  let workers : Array[@moonplan.Worker] = [
    { id: 1, name: "Ada", skills: ["support"], available_slots: [9, 10, 11], },
  ]
  let shifts : Array[@moonplan.Shift] = [
    { id: 1, name: "Morning", slot: 9, required_skill: "support", },
    { id: 2, name: "Midday", slot: 10, required_skill: "support", },
    { id: 3, name: "Evening", slot: 11, required_skill: "support", },
  ]
  let result = @moonplan.build_preferred_roster_with_objective(
    workers,
    shifts,
    @moonplan.RosterPolicy::default(),
    { assignment_penalties: [], consecutive_slot_penalty: 7, },
    1,
  ).unwrap()
  assert_eq(result.total_penalty, 14)
  assert_eq(result.penalty_breakdown.assignment_total, 0)
  assert_eq(result.penalty_breakdown.consecutive_slot_total, 14)
  assert_eq(result.penalty_breakdown.consecutive_slot_charges.length(), 2)
  assert_eq(result.penalty_breakdown.consecutive_slot_charges[0], {
    worker_id: 1,
    earlier_shift_id: 1,
    later_shift_id: 2,
    penalty: 7,
  })
  assert_eq(result.penalty_breakdown.consecutive_slot_charges[1], {
    worker_id: 1,
    earlier_shift_id: 2,
    later_shift_id: 3,
    penalty: 7,
  })
}

///|
test "explains assignment and consecutive slot costs separately" {
  let workers : Array[@moonplan.Worker] = [
    { id: 1, name: "Ada", skills: ["support"], available_slots: [9, 10], },
  ]
  let shifts : Array[@moonplan.Shift] = [
    { id: 1, name: "Morning", slot: 9, required_skill: "support", },
    { id: 2, name: "Midday", slot: 10, required_skill: "support", },
  ]
  let result = @moonplan.build_preferred_roster_with_objective(
    workers,
    shifts,
    @moonplan.RosterPolicy::default(),
    {
      assignment_penalties: [{ worker_id: 1, shift_id: 2, penalty: 5, }],
      consecutive_slot_penalty: 7,
    },
    1,
  ).unwrap()
  let breakdown = result.penalty_breakdown
  assert_eq(breakdown.assignment_total, 5)
  assert_eq(breakdown.consecutive_slot_total, 7)
  assert_eq(breakdown.total_penalty, result.total_penalty)
  assert_eq(breakdown.assignment_charges, [
    { worker_id: 1, shift_id: 2, penalty: 5, },
  ])
  assert_eq(breakdown.consecutive_slot_charges, [
    { worker_id: 1, earlier_shift_id: 1, later_shift_id: 2, penalty: 7, },
  ])
}

///|
test "orders consecutive shift evidence by slot rather than input order" {
  let workers : Array[@moonplan.Worker] = [
    { id: 1, name: "Ada", skills: ["support"], available_slots: [9, 10], },
  ]
  let shifts : Array[@moonplan.Shift] = [
    { id: 2, name: "Midday", slot: 10, required_skill: "support", },
    { id: 1, name: "Morning", slot: 9, required_skill: "support", },
  ]
  let result = @moonplan.build_preferred_roster_with_objective(
    workers,
    shifts,
    @moonplan.RosterPolicy::default(),
    { assignment_penalties: [], consecutive_slot_penalty: 3, },
    1,
  ).unwrap()
  assert_eq(result.penalty_breakdown.consecutive_slot_charges, [
    { worker_id: 1, earlier_shift_id: 1, later_shift_id: 2, penalty: 3, },
  ])
}

///|
test "does not charge separated shifts as consecutive" {
  let shifts : Array[@moonplan.Shift] = [
    { id: 1, name: "Morning", slot: 9, required_skill: "support", },
    { id: 2, name: "Evening", slot: 11, required_skill: "support", },
  ]
  let result = @moonplan.build_preferred_roster_with_objective(
    preference_workers(),
    shifts,
    @moonplan.RosterPolicy::default(),
    { assignment_penalties: [], consecutive_slot_penalty: 7, },
    1,
  ).unwrap()
  assert_eq(result.total_penalty, 0)
  assert_eq(result.penalty_breakdown.assignment_charges, [])
  assert_eq(result.penalty_breakdown.consecutive_slot_charges, [])
}

///|
test "rejects a negative consecutive slot penalty" {
  assert_true(
    @moonplan.build_preferred_roster_with_objective(
      preference_workers(),
      [],
      @moonplan.RosterPolicy::default(),
      { assignment_penalties: [], consecutive_slot_penalty: -1, },
      1,
    )
    is Err(@moonplan.InvalidConsecutiveSlotPenalty(-1)),
  )
}
