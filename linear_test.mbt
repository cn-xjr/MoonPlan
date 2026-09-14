///|
test "enforces a weighted resource budget" {
  let problem = @moonplan.Problem::new()
  let primary = problem.add_variable("primary", [0, 1]).unwrap()
  let optional = problem.add_variable("optional", [0, 1]).unwrap()
  problem
  .add_constraint(@moonplan.LinearAtMost([primary, optional], [6, 4], 6))
  .unwrap()
  problem.add_constraint(@moonplan.Equal(primary, 1)).unwrap()
  match problem.solve() {
    @moonplan.Unsatisfied(_) => fail("the primary allocation fits alone")
    @moonplan.Satisfied(solution, _) => {
      assert_eq(solution.get("primary"), Some(1))
      assert_eq(solution.get("optional"), Some(0))
    }
  }
}

///|
test "supports negative coefficients in a linear equality" {
  let problem = @moonplan.Problem::new()
  let supplied = problem.add_variable("supplied", [0, 1, 2, 3]).unwrap()
  let consumed = problem.add_variable("consumed", [0, 1, 2, 3]).unwrap()
  problem
  .add_constraint(@moonplan.LinearEquals([supplied, consumed], [2, -1], 1))
  .unwrap()
  problem.add_constraint(@moonplan.Equal(supplied, 2)).unwrap()
  match problem.solve() {
    @moonplan.Unsatisfied(_) => fail("the balance equation must be solvable")
    @moonplan.Satisfied(solution, _) => {
      assert_eq(solution.get("supplied"), Some(2))
      assert_eq(solution.get("consumed"), Some(3))
    }
  }
}

///|
test "detects an impossible weighted upper bound" {
  let problem = @moonplan.Problem::new()
  let units = problem.add_variable("units", [2, 3]).unwrap()
  problem.add_constraint(@moonplan.LinearAtMost([units], [3], 5)).unwrap()
  assert_true(problem.solve() is @moonplan.Unsatisfied(_))
}

///|
test "validates linear coefficient arity" {
  let problem = @moonplan.Problem::new()
  let left = problem.add_variable("left", [0, 1]).unwrap()
  let right = problem.add_variable("right", [0, 1]).unwrap()
  assert_true(
    problem.add_constraint(@moonplan.LinearEquals([left, right], [1], 0))
    is Err(@moonplan.InvalidCoefficientArity(2, 1)),
  )
}

///|
test "keeps linear terms stable after caller mutation" {
  let problem = @moonplan.Problem::new()
  let left = problem.add_variable("left", [1]).unwrap()
  let right = problem.add_variable("right", [2]).unwrap()
  let variables = [left, right]
  let coefficients = [1, 2]
  problem
  .add_constraint(@moonplan.LinearEquals(variables, coefficients, 5))
  .unwrap()
  variables[1] = left
  coefficients[1] = 1
  assert_true(problem.solve() is @moonplan.Satisfied(_, _))
}
