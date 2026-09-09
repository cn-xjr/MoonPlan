///|
test "finds an irreducible named conflict" {
  let problem = @moonplan.Problem::new()
  let worker = problem.add_variable("worker", [0, 1]).unwrap()
  let room = problem.add_variable("room", [1, 2]).unwrap()
  problem
  .add_named_constraint("assign Ada", @moonplan.Equal(worker, 0))
  .unwrap()
  problem
  .add_named_constraint("exclude Ada", @moonplan.NotEqual(worker, 0))
  .unwrap()
  problem
  .add_named_constraint("use room one", @moonplan.Equal(room, 1))
  .unwrap()
  match problem.explain() {
    @moonplan.Consistent(_) => fail("the model must be inconsistent")
    @moonplan.Inconsistent(report) => {
      assert_eq(report.items.length(), 2)
      assert_eq(report.items[0].index, 0)
      assert_eq(report.items[0].name, Some("assign Ada"))
      assert_eq(report.items[1].index, 1)
      assert_eq(report.items[1].name, Some("exclude Ada"))
      assert_eq(report.solver_runs, 4)
      assert_eq(problem.constraint_count(), 3)
      assert_true(problem.solve() is @moonplan.Unsatisfied(_))
    }
  }
}

///|
test "reports a satisfiable model as consistent" {
  let problem = @moonplan.Problem::new()
  let worker = problem.add_variable("worker", [0, 1]).unwrap()
  problem.add_constraint(@moonplan.Equal(worker, 1)).unwrap()
  assert_true(problem.explain() is @moonplan.Consistent(_))
}

///|
test "validates named constraint boundaries" {
  let problem = @moonplan.Problem::new()
  let worker = problem.add_variable("worker", [0]).unwrap()
  assert_true(
    problem.add_named_constraint("", @moonplan.Equal(worker, 0))
    is Err(@moonplan.EmptyConstraintName),
  )
  problem
  .add_named_constraint("assign worker", @moonplan.Equal(worker, 0))
  .unwrap()
  assert_true(
    problem.add_named_constraint("assign worker", @moonplan.NotEqual(worker, 0))
    is Err(@moonplan.DuplicateConstraintName("assign worker")),
  )
}
