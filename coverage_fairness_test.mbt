///|
fn fairness_request() -> @moonplan.CoverageRequest {
  {
    workers: [
      { id: 1, name: "Support", skills: ["support"], available_slots: [1, 2], },
      { id: 2, name: "Front A", skills: ["front"], available_slots: [3], },
      { id: 3, name: "Front B", skills: ["front"], available_slots: [3], },
    ],
    requirements: [
      {
        id: 1,
        name: "First support",
        slot: 1,
        required_skill: "support",
        workers_needed: 1,
      },
      {
        id: 2,
        name: "Second support",
        slot: 2,
        required_skill: "support",
        workers_needed: 1,
      },
      {
        id: 3,
        name: "Front",
        slot: 3,
        required_skill: "front",
        workers_needed: 1,
      },
    ],
    policy: { max_shifts_per_worker: Some(2), minimum_slot_gap: 0, },
  }
}

///|
test "fairness search proves an unavoidable workload spread" {
  match fairness_request().solve_fairest(1000).unwrap() {
    @moonplan.FairCoverageFound(result) => {
      assert_eq(result.balance.spread, 2)
      assert_eq(result.balance.maximum_load, 2)
      assert_true(result.windows_checked > 1)
      assert_eq(result.roster.entries.length(), 3)
    }
    _ => fail("the roster is feasible and has a provable minimum spread")
  }
}

///|
test "fairness search proves a perfectly balanced roster" {
  let request : @moonplan.CoverageRequest = {
    workers: [
      { id: 1, name: "An", skills: ["support"], available_slots: [1, 2], },
      { id: 2, name: "Bo", skills: ["support"], available_slots: [1, 2], },
    ],
    requirements: [
      {
        id: 1,
        name: "First",
        slot: 1,
        required_skill: "support",
        workers_needed: 1,
      },
      {
        id: 2,
        name: "Second",
        slot: 2,
        required_skill: "support",
        workers_needed: 1,
      },
    ],
    policy: { max_shifts_per_worker: Some(2), minimum_slot_gap: 0, },
  }
  match request.solve_fairest(100).unwrap() {
    @moonplan.FairCoverageFound(result) => {
      assert_eq(result.balance.spread, 0)
      assert_eq(result.windows_checked, 1)
    }
    _ => fail("one shift per worker is possible")
  }
}

///|
test "fairness search never claims an optimum after budget exhaustion" {
  match fairness_request().solve_fairest(1).unwrap() {
    @moonplan.FairCoverageBudgetExhausted(stats, windows_checked) => {
      assert_eq(stats.nodes, 1)
      assert_eq(windows_checked, 1)
    }
    _ => fail("one attempted assignment cannot prove the optimum")
  }
}

///|
test "fairness search proves infeasibility under a zero workload cap" {
  let base = fairness_request()
  let request : @moonplan.CoverageRequest = {
    workers: base.workers,
    requirements: base.requirements,
    policy: { max_shifts_per_worker: Some(0), minimum_slot_gap: 0, },
  }
  assert_true(
    request.solve_fairest(1000).unwrap()
    is @moonplan.FairCoverageProvedUnsatisfiable(_, _),
  )
}
