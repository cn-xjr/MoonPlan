///|
test "solves an allowed tuple table" {
  let problem = @moonplan.Problem::new()
  let day = problem.add_variable("day", [0, 1]).unwrap()
  let worker = problem.add_variable("worker", [10, 20]).unwrap()
  let room = problem.add_variable("room", [100, 200]).unwrap()
  problem
  .add_named_constraint(
    "rotation templates",
    @moonplan.AllowedTuples([day, worker, room], [[0, 10, 100], [1, 20, 200]]),
  )
  .unwrap()
  problem.add_constraint(@moonplan.Equal(day, 1)).unwrap()
  match problem.solve() {
    @moonplan.Unsatisfied(_) => fail("the second rotation must be available")
    @moonplan.Satisfied(solution, _) => {
      assert_eq(solution.get("day"), Some(1))
      assert_eq(solution.get("worker"), Some(20))
      assert_eq(solution.get("room"), Some(200))
    }
  }
}

///|
test "prunes a table when no row matches the partial assignment" {
  let problem = @moonplan.Problem::new()
  let day = problem.add_variable("day", [0, 1]).unwrap()
  let worker = problem.add_variable("worker", [10, 20]).unwrap()
  problem
  .add_constraint(@moonplan.AllowedTuples([day, worker], [[0, 10], [1, 20]]))
  .unwrap()
  problem.add_constraint(@moonplan.Equal(day, 1)).unwrap()
  problem.add_constraint(@moonplan.Equal(worker, 10)).unwrap()
  assert_true(problem.solve() is @moonplan.Unsatisfied(_))
}

///|
test "validates tuple table shape and domain values" {
  let problem = @moonplan.Problem::new()
  let day = problem.add_variable("day", [0, 1]).unwrap()
  let worker = problem.add_variable("worker", [10, 20]).unwrap()
  assert_true(
    problem.add_constraint(@moonplan.AllowedTuples([day, worker], []))
    is Err(@moonplan.EmptyTupleTable),
  )
  assert_true(
    problem.add_constraint(@moonplan.AllowedTuples([day, worker], [[0]]))
    is Err(@moonplan.InvalidTupleArity(0, 2, 1)),
  )
  assert_true(
    problem.add_constraint(@moonplan.AllowedTuples([day, worker], [[0, 99]]))
    is Err(@moonplan.TupleValueOutsideDomain(0, "worker", 99)),
  )
  assert_true(
    problem.add_constraint(
      @moonplan.AllowedTuples([day, worker], [[0, 10], [0, 10]]),
    )
    is Err(@moonplan.DuplicateTuple(0, 1)),
  )
}

///|
test "keeps table constraints stable after caller mutation" {
  let problem = @moonplan.Problem::new()
  let day = problem.add_variable("day", [0, 1]).unwrap()
  let worker = problem.add_variable("worker", [10, 20]).unwrap()
  let variables = [day, worker]
  let tuples = [[0, 10], [1, 20]]
  problem.add_constraint(@moonplan.AllowedTuples(variables, tuples)).unwrap()
  variables[0] = worker
  tuples[0][1] = 20
  match problem.solve() {
    @moonplan.Unsatisfied(_) => fail("the copied table must remain satisfiable")
    @moonplan.Satisfied(solution, _) => {
      assert_eq(solution.get("day"), Some(0))
      assert_eq(solution.get("worker"), Some(10))
    }
  }
}
