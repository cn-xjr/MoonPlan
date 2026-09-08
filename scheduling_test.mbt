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
    @moonplan.build_roster(workers, shifts) is Err(@moonplan.Unsatisfiable(_)),
  )
}
