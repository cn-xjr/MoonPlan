///|
test "keeps a value count inside inclusive bounds" {
  let problem = @moonplan.Problem::new()
  let first = problem.add_variable("first", [0, 1]).unwrap()
  let second = problem.add_variable("second", [0, 1]).unwrap()
  let third = problem.add_variable("third", [0, 1]).unwrap()
  problem
  .add_constraint(@moonplan.CountBetween([first, second, third], 0, 1, 2))
  .unwrap()
  let (solutions, _) = problem.solve_all(10).unwrap()
  assert_eq(solutions.length(), 6)
}

///|
test "prunes when a minimum count can no longer be reached" {
  let problem = @moonplan.Problem::new()
  let first = problem.add_variable("first", [1]).unwrap()
  let second = problem.add_variable("second", [0, 1]).unwrap()
  problem
  .add_constraint(@moonplan.CountBetween([first, second], 0, 2, 2))
  .unwrap()
  assert_true(problem.solve() is @moonplan.Unsatisfied(_))
}

///|
test "validates count bounds" {
  let problem = @moonplan.Problem::new()
  let value = problem.add_variable("value", [0, 1]).unwrap()
  assert_true(
    problem.add_constraint(@moonplan.CountBetween([value], 0, -1, 1))
    is Err(@moonplan.InvalidCountBounds(-1, 1)),
  )
  assert_true(
    problem.add_constraint(@moonplan.CountBetween([value], 0, 2, 1))
    is Err(@moonplan.InvalidCountBounds(2, 1)),
  )
}

///|
test "keeps count variables stable after caller mutation" {
  let problem = @moonplan.Problem::new()
  let first = problem.add_variable("first", [0]).unwrap()
  let second = problem.add_variable("second", [1]).unwrap()
  let variables = [first, second]
  problem.add_constraint(@moonplan.CountBetween(variables, 0, 1, 1)).unwrap()
  variables[0] = second
  assert_true(problem.solve() is @moonplan.Satisfied(_, _))
}
