///|
fn coverage_workers() -> Array[@moonplan.Worker] {
  [
    { id: 1, name: "Ada", skills: ["support"], available_slots: [9, 10], },
    { id: 2, name: "Bo", skills: ["support"], available_slots: [9, 10], },
    { id: 3, name: "Chen", skills: ["support"], available_slots: [9, 10], },
  ]
}

///|
test "fills every position in a coverage requirement" {
  let roster = @moonplan.build_coverage_roster(
    coverage_workers(),
    [
      {
        id: 10,
        name: "Morning support",
        slot: 9,
        required_skill: "support",
        workers_needed: 2,
      },
      {
        id: 20,
        name: "Midday support",
        slot: 10,
        required_skill: "support",
        workers_needed: 1,
      },
    ],
    @moonplan.RosterPolicy::default(),
  ).unwrap()
  let morning = roster.workers_for_requirement(10)
  assert_eq(morning.length(), 2)
  assert_true(morning[0].id != morning[1].id)
  assert_eq(roster.workers_for_requirement(20).length(), 1)
  assert_eq(roster.entries[0].position, 1)
  assert_eq(roster.entries[1].position, 2)
}

///|
test "applies workload policy to expanded coverage positions" {
  let roster = @moonplan.build_coverage_roster(
    coverage_workers(),
    [
      {
        id: 10,
        name: "Morning support",
        slot: 9,
        required_skill: "support",
        workers_needed: 2,
      },
      {
        id: 20,
        name: "Midday support",
        slot: 10,
        required_skill: "support",
        workers_needed: 1,
      },
    ],
    { max_shifts_per_worker: Some(1), minimum_slot_gap: 0, },
  ).unwrap()
  assert_eq(roster.entries.length(), 3)
  assert_true(roster.entries[0].worker.id != roster.entries[2].worker.id)
  assert_true(roster.entries[1].worker.id != roster.entries[2].worker.id)
}

///|
test "reports insufficient capacity for a coverage demand" {
  let workers : Array[@moonplan.Worker] = [
    { id: 1, name: "Ada", skills: ["support"], available_slots: [9], },
  ]
  assert_true(
    @moonplan.build_coverage_roster(
      workers,
      [
        {
          id: 10,
          name: "Morning support",
          slot: 9,
          required_skill: "support",
          workers_needed: 2,
        },
      ],
      @moonplan.RosterPolicy::default(),
    )
    is Err(@moonplan.InsufficientSlotCapacity(9, 2, 1)),
  )
}

///|
test "validates coverage requirement identifiers and worker counts" {
  let policy = @moonplan.RosterPolicy::default()
  assert_true(
    @moonplan.build_coverage_roster(
      coverage_workers(),
      [
        {
          id: 10,
          name: "Unused",
          slot: 9,
          required_skill: "support",
          workers_needed: 0,
        },
      ],
      policy,
    )
    is Err(@moonplan.InvalidCoverageWorkerCount(10, 0)),
  )
  assert_true(
    @moonplan.build_coverage_roster(
      coverage_workers(),
      [
        {
          id: 10,
          name: "First",
          slot: 9,
          required_skill: "support",
          workers_needed: 1,
        },
        {
          id: 10,
          name: "Duplicate",
          slot: 10,
          required_skill: "support",
          workers_needed: 1,
        },
      ],
      policy,
    )
    is Err(@moonplan.DuplicateCoverageRequirementId(10)),
  )
}

///|
test "accepts an empty coverage plan" {
  let roster = @moonplan.build_coverage_roster(
    coverage_workers(),
    [],
    @moonplan.RosterPolicy::default(),
  ).unwrap()
  assert_eq(roster.entries, [])
}
