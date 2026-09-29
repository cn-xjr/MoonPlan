///|
test "CSV export preserves position order and exact bytes" {
  let roster = @moonplan.build_coverage_roster(
    [
      { id: 1, name: "An", skills: ["support"], available_slots: [9], },
      { id: 2, name: "Bo", skills: ["support"], available_slots: [9], },
    ],
    [
      {
        id: 7,
        name: "Help",
        slot: 9,
        required_skill: "support",
        workers_needed: 2,
      },
    ],
    @moonplan.RosterPolicy::default(),
  ).unwrap()
  assert_eq(
    @moonplan.encode_coverage_roster_csv(roster),
    "requirement_id,requirement_name,slot,position,worker_id,worker_name\r\n7,Help,9,1,1,An\r\n7,Help,9,2,2,Bo",
  )
}

///|
test "CSV export quotes punctuation and blocks spreadsheet formulas in names" {
  let roster = @moonplan.build_coverage_roster(
    [{ id: 1, name: "=SUM(1,1)", skills: ["support"], available_slots: [9], }],
    [
      {
        id: 7,
        name: "Help, \"urgent\"\nline 2",
        slot: 9,
        required_skill: "support",
        workers_needed: 1,
      },
    ],
    @moonplan.RosterPolicy::default(),
  ).unwrap()
  assert_eq(
    @moonplan.encode_coverage_roster_csv(roster),
    "requirement_id,requirement_name,slot,position,worker_id,worker_name\r\n7,\"Help, \"\"urgent\"\"\nline 2\",9,1,1,\"'=SUM(1,1)\"",
  )
}

///|
test "empty CSV export contains only the header" {
  let roster = @moonplan.build_coverage_roster(
    [],
    [],
    @moonplan.RosterPolicy::default(),
  ).unwrap()
  assert_eq(
    @moonplan.encode_coverage_roster_csv(roster),
    "requirement_id,requirement_name,slot,position,worker_id,worker_name",
  )
}
