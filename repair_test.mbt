///|
fn flexible_workers() -> Array[@moonplan.Worker] {
  [
    { id: 1, name: "Ada", skills: ["support"], available_slots: [9, 10, 11], },
    { id: 2, name: "Bo", skills: ["support"], available_slots: [9, 10, 11], },
  ]
}

///|
fn daily_shifts() -> Array[@moonplan.Shift] {
  [
    { id: 1, name: "Morning", slot: 9, required_skill: "support", },
    { id: 2, name: "Midday", slot: 10, required_skill: "support", },
    { id: 3, name: "Evening", slot: 11, required_skill: "support", },
  ]
}

///|
test "suggests the smallest feasible workload limit" {
  let plan = @moonplan.suggest_capped_roster_repairs(
    flexible_workers(),
    daily_shifts(),
    1,
  ).unwrap()
  assert_false(plan.is_feasible())
  assert_eq(plan.issues, [])
  assert_eq(plan.repairs, [@moonplan.RaiseWorkloadLimit(1, 2)])
  match plan.conflict {
    None => fail("a solver conflict must be retained")
    Some(conflict) => {
      assert_eq(conflict.items.length(), 2)
      assert_eq(conflict.items[0].name, Some("worker-1:workload-cap"))
      assert_eq(conflict.items[1].name, Some("worker-2:workload-cap"))
    }
  }
}

///|
test "turns preflight failures into concrete repairs" {
  let workers : Array[@moonplan.Worker] = []
  let shifts : Array[@moonplan.Shift] = [
    { id: 7, name: "Security", slot: 9, required_skill: "security", },
  ]
  let plan = @moonplan.suggest_capped_roster_repairs(workers, shifts, 1).unwrap()
  assert_eq(plan.issues.length(), 2)
  assert_eq(plan.repairs, [
    @moonplan.AddQualifiedWorker(7, "Security", "security"),
  ])
  assert_eq(
    plan.summary(),
    "add a worker with skill security who is available for shift 7 (Security)",
  )
  assert_true(plan.conflict is None)
}

///|
test "suggests additional capacity for a shared slot bottleneck" {
  let workers : Array[@moonplan.Worker] = [
    { id: 1, name: "Ada", skills: ["support"], available_slots: [9], },
  ]
  let shifts : Array[@moonplan.Shift] = [
    { id: 1, name: "Desk A", slot: 9, required_skill: "support", },
    { id: 2, name: "Desk B", slot: 9, required_skill: "support", },
  ]
  let plan = @moonplan.suggest_capped_roster_repairs(workers, shifts, 2).unwrap()
  assert_eq(plan.repairs, [@moonplan.AddSlotCapacity(9, 1)])
}

///|
test "returns no repairs for a feasible capped roster" {
  let plan = @moonplan.suggest_capped_roster_repairs(
    flexible_workers(),
    daily_shifts(),
    2,
  ).unwrap()
  assert_true(plan.is_feasible())
  assert_eq(plan.repairs, [])
}

///|
test "rejects a negative repair workload limit" {
  assert_true(
    @moonplan.suggest_capped_roster_repairs([], [], -1)
    is Err(@moonplan.InvalidWorkloadLimit(-1)),
  )
}
