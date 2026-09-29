///|
test "seven-day example fills every position without exceeding four shifts" {
  let request = weekly_request()
  let roster = request.solve().unwrap()
  assert_eq(request.requirements.length(), 14)
  assert_eq(roster.entries.length(), 21)
  let loads = [0, 0, 0, 0, 0, 0]
  for requirement in request.requirements {
    let assigned = roster.workers_for_requirement(requirement.id)
    assert_eq(assigned.length(), requirement.workers_needed)
    if requirement.workers_needed == 2 {
      assert_true(assigned[0].id != assigned[1].id)
    }
  }
  for entry in roster.entries {
    let worker = entry.worker
    assert_true(worker.available_slots.contains(entry.requirement.slot))
    assert_true(worker.skills.contains(entry.requirement.required_skill))
    loads[worker.id - 1] += 1
  }
  for load in loads {
    assert_true(load <= 4)
  }
}
