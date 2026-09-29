///|
test "coverage preflight reports original demand id only once" {
  let analysis = @moonplan.analyze_coverage([], [
    {
      id: 42,
      name: "Help desk",
      slot: 9,
      required_skill: "support",
      workers_needed: 2,
    },
  ]).unwrap()
  assert_true(!analysis.is_feasible())
  assert_eq(
    analysis.issues[0],
    @moonplan.CoverageNoEligibleWorker(42, "Help desk"),
  )
  assert_eq(analysis.issues.length(), 2)
  assert_true(analysis.summary().contains("requirement 42"))
}

///|
test "coverage preflight detects skill bottleneck across demands" {
  let workers : Array[@moonplan.Worker] = [
    { id: 1, name: "An", skills: ["support"], available_slots: [9], },
    { id: 2, name: "Bo", skills: ["reception"], available_slots: [9], },
  ]
  let requirements : Array[@moonplan.CoverageRequirement] = [
    {
      id: 10,
      name: "Help",
      slot: 9,
      required_skill: "support",
      workers_needed: 2,
    },
    {
      id: 20,
      name: "Desk",
      slot: 9,
      required_skill: "reception",
      workers_needed: 1,
    },
  ]
  let analysis = @moonplan.analyze_coverage(workers, requirements).unwrap()
  assert_eq(analysis.issues, [@moonplan.CoverageSlotShortfall(9, 3, 2)])
}

///|
test "coverage preflight distinguishes capacity from policy feasibility" {
  let workers : Array[@moonplan.Worker] = [
    { id: 1, name: "An", skills: ["support"], available_slots: [9, 10], },
  ]
  let requirements : Array[@moonplan.CoverageRequirement] = [
    {
      id: 10,
      name: "Morning",
      slot: 9,
      required_skill: "support",
      workers_needed: 1,
    },
    {
      id: 20,
      name: "Evening",
      slot: 10,
      required_skill: "support",
      workers_needed: 1,
    },
  ]
  assert_true(
    @moonplan.analyze_coverage(workers, requirements).unwrap().is_feasible(),
  )
  assert_true(
    @moonplan.build_coverage_roster(workers, requirements, {
      max_shifts_per_worker: Some(1),
      minimum_slot_gap: 0,
    })
    is Err(_),
  )
}

///|
test "coverage preflight rejects invalid demand before expansion" {
  let requirements : Array[@moonplan.CoverageRequirement] = [
    { id: 7, name: "Invalid", slot: 0, required_skill: "x", workers_needed: 0, },
  ]
  assert_true(
    @moonplan.analyze_coverage([], requirements)
    is Err(@moonplan.InvalidCoverageWorkerCount(7, 0)),
  )
}
