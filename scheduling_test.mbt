///|
fn demo_workers() -> Array[@moonplan.Worker] {
  [
    { id: 10, name: "Ada", skills: ["frontdesk"], available_slots: [9], },
    { id: 20, name: "Bo", skills: ["support"], available_slots: [9], },
    {
      id: 30,
      name: "Chen",
      skills: ["frontdesk", "support"],
      available_slots: [9, 10],
    },
  ]
}

///|
test "builds a roster from skills and availability" {
  let shifts : Array[@moonplan.Shift] = [
    { id: 1, name: "Reception", slot: 9, required_skill: "frontdesk", },
    { id: 2, name: "Help desk", slot: 9, required_skill: "support", },
    { id: 3, name: "Late support", slot: 10, required_skill: "support", },
  ]
  let roster = @moonplan.build_roster(demo_workers(), shifts).unwrap()
  assert_eq(roster.worker_for_shift(1).unwrap().name, "Ada")
  assert_eq(roster.worker_for_shift(2).unwrap().name, "Bo")
  assert_eq(roster.worker_for_shift(3).unwrap().name, "Chen")
}

///|
test "rejects shifts without an eligible worker" {
  let shifts : Array[@moonplan.Shift] = [
    { id: 7, name: "Security", slot: 9, required_skill: "security", },
  ]
  assert_true(
    @moonplan.build_roster(demo_workers(), shifts)
    is Err(@moonplan.NoEligibleWorker(7, "Security")),
  )
}

///|
test "detects same-slot capacity conflicts" {
  let workers : Array[@moonplan.Worker] = [
    { id: 1, name: "Solo", skills: ["support"], available_slots: [9], },
  ]
  let shifts : Array[@moonplan.Shift] = [
    { id: 1, name: "A", slot: 9, required_skill: "support", },
    { id: 2, name: "B", slot: 9, required_skill: "support", },
  ]
  assert_true(
    @moonplan.build_roster(workers, shifts)
    is Err(@moonplan.InsufficientSlotCapacity(9, 2, 1)),
  )
}

///|
test "balances workload across feasible candidates" {
  let workers : Array[@moonplan.Worker] = [
    { id: 1, name: "Ada", skills: ["support"], available_slots: [9, 10, 11], },
    { id: 2, name: "Bo", skills: ["support"], available_slots: [9, 10, 11], },
  ]
  let shifts : Array[@moonplan.Shift] = [
    { id: 1, name: "Morning", slot: 9, required_skill: "support", },
    { id: 2, name: "Midday", slot: 10, required_skill: "support", },
    { id: 3, name: "Evening", slot: 11, required_skill: "support", },
  ]
  let first = @moonplan.build_roster(workers, shifts).unwrap()
  assert_eq(first.assignment_count(1), 3)
  let optimized = @moonplan.build_balanced_roster(workers, shifts, 8).unwrap()
  assert_eq(optimized.balance.spread, 1)
  assert_eq(optimized.balance.maximum_load, 2)
  assert_eq(optimized.candidates_evaluated, 8)
  assert_eq(optimized.roster.assignment_count(1), 2)
  assert_eq(optimized.roster.assignment_count(2), 1)
}

///|
test "rejects a non-positive optimization budget" {
  assert_true(
    @moonplan.build_balanced_roster(demo_workers(), [], 0)
    is Err(@moonplan.InvalidCandidateLimit(0)),
  )
}

///|
test "enforces a hard workload cap" {
  let workers : Array[@moonplan.Worker] = [
    { id: 1, name: "Ada", skills: ["support"], available_slots: [9, 10, 11], },
    { id: 2, name: "Bo", skills: ["support"], available_slots: [9, 10, 11], },
  ]
  let shifts : Array[@moonplan.Shift] = [
    { id: 1, name: "Morning", slot: 9, required_skill: "support", },
    { id: 2, name: "Midday", slot: 10, required_skill: "support", },
    { id: 3, name: "Evening", slot: 11, required_skill: "support", },
  ]
  let roster = @moonplan.build_capped_roster(workers, shifts, 2).unwrap()
  assert_true(roster.assignment_count(1) <= 2)
  assert_true(roster.assignment_count(2) <= 2)
}

///|
test "reports when a workload cap makes the roster impossible" {
  let workers : Array[@moonplan.Worker] = [
    { id: 1, name: "Solo", skills: ["support"], available_slots: [9, 10, 11], },
  ]
  let shifts : Array[@moonplan.Shift] = [
    { id: 1, name: "Morning", slot: 9, required_skill: "support", },
    { id: 2, name: "Midday", slot: 10, required_skill: "support", },
    { id: 3, name: "Evening", slot: 11, required_skill: "support", },
  ]
  assert_true(
    @moonplan.build_capped_roster(workers, shifts, 2)
    is Err(@moonplan.Unsatisfiable(_)),
  )
}

///|
test "rejects a negative workload cap" {
  assert_true(
    @moonplan.build_capped_roster(demo_workers(), [], -1)
    is Err(@moonplan.InvalidWorkloadLimit(-1)),
  )
}

///|
test "accepts an empty roster with a zero workload cap" {
  let roster = @moonplan.build_capped_roster(demo_workers(), [], 0).unwrap()
  assert_eq(roster.entries.length(), 0)
}
