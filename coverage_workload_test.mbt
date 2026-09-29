///|
fn workload_coverage() -> (
  Array[@moonplan.Worker],
  Array[@moonplan.CoverageRequirement],
) {
  let workers : Array[@moonplan.Worker] = [
    { id: 1, name: "An", skills: ["support"], available_slots: [9, 10, 11], },
    { id: 2, name: "Bo", skills: ["support"], available_slots: [9, 10, 11], },
  ]
  let requirements : Array[@moonplan.CoverageRequirement] = [
    {
      id: 21,
      name: "Early",
      slot: 9,
      required_skill: "support",
      workers_needed: 1,
    },
    {
      id: 22,
      name: "Middle",
      slot: 10,
      required_skill: "support",
      workers_needed: 1,
    },
    {
      id: 23,
      name: "Late",
      slot: 11,
      required_skill: "support",
      workers_needed: 1,
    },
  ]
  (workers, requirements)
}

///|
test "coverage preflight finds aggregate workload shortfall" {
  let (workers, requirements) = workload_coverage()
  assert_true(
    @moonplan.analyze_coverage(workers, requirements).unwrap().is_feasible(),
  )
  let analysis = @moonplan.analyze_coverage_with_policy(workers, requirements, {
    max_shifts_per_worker: Some(1),
    minimum_slot_gap: 0,
  }).unwrap()
  assert_eq(analysis.issues, [@moonplan.CoverageWorkloadShortfall(3, 2)])
  let output = @moonplan.encode_coverage_analysis(analysis, 0)
  assert_true(output.contains("\"code\":\"workload_shortfall\""))
  assert_true(output.contains("\"required\":3"))
  assert_true(output.contains("\"assignable\":2"))
}

///|
test "coverage workload preflight does not reject sufficient upper bound" {
  let (workers, requirements) = workload_coverage()
  assert_true(
    @moonplan.analyze_coverage_with_policy(workers, requirements, {
      max_shifts_per_worker: Some(2),
      minimum_slot_gap: 0,
    })
    .unwrap()
    .is_feasible(),
  )
}

///|
test "coverage workload preflight validates the policy" {
  let (workers, requirements) = workload_coverage()
  assert_true(
    @moonplan.analyze_coverage_with_policy(workers, requirements, {
      max_shifts_per_worker: Some(-1),
      minimum_slot_gap: 0,
    })
    is Err(@moonplan.InvalidWorkloadLimit(-1)),
  )
}

///|
test "zero workload allowance is a valid but insufficient policy" {
  let (workers, requirements) = workload_coverage()
  let analysis = @moonplan.analyze_coverage_with_policy(workers, requirements, {
    max_shifts_per_worker: Some(0),
    minimum_slot_gap: 0,
  }).unwrap()
  assert_eq(analysis.issues, [@moonplan.CoverageWorkloadShortfall(3, 0)])
}
