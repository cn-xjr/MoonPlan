///|
test "records a deterministic successful search trace" {
  let problem = @moonplan.Problem::new()
  let worker = problem.add_variable("worker", [1, 2]).unwrap()
  problem.add_constraint(@moonplan.Equal(worker, 2)).unwrap()
  let trace = problem.solve_with_trace(10).unwrap()
  assert_true(trace.outcome is @moonplan.Satisfied(_, _))
  assert_eq(trace.events, [
    @moonplan.TryValue("worker", 2, 0),
    @moonplan.SolutionFound(1, 1),
  ])
  assert_false(trace.truncated)
}

///|
test "records a dead end for an unsatisfiable model" {
  let problem = @moonplan.Problem::new()
  let worker = problem.add_variable("worker", [1]).unwrap()
  problem.add_constraint(@moonplan.Equal(worker, 1)).unwrap()
  problem.add_constraint(@moonplan.NotEqual(worker, 1)).unwrap()
  let trace = problem.solve_with_trace(10).unwrap()
  assert_true(trace.outcome is @moonplan.Unsatisfied(_))
  assert_eq(trace.events, [@moonplan.DeadEnd("worker", 0)])
}

///|
test "records failed branches before backtracking" {
  let problem = @moonplan.Problem::new()
  let a = problem.add_variable("a", [0, 1]).unwrap()
  let b = problem.add_variable("b", [0, 1]).unwrap()
  let c = problem.add_variable("c", [0, 1]).unwrap()
  problem.add_constraint(@moonplan.Different(a, b)).unwrap()
  problem.add_constraint(@moonplan.Different(b, c)).unwrap()
  problem.add_constraint(@moonplan.Different(a, c)).unwrap()
  let trace = problem.solve_with_trace(30).unwrap()
  assert_true(trace.outcome is @moonplan.Unsatisfied(_))
  assert_true(trace.events.contains(@moonplan.DeadEnd("c", 2)))
  assert_true(trace.events.contains(@moonplan.Backtrack("b", 1, 1)))
  assert_true(trace.events.contains(@moonplan.Backtrack("a", 0, 0)))
}

///|
test "truncates events without changing the search outcome" {
  let trace = queens_problem(4).solve_with_trace(2).unwrap()
  assert_true(trace.outcome is @moonplan.Satisfied(_, _))
  assert_eq(trace.events.length(), 2)
  assert_true(trace.truncated)
}

///|
test "exports trace events as JSON" {
  let problem = @moonplan.Problem::new()
  ignore(problem.add_variable("worker", [3]).unwrap())
  let trace = problem.solve_with_trace(10).unwrap()
  let output = @json.to_json(trace).stringify()
  assert_true(output.contains("TryValue"))
  assert_true(output.contains("SolutionFound"))
}

///|
test "rejects a non-positive trace event limit" {
  assert_true(
    @moonplan.Problem::new().solve_with_trace(0)
    is Err(@moonplan.InvalidTraceLimit(0)),
  )
}
