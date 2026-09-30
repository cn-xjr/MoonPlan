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

///|
test "coverage preflight finds a cross-slot skill bottleneck" {
  let workers : Array[@moonplan.Worker] = [
    { id: 1, name: "S1", skills: ["support"], available_slots: [1, 2], },
    { id: 2, name: "S2", skills: ["support"], available_slots: [1, 2], },
    { id: 3, name: "F1", skills: ["front"], available_slots: [1, 2], },
    { id: 4, name: "F2", skills: ["front"], available_slots: [1, 2], },
    { id: 5, name: "F3", skills: ["front"], available_slots: [1, 2], },
  ]
  let requirements : Array[@moonplan.CoverageRequirement] = [
    {
      id: 11,
      name: "Morning support",
      slot: 1,
      required_skill: "support",
      workers_needed: 2,
    },
    {
      id: 12,
      name: "Later support",
      slot: 2,
      required_skill: "support",
      workers_needed: 1,
    },
    {
      id: 13,
      name: "Later front",
      slot: 2,
      required_skill: "front",
      workers_needed: 1,
    },
  ]
  let policy : @moonplan.RosterPolicy = {
    max_shifts_per_worker: Some(1),
    minimum_slot_gap: 0,
  }
  assert_true(
    @moonplan.analyze_coverage(workers, requirements).unwrap().is_feasible(),
  )
  let analysis = @moonplan.analyze_coverage_with_policy(
    workers, requirements, policy,
  ).unwrap()
  assert_eq(analysis.issues, [@moonplan.CoveragePolicyShortfall(4, 3)])
  let encoded = @moonplan.encode_coverage_analysis(analysis, 0)
  assert_true(encoded.contains("policy_shortfall"))
  assert_true(encoded.contains("\"assignable\":3"))
}

///|
test "cross-slot capacity accepts an additional qualified worker" {
  let workers : Array[@moonplan.Worker] = [
    { id: 1, name: "S1", skills: ["support"], available_slots: [1, 2], },
    { id: 2, name: "S2", skills: ["support"], available_slots: [1, 2], },
    { id: 3, name: "S3", skills: ["support"], available_slots: [2], },
    { id: 4, name: "F1", skills: ["front"], available_slots: [2], },
  ]
  let requirements : Array[@moonplan.CoverageRequirement] = [
    {
      id: 11,
      name: "Morning support",
      slot: 1,
      required_skill: "support",
      workers_needed: 2,
    },
    {
      id: 12,
      name: "Later support",
      slot: 2,
      required_skill: "support",
      workers_needed: 1,
    },
    {
      id: 13,
      name: "Later front",
      slot: 2,
      required_skill: "front",
      workers_needed: 1,
    },
  ]
  let policy : @moonplan.RosterPolicy = {
    max_shifts_per_worker: Some(1),
    minimum_slot_gap: 0,
  }
  assert_true(
    @moonplan.analyze_coverage_with_policy(workers, requirements, policy)
    .unwrap()
    .is_feasible(),
  )
  assert_eq(
    @moonplan.build_coverage_roster(workers, requirements, policy).unwrap().entries.length(),
    4,
  )
}

///|
test "workload preflight treats an empty skill requirement as open to all" {
  let workers : Array[@moonplan.Worker] = [
    { id: 1, name: "Generalist", skills: [], available_slots: [1], },
  ]
  let requirements : Array[@moonplan.CoverageRequirement] = [
    {
      id: 1,
      name: "Open desk",
      slot: 1,
      required_skill: "",
      workers_needed: 1,
    },
  ]
  let policy : @moonplan.RosterPolicy = {
    max_shifts_per_worker: Some(1),
    minimum_slot_gap: 0,
  }
  assert_true(
    @moonplan.analyze_coverage_with_policy(workers, requirements, policy)
    .unwrap()
    .is_feasible(),
  )
  assert_eq(
    @moonplan.build_coverage_roster(workers, requirements, policy).unwrap().entries.length(),
    1,
  )
}

///|
test "capacity preflight agrees with exact solver on small skill combinations" {
  let requirements : Array[@moonplan.CoverageRequirement] = [
    {
      id: 1,
      name: "Support",
      slot: 1,
      required_skill: "support",
      workers_needed: 1,
    },
    {
      id: 2,
      name: "Front",
      slot: 2,
      required_skill: "front",
      workers_needed: 1,
    },
  ]
  let policy : @moonplan.RosterPolicy = {
    max_shifts_per_worker: Some(1),
    minimum_slot_gap: 0,
  }
  for case_index = 0; case_index < 64; case_index = case_index + 1 {
    let workers : Array[@moonplan.Worker] = []
    let mut code = case_index
    for index = 0; index < 3; index = index + 1 {
      let skills : Array[String] = match code % 4 {
        0 => []
        1 => ["support"]
        2 => ["front"]
        _ => ["support", "front"]
      }
      workers.push({
        id: index + 1,
        name: "Worker \{index}",
        skills,
        available_slots: [1, 2],
      })
      code = code / 4
    }
    let preflight = @moonplan.analyze_coverage_with_policy(
        workers, requirements, policy,
      )
      .unwrap()
      .is_feasible()
    let solved = @moonplan.build_coverage_roster(workers, requirements, policy)
      is Ok(_)
    if preflight != solved {
      fail("preflight disagrees with solver for skill case \{case_index}")
    }
  }
}
