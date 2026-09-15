///|
test "solves with the degree and LCV strategy" {
  let problem = @moonplan.Problem::new()
  let first = problem.add_variable("first", [1, 0]).unwrap()
  let second = problem.add_variable("second", [0, 1, 2]).unwrap()
  problem.add_constraint(@moonplan.LessThan(first, second)).unwrap()
  match problem.solve_with_strategy(@moonplan.DegreeLcv) {
    @moonplan.Unsatisfied(_) => fail("the ordered pair must be solvable")
    @moonplan.Satisfied(solution, stats) => {
      assert_eq(solution.get("first"), Some(0))
      assert_eq(solution.get("second"), Some(1))
      assert_eq(stats.solutions, 1)
    }
  }
}

///|
test "enumerates the same solution set across search strategies" {
  let problem = @moonplan.Problem::new()
  let left = problem.add_variable("left", [0, 1]).unwrap()
  let right = problem.add_variable("right", [0, 1]).unwrap()
  problem.add_constraint(@moonplan.Different(left, right)).unwrap()
  let (mrv, _) = problem.solve_all_with_strategy(10, @moonplan.Mrv).unwrap()
  let (degree_lcv, _) = problem
    .solve_all_with_strategy(10, @moonplan.DegreeLcv)
    .unwrap()
  assert_eq(mrv.length(), 2)
  assert_eq(degree_lcv.length(), 2)
  assert_eq(mrv, degree_lcv)
}

///|
test "validates the solution limit for explicit strategies" {
  assert_true(
    @moonplan.Problem::new().solve_all_with_strategy(0, @moonplan.DegreeLcv)
    is Err(@moonplan.InvalidSolutionLimit(0)),
  )
}
