///|
fn budget_coverage_request() -> @moonplan.CoverageRequest {
  {
    workers: [
      { id: 1, name: "An", skills: ["support"], available_slots: [9, 10], },
      { id: 2, name: "Bo", skills: ["support"], available_slots: [9, 10], },
    ],
    requirements: [
      {
        id: 7,
        name: "Desk",
        slot: 9,
        required_skill: "support",
        workers_needed: 2,
      },
    ],
    policy: { max_shifts_per_worker: Some(1), minimum_slot_gap: 0, },
  }
}

///|
test "coverage search reports an incomplete budget" {
  let request = budget_coverage_request()
  match request.solve_with_node_limit(1).unwrap() {
    @moonplan.CoverageBudgetExhausted(stats) => {
      assert_eq(stats.nodes, 1)
      assert_eq(stats.solutions, 0)
    }
    _ => fail("one assignment cannot fill two positions")
  }
}

///|
test "coverage search finds a roster at the exact budget" {
  let request = budget_coverage_request()
  match request.solve_with_node_limit(2).unwrap() {
    @moonplan.CoverageFound(roster) => {
      assert_eq(roster.entries.length(), 2)
      assert_eq(roster.stats.nodes, 2)
      assert_eq(roster.workers_for_requirement(7).length(), 2)
    }
    _ => fail("two assignments should fill two positions")
  }
}

///|
test "coverage search can prove infeasibility without a preflight shortcut" {
  let base = budget_coverage_request()
  let request : @moonplan.CoverageRequest = {
    workers: base.workers,
    requirements: [
      {
        id: 8,
        name: "Morning",
        slot: 9,
        required_skill: "support",
        workers_needed: 2,
      },
      {
        id: 9,
        name: "Afternoon",
        slot: 10,
        required_skill: "support",
        workers_needed: 1,
      },
    ],
    policy: base.policy,
  }
  match request.solve_with_node_limit(100).unwrap() {
    @moonplan.CoverageProvedUnsatisfiable(stats) =>
      assert_eq(stats.solutions, 0)
    _ => fail("two one-shift workers cannot fill three positions")
  }
}

///|
test "coverage search validates budget separately from feasibility" {
  assert_true(
    budget_coverage_request().solve_with_node_limit(0)
    is Err(@moonplan.InvalidModel(@moonplan.InvalidNodeLimit(0))),
  )
}
