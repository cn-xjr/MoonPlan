///|
test "preflight accepts a schedulable roster" {
  let workers : Array[@moonplan.Worker] = [
    { id: 1, name: "Ada", skills: ["frontdesk"], available_slots: [9], },
    { id: 2, name: "Bo", skills: ["support"], available_slots: [9], },
  ]
  let shifts : Array[@moonplan.Shift] = [
    { id: 1, name: "Reception", slot: 9, required_skill: "frontdesk", },
    { id: 2, name: "Help desk", slot: 9, required_skill: "support", },
  ]
  let analysis = @moonplan.analyze_roster(workers, shifts)
  assert_true(analysis.is_feasible())
  assert_eq(analysis.issues, [])
}

///|
test "preflight explains a skill bottleneck with matching" {
  let workers : Array[@moonplan.Worker] = [
    { id: 1, name: "Ada", skills: ["support"], available_slots: [9], },
    { id: 2, name: "Bo", skills: ["frontdesk"], available_slots: [9], },
  ]
  let shifts : Array[@moonplan.Shift] = [
    { id: 1, name: "Support A", slot: 9, required_skill: "support", },
    { id: 2, name: "Support B", slot: 9, required_skill: "support", },
  ]
  let analysis = @moonplan.analyze_roster(workers, shifts)
  assert_false(analysis.is_feasible())
  assert_true(analysis.issues[0] is @moonplan.SlotCoverageShortfall(9, 2, 1))
}

///|
test "preflight returns multiple independent issues" {
  let workers : Array[@moonplan.Worker] = [
    { id: 1, name: "Ada", skills: ["support"], available_slots: [9], },
    { id: 1, name: "Duplicate", skills: [], available_slots: [], },
  ]
  let shifts : Array[@moonplan.Shift] = [
    { id: 7, name: "Security", slot: 10, required_skill: "security", },
  ]
  let analysis = @moonplan.analyze_roster(workers, shifts)
  assert_eq(analysis.issues.length(), 3)
  assert_true(analysis.issues[0] is @moonplan.DuplicateWorkerIdFound(1))
  assert_true(
    analysis.issues[1] is @moonplan.NoEligibleWorkerFound(7, "Security"),
  )
  assert_true(analysis.issues[2] is @moonplan.SlotCoverageShortfall(10, 1, 0))
}
