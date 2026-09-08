///|
fn queens_problem(size : Int) -> @moonplan.Problem {
  let problem = @moonplan.Problem::new()
  let queens : Array[@moonplan.Var] = []
  for column = 0; column < size; column = column + 1 {
    queens.push(
      problem
      .add_variable("q\{column}", @moonplan.int_domain(0, size - 1))
      .unwrap(),
    )
  }
  problem.add_constraint(@moonplan.AllDifferent(queens.copy())).unwrap()
  for left = 0; left < size; left = left + 1 {
    for right = left + 1; right < size; right = right + 1 {
      let delta = right - left
      problem
      .add_constraint(
        @moonplan.OffsetDifferent(queens[right], queens[left], delta),
      )
      .unwrap()
      problem
      .add_constraint(
        @moonplan.OffsetDifferent(queens[right], queens[left], -delta),
      )
      .unwrap()
    }
  }
  problem
}

///|
test "solves four queens" {
  match queens_problem(4).solve() {
    @moonplan.Unsatisfied(_) => fail("four queens must have a solution")
    @moonplan.Satisfied(solution, stats) => {
      assert_eq(solution.get("q0"), Some(1))
      assert_eq(solution.get("q1"), Some(3))
      assert_eq(solution.get("q2"), Some(0))
      assert_eq(solution.get("q3"), Some(2))
      assert_eq(stats.solutions, 1)
    }
  }
}

///|
test "enumerates both four queens solutions" {
  let (solutions, stats) = queens_problem(4).solve_all(10).unwrap()
  assert_eq(solutions.length(), 2)
  assert_eq(stats.solutions, 2)
}

///|
test "reports an unsatisfiable model" {
  let problem = @moonplan.Problem::new()
  let x = problem.add_variable("x", [1]).unwrap()
  problem.add_constraint(@moonplan.Equal(x, 1)).unwrap()
  problem.add_constraint(@moonplan.NotEqual(x, 1)).unwrap()
  assert_true(problem.solve() is @moonplan.Unsatisfied(_))
}

///|
test "solves a small staffing model" {
  let problem = @moonplan.Problem::new()
  // Worker ids: 0 = Ada, 1 = Bo, 2 = Chen.
  let reception = problem.add_variable("reception", [0, 1]).unwrap()
  let support = problem.add_variable("support", [1, 2]).unwrap()
  let on_call = problem.add_variable("on_call", [0, 2]).unwrap()
  problem
  .add_constraint(@moonplan.AllDifferent([reception, support, on_call]))
  .unwrap()
  match problem.solve() {
    @moonplan.Unsatisfied(_) => fail("staffing model must be satisfiable")
    @moonplan.Satisfied(solution, _) => {
      assert_eq(solution.get("reception"), Some(0))
      assert_eq(solution.get("support"), Some(1))
      assert_eq(solution.get("on_call"), Some(2))
    }
  }
}

///|
test "validates model boundaries" {
  let problem = @moonplan.Problem::new()
  assert_true(problem.add_variable("", [1]) is Err(@moonplan.EmptyName))
  ignore(problem.add_variable("x", [1]).unwrap())
  assert_true(
    problem.add_variable("x", [2]) is Err(@moonplan.DuplicateName("x")),
  )
}
